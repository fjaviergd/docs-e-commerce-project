# eBay API Integration — Flujos y APIs

Documentación de todas las APIs de eBay consumidas por `crm-api_nest` en el flujo de creación de listings, ordenados según la secuencia de uso.

---

## Flujos de creación de listing

**[00-listing-creation-flow.md](./00-listing-creation-flow.md)** — Mapeo completo de todos los endpoints del CRM con sus endpoints de eBay correspondientes, en orden de uso (listing simple, sin variaciones).

**[00b-listing-variations-flow.md](./00b-listing-variations-flow.md)** — Flujo equivalente para listings con variaciones: qué cambia respecto al simple, qué está implementado en v1, qué falta para v2, y un payload de ejemplo completo.

---

## APIs de eBay identificadas

| # | Documento | eBay API | Base URL | Propósito |
|---|-----------|----------|----------|-----------|
| 1 | [01-media-api.md](./01-media-api.md) | Media API | `https://apim.ebay.com` | Subir imágenes y documentos a eBay |
| 2 | [02-taxonomy-api.md](./02-taxonomy-api.md) | Taxonomy API + Sell Metadata API | `https://api.ebay.com` | Obtener categorías y atributos del producto |
| 3 | [03-account-policies-api.md](./03-account-policies-api.md) | Sell Account API | `https://api.ebay.com` | Obtener políticas de devolución, envío y pago |
| 4 | [04-inventory-api.md](./04-inventory-api.md) | Sell Inventory API | `https://api.ebay.com` | Crear/actualizar inventory items y locations |
| 5 | [05-offer-api.md](./05-offer-api.md) | Sell Inventory API (Offer resources) | `https://api.ebay.com` | Crear, actualizar y publicar offers |
| 6 | [06-browse-api.md](./06-browse-api.md) | Buy Browse API | `https://api.ebay.com` | Buscar items públicamente (no parte del listing flow) |

---

## Ambientes

| Entorno | Base URL (Sell / Browse / Account) | Base URL (Media) |
|---------|-------------------------------------|------------------|
| Production | `https://api.ebay.com` | `https://apim.ebay.com` |
| Sandbox | `https://api.sandbox.ebay.com` | `https://apim.ebay.com` (sin sandbox) |

> La Media API **no tiene sandbox**. Siempre apunta a producción.

---

## Autenticación

Todas las llamadas usan **OAuth 2.0 Bearer Token** en el header:
```
Authorization: Bearer <token>
```

Los tokens se gestionan en `EbayOauthService` (`src/ecommerce/modules/ebay-oauth/`). Hay dos tipos:
- **User token** (`getValidToken`) — requerido para endpoints Sell
- **Application token** (`getApplicationToken`) — usado para Taxonomy y Browse (APIs públicas)

---

## Flujo general de creación de listing

```
1. [Media API]      → createImageFromUrl / createImageFromFile  → obtiene eBay imageUrl
2. [Taxonomy API]   → getCategorySuggestions                    → obtiene categoryId
3. [Taxonomy API]   → getItemAspectsForCategory                 → obtiene atributos requeridos
4. [Account API]    → getReturnPolicies / getFulfillmentPolicies → obtiene policy IDs
5. [Inventory API]  → createOrReplaceInventoryItem (PUT)        → crea el inventory item con SKU
6. [Offer API]      → createOffer (POST)                        → vincula el item a un marketplace
7. [Offer API]      → publishOffer (POST)                       → hace el listing visible en eBay
```
