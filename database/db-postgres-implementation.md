# GTS eStore — Implementación PostgreSQL

> Base de datos del sistema ecommerce de GreenTek Solutions.  
> Stack: PostgreSQL 16 · NestJS (backend) · Next.js (frontend)  
> Esquema de referencia: `database/final-database-schema.md`  
> SRS: `srs/SRS_gts_eStore_v5.md`

---

## Arquitectura de schemas

| Schema | Dominio | Tablas |
|--------|---------|--------|
| `catalog` | Listings, catálogo, precios, stock, canales de venta | 15 tablas |
| `commerce` | Usuarios, carrito, órdenes, pagos, envíos, config | 16 tablas |
| `infra` | Async workers, webhooks, notificaciones, idempotencia | 6 tablas |

---

## Convenciones globales

- **PKs:** `UUID` generado con `gen_random_uuid()` en dev. En producción usar `pg_uuidv7` para UUID v7 (ordenado por tiempo).
- **FKs al CRM (externas):** tipo `INT` — referencian tablas del sistema CRM de GreenTek (Angular), no se declaran como FK constraint.
- **Timestamps:** `TIMESTAMPTZ` (UTC) en todas las tablas.
- **Soft delete:** varía por tabla — ver columna `deleted_at`, `is_active` o `status = inactive` según el contexto.
- **Tablas append-only** (nunca UPDATE ni DELETE): `listing_stock_movements`, `order_status_history`, `payment_intent_events`, `price_config_history`.
- **Precios y montos:** `NUMERIC(10,2)`. Porcentajes de descuento: `NUMERIC(5,4)` (ej. `0.0500` = 5%).
- **FKs cross-schema:** NestJS las resuelve a nivel de aplicación con los IDs UUID correspondientes.

---

## SQL — Implementación completa

### 1. Setup inicial

```sql
-- Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- En producción para UUID v7:
-- CREATE EXTENSION IF NOT EXISTS "pg_uuidv7";

-- Schemas
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS commerce;
CREATE SCHEMA IF NOT EXISTS infra;
```

---

### 2. Schema: `catalog`

#### Tipos enum

```sql
CREATE TYPE catalog.listing_condition_enum  AS ENUM ('EXCELLENT', 'GOOD', 'FAIR');
CREATE TYPE catalog.listing_type_enum       AS ENUM ('LISTING', 'TEMPLATE');
CREATE TYPE catalog.listing_status_enum     AS ENUM (
    'draft', 'ready', 'scheduled', 'published',
    'partially_published', 'out_of_stock', 'unpublished', 'inactive'
);
CREATE TYPE catalog.source_type_enum        AS ENUM ('ORIGINAL', 'FROM_TEMPLATE', 'FROM_COPY');
CREATE TYPE catalog.r2v3_sanitization_enum  AS ENUM ('NON_DATA');
CREATE TYPE catalog.r2v3_cosmetic_enum      AS ENUM ('C1', 'C2', 'C3');
CREATE TYPE catalog.r2v3_functionality_enum AS ENUM ('F1', 'F2', 'F3');
CREATE TYPE catalog.shipping_policy_enum    AS ENUM ('NORMAL', 'FREIGHT', 'FREE');
CREATE TYPE catalog.variation_status_enum   AS ENUM ('active', 'out_of_stock', 'inactive');
CREATE TYPE catalog.sync_status_enum        AS ENUM (
    'not_requested', 'scheduled', 'pending', 'success', 'failed'
);
CREATE TYPE catalog.movement_type_enum      AS ENUM (
    'INITIAL', 'SALE_EBAY', 'SALE_GTS_STORE',
    'RETURN_EBAY', 'RETURN_GTS_STORE', 'CANCELLED_SALE',
    'MANUAL_ADD', 'MANUAL_REMOVE', 'ADJUSTMENT',
    'SYNC_EBAY', 'SYNC_GTS_STORE',
    'LISTING_DEACTIVATED', 'LISTING_REACTIVATED'
);
CREATE TYPE catalog.stock_channel_enum          AS ENUM ('EBAY', 'GTS_STORE', 'MANUAL', 'SYSTEM');
CREATE TYPE catalog.inventory_link_status_enum  AS ENUM ('available', 'reserved', 'sold');
CREATE TYPE catalog.restriction_type_enum       AS ENUM ('STATE', 'ZIP_CODE', 'COUNTRY', 'MILITARY');
```

#### Tablas

```sql
-- -------------------------------------------------------------------
-- catalog.gts_categories
-- Categorías planas de la GTS Store (no eBay). Se desactivan, nunca
-- se borran, para no romper FKs existentes.
-- -------------------------------------------------------------------
CREATE TABLE catalog.gts_categories (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    sort_order  INT         NOT NULL DEFAULT 0,
    icon        VARCHAR(100),
    image       VARCHAR(500),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- catalog.listings
-- Entidad central del catálogo. Cubre listing simple, con variaciones
-- y templates. nullable en la mayoría de campos para soportar borradores
-- incompletos.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listings (
    id                      UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    title                   VARCHAR(255),
    description             TEXT,
    condition               catalog.listing_condition_enum,
    listing_type            catalog.listing_type_enum       NOT NULL,
    status                  catalog.listing_status_enum     NOT NULL DEFAULT 'draft',
    source_type             catalog.source_type_enum        NOT NULL DEFAULT 'ORIGINAL',
    source_id               UUID                            REFERENCES catalog.listings(id),
    is_variation            BOOLEAN                         NOT NULL DEFAULT FALSE,
    gts_category_id         UUID                            REFERENCES catalog.gts_categories(id),
    currency                VARCHAR(3)                      NOT NULL DEFAULT 'USD',
    important_notes         JSONB,
    included_items          JSONB,
    r2v3_data_sanitization  catalog.r2v3_sanitization_enum,
    r2v3_cosmetic           catalog.r2v3_cosmetic_enum,
    r2v3_functionality      catalog.r2v3_functionality_enum,
    shipping_policy         catalog.shipping_policy_enum,
    fixed_shipping_cost     NUMERIC(10,2),
    weight_value            NUMERIC(10,3),
    weight_unit             VARCHAR(3),
    dim_length              NUMERIC(10,3),
    dim_width               NUMERIC(10,3),
    dim_height              NUMERIC(10,3),
    dim_unit                VARCHAR(2),
    ebay_category_id        VARCHAR(50),
    ebay_category_name      VARCHAR(255),
    shared_aspects          JSONB,
    meta_title              VARCHAR(255),
    meta_description        TEXT,
    slug                    VARCHAR(255)                    UNIQUE,
    units_sold              INT                             NOT NULL DEFAULT 0,
    draft_progress          JSONB                           NOT NULL DEFAULT '{}',
    created_by              INT                             NOT NULL,
    created_at              TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- catalog.listing_pricing
-- Precio del listing simple (is_variation = false). 1-1 con listings.
-- Los porcentajes son snapshots del config global al crear el listing.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_pricing (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id          UUID            NOT NULL UNIQUE REFERENCES catalog.listings(id) ON DELETE CASCADE,
    sku                 VARCHAR(100),
    base_price          NUMERIC(10,2),
    ebay_discount_pct   NUMERIC(5,4),
    ebay_price          NUMERIC(10,2),
    store_discount_pct  NUMERIC(5,4),
    store_price         NUMERIC(10,2)
);

-- -------------------------------------------------------------------
-- catalog.listing_variation_axes
-- Ejes de variación del listing (ej. Color, RAM). Solo para
-- is_variation = true.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_variation_axes (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id    UUID        NOT NULL REFERENCES catalog.listings(id) ON DELETE CASCADE,
    aspect_name   VARCHAR(100) NOT NULL,
    values        JSONB       NOT NULL,
    affects_image BOOLEAN     NOT NULL DEFAULT FALSE,
    sort_order    INT         NOT NULL DEFAULT 0
);

-- -------------------------------------------------------------------
-- catalog.listing_variations
-- Una fila = un SKU con precio propio. Solo para is_variation = true.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_variations (
    id                  UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id          UUID                            NOT NULL REFERENCES catalog.listings(id) ON DELETE CASCADE,
    sku                 VARCHAR(100),
    label               VARCHAR(255),
    aspects             JSONB,
    base_price          NUMERIC(10,2),
    ebay_discount_pct   NUMERIC(5,4),
    ebay_price          NUMERIC(10,2),
    store_discount_pct  NUMERIC(5,4),
    store_price         NUMERIC(10,2),
    status              catalog.variation_status_enum   NOT NULL DEFAULT 'active',
    sort_order          INT                             NOT NULL DEFAULT 0
);

-- -------------------------------------------------------------------
-- catalog.listing_images
-- Imágenes del listing. listing_variation_id = NULL → imagen de grupo.
-- listing_variation_id NOT NULL → imagen propia de esa variación.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_images (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id              UUID        NOT NULL REFERENCES catalog.listings(id) ON DELETE CASCADE,
    listing_variation_id    UUID        REFERENCES catalog.listing_variations(id) ON DELETE CASCADE,
    original_url            VARCHAR(500) NOT NULL,
    ebay_url                VARCHAR(500),
    gts_store_url           VARCHAR(500),
    ebay_url_expires_at     DATE,
    sort_order              INT         NOT NULL DEFAULT 0,
    is_primary              BOOLEAN     NOT NULL DEFAULT FALSE
);

-- -------------------------------------------------------------------
-- catalog.listing_inventory_links
-- Cada fila = 1 ítem físico del CRM vinculado al listing.
-- crm_inventory_id UNIQUE → un ítem CRM solo puede estar en 1 listing.
-- status: permite derivar stock disponible por bodega en tiempo real
-- para checkout multi-bodega (RF-LOG-006-4).
-- Query por bodega: COUNT(*) WHERE listing_id=X AND crm_warehouse_id=Y
--                  AND status='available'
-- Se actualiza en la misma transacción que listing_stock e
-- inventory_reservations (saga checkout).
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_inventory_links (
    id                      UUID                                PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id              UUID                                NOT NULL REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    listing_variation_id    UUID                                REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    crm_inventory_id        INT                                 NOT NULL UNIQUE,
    crm_po_id               VARCHAR(100),
    crm_po_line             VARCHAR(100),
    crm_iq_id               VARCHAR(100),
    crm_warehouse_id        INT                                 NOT NULL,
    status                  catalog.inventory_link_status_enum  NOT NULL DEFAULT 'available'
);

-- -------------------------------------------------------------------
-- catalog.listing_stock
-- Snapshot del stock disponible. Una fila por listing (simple) o por
-- variación. Se actualiza en la misma transacción que
-- listing_stock_movements para garantizar consistencia.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_stock (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id              UUID        NOT NULL REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    listing_variation_id    UUID        REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    quantity_available      INT         NOT NULL DEFAULT 0 CHECK (quantity_available >= 0),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Índices únicos parciales para manejar NULL en listing_variation_id
CREATE UNIQUE INDEX uq_listing_stock_single
    ON catalog.listing_stock (listing_id)
    WHERE listing_variation_id IS NULL;
CREATE UNIQUE INDEX uq_listing_stock_variation
    ON catalog.listing_stock (listing_id, listing_variation_id)
    WHERE listing_variation_id IS NOT NULL;

-- -------------------------------------------------------------------
-- catalog.listing_stock_movements
-- Ledger append-only de cambios de stock. Nunca se actualiza ni borra.
-- SUM(quantity_delta) debe coincidir con listing_stock.quantity_available.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_stock_movements (
    id                      UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id              UUID                            NOT NULL REFERENCES catalog.listings(id),
    listing_variation_id    UUID                            REFERENCES catalog.listing_variations(id),
    quantity_delta          INT                             NOT NULL,
    quantity_after          INT                             NOT NULL CHECK (quantity_after >= 0),
    movement_type           catalog.movement_type_enum      NOT NULL,
    channel                 catalog.stock_channel_enum,
    reference_id            VARCHAR(255),
    notes                   TEXT,
    created_by              INT,
    created_at              TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- catalog.listing_channel_ebay
-- Configuración y estado de sincronización del canal eBay por listing.
-- deleted_at: soft delete que conserva el historial de configuración.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_channel_ebay (
    id                              UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id                      UUID                        NOT NULL UNIQUE REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    ebay_linked_account_id          INT                         NOT NULL,
    ebay_listing_id                 VARCHAR(50),
    ebay_sku                        VARCHAR(100),
    ebay_offer_id                   VARCHAR(50),
    ebay_inventory_group_key        VARCHAR(100),
    ebay_merchant_location_key      VARCHAR(100),
    ebay_fulfillment_policy_id      VARCHAR(50),
    ebay_payment_policy_id          VARCHAR(50),
    ebay_return_policy_id           VARCHAR(50),
    ebay_store_category_names       JSONB                       NOT NULL DEFAULT '[]',
    marketplace_id                  VARCHAR(20)                 NOT NULL DEFAULT 'EBAY_US',
    ebay_listing_format             VARCHAR(20)                 NOT NULL DEFAULT 'FIXED_PRICE',
    ebay_listing_duration           VARCHAR(10)                 NOT NULL DEFAULT 'GTC',
    ebay_listing_description_html   TEXT,
    scheduled_at                    TIMESTAMPTZ,
    sync_status                     catalog.sync_status_enum    NOT NULL DEFAULT 'not_requested',
    sync_error_message              TEXT,
    published_at                    TIMESTAMPTZ,
    last_synced_at                  TIMESTAMPTZ,
    deleted_at                      TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- catalog.listing_channel_ebay_variations
-- Un offer de eBay por variación. Solo para is_variation = true.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_channel_ebay_variations (
    id                          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_channel_ebay_id     UUID        NOT NULL REFERENCES catalog.listing_channel_ebay(id) ON DELETE CASCADE,
    listing_variation_id        UUID        NOT NULL REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    ebay_sku                    VARCHAR(100) NOT NULL,
    ebay_offer_id               VARCHAR(50)
);

-- -------------------------------------------------------------------
-- catalog.listing_channel_gts_store
-- Configuración y estado de sincronización del canal GTS Store.
-- deleted_at: soft delete que conserva el historial de configuración.
-- -------------------------------------------------------------------
CREATE TABLE catalog.listing_channel_gts_store (
    id                      UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id              UUID                        NOT NULL UNIQUE REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    gts_store_product_id    INT,
    gts_store_slug          VARCHAR(255),
    gts_store_url           VARCHAR(500),
    scheduled_at            TIMESTAMPTZ,
    sync_status             catalog.sync_status_enum    NOT NULL DEFAULT 'not_requested',
    sync_error_message      TEXT,
    published_at            TIMESTAMPTZ,
    last_synced_at          TIMESTAMPTZ,
    deleted_at              TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- catalog.price_config
-- Configuración global de descuentos por canal. Los porcentajes se
-- copian como snapshot al listing al crearlo; cambios futuros no
-- afectan listings existentes.
-- -------------------------------------------------------------------
CREATE TABLE catalog.price_config (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    channel                 VARCHAR(20)     NOT NULL,
    ebay_linked_account_id  INT,
    discount_pct            NUMERIC(5,4)    NOT NULL,
    updated_by              INT             NOT NULL,
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- catalog.price_config_history
-- Ledger append-only de cambios al descuento global. Nunca se borra.
-- -------------------------------------------------------------------
CREATE TABLE catalog.price_config_history (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    channel                 VARCHAR(20)     NOT NULL,
    ebay_linked_account_id  INT,
    discount_pct_previous   NUMERIC(5,4)    NOT NULL,
    discount_pct_new        NUMERIC(5,4)    NOT NULL,
    changed_by              INT             NOT NULL,
    changed_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    notes                   TEXT
);

-- -------------------------------------------------------------------
-- catalog.shipping_restrictions
-- Lista negra de ubicaciones de envío configurada por el admin.
-- is_active = false desactiva sin borrar (RF-LOG-002).
-- -------------------------------------------------------------------
CREATE TABLE catalog.shipping_restrictions (
    id                  UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    restriction_type    catalog.restriction_type_enum   NOT NULL,
    value               VARCHAR(50)                     NOT NULL,
    label               VARCHAR(100)                    NOT NULL,
    is_active           BOOLEAN                         NOT NULL DEFAULT TRUE,
    created_by          INT                             NOT NULL,
    created_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);
```

