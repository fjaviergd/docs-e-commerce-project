# Flujo completo de creación de listing (single, sin variaciones)

Documento de referencia para v2. Mapea cada endpoint del CRM con el endpoint de eBay que consume, en el orden exacto en que se usan.

---

## Diagrama de flujo

```
[1] Cargar cuentas vinculadas    → CRM DB (sin eBay API)
[2] Buscar categoría / producto  → eBay Taxonomy API + eBay Browse API
[3] Cargar datos del formulario  → eBay Stores API + Taxonomy + Account + Inventory APIs
[4] Obtener descripción          → CRM interno (sin eBay API)
[5] Subir imagen                 → Servidor privado → eBay Media API
[6] CREATE LISTING               → eBay Inventory API (3 llamadas secuenciales)
```

---

## Fase 1 — Cargar cuentas vinculadas

### `GET api/store/ebay-oauth/linked-accounts?userId=4`

| Campo | Valor |
|-------|-------|
| Propósito | Obtener la lista de cuentas de eBay vinculadas al userId |
| eBay API | **Ninguna** — consulta la base de datos interna del CRM |
| Tabla CRM | `gobig_ebay_linked_accounts` / `gts_crm_ebay_accounts` |

> Se llama **dos veces** en el flujo (al inicio y antes de cargar el formulario). En ambos casos solo accede a la DB del CRM, no llama a eBay.

---

## Fase 2 — Consultas de catálogo (el usuario busca la categoría y el producto)

Estas llamadas son de exploración/referencia. El usuario las usa para decidir qué categoría y datos usar. No son obligatorias para crear el listing, pero su resultado alimenta los campos del formulario.

### `GET api/ebay-taxonomy/category-suggestions?query=iphone`

| Campo | Valor |
|-------|-------|
| Propósito | Sugerir categorías de eBay basadas en el nombre del producto |
| eBay API | **Taxonomy API** |
| eBay Endpoint | `GET https://api.ebay.com/commerce/taxonomy/v1/category_tree/0/get_category_suggestions` |
| Query params a eBay | `q=iphone&marketplace_id=EBAY_US` |
| Auth eBay | Application token (no requiere user) |
| Doc detallado | [02-taxonomy-api.md](./02-taxonomy-api.md) |

**Dato clave que se extrae:** `categoryId` (ej. `"9355"`) — se usa en la Fase 3 y en el offer.

---

### `GET api/ebay-browse/search?q=iphone&limit=10`

| Campo | Valor |
|-------|-------|
| Propósito | Buscar productos existentes en eBay para referencia de datos y precios |
| eBay API | **Buy Browse API** |
| eBay Endpoint | `GET https://api.ebay.com/buy/browse/v1/item_summary/search` |
| Query params a eBay | `q=iphone&limit=10` |
| Auth eBay | Application token (no requiere user) |
| Parte del listing flow | **No** — es consulta de referencia solamente |
| Doc detallado | [06-browse-api.md](./06-browse-api.md) |

---

## Fase 3 — Cargar datos para el formulario de listing

Una vez elegida la categoría, se cargan todos los datos necesarios para construir el payload del listing.

### `GET api/ebay-stores/categories/2/4`
_(parámetros: ebayAccountId=2, userId=4)_

| Campo | Valor |
|-------|-------|
| Propósito | Obtener las categorías de la tienda eBay del vendedor |
| eBay API | **Sell Stores API** |
| eBay Endpoint | `GET https://api.ebay.com/sell/stores/v1/store/categories` |
| Auth eBay | User token |
| Nota | Si el vendedor no tiene suscripción de tienda eBay, retorna `hasStoreSubscription: false` y array vacío — el listing se puede crear igual |

**Dato clave que se extrae:** `storeCategoryNames` — se incluye en el offer (campo opcional).

---

### `GET api/ebay-taxonomy/category/9355/aspects`
_(parámetro: categoryId=9355)_

| Campo | Valor |
|-------|-------|
| Propósito | Obtener los atributos requeridos/disponibles para la categoría elegida |
| eBay API | **Taxonomy API** |
| eBay Endpoint | `GET https://api.ebay.com/commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category` |
| Query params a eBay | `category_id=9355&marketplace_id=EBAY_US` |
| Auth eBay | Application token |
| Doc detallado | [02-taxonomy-api.md](./02-taxonomy-api.md) |

**Dato clave que se extrae:** Lista de `aspects` con sus valores válidos — se mapean al campo `product.aspects` del inventory item.

---

### `GET api/ebay-policies/fulfillment/2/4?marketplace_id=EBAY_US`

