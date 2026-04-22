# 06 — eBay Buy Browse API

**Orden en el flujo de listing:** No es parte del flujo de creación de listings.

> Esta API se usa para **buscar y consultar productos** públicamente en eBay (como lo haría un comprador). No se usa para crear listings. Se documenta aquí porque está implementada en el CRM y puede ser útil para consultas de referencia o pricing.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Buy Browse API** |
| Base URL | `https://api.ebay.com` / `https://api.sandbox.ebay.com` |
| Base Path | `/buy/browse/v1/` |
| Auth requerida | Application token (`getApplicationToken`) — no requiere user token |
| Servicio en CRM | `EbayBrowseService` |
| Archivo | `src/ecommerce/modules/ebay-browser/ebay-browse.service.ts` |

> Esta API usa **Application token** (Client Credentials), no User token. Cualquier búsqueda pública puede hacerse sin que el usuario de eBay esté autenticado.

---

## Headers especiales

A diferencia de otras APIs, Browse API requiere headers adicionales:

```
X-EBAY-C-MARKETPLACE-ID: EBAY_US
X-EBAY-C-ENDUSERCTX: affiliateCampaignId=<id>,affiliateReferenceId=<ref>
```

---

## Endpoints implementados

### 1. `searchItems`

Busca items en eBay por keywords, categoría, GTIN, EPID u otros filtros.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/buy/browse/v1/item_summary/search` |

**Query params:**
| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `q` | Keywords | `"iPhone 13 Pro"` |
| `category_id` | ID de categoría | `"9355"` |
| `gtin` | Código UPC/EAN/ISBN | `"195949061486"` |
| `epid` | eBay Product ID | `"10045450165"` |
| `limit` | Resultados por página | `20` |
| `offset` | Paginación | `0` |
| `filter` | Filtros avanzados | `"price:[50..200]"` |
| `sort` | Ordenamiento | `"price"` |
| `aspect_filter` | Filtros de atributos | `"Brand:Apple"` |
| `fieldgroups` | Campos extra en respuesta | `"EXTENDED"` |

---

### 2. `searchByGtin`

Wrapper de `searchItems` que busca por código GTIN (UPC, EAN, ISBN).

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/buy/browse/v1/item_summary/search?gtin={gtin}` |

---

### 3. `searchByEpid`

Wrapper de `searchItems` que busca por eBay Product ID.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/buy/browse/v1/item_summary/search?epid={epid}` |

---

### 4. `getItem`

Obtiene los detalles completos de un item específico por su `itemId`.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/buy/browse/v1/item/{itemId}` |

**Query params:**
| Parámetro | Descripción |
|-----------|-------------|
| `fieldgroups` | Campos adicionales (ej. `"PRODUCT"`, `"EXTENDED"`) |

---

### 5. `getSimilarItems`

Obtiene items similares a un item dado.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/buy/browse/v1/item/{itemId}/similar_items` |

---

## Posibles usos en el flujo de v2

Aunque no forma parte del flujo de creación de listings, Browse API puede ser útil para:

- **Investigación de precio:** buscar el mismo producto para referencia de precio de mercado antes de crear el listing
- **Búsqueda por UPC/GTIN:** encontrar datos de producto (título, imágenes, atributos) usando el código de barras para auto-completar el inventory item
- **Validación de categoría:** confirmar que un `categoryId` tiene resultados activos en eBay