---

### 3. Schema: `commerce`

#### Tipos enum

```sql
CREATE TYPE commerce.user_status_enum           AS ENUM ('active', 'blocked');
CREATE TYPE commerce.cart_status_enum           AS ENUM ('active', 'merged', 'expired');
CREATE TYPE commerce.auth_token_type_enum       AS ENUM ('verify_email', 'reset_password');
CREATE TYPE commerce.customer_type_enum         AS ENUM ('guest', 'registered');
CREATE TYPE commerce.order_status_enum          AS ENUM (
    'pending', 'paid', 'processing', 'shipped', 'delivered',
    'completed', 'cancelled', 'partially_returned', 'fully_returned'
);
CREATE TYPE commerce.payment_status_enum        AS ENUM (
    'created', 'requires_payment_method', 'requires_confirmation',
    'requires_action', 'processing', 'succeeded', 'failed', 'cancelled'
);
CREATE TYPE commerce.shipment_status_enum       AS ENUM (
    'pending', 'label_generated', 'shipped', 'delivered', 'failed'
);
CREATE TYPE commerce.reservation_status_enum    AS ENUM ('pending', 'confirmed', 'released', 'expired');
CREATE TYPE commerce.saga_status_enum           AS ENUM (
    'started', 'inventory_reserved', 'payment_processing',
    'succeeded', 'compensating', 'compensated', 'failed'
);
CREATE TYPE commerce.order_history_source_enum  AS ENUM ('admin', 'system', 'shipengine_webhook');
CREATE TYPE commerce.push_browser_enum          AS ENUM ('chrome', 'firefox', 'safari', 'edge', 'other');
```

#### Tablas