| Campo | Valor |
|-------|-------|
| Propósito | Cargar las políticas de envío del vendedor |
| eBay API | **Sell Account API** |
| eBay Endpoint | `GET https://api.ebay.com/sell/account/v1/fulfillment_policy` |
| Query params a eBay | `marketplace_id=EBAY_US` |
| Auth eBay | User token |
| Doc detallado | [03-account-policies-api.md](./03-account-policies-api.md) |

**Dato clave que se extrae:** `fulfillmentPolicyId` — requerido en `listingPolicies` del offer.

---

### `GET api/ebay-policies/payment/2/4?marketplace_id=EBAY_US`

| Campo | Valor |
|-------|-------|
| Propósito | Cargar las políticas de pago del vendedor |
| eBay API | **Sell Account API** |
| eBay Endpoint | `GET https://api.ebay.com/sell/account/v1/payment_policy` |
| Query params a eBay | `marketplace_id=EBAY_US` |
| Doc detallado | [03-account-policies-api.md](./03-account-policies-api.md) |

**Dato clave que se extrae:** `paymentPolicyId` — requerido en `listingPolicies` del offer.

---

### `GET api/ebay-policies/return/2/4?marketplace_id=EBAY_US`

| Campo | Valor |
|-------|-------|
| Propósito | Cargar las políticas de devolución del vendedor |
| eBay API | **Sell Account API** |
| eBay Endpoint | `GET https://api.ebay.com/sell/account/v1/return_policy` |
| Query params a eBay | `marketplace_id=EBAY_US` |
| Doc detallado | [03-account-policies-api.md](./03-account-policies-api.md) |

**Dato clave que se extrae:** `returnPolicyId` — requerido en `listingPolicies` del offer.

---

### `GET api/ebay-inventory/locations/2/4?limit=100&offset=0`

| Campo | Valor |
|-------|-------|
| Propósito | Cargar las ubicaciones de inventario/almacén del vendedor |
| eBay API | **Sell Inventory API** |
| eBay Endpoint | `GET https://api.ebay.com/sell/inventory/v1/location` |
| Query params a eBay | `limit=100&offset=0` |
| Auth eBay | User token |
| Doc detallado | [04-inventory-api.md](./04-inventory-api.md) |

**Dato clave que se extrae:** `merchantLocationKey` — requerido en el offer.

---

## Fase 4 — Descripción del producto

### `GET/POST api/ecommerce-catalog-descriptions`

| Campo | Valor |
|-------|-------|
| Propósito | Obtener o generar descripción del producto |
| eBay API | **Ninguna** — endpoint interno del CRM |
| Nota | Probablemente consulta una tabla de descripciones del catálogo propio o genera HTML para el campo `listingDescription` del offer |

---

## Fase 5 — Subir imagen

Este proceso tiene **dos pasos** y usa un servidor externo antes de llamar a eBay.

### Paso 5a — `POST https://api.sm_imageserve_priv.com/upload`

| Campo | Valor |
|-------|-------|
| Propósito | Subir la imagen al servidor privado para obtener una URL pública HTTPS |
| eBay API | **Ninguna** — servidor privado de imágenes |
| Por qué se hace | eBay Media API requiere una URL HTTPS pública para descargar la imagen; no acepta uploads directos desde el cliente |

**Resultado:** URL pública de la imagen (ej. `https://api.sm_imageserve_priv.com/images/producto.jpg`)

---

### Paso 5b — `POST api/ebay-media/image/create-from-url/2/4`
_(parámetros: ebayAccountId=2, userId=4)_

| Campo | Valor |
|-------|-------|
| Propósito | Subir la imagen a eBay Picture Services usando la URL del servidor privado |
| eBay API | **Media API** |
| eBay Endpoint | `POST https://apim.ebay.com/commerce/media/v1_beta/image/create_image_from_url` |
| Base URL especial | `apim.ebay.com` (no `api.ebay.com`) — **sin sandbox** |
| Auth eBay | User token |
| Doc detallado | [01-media-api.md](./01-media-api.md) |

**Request body a eBay:**
```json
{
  "imageUrl": "https://api.sm_imageserve_priv.com/images/producto.jpg"
}
```

**Resultado:** URL de eBay Picture Services (ej. `https://i.ebayimg.com/images/g/XXXX/s-l1600.jpg`)  
Esta URL es la que va en `product.imageUrls[]` del inventory item.

---

## Fase 6 — Crear el listing en eBay (el endpoint final)

