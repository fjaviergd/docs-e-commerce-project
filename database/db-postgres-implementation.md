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
-- -------------------------------------------------------------------
CREATE TABLE commerce.user_notification_preferences (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID        NOT NULL UNIQUE REFERENCES commerce.users(id) ON DELETE CASCADE,
    email_order_updates     BOOLEAN     NOT NULL DEFAULT TRUE,
    email_shipping_updates  BOOLEAN     NOT NULL DEFAULT TRUE,
    email_marketing         BOOLEAN     NOT NULL DEFAULT FALSE,
    email_security          BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
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
-- commerce.faqs
-- Gestionadas por admins del CRM (created_by/updated_by son int CRM,
-- NO uuids de commerce.users).
-- is_active = false: conservada pero no visible en tienda.
-- -------------------------------------------------------------------
CREATE TABLE commerce.faqs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    question    TEXT        NOT NULL,
    answer      TEXT        NOT NULL,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    sort_order  INT         NOT NULL DEFAULT 0,
    created_by  INT         NOT NULL,
    updated_by  INT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
CREATE TYPE infra.outbox_status_enum    AS ENUM ('pending', 'processing', 'published', 'failed');
CREATE TYPE infra.webhook_status_enum   AS ENUM ('received', 'processing', 'processed', 'failed', 'ignored');
CREATE TYPE infra.notif_channel_enum    AS ENUM ('email', 'sms', 'push');
CREATE TYPE infra.recipient_type_enum   AS ENUM ('registered_user', 'guest');
CREATE TYPE infra.delivery_status_enum  AS ENUM ('pending', 'sending', 'delivered', 'failed', 'bounced');
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
     '[{"name":"visible_order_id","required":true},{"name":"listing_title","required":true}]');
