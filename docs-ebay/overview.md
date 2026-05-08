# eBay APIs — Overview y Checklist de Documentación

Resumen de todas las APIs de eBay consumidas en `crm-api_nest/src/ecommerce`.  
Cada fila indica si ya existe el spec oficial descargado en esta carpeta (`docs-ebay/`).

---

## APIs identificadas

| # | API / Namespace | Base path | Doc local | Estado |
|---|----------------|-----------|-----------|--------|
| 1 | **Inventory API** | `/sell/inventory/v1/` | [`sell_inventory_v1_oas3.yaml`](sell_inventory_v1_oas3.yaml) | ✅ Documentada |
| 2 | **Account API** | `/sell/account/v1/` | [`sell_account_v1_oas3.yaml`](sell_account_v1_oas3.yaml) | ✅ Documentada |
| 3 | **Stores API** | `/sell/stores/v1/` | [`sell_stores_v1_oas3.yaml`](sell_stores_v1_oas3.yaml) | ✅ Documentada |
| 4 | **Browse API** | `/buy/browse/v1/` | [`buy_browse_v1_oas3.yaml`](buy_browse_v1_oas3.yaml) | ✅ Documentada |
| 5 | **Taxonomy API** | `/commerce/taxonomy/v1/` | [`commerce_taxonomy_v1_oas3.yaml`](commerce_taxonomy_v1_oas3.yaml) | ✅ Documentada |
| 6 | **Media API** | `/commerce/media/v1_beta/` | [`commerce_media_v1_beta_oas3.yaml`](commerce_media_v1_beta_oas3.yaml) | ✅ Documentada |
| 7 | **Metadata API** | `/sell/metadata/v1/` | [`sell_metadata_v1_oas3.yaml`](sell_metadata_v1_oas3.yaml) | ✅ Documentada |
| 8 | **OAuth / Identity API** | `/identity/v1/oauth2/` | [`commerce_identity_v1_oas3.yaml`](commerce_identity_v1_oas3.yaml) | ✅ Documentada |

---

## Detalle de endpoints por API

### 1. Inventory API — `sell_inventory_v1_oas3.yaml`

Cubre inventory items, offers, listings y grupos de inventario.

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `PUT` | `/sell/inventory/v1/inventory_item/{sku}` |
| ✅ | `GET` | `/sell/inventory/v1/inventory_item/{sku}` |
| ✅ | `POST` | `/sell/inventory/v1/bulk_create_or_replace_inventory_item` |
| ✅ | `PUT` | `/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |
| ✅ | `GET` | `/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |
| ✅ | `POST` | `/sell/inventory/v1/offer` |
| ✅ | `GET` | `/sell/inventory/v1/offer` |
| ✅ | `POST` | `/sell/inventory/v1/bulk_create_offer` |
| ✅ | `GET` | `/sell/inventory/v1/offer/{offerId}` |
| ✅ | `PUT` | `/sell/inventory/v1/offer/{offerId}` |
| ✅ | `DELETE` | `/sell/inventory/v1/offer/{offerId}` |
| ✅ | `POST` | `/sell/inventory/v1/offer/{offerId}/publish` |
| ✅ | `POST` | `/sell/inventory/v1/bulk_publish_offer` |
| ✅ | `POST` | `/sell/inventory/v1/offer/publish_by_inventory_item_group` |
| ✅ | `POST` | `/sell/inventory/v1/offer/{offerId}/withdraw` |
| ✅ | `POST` | `/sell/inventory/v1/offer/withdraw_by_inventory_item_group` |
| ✅ | `POST` | `/sell/inventory/v1/offer/get_listing_fees` |
| ✅ | `POST` | `/sell/inventory/v1/bulk_migrate_listing` |
| ✅ | `PUT` | `/sell/inventory/v1/listing/{listingId}/sku/{sku}/locations` |
| ✅ | `GET` | `/sell/inventory/v1/listing/{listingId}/sku/{sku}/locations` |
| ✅ | `DELETE` | `/sell/inventory/v1/listing/{listingId}/sku/{sku}/locations` |

---

### 2. Account API — `sell_account_v1_oas3.yaml`

Políticas de cuenta del vendedor (devolución, envío, pago, custom).

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `GET` | `/sell/account/v1/return_policy` |
| ✅ | `GET` | `/sell/account/v1/return_policy/{policyId}` |
| ✅ | `GET` | `/sell/account/v1/fulfillment_policy` |
| ✅ | `GET` | `/sell/account/v1/fulfillment_policy/{policyId}` |
| ✅ | `GET` | `/sell/account/v1/payment_policy` |
| ✅ | `GET` | `/sell/account/v1/payment_policy/{policyId}` |
| ✅ | `GET` | `/sell/account/v1/custom_policy` |
| ✅ | `GET` | `/sell/account/v1/custom_policy/{policyId}` |