```sql
-- -------------------------------------------------------------------
-- commerce.users
-- Clientes registrados del e-commerce. Independiente del CRM.
-- Los admins del CRM NO están en esta tabla.
-- deleted_at: soft delete, el email queda bloqueado.
-- -------------------------------------------------------------------
CREATE TABLE commerce.users (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name          VARCHAR(100)                NOT NULL,
    last_name           VARCHAR(100)                NOT NULL,
    email               VARCHAR(255)                NOT NULL UNIQUE,
    password_hash       TEXT                        NOT NULL,
    phone               VARCHAR(30),
    email_verified      BOOLEAN                     NOT NULL DEFAULT FALSE,
    email_verified_at   TIMESTAMPTZ,
    status              commerce.user_status_enum   NOT NULL DEFAULT 'active',
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- commerce.user_crm_links
-- Vínculo opcional entre cuenta del e-commerce y cuenta del CRM.
-- Se crea tras verificación mediante código generado en el CRM.
-- -------------------------------------------------------------------
CREATE TABLE commerce.user_crm_links (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES commerce.users(id) ON DELETE CASCADE,
    crm_email           VARCHAR(255) NOT NULL,
    crm_reference_id    VARCHAR(100),
    linked_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.user_addresses
-- Direcciones guardadas de usuarios registrados. Máximo configurable
-- en system_config (max_addresses_per_user = 20 por defecto).
-- -------------------------------------------------------------------
CREATE TABLE commerce.user_addresses (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES commerce.users(id) ON DELETE CASCADE,
    recipient_name  VARCHAR(255) NOT NULL,
    phone           VARCHAR(30),
    address_line1   VARCHAR(255) NOT NULL,
    address_line2   VARCHAR(255),
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    postal_code     VARCHAR(20)  NOT NULL,
    country         VARCHAR(100) NOT NULL DEFAULT 'US',
    is_default      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.user_notification_preferences
-- Una fila por usuario. email_security NO puede desactivarse desde
-- la UI — protege tokens de verificación y reset de contraseña.
-- No existe push_security — las notificaciones de seguridad son
-- exclusivamente por email.
-- -------------------------------------------------------------------
CREATE TABLE commerce.user_notification_preferences (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID        NOT NULL UNIQUE REFERENCES commerce.users(id) ON DELETE CASCADE,
    email_order_updates     BOOLEAN     NOT NULL DEFAULT TRUE,
    email_shipping_updates  BOOLEAN     NOT NULL DEFAULT TRUE,
    email_marketing         BOOLEAN     NOT NULL DEFAULT FALSE,
    email_security          BOOLEAN     NOT NULL DEFAULT TRUE,
    push_order_updates      BOOLEAN     NOT NULL DEFAULT TRUE,
    push_shipping_updates   BOOLEAN     NOT NULL DEFAULT TRUE,
    push_marketing          BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.user_push_subscriptions
-- Suscripciones Web Push del usuario por browser (PWA).
-- endpoint: URL del push service del browser — UNIQUE, varía por
--   browser/dispositivo. Chrome → FCM, Firefox → Mozilla Push, etc.
-- p256dh: clave pública de cifrado de la PushSubscription.
-- auth: secreto de autenticación de la PushSubscription.
-- El backend usa la librería web-push (VAPID) para enviar al endpoint.
-- is_active = FALSE cuando el push service retorna HTTP 410 Gone
--   (suscripción expirada o revocada por el usuario).
-- -------------------------------------------------------------------
CREATE TABLE commerce.user_push_subscriptions (
    id              UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID                            NOT NULL REFERENCES commerce.users(id) ON DELETE CASCADE,
    endpoint        TEXT                            NOT NULL UNIQUE,
    p256dh          TEXT                            NOT NULL,
    auth            TEXT                            NOT NULL,
    browser         commerce.push_browser_enum      NOT NULL DEFAULT 'other',
    is_active       BOOLEAN                         NOT NULL DEFAULT TRUE,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.auth_tokens
-- Tokens de verificación de email y recuperación de contraseña.
-- Se almacena el hash, nunca el token en texto plano.
-- -------------------------------------------------------------------
CREATE TABLE commerce.auth_tokens (
    id          UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID                            NOT NULL REFERENCES commerce.users(id) ON DELETE CASCADE,
    type        commerce.auth_token_type_enum   NOT NULL,
    token_hash  TEXT                            NOT NULL,
    expires_at  TIMESTAMPTZ                     NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.carts
-- Carrito para usuarios registrados y guest.
-- user_id = NULL → carrito guest identificado por el UUID del carrito
-- (almacenado en cookie). Expira en 7 días para guests.
-- -------------------------------------------------------------------
CREATE TABLE commerce.carts (
    id          UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID                        REFERENCES commerce.users(id) ON DELETE SET NULL,
    status      commerce.cart_status_enum   NOT NULL DEFAULT 'active',
    expires_at  TIMESTAMPTZ                 NOT NULL,
    created_at  TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.cart_items
-- price_snapshot: precio informativo al agregar. El precio final al
-- pagar siempre se recalcula desde el listing vigente.
-- -------------------------------------------------------------------
CREATE TABLE commerce.cart_items (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id                 UUID            NOT NULL REFERENCES commerce.carts(id) ON DELETE CASCADE,
    listing_id              UUID            NOT NULL REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    listing_variation_id    UUID            REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    quantity                INT             NOT NULL CHECK (quantity > 0),
    price_snapshot          NUMERIC(10,2)   NOT NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.orders
-- Snapshot completo del cliente e ítems. No depende de que el listing
-- exista después de la compra (integridad histórica contable).
-- visible_order_id: formato GTS-YYYY-{so_id}, se genera SOLO al
-- recibir so_id del CRM.
-- label_generated: cualquier label generada bloquea cancelación total.
-- -------------------------------------------------------------------
CREATE TABLE commerce.orders (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    visible_order_id    VARCHAR(50)                 UNIQUE,
    so_id               VARCHAR(50),
    user_id             UUID                        REFERENCES commerce.users(id) ON DELETE SET NULL,
    customer_first_name VARCHAR(100)                NOT NULL,
    customer_last_name  VARCHAR(100)                NOT NULL,
    customer_email      VARCHAR(255)                NOT NULL,
    customer_phone      VARCHAR(30),
    customer_type       commerce.customer_type_enum NOT NULL,
    status              commerce.order_status_enum  NOT NULL DEFAULT 'pending',
    currency            VARCHAR(3)                  NOT NULL DEFAULT 'USD',
    subtotal            NUMERIC(10,2)               NOT NULL,
    shipping_cost       NUMERIC(10,2)               NOT NULL,
    tax_amount          NUMERIC(10,2)               NOT NULL,
    total               NUMERIC(10,2)               NOT NULL,
    label_generated     BOOLEAN                     NOT NULL DEFAULT FALSE,
    label_generated_at  TIMESTAMPTZ,
    has_stock_conflict  BOOLEAN                     NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.order_addresses
-- Snapshot de dirección de envío y facturación al momento del checkout.
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_addresses (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID        NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    type            VARCHAR(20) NOT NULL CHECK (type IN ('shipping', 'billing')),
    recipient_name  VARCHAR(255) NOT NULL,
    phone           VARCHAR(30),
    address_line1   VARCHAR(255) NOT NULL,
    address_line2   VARCHAR(255),
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    postal_code     VARCHAR(20)  NOT NULL,
    country         VARCHAR(100) NOT NULL
);

-- -------------------------------------------------------------------
-- commerce.order_items
-- Líneas de la orden con snapshot completo del producto al comprar.
-- unit_price: store_price vigente al momento del checkout.
-- crm_warehouse_id: bodega de origen del ítem al hacer checkout.
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_items (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID            NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    listing_id              UUID            NOT NULL REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    listing_variation_id    UUID            REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    product_name            VARCHAR(255)    NOT NULL,
    product_sku             VARCHAR(100),
    product_condition       VARCHAR(50),
    quantity                INT             NOT NULL CHECK (quantity > 0),
    unit_price              NUMERIC(10,2)   NOT NULL,
    subtotal                NUMERIC(10,2)   NOT NULL,
    crm_warehouse_id        INT             NOT NULL
);

-- -------------------------------------------------------------------
-- commerce.order_shipments
-- Un shipment por bodega involucrada. label_generated_at activa
-- orders.label_generated = true en trigger o lógica de aplicación.
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_shipments (
    id                      UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID                            NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    crm_warehouse_id        INT                             NOT NULL,
    status                  commerce.shipment_status_enum   NOT NULL DEFAULT 'pending',
    carrier                 VARCHAR(50),
    service                 VARCHAR(100),
    shipping_cost           NUMERIC(10,2)                   NOT NULL,
    insurance_selected      BOOLEAN                         NOT NULL DEFAULT FALSE,
    insurance_cost          NUMERIC(10,2),
    tracking_number         VARCHAR(100),
    tracking_url            VARCHAR(500),
    label_url               VARCHAR(500),
    shipengine_shipment_id  VARCHAR(100),
    label_generated_at      TIMESTAMPTZ,
    shipped_at              TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ                     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.order_shipment_items
-- Tabla puente order_items ↔ order_shipments. Necesaria para emails
-- por shipment y detalle del comprobante por bodega.
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_shipment_items (
    id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    order_shipment_id   UUID    NOT NULL REFERENCES commerce.order_shipments(id) ON DELETE RESTRICT,
    order_item_id       UUID    NOT NULL REFERENCES commerce.order_items(id) ON DELETE RESTRICT,
    quantity            INT     NOT NULL CHECK (quantity > 0)
);

-- -------------------------------------------------------------------
-- commerce.payment_intents
-- Ciclo de vida del pago. Diseño provider-agnostic (Stripe en V1).
-- idempotency_key: evita doble cobro en resubmits del cliente.
-- client_secret: solo para frontend Stripe SDK (3DS) — nunca exponer
-- en listados ni logs.
-- retry_count / max_retries: gestionados por el PaymentWorker.
-- -------------------------------------------------------------------
CREATE TABLE commerce.payment_intents (
    id                          UUID                            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                    UUID                            NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    idempotency_key             VARCHAR(255)                    NOT NULL UNIQUE,
    provider                    VARCHAR(50)                     NOT NULL DEFAULT 'stripe',
    provider_payment_intent_id  VARCHAR(100)                    NOT NULL UNIQUE,
    provider_charge_id          VARCHAR(100),
    amount                      NUMERIC(10,2)                   NOT NULL,
    currency                    VARCHAR(3)                      NOT NULL DEFAULT 'USD',
    status                      commerce.payment_status_enum    NOT NULL DEFAULT 'created',
    payment_method_type         VARCHAR(50),
    card_last4                  VARCHAR(4),
    card_brand                  VARCHAR(20),
    client_secret               TEXT,
    failure_code                VARCHAR(100),
    failure_message             TEXT,
    retry_count                 INT                             NOT NULL DEFAULT 0,
    max_retries                 INT                             NOT NULL DEFAULT 3,
    next_retry_at               TIMESTAMPTZ,
    refunded_amount             NUMERIC(10,2)                   NOT NULL DEFAULT 0,
    metadata                    JSONB,
    created_at                  TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ                     NOT NULL DEFAULT NOW(),
    deleted_at                  TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- commerce.order_status_history
-- Ledger append-only de transiciones de estado. Nunca se actualiza.
-- changed_by = NULL → cambio automático por sistema o webhook.
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_status_history (
    id          UUID                                PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID                                NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    status      VARCHAR(50)                         NOT NULL,
    changed_by  UUID                                REFERENCES commerce.users(id) ON DELETE SET NULL,
    source      commerce.order_history_source_enum  NOT NULL,
    notes       TEXT,
    created_at  TIMESTAMPTZ                         NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.inventory_reservations
-- Ítems reservados durante el flujo Saga de checkout.
-- crm_inventory_id: ítem físico específico reservado.
-- expires_at: auto-release si el checkout no completa (15 min).
-- -------------------------------------------------------------------
CREATE TABLE commerce.inventory_reservations (
    id                      UUID                                PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID                                NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    listing_id              UUID                                NOT NULL REFERENCES catalog.listings(id) ON DELETE RESTRICT,
    listing_variation_id    UUID                                REFERENCES catalog.listing_variations(id) ON DELETE RESTRICT,
    crm_inventory_id        INT                                 NOT NULL,
    quantity                INT                                 NOT NULL CHECK (quantity > 0),
    status                  commerce.reservation_status_enum    NOT NULL DEFAULT 'pending',
    expires_at              TIMESTAMPTZ                         NOT NULL,
    released_at             TIMESTAMPTZ,
    release_reason          VARCHAR(50),
    created_at              TIMESTAMPTZ                         NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ                         NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.saga_instances
-- Estado persistido del Saga Orchestrator para recuperación tras
-- crashes. steps: log de cada paso con estado y error si aplica.
-- -------------------------------------------------------------------
CREATE TABLE commerce.saga_instances (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    saga_type           VARCHAR(50)                 NOT NULL,
    order_id            UUID                        NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    status              commerce.saga_status_enum   NOT NULL DEFAULT 'started',
    current_step        VARCHAR(100),
    steps               JSONB                       NOT NULL DEFAULT '[]',
    compensation_steps  JSONB,
    failure_reason      TEXT,
    started_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.order_return_metadata
-- Metadata de devolución registrada manualmente por el admin.
-- returned_items: [{order_item_id, quantity, notes}]
-- -------------------------------------------------------------------
CREATE TABLE commerce.order_return_metadata (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID            NOT NULL UNIQUE REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    return_type     VARCHAR(20)     NOT NULL CHECK (return_type IN ('partial', 'full')),
    return_reason   TEXT,
    returned_items  JSONB,
    refund_amount   NUMERIC(10,2),
    refund_method   VARCHAR(50),
    received_at     TIMESTAMPTZ,
    processed_by    UUID            NOT NULL REFERENCES commerce.users(id),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.guest_order_access
-- Token de acceso seguro para que invitados vean su orden por email.
-- access_token_hash: hash del token — nunca en texto plano.
-- -------------------------------------------------------------------
CREATE TABLE commerce.guest_order_access (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID        NOT NULL REFERENCES commerce.orders(id) ON DELETE RESTRICT,
    access_token_hash   TEXT        NOT NULL,
    expires_at          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- commerce.faq_groups
-- Entidades gestionadas (CRUD admin CRM). Cada grupo tiene un slug
-- único usado en rutas públicas. Los FAQs referencian el grupo por FK.
-- -------------------------------------------------------------------
CREATE TABLE commerce.faq_groups (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    slug        VARCHAR(100) NOT NULL,
    description TEXT,
    sort_order  INT          NOT NULL DEFAULT 0,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by  INT          NOT NULL,
    updated_by  INT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT faq_groups_slug_key UNIQUE (slug)
);

CREATE INDEX faq_groups_is_active_sort_order_idx ON commerce.faq_groups (is_active, sort_order);

-- -------------------------------------------------------------------
-- commerce.faqs
-- Gestionadas por admins del CRM (created_by/updated_by son int CRM,
-- NO uuids de commerce.users).
-- group_id: FK a faq_groups — reemplaza el campo libre "group varchar".
-- is_active = false: conservada pero no visible en tienda.
-- -------------------------------------------------------------------
CREATE TABLE commerce.faqs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id    UUID        NOT NULL REFERENCES commerce.faq_groups(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    question    TEXT        NOT NULL,
    answer      TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    sort_order  INT         NOT NULL DEFAULT 0,
    created_by  INT         NOT NULL,
    updated_by  INT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX faqs_group_id_is_active_idx ON commerce.faqs (group_id, is_active);

-- -------------------------------------------------------------------
-- commerce.system_config
-- Parámetros operativos configurables desde el panel admin sin código.
-- Seed requerido: max_addresses_per_user = 20 (RF-USR-002-1).
-- updated_by: superadmin del CRM (int).
-- -------------------------------------------------------------------
CREATE TABLE commerce.system_config (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(100) NOT NULL UNIQUE,
    value       VARCHAR(500) NOT NULL,
    description TEXT,
    updated_by  INT         NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

### 4. Schema: `infra`

#### Tipos enum

```sql
CREATE TYPE infra.outbox_status_enum        AS ENUM ('pending', 'processing', 'published', 'failed');
CREATE TYPE infra.webhook_status_enum       AS ENUM ('received', 'processing', 'processed', 'failed', 'ignored');
CREATE TYPE infra.notif_channel_enum        AS ENUM ('email', 'sms', 'push');
CREATE TYPE infra.recipient_type_enum       AS ENUM ('registered_user', 'guest');
CREATE TYPE infra.delivery_status_enum      AS ENUM ('pending', 'sending', 'delivered', 'failed', 'bounced');
CREATE TYPE infra.push_notif_type_enum      AS ENUM (
    'order_update', 'shipping_update', 'promotion', 'restock', 'system'
);
```

#### Tablas

```sql
-- -------------------------------------------------------------------
-- infra.outbox_events
-- Transactional Outbox: se escribe en la MISMA transacción que el
-- cambio de negocio. Un proceso de polling lee filas 'pending' y las
-- publica a BullMQ. Garantiza at-least-once delivery.
-- aggregate_id: UUID lógico — no hay FK constraint por diseño.
-- -------------------------------------------------------------------
CREATE TABLE infra.outbox_events (
    id              UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type  VARCHAR(50)                 NOT NULL,
    aggregate_id    UUID                        NOT NULL,
    event_type      VARCHAR(100)                NOT NULL,
    payload         JSONB                       NOT NULL,
    status          infra.outbox_status_enum    NOT NULL DEFAULT 'pending',
    published_at    TIMESTAMPTZ,
    retry_count     INT                         NOT NULL DEFAULT 0,
    last_error      TEXT,
    created_at      TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- infra.webhook_events
-- Almacén de webhooks entrantes de Stripe, ShipEngine y eBay.
-- UNIQUE (provider, provider_event_id): idempotencia — si Stripe
-- envía el mismo evento dos veces, el segundo INSERT falla y el
-- worker lo descarta silenciosamente.
-- -------------------------------------------------------------------
CREATE TABLE infra.webhook_events (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    provider            VARCHAR(50)                 NOT NULL,
    provider_event_id   VARCHAR(255)                NOT NULL,
    event_type          VARCHAR(100)                NOT NULL,
    payload             JSONB                       NOT NULL,
    status              infra.webhook_status_enum   NOT NULL DEFAULT 'received',
    processed_at        TIMESTAMPTZ,
    error_message       TEXT,
    retry_count         INT                         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_event_id)
);