```

---

## Diccionario de datos

### Schema `catalog`

| Tabla | Propósito | Soft delete | Append-only |
|-------|-----------|-------------|-------------|
| `gts_categories` | Categorías planas de la GTS Store | `is_active = false` | No |
| `listings` | Entidad central — listing simple, con variaciones o template | `status = inactive` | No |
| `listing_pricing` | Precio de listing simple (1-1) | No | No |
| `listing_variation_axes` | Ejes de variación (Color, RAM, etc.) | No | No |
| `listing_variations` | Una variación = un SKU con precio propio | `status = inactive` | No |
| `listing_images` | Imágenes del listing o de variación específica | No | No |
| `listing_inventory_links` | Vínculo 1-1 entre ítem físico del CRM y listing | No — `status` activo | No |
| `listing_stock` | Snapshot de stock disponible | No | No |
| `listing_stock_movements` | Ledger de cambios de stock | — | **Sí** |
| `listing_channel_ebay` | Config de publicación en eBay | `deleted_at` | No |
| `listing_channel_ebay_variations` | Offer eBay por variación | No | No |
| `listing_channel_gts_store` | Config de publicación en GTS Store | `deleted_at` | No |
| `price_config` | Descuento global por canal (vigente) | `deleted_at` | No |
| `price_config_history` | Historial de cambios de descuento | — | **Sí** |
| `shipping_restrictions` | Lista negra de ubicaciones de envío | `is_active = false` | No |

#### Campos clave — `catalog.listings`

| Campo | Descripción |
|-------|-------------|
| `listing_type` | `LISTING` = publicable; `TEMPLATE` = reutilizable, nunca se publica |
| `status` | Máquina de estados completa — ver `final-database-schema.md` |
| `is_variation` | `false` → usa `listing_pricing`; `true` → usa `listing_variations` |
| `condition` | GTS Grade visible al cliente. No puede ser variación |
| `r2v3_*` | Códigos R2V3 de certificación — respaldo del `condition` |
| `shipping_policy` | `NORMAL` (ShipEngine), `FREIGHT` (precio fijo), `FREE` |
| `fixed_shipping_cost` | Obligatorio para publicar. Fallback si ShipEngine falla |
| `slug` | URL amigable única — ej. `cisco-catalyst-switch-3750` |
| `draft_progress` | `{general, category, aspects, variations, images, pricing, shipping, inventory, channels}` — progreso del formulario |
| `units_sold` | Contador de unidades vendidas — usado para métricas visibles |
| `created_by` | `int` — ID del admin en el CRM (no es FK a `commerce.users`) |

#### Campos clave — `catalog.listing_inventory_links`

| Campo | Descripción |
|-------|-------------|
| `crm_inventory_id` | UNIQUE — 1 ítem físico CRM solo puede estar en 1 listing |
| `crm_warehouse_id` | Bodega del ítem — denormalizado para queries rápidos |
| `status` | `available` → libre; `reserved` → en checkout activo; `sold` → vendido |

> **Query multi-bodega:** `SELECT COUNT(*) FROM catalog.listing_inventory_links WHERE listing_id = $1 AND crm_warehouse_id = $2 AND status = 'available'`

#### Campos clave — `catalog.listing_pricing` / `listing_variations`

| Campo | Descripción |
|-------|-------------|
| `base_price` | Precio ingresado por el empleado. Se muestra tachado en la tienda |
| `store_discount_pct` | Snapshot del `price_config` al crear el listing. No cambia retroactivamente |
| `store_price` | `base_price × (1 − store_discount_pct)` — precio final que paga el cliente |
| `ebay_price` | En V1 = `base_price` (descuento eBay = 0%) |

---

### Schema `commerce`

| Tabla | Propósito | Soft delete | Append-only |
|-------|-----------|-------------|-------------|
| `users` | Clientes registrados del e-commerce | `deleted_at` | No |
| `user_crm_links` | Vínculo opcional con cuenta CRM | No | No |
| `user_addresses` | Direcciones guardadas (máx. `system_config.max_addresses_per_user`) | No | No |
| `user_notification_preferences` | Preferencias de email (1-1 con users) | No | No |
| `auth_tokens` | Tokens de verificación de email y reset de contraseña | No | No |
| `carts` | Carrito para registrados y guests | `status = expired` | No |
| `cart_items` | Ítems del carrito con precio snapshot | No | No |
| `orders` | Orden de compra con snapshot completo del cliente | No | No |
| `order_addresses` | Snapshot de dirección de envío y facturación | No | No |
| `order_items` | Líneas de la orden con snapshot del producto | No | No |
| `order_shipments` | Un shipment por bodega involucrada | No | No |
| `order_shipment_items` | Puente `order_items ↔ order_shipments` | No | No |
| `payment_intents` | Ciclo de vida del pago — provider-agnostic | `deleted_at` | No |
| `order_status_history` | Historial de estados de la orden | — | **Sí** |
| `inventory_reservations` | Ítems reservados durante el checkout Saga | No | No |
| `saga_instances` | Estado del Saga Orchestrator por orden | No | No |
| `order_return_metadata` | Metadata de devolución parcial o total | No | No |
| `guest_order_access` | Token de acceso seguro para invitados | No | No |
| `faqs` | Preguntas frecuentes gestionadas por admins CRM | `is_active = false` | No |
| `system_config` | Parámetros operativos configurables desde el panel admin | No | No |

#### Campos clave — `commerce.orders`

| Campo | Descripción |
|-------|-------------|
| `id` | UUID interno — nunca se muestra al cliente |
| `visible_order_id` | `GTS-YYYY-{so_id}` — se genera SOLO al recibir `so_id` del CRM |
| `so_id` | ID de la orden en la tabla `so_info` del CRM |
| `customer_*` | Snapshot del cliente al checkout — integridad histórica |
| `label_generated` | `true` cuando cualquier `order_shipments.label_generated_at` se llena. Bloquea cancelación total |
| `has_stock_conflict` | Flag de sobreventa detectada (eBay + GTS Store simultáneos) |

#### Campos clave — `commerce.payment_intents`

| Campo | Descripción |
|-------|-------------|
| `idempotency_key` | Generado por el backend. Evita doble cobro en resubmits |
| `provider_payment_intent_id` | ID del PaymentIntent en Stripe (`pi_3OaB...`) |
| `client_secret` | Solo para frontend Stripe SDK — nunca exponer en listados ni logs |
| `retry_count` / `max_retries` | Gestionados por el `PaymentWorker`. Default: máx. 3 reintentos |
| `refunded_amount` | Monto total reembolsado acumulado (no cambia `status` principal) |

#### Campos clave — `commerce.carts`

| Campo | Descripción |
|-------|-------------|
| `id` | Se usa como `cartId` en cookie del cliente |
| `user_id` | `NULL` = carrito guest. Al hacer login se fusiona con el carrito del usuario |
| `expires_at` | 7 días para guest; extendido para registrados |

#### Campos clave — `commerce.system_config`

| `key` | `value` default | Descripción |
|-------|-----------------|-------------|
| `max_addresses_per_user` | `20` | Máximo de direcciones por usuario registrado (RF-USR-002-1) |

---

### Schema `infra`

| Tabla | Propósito | Append-only |
|-------|-----------|-------------|
| `outbox_events` | Transactional Outbox — garantía at-least-once hacia BullMQ | No (cambia `status`) |
| `webhook_events` | Almacén de webhooks entrantes de Stripe, ShipEngine, eBay | No (cambia `status`) |
| `payment_intent_events` | Historial de transiciones del payment_intent | **Sí** |
| `notification_templates` | Plantillas de email con variables Handlebars | No |
| `notification_deliveries` | Log de cada intento de envío del EmailWorker | No |
| `idempotency_keys` | Respaldo durable de Redis para evitar doble orden/cobro | No |

#### Campos clave — `infra.outbox_events`

| Campo | Descripción |
|-------|-------------|
| `aggregate_type` | `order \| payment \| inventory \| listing \| notification` |
| `aggregate_id` | UUID de la entidad origen — referencia lógica, sin FK constraint |
| `event_type` | Ej: `order.paid`, `payment.succeeded`, `stock.updated` |
| `payload` | Todo lo necesario para el handler — no requiere JOIN |
| Índice de polling | `(status, created_at) WHERE status = 'pending'` |

#### Campos clave — `infra.notification_templates`

| `key` requerido | Cuándo se dispara |
|-----------------|-------------------|
| `order_confirmed` | Pago exitoso — incluye comprobante y link a la orden |
| `order_shipped` | Label generada por shipment — se envía 1 email por shipment |
| `order_delivered` | Entrega confirmada — incluye recordatorio de garantía 30d/1y |
| `email_verification` | Registro de nuevo usuario |
| `password_reset` | Solicitud de recuperación de contraseña |
| `stock_conflict_alert` | Sobreventa detectada — notificación interna al equipo |

---

## FKs cross-schema

Las siguientes FKs cruzan schemas y se resuelven a nivel de aplicación (NestJS), no como constraints de PostgreSQL:

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

> Las marcadas con ✓ sí tienen FK constraint declarada porque son en la misma dirección de dependencia (infra → commerce). Las demás (commerce → catalog) se validan en la capa de servicio de NestJS para evitar dependencias circulares entre schemas.