### `POST api/store/create-listing/2/4`
_(parámetros: ebayAccountId=2, userId=4)_

Este es el único endpoint que **realmente crea el listing**. Internamente el CRM llama a **3 endpoints de eBay en secuencia**, no 2.

**Controlador:** `EcommerceController.createListing()`  
**Orquestador:** `LeadOrchestratorService.createListing()` → `EbayOrchestratorService.processSingleProduct()`

---

### Llamada 1 de 3 — `createOrReplaceInventoryItem`

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `PUT` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item/{sku}` |
| Doc detallado | [04-inventory-api.md](./04-inventory-api.md) |

Crea el producto en el catálogo de inventario de eBay. Incluye título, descripción, aspectos, condición, imágenes (URLs de eBay Picture Services del paso 5b) y cantidad.

---

### Llamada 2 de 3 — `createOffer`

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `POST` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/offer` |
| Doc detallado | [05-offer-api.md](./05-offer-api.md) |

Vincula el inventory item al marketplace EBAY_US con precio, categoría, políticas y location. Devuelve el `offerId`.

---

### Llamada 3 de 3 — `publishOffer`

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `POST` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}/publish` |
| Doc detallado | [05-offer-api.md](./05-offer-api.md) |

Publica el offer y lo convierte en un listing activo y visible en eBay. Devuelve el `listingId`.

---

## Resumen completo

| # | CRM Endpoint | eBay API | eBay Endpoint | Parte del listing |
|---|-------------|----------|---------------|:-----------------:|
| 1 | `GET /store/ebay-oauth/linked-accounts` | — | CRM DB | No |
| 2 | `GET /ebay-taxonomy/category-suggestions` | Taxonomy API | `GET /commerce/taxonomy/v1/category_tree/0/get_category_suggestions` | Consulta |
| 3 | `GET /ebay-browse/search` | Browse API | `GET /buy/browse/v1/item_summary/search` | Consulta |
| 4 | `GET /store/ebay-oauth/linked-accounts` | — | CRM DB | No |
| 5 | `GET /ebay-stores/categories` | Sell Stores API | `GET /sell/stores/v1/store/categories` | Consulta |
| 6 | `GET /ebay-taxonomy/category/{id}/aspects` | Taxonomy API | `GET /commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category` | Consulta |
| 7 | `GET /ebay-policies/fulfillment` | Sell Account API | `GET /sell/account/v1/fulfillment_policy` | Consulta |
| 8 | `GET /ebay-policies/payment` | Sell Account API | `GET /sell/account/v1/payment_policy` | Consulta |
| 9 | `GET /ebay-policies/return` | Sell Account API | `GET /sell/account/v1/return_policy` | Consulta |
| 10 | `GET /ebay-inventory/locations` | Sell Inventory API | `GET /sell/inventory/v1/location` | Consulta |
| 11 | `GET/POST /ecommerce-catalog-descriptions` | — | CRM interno | No |
| 12 | `POST https://api.sm_imageserve_priv.com/upload` | — | Servidor privado | Prerequisito |
| 13 | `POST /ebay-media/image/create-from-url` | Media API | `POST /commerce/media/v1_beta/image/create_image_from_url` | **SÍ** |
| 14a | `POST /store/create-listing` → step 1 | Sell Inventory API | `PUT /sell/inventory/v1/inventory_item/{sku}` | **SÍ** |
| 14b | `POST /store/create-listing` → step 2 | Sell Inventory API | `POST /sell/inventory/v1/offer` | **SÍ** |
| 14c | `POST /store/create-listing` → step 3 | Sell Inventory API | `POST /sell/inventory/v1/offer/{offerId}/publish` | **SÍ** |

**Total de llamadas a eBay que crean el listing:** 4  
(1 imagen en Media API + 3 en Sell Inventory API dentro de `create-listing`)

---

## Si fuera con variaciones (para referencia futura)

El endpoint `POST /store/create-listing` detecta `configuration.variation = true` y en lugar del flujo de arriba llama a:

1. `PUT /sell/inventory/v1/inventory_item/{sku}` — para **cada** variación (N llamadas)
2. `PUT /sell/inventory/v1/inventory_item_group/{key}` — crea el grupo de variaciones
3. `POST /sell/inventory/v1/offer` — para **cada** variación (N llamadas)
4. `POST /sell/inventory/v1/offer/publish_by_inventory_item_group` — publica todo el grupo en una sola llamada

Los endpoints de catálogo (fases 2 y 3) serían los mismos, pero se llamarían múltiples veces para aspectos específicos de cada variación.