---

### 3. Stores API — `sell_stores_v1_oas3.yaml`

Gestión de tienda eBay y sus categorías.

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `GET` | `/sell/stores/v1/store/categories` |

---

### 4. Browse API — `buy_browse_v1_oas3.yaml`

Búsqueda y consulta de listings para compradores.

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `GET` | `/buy/browse/v1/item_summary/search` |
| ✅ | `GET` | `/buy/browse/v1/item/{itemId}` |
| ✅ | `GET` | `/buy/browse/v1/item/{itemId}/similar_items` |

---

### 5. Taxonomy API — `commerce_taxonomy_v1_oas3.yaml`

Árbol de categorías eBay y aspectos de ítem.

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `GET` | `/commerce/taxonomy/v1/category_tree/0` |
| ✅ | `GET` | `/commerce/taxonomy/v1/category_tree/0/get_category_suggestions` |
| ✅ | `GET` | `/commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category` |

---

### 6. Media API — `commerce_media_v1_beta_oas3.yaml`

Gestión de imágenes, videos y documentos (GPSR).  
**Base URL especial:** `https://apim.ebay.com` (sin sandbox disponible).

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `POST` | `/commerce/media/v1_beta/document` |
| ✅ | `GET` | `/commerce/media/v1_beta/document/{documentId}` |
| ✅ | `POST` | `/commerce/media/v1_beta/document/{documentId}/upload` |
| ✅ | `POST` | `/commerce/media/v1_beta/image/create_image_from_file` |
| ✅ | `POST` | `/commerce/media/v1_beta/image/create_image_from_url` |
| ✅ | `POST` | `/commerce/media/v1_beta/video` |
| ✅ | `GET` | `/commerce/media/v1_beta/video/{videoId}` |

---

### 7. Metadata API — `sell_metadata_v1_oas3.yaml`

Consultada desde `ebay-taxonomy.service.ts` para obtener las condiciones de ítem válidas por marketplace.

| ✅ | Método | Endpoint |
|----|--------|----------|
| ✅ | `GET` | `/sell/metadata/v1/marketplace/{marketplaceId}/get_item_condition_policies` |

---

### 8. OAuth / Identity API — `commerce_identity_v1_oas3.yaml`

Aunque los tokens se almacenan en BD, el paquete `ebay-oauth-nodejs-client` sí realiza llamadas reales al Identity API en dos escenarios:

| ✅ | Método | Endpoint | Cuándo se dispara |
|----|--------|----------|-------------------|
| ✅ | `POST` | `/identity/v1/oauth2/token` | `getApplicationToken()` — grant_type: `client_credentials` |
| ✅ | `POST` | `/identity/v1/oauth2/token` | `refreshToken()` — grant_type: `refresh_token` |

**Flujo de renovación automática** (`ebay-oauth.service.ts`):
1. `getValidToken()` recupera el token de BD y revisa `access_token_expires`.
2. Si vence en menos de **20 minutos**, llama a `refreshToken()`.
3. `refreshToken()` invoca `ebayAuth.getAccessToken(env, refresh_token, scopes)` → Identity API.
4. El nuevo `access_token` se persiste en BD junto a la nueva fecha de expiración (~2 h).
5. Si cualquier llamada recibe un **403**, `executeWithTokenRefresh()` fuerza el refresh y reintenta una vez.

**Scopes declarados:**

| Scope |
|-------|
| `https://api.ebay.com/oauth/api_scope/sell.inventory` |
| `https://api.ebay.com/oauth/api_scope/sell.account` |
| `https://api.ebay.com/oauth/api_scope/sell.fulfillment` |
| `https://api.ebay.com/oauth/api_scope/sell.stores` |

> **Nota:** El `refresh_token` dura **18 meses** (eBay estándar). Si expira, se requiere re-autorización manual por el vendedor. El campo `expired = 1` en BD marca esta condición.

---

## Resumen ejecutivo

| Categoría | Cantidad |
|-----------|----------|
| APIs distintas identificadas | **8** |
| APIs con spec local | **6** |
| APIs sin spec (pendientes) | **0** — todas documentadas ✅ |
| Endpoints totales mapeados | **37+** |
| Entornos soportados | Production + Sandbox (excepto Media API) |