-- -------------------------------------------------------------------
-- infra.payment_intent_events
-- Ledger append-only del ciclo de vida de cada payment_intent.
-- Traza qué webhook originó cada transición de estado.
-- provider_event_id: referencia lógica a webhook_events.provider_event_id.
-- -------------------------------------------------------------------
CREATE TABLE infra.payment_intent_events (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_intent_id   UUID            NOT NULL REFERENCES commerce.payment_intents(id) ON DELETE RESTRICT,
    event_type          VARCHAR(100)    NOT NULL,
    status_before       VARCHAR(50),
    status_after        VARCHAR(50)     NOT NULL,
    amount              NUMERIC(10,2),
    provider_event_id   VARCHAR(255),
    payload             JSONB,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- infra.notification_templates
-- Plantillas de email gestionadas por el equipo dev/admin.
-- key: identificador único usado por el NotificationsModule para
-- buscar la plantilla al disparar un evento.
-- variables: [{name, description, required, example}]
-- -------------------------------------------------------------------
CREATE TABLE infra.notification_templates (
    id          UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(100)                NOT NULL UNIQUE,
    name        VARCHAR(255)                NOT NULL,
    channel     infra.notif_channel_enum    NOT NULL DEFAULT 'email',
    subject     VARCHAR(500),
    body_html   TEXT                        NOT NULL,
    body_text   TEXT,
    variables   JSONB,
    is_active   BOOLEAN                     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ
);

-- -------------------------------------------------------------------
-- infra.notification_deliveries
-- Log de cada intento de envío del EmailWorker. Soporta retry de
-- notificaciones fallidas y auditoría de entregas por orden/usuario.
-- recipient_user_id = NULL → guest (identificado por recipient_email).
-- -------------------------------------------------------------------
CREATE TABLE infra.notification_deliveries (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key        VARCHAR(100),
    channel             infra.notif_channel_enum    NOT NULL,
    recipient_type      infra.recipient_type_enum   NOT NULL,
    recipient_user_id   UUID                        REFERENCES commerce.users(id) ON DELETE SET NULL,
    recipient_email     VARCHAR(255),
    subject             VARCHAR(500),
    reference_type      VARCHAR(50),
    reference_id        UUID,
    status              infra.delivery_status_enum  NOT NULL DEFAULT 'pending',
    provider            VARCHAR(50),
    provider_message_id VARCHAR(255),
    error_message       TEXT,
    retry_count         INT                         NOT NULL DEFAULT 0,
    sent_at             TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    opened_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- infra.user_notifications
-- Inbox de notificaciones del usuario visible en la app (bell icon).
-- Separado de notification_deliveries (log del sistema).
-- Solo aplica a usuarios registrados — guests no tienen inbox.
-- La única mutación posible es marcar como leída: is_read + read_at.
-- Sin updated_at ni soft delete — se eliminan por TTL o acción del usuario.
-- -------------------------------------------------------------------
CREATE TABLE infra.user_notifications (
    id              UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID                        NOT NULL REFERENCES commerce.users(id) ON DELETE CASCADE,
    type            infra.push_notif_type_enum  NOT NULL,
    title           VARCHAR(255)                NOT NULL,
    body            TEXT                        NOT NULL,
    reference_type  VARCHAR(50),
    reference_id    UUID,
    is_read         BOOLEAN                     NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------
-- infra.idempotency_keys
-- Respaldo durable en PostgreSQL de las claves de idempotencia que
-- Redis mantiene en memoria. Si Redis se reinicia, evita doble orden
-- o doble cobro en resubmits del cliente.
-- request_hash: hash del body normalizado — detecta mismo key con
-- body diferente (potencial ataque o bug de cliente).
-- -------------------------------------------------------------------
CREATE TABLE infra.idempotency_keys (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    key             VARCHAR(255) NOT NULL UNIQUE,
    request_path    VARCHAR(255) NOT NULL,
    request_hash    VARCHAR(64)  NOT NULL,
    response_status INT,
    response_body   JSONB,
    resource_type   VARCHAR(50),
    resource_id     UUID,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

### 5. Índices

```sql
-- =====================================================================
-- catalog
-- =====================================================================
CREATE INDEX idx_listings_status           ON catalog.listings (status);
CREATE INDEX idx_listings_gts_category     ON catalog.listings (gts_category_id);
CREATE INDEX idx_listings_slug             ON catalog.listings (slug);

-- Clave para el checkout multi-bodega (RF-LOG-006-4)
CREATE INDEX idx_inv_links_warehouse_status
    ON catalog.listing_inventory_links (listing_id, crm_warehouse_id, status);

CREATE INDEX idx_stock_movements_listing   ON catalog.listing_stock_movements (listing_id, created_at DESC);
CREATE INDEX idx_channel_ebay_sync         ON catalog.listing_channel_ebay (sync_status);
CREATE INDEX idx_channel_gts_sync          ON catalog.listing_channel_gts_store (sync_status);

-- =====================================================================
-- commerce
-- =====================================================================
CREATE INDEX idx_users_email               ON commerce.users (email);
CREATE INDEX idx_users_status              ON commerce.users (status);

CREATE INDEX idx_carts_user               ON commerce.carts (user_id, status);

CREATE INDEX idx_cart_items_cart          ON commerce.cart_items (cart_id);

CREATE INDEX idx_orders_user              ON commerce.orders (user_id);
CREATE INDEX idx_orders_status            ON commerce.orders (status);
CREATE INDEX idx_orders_customer_email    ON commerce.orders (customer_email);
CREATE INDEX idx_orders_visible_id        ON commerce.orders (visible_order_id);

CREATE INDEX idx_order_items_order        ON commerce.order_items (order_id);
CREATE INDEX idx_order_shipments_order    ON commerce.order_shipments (order_id);
CREATE INDEX idx_shipment_items_shipment  ON commerce.order_shipment_items (order_shipment_id);

CREATE INDEX idx_payment_intents_order    ON commerce.payment_intents (order_id);

CREATE INDEX idx_reservations_order       ON commerce.inventory_reservations (order_id);
CREATE INDEX idx_reservations_crm_item    ON commerce.inventory_reservations (crm_inventory_id);
CREATE INDEX idx_reservations_expiry      ON commerce.inventory_reservations (status, expires_at)
    WHERE status IN ('pending', 'confirmed');

CREATE INDEX idx_auth_tokens_user_type    ON commerce.auth_tokens (user_id, type);
CREATE INDEX idx_auth_tokens_hash         ON commerce.auth_tokens (token_hash);

CREATE INDEX idx_order_history_order      ON commerce.order_status_history (order_id, created_at DESC);
CREATE INDEX idx_saga_order               ON commerce.saga_instances (order_id);

-- =====================================================================
-- infra
-- =====================================================================
-- Clave para el polling worker del Outbox
CREATE INDEX idx_outbox_pending           ON infra.outbox_events (status, created_at)
    WHERE status = 'pending';

CREATE INDEX idx_webhook_provider_status  ON infra.webhook_events (provider, status);

CREATE INDEX idx_payment_events_intent    ON infra.payment_intent_events (payment_intent_id, created_at DESC);

CREATE INDEX idx_notif_deliveries_ref     ON infra.notification_deliveries (reference_type, reference_id);
CREATE INDEX idx_notif_deliveries_user    ON infra.notification_deliveries (recipient_user_id);
CREATE INDEX idx_notif_deliveries_status  ON infra.notification_deliveries (status)
    WHERE status IN ('pending', 'failed');

CREATE INDEX idx_push_subs_user           ON commerce.user_push_subscriptions (user_id)
    WHERE is_active = TRUE;
CREATE INDEX idx_push_subs_endpoint       ON commerce.user_push_subscriptions (endpoint);

CREATE INDEX idx_user_notifications_user  ON infra.user_notifications (user_id, created_at DESC);
CREATE INDEX idx_user_notifications_unread ON infra.user_notifications (user_id, is_read)
    WHERE is_read = FALSE;

CREATE INDEX idx_idempotency_expires      ON infra.idempotency_keys (expires_at);
```

---

### 6. Seed data

```sql
-- =====================================================================
-- Configuración inicial del sistema
-- =====================================================================
INSERT INTO commerce.system_config (key, value, description, updated_by, updated_at)
VALUES
    ('max_addresses_per_user', '20',
     'Número máximo de direcciones guardadas por usuario registrado (RF-USR-002-1)',
     1, NOW());

-- =====================================================================
-- Plantillas de notificación (claves requeridas por NotificationsModule)
-- =====================================================================
INSERT INTO infra.notification_templates (key, name, channel, subject, body_html, variables)
VALUES
    ('order_confirmed', 'Confirmación de orden', 'email',
     'Your order {{visible_order_id}} is confirmed — GreenTek Solutions',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"visible_order_id","required":true},{"name":"customer_first_name","required":true},{"name":"subtotal","required":true},{"name":"shipping_cost","required":true},{"name":"tax_amount","required":true},{"name":"total","required":true},{"name":"order_detail_url","required":true}]'),

    ('order_shipped', 'Orden enviada (por shipment)', 'email',
     'Your package is on its way — Order {{visible_order_id}}',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"visible_order_id","required":true},{"name":"tracking_number","required":true},{"name":"tracking_url","required":true},{"name":"carrier","required":true},{"name":"warehouse_label","required":false}]'),

    ('order_delivered', 'Orden entregada', 'email',
     'Your order {{visible_order_id}} has been delivered',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"visible_order_id","required":true},{"name":"customer_first_name","required":true}]'),

    ('email_verification', 'Verificación de email', 'email',
     'Verify your email — GreenTek Solutions',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"verification_url","required":true},{"name":"customer_first_name","required":true}]'),

    ('password_reset', 'Recuperación de contraseña', 'email',
     'Reset your password — GreenTek Solutions',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"reset_url","required":true},{"name":"expires_in_hours","required":true}]'),

    ('stock_conflict_alert', 'Alerta de conflicto de stock (admin)', 'email',
     'Stock conflict detected — Order {{visible_order_id}}',
     '<p>Placeholder — reemplazar con template HTML final</p>',
     '[{"name":"visible_order_id","required":true},{"name":"listing_title","required":true}]'),

-- Templates de notificación push (PWA — Web Push Protocol)
-- body_html almacena el cuerpo corto; el browser renderiza la UI de notificación.
    ('push_order_confirmed', 'Order Confirmed (Push)', 'push',
     'Your order {{order_id}} is confirmed',
     'GreenTek Solutions received your order. We will notify you when it ships.',
     '[{"name":"order_id","required":true},{"name":"customer_first_name","required":true}]'),

    ('push_order_shipped', 'Order Shipped (Push)', 'push',
     'Your order {{order_id}} is on its way',
     'Your package has been shipped. Tap to see tracking details.',
     '[{"name":"order_id","required":true},{"name":"tracking_number","required":false}]'),

    ('push_order_delivered', 'Order Delivered (Push)', 'push',
     'Your order {{order_id}} has been delivered',
     'Your package was delivered. Enjoy your purchase!',
     '[{"name":"order_id","required":true}]');
```

---

## Diccionario de datos

> Documenta todas las columnas de cada tabla: tipo PostgreSQL, restricciones y regla de negocio.
>
> **Convenciones de la tabla:**
> - `Nullable` — `Sí` = acepta NULL · `No` = NOT NULL
> - `Default` — `—` = sin valor por defecto declarado
> - **†** = tabla append-only: nunca se ejecuta UPDATE ni DELETE sobre ninguna fila
> - **‡** = FK lógica: la relación se valida en la capa de aplicación (NestJS), sin FK constraint en PostgreSQL

---

### Schema `catalog` — 15 tablas

| Tabla | Propósito | Soft delete | Append-only |
|-------|-----------|-------------|-------------|
| `gts_categories` | Categorías planas de la GTS Store | `is_active = false` | No |
| `listings` | Entidad central — listing simple, con variaciones o template | `status = inactive` | No |
| `listing_pricing` | Precio del listing simple (1-1 con `listings`) | — | No |
| `listing_variation_axes` | Ejes de variación (Color, RAM, etc.) | — | No |
| `listing_variations` | Una variación = un SKU con precio propio | `status = inactive` | No |
| `listing_images` | Imágenes del listing o de variación específica | — | No |
| `listing_inventory_links` | Vínculo 1-1 entre ítem físico del CRM y listing | — (`status` activo) | No |
| `listing_stock` | Snapshot de stock disponible | — | No |
| `listing_stock_movements` | Ledger de cambios de stock | — | **Sí** † |
| `listing_channel_ebay` | Config de publicación en eBay | `deleted_at` | No |
| `listing_channel_ebay_variations` | Offer de eBay por variación | — | No |
| `listing_channel_gts_store` | Config de publicación en GTS Store | `deleted_at` | No |
| `price_config` | Descuento global por canal (vigente) | `deleted_at` | No |
| `price_config_history` | Historial de cambios de descuento global | — | **Sí** † |
| `shipping_restrictions` | Lista negra de ubicaciones de envío | `is_active = false` | No |

---

#### `catalog.gts_categories`

Categorías planas de la GTS Store (sin anidamiento). Nunca se borran para preservar FKs activas.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `name` | `varchar(100)` | No | — | Nombre visible en tienda. Ej: `Laptops`, `Desktops` |
| `is_active` | `boolean` | No | `true` | **Soft delete** — `false` oculta la categoría sin romper FKs |
| `sort_order` | `int` | No | `0` | Orden de presentación en la tienda. Gestionado vía endpoint de reorder — no se edita manualmente |
| `icon` | `varchar(100)` | Sí | — | Nombre del ícono de [HugeIcons](https://hugeicons.com) para mostrar junto a la categoría en el storefront |
| `image` | `varchar(500)` | Sí | — | URL de imagen de portada de la categoría para mostrar en el storefront |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `catalog.listings`

Entidad central del catálogo. Cubre listing simple, con variaciones y templates. La mayoría de campos son nullable para soportar borradores incompletos.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `title` | `varchar(255)` | Sí | — | Nullable en draft |
| `description` | `text` | Sí | — | |
| `condition` | `enum` | Sí | — | GTS Grade: `EXCELLENT \| GOOD \| FAIR` — visible al cliente (RF-CAT-009). Solo para `LISTING`, no para templates |
| `listing_type` | `enum` | No | — | `LISTING` = publicable · `TEMPLATE` = reutilizable, nunca se publica directamente |
| `status` | `enum` | No | `'draft'` | Ciclo de vida: `draft → ready → scheduled → published → out_of_stock → unpublished → inactive` |
| `source_type` | `enum` | No | `'ORIGINAL'` | `ORIGINAL \| FROM_TEMPLATE \| FROM_COPY` |
| `source_id` | `uuid` | Sí | — | FK → `listings.id` — referencia al template o listing que originó la copia |
| `is_variation` | `boolean` | No | `false` | `false` → usa `listing_pricing` · `true` → usa `listing_variations` |
| `gts_category_id` | `uuid` | Sí | — | FK → `gts_categories.id` — obligatorio para publicar en GTS Store |
| `currency` | `varchar(3)` | No | `'USD'` | |
| `important_notes` | `jsonb` | Sí | — | Array de notas del producto |
| `included_items` | `jsonb` | Sí | — | Array de ítems incluidos con el producto |
| `r2v3_data_sanitization` | `enum` | Sí | — | Certificación R2V3: `NON_DATA` |
| `r2v3_cosmetic` | `enum` | Sí | — | Certificación R2V3: `C1 \| C2 \| C3` (estado cosmético) |
| `r2v3_functionality` | `enum` | Sí | — | Certificación R2V3: `F1 \| F2 \| F3` (estado funcional) |
| `shipping_policy` | `enum` | Sí | — | `NORMAL` = ShipEngine calcula · `FREIGHT` = precio fijo · `FREE` = sin costo |
| `fixed_shipping_cost` | `numeric(10,2)` | Sí | — | Costo fijo de envío. Obligatorio para publicar (RF-LOG-003). Fallback si ShipEngine falla |
| `weight_value` | `numeric(10,3)` | Sí | — | |
| `weight_unit` | `varchar(3)` | Sí | — | `LB \| OZ \| KG` |
| `dim_length` | `numeric(10,3)` | Sí | — | |
| `dim_width` | `numeric(10,3)` | Sí | — | |
| `dim_height` | `numeric(10,3)` | Sí | — | |
| `dim_unit` | `varchar(2)` | Sí | — | `IN \| CM` |
| `ebay_category_id` | `varchar(50)` | Sí | — | ID de categoría en eBay |
| `ebay_category_name` | `varchar(255)` | Sí | — | Nombre de categoría eBay — desnormalizado para UX |
| `shared_aspects` | `jsonb` | Sí | — | Aspectos compartidos entre variaciones. Ej: `{ "Brand": "Cisco", "Model": "3750" }` |
| `meta_title` | `varchar(255)` | Sí | — | SEO: título de la página del producto (RF-MKT-004) |
| `meta_description` | `text` | Sí | — | SEO: descripción para motores de búsqueda (RF-MKT-004) |
| `slug` | `varchar(255)` | Sí | — | **UNIQUE** — URL amigable. Ej: `cisco-catalyst-switch-3750` (RF-MKT-004) |
| `units_sold` | `int` | No | `0` | Contador de unidades vendidas — incrementa al completar una orden (RF-BUS-004-1) |
| `draft_progress` | `jsonb` | No | `'{}'` | Progreso del formulario multi-paso: `{general, category, aspects, variations, images, pricing, shipping, inventory, channels}` |
| `created_by` | `int` | No | — | ID del admin en el CRM — **no es FK** a `commerce.users` |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `catalog.listing_pricing`

Precio del listing simple (1-1 con `listings`). Solo existe cuando `is_variation = false`. Los descuentos son snapshots al momento de creación — no cambian retroactivamente si `price_config` cambia.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK **UNIQUE** → `listings.id` ON DELETE CASCADE |
| `sku` | `varchar(100)` | Sí | — | Nullable en draft |
| `base_price` | `numeric(10,2)` | Sí | — | Precio ingresado por el empleado. Se muestra tachado en tienda |
| `ebay_discount_pct` | `numeric(5,4)` | Sí | — | Snapshot del `price_config` al crear. Ej: `0.0500` = 5%. En V1 = `0.0000` |
| `ebay_price` | `numeric(10,2)` | Sí | — | Calculado: `base_price × (1 − ebay_discount_pct)` |
| `store_discount_pct` | `numeric(5,4)` | Sí | — | Snapshot del `price_config` al crear |
| `store_price` | `numeric(10,2)` | Sí | — | Calculado: `base_price × (1 − store_discount_pct)` — precio final al cliente |

---

#### `catalog.listing_variation_axes`

Define los ejes de variación del listing (Ej: Color, RAM). Solo existe cuando `is_variation = true`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` ON DELETE CASCADE |
| `aspect_name` | `varchar(100)` | No | — | Nombre del eje. Ej: `Color`, `Storage Capacity`, `RAM` |
| `values` | `jsonb` | No | — | Valores posibles. Ej: `["Space Gray", "Gold", "Sierra Blue"]` |
| `affects_image` | `boolean` | No | `false` | `true` → cada variación puede tener imagen propia |
| `sort_order` | `int` | No | `0` | |

---

#### `catalog.listing_variations`

Una variación = un SKU con precio propio. Solo existe cuando `is_variation = true`. Soft delete mediante `status = inactive`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` ON DELETE CASCADE |
| `sku` | `varchar(100)` | Sí | — | Nullable en draft |
| `label` | `varchar(255)` | Sí | — | Etiqueta de presentación. Ej: `256GB / Gold` |
| `aspects` | `jsonb` | Sí | — | Combinación de valores. Ej: `{ "Color": ["Gold"], "Storage": ["256 GB"] }` |
| `base_price` | `numeric(10,2)` | Sí | — | Precio base ingresado por el empleado |
| `ebay_discount_pct` | `numeric(5,4)` | Sí | — | Snapshot del config global al crear |
| `ebay_price` | `numeric(10,2)` | Sí | — | Calculado: `base_price × (1 − ebay_discount_pct)` |
| `store_discount_pct` | `numeric(5,4)` | Sí | — | Snapshot del config global al crear |
| `store_price` | `numeric(10,2)` | Sí | — | Calculado: `base_price × (1 − store_discount_pct)` |
| `status` | `enum` | No | `'active'` | **Soft delete**: `active \| out_of_stock \| inactive` |
| `sort_order` | `int` | No | `0` | |

---

#### `catalog.listing_images`

Imágenes del listing o de variación específica. `listing_variation_id = NULL` → imagen del grupo; `NOT NULL` → imagen propia de esa variación.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` ON DELETE CASCADE |
| `listing_variation_id` | `uuid` | Sí | — | FK → `listing_variations.id` ON DELETE CASCADE · `NULL` = imagen del grupo |
| `original_url` | `varchar(500)` | No | — | URL en servidor privado — fuente de verdad |
| `ebay_url` | `varchar(500)` | Sí | — | Resultado de `createImageFromUrl` de eBay API |
| `gts_store_url` | `varchar(500)` | Sí | — | URL pública en la GTS Store |
| `ebay_url_expires_at` | `date` | Sí | — | Las URLs de eBay expiran — se renuevan antes de la fecha límite |
| `sort_order` | `int` | No | `0` | |
| `is_primary` | `boolean` | No | `false` | Imagen principal del listing o variación |

---

#### `catalog.listing_inventory_links`

1 fila = 1 ítem físico del CRM vinculado al listing. `crm_inventory_id UNIQUE` garantiza que un ítem físico solo puede pertenecer a un listing.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` ON DELETE RESTRICT |
| `listing_variation_id` | `uuid` | Sí | — | FK → `listing_variations.id` ON DELETE RESTRICT · `NULL` = listing simple |
| `crm_inventory_id` | `int` | No | — | **UNIQUE** — ID del ítem en el CRM. 1 ítem CRM = 1 listing |
| `crm_po_id` | `varchar(100)` | Sí | — | PO de origen en el CRM |
| `crm_po_line` | `varchar(100)` | Sí | — | Línea del PO |
| `crm_iq_id` | `varchar(100)` | Sí | — | IQ de referencia en el CRM |
| `crm_warehouse_id` | `int` | No | — | Bodega del ítem — desnormalizado para queries de checkout multi-bodega |
| `status` | `enum` | No | `'available'` | `available` → libre · `reserved` → en checkout activo · `sold` → vendido |

> **Query multi-bodega (RF-LOG-006-4):** `SELECT COUNT(*) FROM catalog.listing_inventory_links WHERE listing_id = $1 AND crm_warehouse_id = $2 AND status = 'available'`

---

#### `catalog.listing_stock`

Snapshot del stock disponible. 1 fila por listing simple o por variación. Índices únicos parciales manejan el `NULL` en `listing_variation_id`. Se actualiza en la misma transacción que `listing_stock_movements`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` ON DELETE RESTRICT |
| `listing_variation_id` | `uuid` | Sí | — | FK → `listing_variations.id` · `NULL` = listing simple |
| `quantity_available` | `int` | No | `0` | `CHECK (quantity_available >= 0)` — nunca negativo |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `catalog.listing_stock_movements` †

**Ledger append-only** — nunca se actualiza ni borra. `SUM(quantity_delta)` debe coincidir siempre con `listing_stock.quantity_available`. Para corregir un movimiento incorrecto, agregar una fila compensatoria con `movement_type = ADJUSTMENT`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK → `listings.id` |
| `listing_variation_id` | `uuid` | Sí | — | FK → `listing_variations.id` · `NULL` = listing simple |
| `quantity_delta` | `int` | No | — | Cambio de stock (+/-). Ej: `-1` = venta · `+1` = devolución |
| `quantity_after` | `int` | No | — | Stock resultante tras el movimiento. `CHECK (quantity_after >= 0)` |
| `movement_type` | `enum` | No | — | `INITIAL \| SALE_EBAY \| SALE_GTS_STORE \| RETURN_EBAY \| RETURN_GTS_STORE \| CANCELLED_SALE \| MANUAL_ADD \| MANUAL_REMOVE \| ADJUSTMENT \| SYNC_EBAY \| SYNC_GTS_STORE \| LISTING_DEACTIVATED \| LISTING_REACTIVATED` |
| `channel` | `enum` | Sí | — | `EBAY \| GTS_STORE \| MANUAL \| SYSTEM` |
| `reference_id` | `varchar(255)` | Sí | — | ID de la entidad origen. Ej: `order_id`, `ebay_order_id` |
| `notes` | `text` | Sí | — | Notas adicionales — obligatorio para `ADJUSTMENT` |
| `created_by` | `int` | Sí | — | ID del admin CRM si el movimiento fue manual |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `catalog.listing_channel_ebay`

Configuración y estado de sincronización del canal eBay por listing. `deleted_at` conserva el historial de configuración al desvincular el canal.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK **UNIQUE** → `listings.id` ON DELETE RESTRICT |
| `ebay_linked_account_id` | `int` | No | — | Cuenta eBay vinculada en el CRM |
| `ebay_listing_id` | `varchar(50)` | Sí | — | ID del listing en eBay — `null` hasta primera publicación |
| `ebay_sku` | `varchar(100)` | Sí | — | |
| `ebay_offer_id` | `varchar(50)` | Sí | — | ID del offer en eBay Inventory API (listing simple) |
| `ebay_inventory_group_key` | `varchar(100)` | Sí | — | Key del inventory group (listing con variaciones) |
| `ebay_merchant_location_key` | `varchar(100)` | Sí | — | Ubicación de inventario registrada en eBay |
| `ebay_fulfillment_policy_id` | `varchar(50)` | Sí | — | Política de envío aplicada |
| `ebay_payment_policy_id` | `varchar(50)` | Sí | — | Política de pago aplicada |
| `ebay_return_policy_id` | `varchar(50)` | Sí | — | Política de devolución aplicada |
| `ebay_store_category_names` | `jsonb` | No | `'[]'` | Categorías de la tienda eBay |
| `marketplace_id` | `varchar(20)` | No | `'EBAY_US'` | Marketplace destino |
| `ebay_listing_format` | `varchar(20)` | No | `'FIXED_PRICE'` | |
| `ebay_listing_duration` | `varchar(10)` | No | `'GTC'` | Good Till Cancelled |
| `ebay_listing_description_html` | `text` | Sí | — | Descripción HTML personalizada para eBay |
| `scheduled_at` | `timestamptz` | Sí | — | Fecha de publicación programada |
| `sync_status` | `enum` | No | `'not_requested'` | `not_requested \| scheduled \| pending \| success \| failed` |
| `sync_error_message` | `text` | Sí | — | Mensaje del último error de sincronización |
| `published_at` | `timestamptz` | Sí | — | Timestamp de primera publicación exitosa |
| `last_synced_at` | `timestamptz` | Sí | — | Timestamp de última sincronización |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** — preserva historial de configuración |

---

#### `catalog.listing_channel_ebay_variations`

Un offer de eBay por variación. Solo existe para listings con `is_variation = true`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_channel_ebay_id` | `uuid` | No | — | FK → `listing_channel_ebay.id` ON DELETE CASCADE |
| `listing_variation_id` | `uuid` | No | — | FK → `listing_variations.id` ON DELETE RESTRICT |
| `ebay_sku` | `varchar(100)` | No | — | SKU del offer en eBay |
| `ebay_offer_id` | `varchar(50)` | Sí | — | ID del offer — `null` hasta primera publicación |

---

#### `catalog.listing_channel_gts_store`

Configuración y estado de sincronización del canal GTS Store por listing.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `listing_id` | `uuid` | No | — | FK **UNIQUE** → `listings.id` ON DELETE RESTRICT |
| `gts_store_product_id` | `int` | Sí | — | ID del producto en la plataforma GTS Store |
| `gts_store_slug` | `varchar(255)` | Sí | — | Slug del producto en GTS Store |
| `gts_store_url` | `varchar(500)` | Sí | — | URL pública del producto |
| `scheduled_at` | `timestamptz` | Sí | — | Fecha de publicación programada |
| `sync_status` | `enum` | No | `'not_requested'` | `not_requested \| scheduled \| pending \| success \| failed` |
| `sync_error_message` | `text` | Sí | — | Mensaje del último error |
| `published_at` | `timestamptz` | Sí | — | Primera publicación exitosa |
| `last_synced_at` | `timestamptz` | Sí | — | Última sincronización |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** — preserva historial de configuración |

---

#### `catalog.price_config`

Descuento global vigente por canal. Los porcentajes se copian como snapshot al crear el listing — cambios futuros no afectan listings existentes.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `channel` | `varchar(20)` | No | — | Canal al que aplica. Ej: `EBAY`, `GTS_STORE` |
| `ebay_linked_account_id` | `int` | Sí | — | Cuenta eBay si el channel es `EBAY` |
| `discount_pct` | `numeric(5,4)` | No | — | Descuento vigente. Ej: `0.0500` = 5% |
| `updated_by` | `int` | No | — | ID del admin CRM |
| `updated_at` | `timestamptz` | No | `NOW()` | |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** |

---

#### `catalog.price_config_history` †

**Ledger append-only** del historial de cambios al descuento global. Nunca se borra.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `channel` | `varchar(20)` | No | — | Canal afectado |
| `ebay_linked_account_id` | `int` | Sí | — | |
| `discount_pct_previous` | `numeric(5,4)` | No | — | Descuento antes del cambio |
| `discount_pct_new` | `numeric(5,4)` | No | — | Descuento después del cambio |
| `changed_by` | `int` | No | — | ID del admin CRM |
| `changed_at` | `timestamptz` | No | `NOW()` | |
| `notes` | `text` | Sí | — | Motivo del cambio |

---

#### `catalog.shipping_restrictions`

Lista negra de ubicaciones de envío configurada por el admin. `is_active = false` desactiva la restricción sin borrarla (RF-LOG-002).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `restriction_type` | `enum` | No | — | `STATE \| ZIP_CODE \| COUNTRY \| MILITARY` |
| `value` | `varchar(50)` | No | — | Valor de la restricción. Ej: `CA`, `90210`, `US`, `APO` |
| `label` | `varchar(100)` | No | — | Etiqueta legible. Ej: `California` |
| `is_active` | `boolean` | No | `true` | **Soft delete** |
| `created_by` | `int` | No | — | ID del admin CRM |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

### Schema `commerce` — 20 tablas

| Tabla | Propósito | Soft delete | Append-only |
|-------|-----------|-------------|-------------|
| `users` | Clientes registrados del e-commerce | `deleted_at` | No |
| `user_crm_links` | Vínculo opcional con cuenta CRM | — | No |
| `user_addresses` | Direcciones guardadas (máx. `system_config.max_addresses_per_user`) | — | No |
| `user_notification_preferences` | Preferencias de email (1-1 con `users`) | — | No |
| `auth_tokens` | Tokens de verificación de email y reset de contraseña | — | No |
| `carts` | Carrito para registrados y guests | `status = expired` | No |
| `cart_items` | Ítems del carrito con precio snapshot | — | No |
| `orders` | Orden de compra con snapshot completo del cliente | — | No |
| `order_addresses` | Snapshot de dirección de envío y facturación | — | No |
| `order_items` | Líneas de la orden con snapshot del producto | — | No |
| `order_shipments` | Un shipment por bodega involucrada | — | No |
| `order_shipment_items` | Puente `order_items ↔ order_shipments` | — | No |
| `payment_intents` | Ciclo de vida del pago — provider-agnostic | `deleted_at` | No |
| `order_status_history` | Historial de transiciones de estado de la orden | — | **Sí** † |
| `inventory_reservations` | Ítems reservados durante el checkout Saga | — | No |
| `saga_instances` | Estado del Saga Orchestrator por orden | — | No |
| `order_return_metadata` | Metadata de devolución parcial o total | — | No |
| `guest_order_access` | Token de acceso seguro para invitados | — | No |
| `faq_groups` | Grupos de FAQs gestionados por admins CRM | `is_active = false` | No |
| `faqs` | Preguntas frecuentes gestionadas por admins CRM | `is_active = false` | No |
| `system_config` | Parámetros operativos configurables sin código | — | No |

---

#### `commerce.users`

Clientes registrados del e-commerce. Independiente del CRM. Los admins del CRM **no** están en esta tabla.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `first_name` | `varchar(100)` | No | — | |
| `last_name` | `varchar(100)` | No | — | |
| `email` | `varchar(255)` | No | — | **UNIQUE** — clave de autenticación |
| `password_hash` | `text` | No | — | Hash bcrypt — nunca texto plano |
| `phone` | `varchar(30)` | Sí | — | |
| `email_verified` | `boolean` | No | `false` | `true` tras confirmación con `auth_tokens` |
| `email_verified_at` | `timestamptz` | Sí | — | Timestamp de verificación |
| `status` | `enum` | No | `'active'` | `active \| blocked` — `blocked` impide el login |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** — el email queda bloqueado para re-registro |

---

#### `commerce.user_crm_links`

Vínculo opcional entre cuenta del e-commerce y cuenta CRM. Se crea tras verificación mediante código generado en el CRM.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `user_id` | `uuid` | No | — | FK → `users.id` ON DELETE CASCADE |
| `crm_email` | `varchar(255)` | No | — | Email de la cuenta en el CRM |
| `crm_reference_id` | `varchar(100)` | Sí | — | ID de referencia en el CRM |
| `linked_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.user_addresses`

Direcciones guardadas por usuario registrado. Máximo configurable en `system_config.max_addresses_per_user` (default: 20).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `user_id` | `uuid` | No | — | FK → `users.id` ON DELETE CASCADE |
| `recipient_name` | `varchar(255)` | No | — | Nombre del destinatario |
| `phone` | `varchar(30)` | Sí | — | |
| `address_line1` | `varchar(255)` | No | — | |
| `address_line2` | `varchar(255)` | Sí | — | Apartamento, suite, etc. |
| `city` | `varchar(100)` | No | — | |
| `state` | `varchar(100)` | No | — | |
| `postal_code` | `varchar(20)` | No | — | |
| `country` | `varchar(100)` | No | `'US'` | |
| `is_default` | `boolean` | No | `false` | Dirección predeterminada del usuario |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.user_notification_preferences`

Preferencias de email por usuario. 1-1 con `users`. `email_security` no puede desactivarse desde la UI — protege los flujos de verificación y reset de contraseña.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `user_id` | `uuid` | No | — | FK **UNIQUE** → `users.id` ON DELETE CASCADE |
| `email_order_updates` | `boolean` | No | `true` | Actualizaciones de estado de la orden |
| `email_shipping_updates` | `boolean` | No | `true` | Actualizaciones de envío y tracking |
| `email_marketing` | `boolean` | No | `false` | Emails promocionales — opt-in explícito |
| `email_security` | `boolean` | No | `true` | **No editable por el usuario** — protege tokens de verificación y reset |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.auth_tokens`

Tokens temporales de verificación de email y recuperación de contraseña. Se almacena el hash — nunca el token en texto plano (RF-USR-006).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `user_id` | `uuid` | No | — | FK → `users.id` ON DELETE CASCADE |
| `type` | `enum` | No | — | `verify_email \| reset_password` |
| `token_hash` | `text` | No | — | Hash SHA-256 del token — el token real se envía solo por email |
| `expires_at` | `timestamptz` | No | — | TTL del token |
| `used_at` | `timestamptz` | Sí | — | Timestamp de uso — el token queda invalidado tras usarse |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.carts`

Carrito para usuarios registrados y guests. `user_id = NULL` → carrito guest, identificado por el UUID del carrito almacenado en cookie.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK — se almacena en cookie del cliente como `cartId` |
| `user_id` | `uuid` | Sí | — | FK → `users.id` ON DELETE SET NULL · `NULL` = carrito guest |
| `status` | `enum` | No | `'active'` | `active \| merged \| expired` — `merged` al fusionar carrito guest con registrado tras login |
| `expires_at` | `timestamptz` | No | — | 7 días para guest · extendido para registrados |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.cart_items`

Ítems del carrito. `price_snapshot` es informativo — el precio final al pagar siempre se recalcula desde el listing vigente.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `cart_id` | `uuid` | No | — | FK → `carts.id` ON DELETE CASCADE |
| `listing_id` | `uuid` | No | — | ‡ FK lógica → `catalog.listings.id` |
| `listing_variation_id` | `uuid` | Sí | — | ‡ FK lógica → `catalog.listing_variations.id` |
| `quantity` | `int` | No | — | `CHECK (quantity > 0)` |
| `price_snapshot` | `numeric(10,2)` | No | — | Precio al agregar al carrito — solo informativo, no se usa para cobrar |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.orders`

Orden de compra con snapshot completo del cliente e ítems. No depende de que el listing exista tras la compra (integridad histórica contable).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK — UUID interno, nunca se muestra al cliente |
| `visible_order_id` | `varchar(50)` | Sí | — | **UNIQUE** — formato `GTS-YYYY-{so_id}` — generado **solo** al recibir `so_id` del CRM (RF-ORD-001) |
| `so_id` | `varchar(50)` | Sí | — | ID de la orden en la tabla `so_info` del CRM |
| `user_id` | `uuid` | Sí | — | FK → `users.id` ON DELETE SET NULL · `NULL` = orden guest |
| `customer_first_name` | `varchar(100)` | No | — | Snapshot del cliente al checkout — inmutable |
| `customer_last_name` | `varchar(100)` | No | — | |
| `customer_email` | `varchar(255)` | No | — | |
| `customer_phone` | `varchar(30)` | Sí | — | |
| `customer_type` | `enum` | No | — | `guest \| registered` |
| `status` | `enum` | No | `'pending'` | `pending → paid → processing → shipped → delivered → completed / cancelled / partially_returned / fully_returned` |
| `currency` | `varchar(3)` | No | `'USD'` | |
| `subtotal` | `numeric(10,2)` | No | — | |
| `shipping_cost` | `numeric(10,2)` | No | — | |
| `tax_amount` | `numeric(10,2)` | No | — | |
| `total` | `numeric(10,2)` | No | — | |
| `label_generated` | `boolean` | No | `false` | `true` cuando cualquier `order_shipments.label_generated_at IS NOT NULL` — **bloquea cancelación total** (RF-ORD-001 RN-4) |
| `label_generated_at` | `timestamptz` | Sí | — | Timestamp de la primera label generada |
| `has_stock_conflict` | `boolean` | No | `false` | Flag de sobreventa detectada (eBay + GTS Store simultáneos) (RF-INV-002) |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.order_addresses`

Snapshot de dirección de envío y facturación al momento del checkout. Inmutable tras creación.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `type` | `varchar(20)` | No | — | `CHECK (type IN ('shipping', 'billing'))` |
| `recipient_name` | `varchar(255)` | No | — | |
| `phone` | `varchar(30)` | Sí | — | |
| `address_line1` | `varchar(255)` | No | — | |
| `address_line2` | `varchar(255)` | Sí | — | |
| `city` | `varchar(100)` | No | — | |
| `state` | `varchar(100)` | No | — | |
| `postal_code` | `varchar(20)` | No | — | |
| `country` | `varchar(100)` | No | — | |

---

#### `commerce.order_items`

Líneas de la orden con snapshot completo del producto al comprar. `crm_warehouse_id` indica la bodega de origen del ítem al hacer checkout.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `listing_id` | `uuid` | No | — | ‡ FK lógica → `catalog.listings.id` — referencia preservada aunque el listing se inactive |
| `listing_variation_id` | `uuid` | Sí | — | ‡ FK lógica → `catalog.listing_variations.id` |
| `product_name` | `varchar(255)` | No | — | Snapshot del nombre al comprar |
| `product_sku` | `varchar(100)` | Sí | — | Snapshot del SKU |
| `product_condition` | `varchar(50)` | Sí | — | Snapshot del `condition` del listing |
| `quantity` | `int` | No | — | `CHECK (quantity > 0)` |
| `unit_price` | `numeric(10,2)` | No | — | `store_price` vigente al checkout |
| `subtotal` | `numeric(10,2)` | No | — | `unit_price × quantity` |
| `crm_warehouse_id` | `int` | No | — | Bodega de origen — desnormalizado para lógica multi-bodega |

---

#### `commerce.order_shipments`

Un shipment por bodega involucrada en la orden (RF-LOG-006). `label_generated_at` activa `orders.label_generated = true` en la capa de aplicación.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `crm_warehouse_id` | `int` | No | — | Bodega de origen del shipment |
| `status` | `enum` | No | `'pending'` | `pending → label_generated → shipped → delivered / failed` |
| `carrier` | `varchar(50)` | Sí | — | Transportista. Ej: `FedEx`, `UPS` |
| `service` | `varchar(100)` | Sí | — | Servicio de envío. Ej: `FedEx Ground` |
| `shipping_cost` | `numeric(10,2)` | No | — | Costo calculado por ShipEngine |
| `insurance_selected` | `boolean` | No | `false` | Si el cliente seleccionó seguro |
| `insurance_cost` | `numeric(10,2)` | Sí | — | Costo del seguro si aplica |
| `tracking_number` | `varchar(100)` | Sí | — | |
| `tracking_url` | `varchar(500)` | Sí | — | URL de rastreo del carrier |
| `label_url` | `varchar(500)` | Sí | — | URL del PDF de la etiqueta |
| `shipengine_shipment_id` | `varchar(100)` | Sí | — | ID del shipment en ShipEngine |
| `label_generated_at` | `timestamptz` | Sí | — | Timestamp de generación de label — activa bloqueo de cancelación |
| `shipped_at` | `timestamptz` | Sí | — | Confirmado por ShipEngine webhook |
| `delivered_at` | `timestamptz` | Sí | — | Confirmado por ShipEngine webhook |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.order_shipment_items`

Tabla puente `order_items ↔ order_shipments`. Necesaria para emails por shipment y detalle del comprobante por bodega (RF-NOT-001).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_shipment_id` | `uuid` | No | — | FK → `order_shipments.id` ON DELETE RESTRICT |
| `order_item_id` | `uuid` | No | — | FK → `order_items.id` ON DELETE RESTRICT |
| `quantity` | `int` | No | — | `CHECK (quantity > 0)` — puede ser subconjunto de `order_items.quantity` en envíos parciales |

---

#### `commerce.payment_intents`

Ciclo de vida completo del pago. Diseño provider-agnostic (Stripe en V1). Soporta 3DS, reintentos automáticos y reembolsos parciales acumulados.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `idempotency_key` | `varchar(255)` | No | — | **UNIQUE** — generado por el backend. Evita doble cobro en resubmits |
| `provider` | `varchar(50)` | No | `'stripe'` | Provider de pago. Extensible a `paypal`, `braintree` |
| `provider_payment_intent_id` | `varchar(100)` | No | — | **UNIQUE** — ID del PaymentIntent en Stripe. Ej: `pi_3OaB...` |
| `provider_charge_id` | `varchar(100)` | Sí | — | ID del Charge en Stripe — disponible tras `payment_intent.succeeded` |
| `amount` | `numeric(10,2)` | No | — | Monto total a cobrar |
| `currency` | `varchar(3)` | No | `'USD'` | |
| `status` | `enum` | No | `'created'` | `created → requires_payment_method → requires_confirmation → requires_action → processing → succeeded / failed / cancelled` |
| `payment_method_type` | `varchar(50)` | Sí | — | `card \| apple_pay \| google_pay` |
| `card_last4` | `varchar(4)` | Sí | — | Últimos 4 dígitos de la tarjeta — para mostrar en UI |
| `card_brand` | `varchar(20)` | Sí | — | `visa \| mastercard \| amex`, etc. |
| `client_secret` | `text` | Sí | — | Solo para Stripe SDK en frontend (flujo 3DS). **Nunca exponer en listados ni logs** |
| `failure_code` | `varchar(100)` | Sí | — | Código de error de Stripe. Ej: `card_declined` |
| `failure_message` | `text` | Sí | — | Mensaje de error localizable |
| `retry_count` | `int` | No | `0` | Reintentos ejecutados por el `PaymentWorker` |
| `max_retries` | `int` | No | `3` | Máximo de reintentos permitidos |
| `next_retry_at` | `timestamptz` | Sí | — | Timestamp para el próximo reintento (backoff exponencial) |
| `refunded_amount` | `numeric(10,2)` | No | `0` | Monto reembolsado acumulado — no modifica `status` principal |
| `metadata` | `jsonb` | Sí | — | Datos adicionales del provider |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** |

---

#### `commerce.order_status_history` †

**Ledger append-only** de transiciones de estado de la orden. Nunca se actualiza. `changed_by = NULL` → cambio automático por sistema o webhook.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `status` | `varchar(50)` | No | — | Estado nuevo tras la transición |
| `changed_by` | `uuid` | Sí | — | FK → `users.id` ON DELETE SET NULL · `NULL` = sistema o webhook |
| `source` | `enum` | No | — | `admin \| system \| shipengine_webhook` |
| `notes` | `text` | Sí | — | Notas opcionales del cambio |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.inventory_reservations`

Ítems reservados durante el flujo Saga de checkout. `expires_at` libera automáticamente la reserva si el checkout no se completa en 15 min.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `listing_id` | `uuid` | No | — | ‡ FK lógica → `catalog.listings.id` |
| `listing_variation_id` | `uuid` | Sí | — | ‡ FK lógica → `catalog.listing_variations.id` |
| `crm_inventory_id` | `int` | No | — | Ítem físico específico reservado en el CRM |
| `quantity` | `int` | No | — | `CHECK (quantity > 0)` |
| `status` | `enum` | No | `'pending'` | `pending \| confirmed \| released \| expired` |
| `expires_at` | `timestamptz` | No | — | TTL de la reserva (15 min post-checkout iniciado) |
| `released_at` | `timestamptz` | Sí | — | Timestamp de liberación |
| `release_reason` | `varchar(50)` | Sí | — | Motivo de liberación: `expired`, `payment_failed`, `cancelled` |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.saga_instances`

Estado persistido del Saga Orchestrator por orden. Permite recuperación tras crashes del servicio. `steps` guarda el log de ejecución de cada paso con estado y error si aplica.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `saga_type` | `varchar(50)` | No | — | Tipo de saga: `checkout \| return` |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `status` | `enum` | No | `'started'` | `started → inventory_reserved → payment_processing → succeeded / compensating → compensated / failed` |
| `current_step` | `varchar(100)` | Sí | — | Paso activo en ejecución |
| `steps` | `jsonb` | No | `'[]'` | Array: `[{ step, status, completed_at, error }]` |
| `compensation_steps` | `jsonb` | Sí | — | Pasos de compensación ejecutados en caso de fallo |
| `failure_reason` | `text` | Sí | — | Descripción del error que detuvo la saga |
| `started_at` | `timestamptz` | No | `NOW()` | |
| `completed_at` | `timestamptz` | Sí | — | |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.order_return_metadata`

Metadata de devolución registrada manualmente por el admin. 1-1 con la orden. `returned_items` detalla ítems y cantidades devueltas.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK **UNIQUE** → `orders.id` ON DELETE RESTRICT |
| `return_type` | `varchar(20)` | No | — | `CHECK (return_type IN ('partial', 'full'))` |
| `return_reason` | `text` | Sí | — | Motivo de la devolución |
| `returned_items` | `jsonb` | Sí | — | Array: `[{ order_item_id, quantity, notes }]` |
| `refund_amount` | `numeric(10,2)` | Sí | — | Monto reembolsado |
| `refund_method` | `varchar(50)` | Sí | — | Ej: `stripe_refund`, `store_credit` |
| `received_at` | `timestamptz` | Sí | — | Fecha de recepción física del producto |
| `processed_by` | `uuid` | No | — | FK → `users.id` — admin que procesó la devolución |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.guest_order_access`

Token de acceso seguro para que invitados vean su orden via link en el email de confirmación (RF-PCV-001).

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `order_id` | `uuid` | No | — | FK → `orders.id` ON DELETE RESTRICT |
| `access_token_hash` | `text` | No | — | Hash SHA-256 del token — el token real se envía solo por email |
| `expires_at` | `timestamptz` | No | — | TTL del token de acceso |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.faq_groups`

Grupos de FAQs gestionados por admins CRM. `created_by` / `updated_by` son IDs del CRM, no UUIDs de `commerce.users`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `name` | `varchar(100)` | No | — | Nombre visible: `Payments`, `Shipping`, etc. |
| `slug` | `varchar(100)` | No | — | **UNIQUE** — identificador URL: `payments`, `about-gts`, etc. |
| `description` | `text` | Sí | — | Descripción corta del grupo |
| `sort_order` | `int` | No | `0` | Orden de aparición del grupo |
| `is_active` | `boolean` | No | `true` | **Soft delete** — `false` oculta el grupo y sus FAQs |
| `created_by` | `int` | No | — | ID admin CRM |
| `updated_by` | `int` | Sí | — | ID admin CRM |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.faqs`

Preguntas frecuentes gestionadas por admins CRM. Referencian un grupo (`faq_groups`) por FK. `created_by` / `updated_by` son IDs del CRM, no UUIDs de `commerce.users`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `group_id` | `uuid` | No | — | **FK → `faq_groups.id`** ON DELETE RESTRICT |
| `question` | `text` | No | — | |
| `answer` | `text` | No | — | |
| `is_active` | `boolean` | No | `true` | **Soft delete** — `false` oculta en tienda |
| `sort_order` | `int` | No | `0` | Orden dentro del grupo |
| `created_by` | `int` | No | — | ID admin CRM |
| `updated_by` | `int` | Sí | — | ID admin CRM |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `commerce.system_config`

Parámetros operativos configurables desde el panel admin sin requerir un deploy.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `key` | `varchar(100)` | No | — | **UNIQUE** — identificador del parámetro |
| `value` | `varchar(500)` | No | — | Valor del parámetro |
| `description` | `text` | Sí | — | |
| `updated_by` | `int` | No | — | ID superadmin CRM |
| `updated_at` | `timestamptz` | No | `NOW()` | |

**Valores iniciales (seed):**

| `key` | `value` | Descripción |
|-------|---------|-------------|
| `max_addresses_per_user` | `20` | Máximo de direcciones por usuario registrado (RF-USR-002-1) |

---

### Schema `infra` — 6 tablas

| Tabla | Propósito | Soft delete | Append-only |
|-------|-----------|-------------|-------------|
| `outbox_events` | Transactional Outbox — garantía at-least-once hacia BullMQ | — (cambia `status`) | No |
| `webhook_events` | Almacén de webhooks entrantes de Stripe, ShipEngine, eBay | — (cambia `status`) | No |
| `payment_intent_events` | Historial de transiciones del `payment_intent` | — | **Sí** † |
| `notification_templates` | Plantillas de email con variables Handlebars | `deleted_at` | No |
| `notification_deliveries` | Log de cada intento de envío del `EmailWorker` | — | No |
| `idempotency_keys` | Respaldo durable de Redis para evitar doble orden/cobro | — | No |

---

#### `infra.outbox_events`

Transactional Outbox. Se escribe en la **misma transacción** que el cambio de negocio. Un polling worker lee filas `pending` y las publica a BullMQ. `aggregate_id` es referencia lógica sin FK constraint por diseño — el worker no necesita JOIN, opera sobre el payload.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `aggregate_type` | `varchar(50)` | No | — | Tipo de entidad origen: `order \| payment \| inventory \| listing \| notification` |
| `aggregate_id` | `uuid` | No | — | ‡ UUID de la entidad origen — sin FK constraint |
| `event_type` | `varchar(100)` | No | — | Ej: `order.paid`, `payment.succeeded`, `inventory.reserved`, `stock.updated` |
| `payload` | `jsonb` | No | — | Todo lo necesario para el handler — diseñado para no requerir JOIN |
| `status` | `enum` | No | `'pending'` | `pending → processing → published / failed` |
| `published_at` | `timestamptz` | Sí | — | Timestamp de publicación exitosa a BullMQ |
| `retry_count` | `int` | No | `0` | Reintentos del polling worker |
| `last_error` | `text` | Sí | — | Último error del worker |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

> Índice crítico para el polling worker: `(status, created_at) WHERE status = 'pending'`

---

#### `infra.webhook_events`

Almacén de webhooks entrantes de Stripe, ShipEngine y eBay. `UNIQUE (provider, provider_event_id)` garantiza idempotencia — si el mismo evento llega dos veces, el segundo INSERT falla y el worker lo descarta silenciosamente.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `provider` | `varchar(50)` | No | — | `stripe \| shipengine \| ebay` |
| `provider_event_id` | `varchar(255)` | No | — | ID único del evento en el provider. **UNIQUE** con `provider` |
| `event_type` | `varchar(100)` | No | — | Ej: `payment_intent.succeeded`, `shipment.delivered` |
| `payload` | `jsonb` | No | — | Payload completo del webhook |
| `status` | `enum` | No | `'received'` | `received → processing → processed / failed / ignored` |
| `processed_at` | `timestamptz` | Sí | — | |
| `error_message` | `text` | Sí | — | Error del último intento de procesamiento |
| `retry_count` | `int` | No | `0` | |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `infra.payment_intent_events` †

**Ledger append-only** del ciclo de vida de cada `payment_intent`. Traza qué webhook originó cada transición de estado. Nunca se actualiza ni borra.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `payment_intent_id` | `uuid` | No | — | FK → `commerce.payment_intents.id` ON DELETE RESTRICT |
| `event_type` | `varchar(100)` | No | — | Ej: `payment_intent.succeeded`, `payment_intent.payment_failed` |
| `status_before` | `varchar(50)` | Sí | — | Estado previo al evento |
| `status_after` | `varchar(50)` | No | — | Estado resultante tras el evento |
| `amount` | `numeric(10,2)` | Sí | — | Monto relevante. Ej: monto reembolsado en un refund |
| `provider_event_id` | `varchar(255)` | Sí | — | ‡ Referencia lógica a `webhook_events.provider_event_id` |
| `payload` | `jsonb` | Sí | — | Datos adicionales del evento |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

#### `infra.notification_templates`

Plantillas de email gestionadas por el equipo dev/admin. `key` es el identificador que usa `NotificationsModule` para buscar la plantilla al disparar un evento.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `key` | `varchar(100)` | No | — | **UNIQUE** — identificador de la plantilla. Ej: `order_confirmed` |
| `name` | `varchar(255)` | No | — | Nombre legible |
| `channel` | `enum` | No | `'email'` | `email \| sms \| push` — en V1 solo `email` |
| `subject` | `varchar(500)` | Sí | — | Asunto del email (soporta variables Handlebars) |
| `body_html` | `text` | No | — | Cuerpo HTML del email |
| `body_text` | `text` | Sí | — | Versión texto plano (fallback) |
| `variables` | `jsonb` | Sí | — | Schema de variables: `[{ name, description, required, example }]` |
| `is_active` | `boolean` | No | `true` | |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |
| `deleted_at` | `timestamptz` | Sí | — | **Soft delete** |

**Keys requeridas en seed:**

| `key` | Disparador |
|-------|------------|
| `order_confirmed` | Pago exitoso — comprobante + link a la orden |
| `order_shipped` | Label generada — 1 email por shipment (RF-NOT-001) |
| `order_delivered` | Entrega confirmada — recordatorio de garantía 30d/1y |
| `email_verification` | Registro de nuevo usuario |
| `password_reset` | Solicitud de recuperación de contraseña |
| `stock_conflict_alert` | Sobreventa detectada — notificación interna al equipo |

---

#### `infra.notification_deliveries`

Log de cada intento de envío del `EmailWorker`. Soporta retry de notificaciones fallidas y auditoría de entregas por orden/usuario. `recipient_user_id = NULL` → guest identificado por `recipient_email`.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `template_key` | `varchar(100)` | Sí | — | ‡ Referencia lógica a `notification_templates.key` |
| `channel` | `enum` | No | — | `email \| sms \| push` |
| `recipient_type` | `enum` | No | — | `registered_user \| guest` |
| `recipient_user_id` | `uuid` | Sí | — | FK → `commerce.users.id` ON DELETE SET NULL · `NULL` = guest |
| `recipient_email` | `varchar(255)` | Sí | — | Email del destinatario — desnormalizado para guests |
| `subject` | `varchar(500)` | Sí | — | Asunto final renderizado |
| `reference_type` | `varchar(50)` | Sí | — | Tipo de entidad asociada: `order`, `user` |
| `reference_id` | `uuid` | Sí | — | UUID de la entidad asociada |
| `status` | `enum` | No | `'pending'` | `pending → sending → delivered / failed / bounced` |
| `provider` | `varchar(50)` | Sí | — | Proveedor SMTP utilizado |
| `provider_message_id` | `varchar(255)` | Sí | — | ID del mensaje en el proveedor — para rastreo de bounces |
| `error_message` | `text` | Sí | — | Error del último intento |
| `retry_count` | `int` | No | `0` | |
| `sent_at` | `timestamptz` | Sí | — | |
| `delivered_at` | `timestamptz` | Sí | — | Confirmado por webhook del proveedor |
| `opened_at` | `timestamptz` | Sí | — | Confirmado por pixel de tracking (si habilitado) |
| `created_at` | `timestamptz` | No | `NOW()` | |
| `updated_at` | `timestamptz` | No | `NOW()` | |

---

#### `infra.idempotency_keys`

Respaldo durable en PostgreSQL de las claves de idempotencia que Redis mantiene en memoria. Si Redis se reinicia, evita doble orden o doble cobro en resubmits del cliente.

| Columna | Tipo | Nullable | Default | Descripción |
|---------|------|----------|---------|-------------|
| `id` | `uuid` | No | `gen_random_uuid()` | PK |
| `key` | `varchar(255)` | No | — | **UNIQUE** — clave de idempotencia enviada por el cliente |
| `request_path` | `varchar(255)` | No | — | Endpoint de la request |
| `request_hash` | `varchar(64)` | No | — | Hash SHA-256 del body normalizado — detecta mismo key con body diferente (posible ataque o bug de cliente) |
| `response_status` | `int` | Sí | — | HTTP status de la respuesta almacenada |
| `response_body` | `jsonb` | Sí | — | Respuesta almacenada para devolver en resubmits sin reprocesar |
| `resource_type` | `varchar(50)` | Sí | — | Tipo del recurso creado: `order \| payment` |
| `resource_id` | `uuid` | Sí | — | UUID del recurso creado |
| `expires_at` | `timestamptz` | No | — | TTL de la clave |
| `created_at` | `timestamptz` | No | `NOW()` | |

---

## FKs cross-schema

Las siguientes relaciones cruzan schemas y se resuelven a nivel de aplicación (NestJS), no como constraints de PostgreSQL:

| Tabla origen | Campo | Referencia lógica |
|---|---|---|
| `commerce.cart_items` | `listing_id` | `catalog.listings.id` |
| `commerce.cart_items` | `listing_variation_id` | `catalog.listing_variations.id` |
| `commerce.order_items` | `listing_id` | `catalog.listings.id` |
| `commerce.order_items` | `listing_variation_id` | `catalog.listing_variations.id` |
| `commerce.inventory_reservations` | `listing_id` | `catalog.listings.id` |
| `commerce.inventory_reservations` | `listing_variation_id` | `catalog.listing_variations.id` |
| `infra.payment_intent_events` | `payment_intent_id` | `commerce.payment_intents.id` ✓ (FK declarada) |
| `infra.notification_deliveries` | `recipient_user_id` | `commerce.users.id` ✓ (FK declarada) |

> Las marcadas con ✓ tienen FK constraint declarada porque la dependencia va en dirección `infra → commerce`. Las demás (`commerce → catalog`) se validan en la capa de servicio de NestJS para evitar dependencias circulares entre schemas.
