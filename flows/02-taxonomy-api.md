# 02 — eBay Taxonomy API + Sell Metadata API

**Orden en el flujo de listing:** Paso 2 — Se consultan las categorías y los atributos requeridos para poder armar el payload del `inventory_item` correctamente.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Taxonomy API** + **Sell Metadata API** |
| Base URL | `https://api.ebay.com` / `https://api.sandbox.ebay.com` |
| Base Path (Taxonomy) | `/commerce/taxonomy/v1/` |
| Base Path (Metadata) | `/sell/metadata/v1/` |
| Auth requerida | Application token (`getApplicationToken`) para Taxonomy · User token para Metadata |
| Servicio en CRM | `EbayTaxonomyService` |
| Archivo | `src/ecommerce/modules/ebay-taxonomy/ebay-taxonomy.service.ts` |

---

## Endpoints — Taxonomy API

### 1. `getCategoryTree`
**Usado en el flujo de listing: Referencia (no siempre se llama en runtime)**

Devuelve el árbol completo de categorías de eBay US. Respuesta muy grande, se usa principalmente para construir selectores de categoría en el frontend.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/commerce/taxonomy/v1/category_tree/0` |
| Auth | Application token |

> El `0` en la URL es el `categoryTreeId` para eBay US (EBAY_US marketplace).

---

### 2. `getCategorySuggestions`
**Usado en el flujo de listing: SÍ**

Busca categorías relevantes dado un texto de búsqueda (nombre del producto). Devuelve sugerencias con su `categoryId`, que luego se usa al crear el offer.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/commerce/taxonomy/v1/category_tree/0/get_category_suggestions` |
| Auth | Application token |

**Query params:**
| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `q` | Texto de búsqueda | `"iPhone 13 Pro"` |
| `marketplace_id` | Marketplace de eBay | `"EBAY_US"` |

**Response (simplificado):**
```json
{
  "categorySuggestions": [
    {
      "category": {
        "categoryId": "9355",
        "categoryName": "Cell Phones & Smartphones"
      },
      "categoryTreeNodeLevel": 3,
      "relevancy": "TOP_LEVEL"
    }
  ]
}
```

---

### 3. `getItemAspectsForCategory`
**Usado en el flujo de listing: SÍ**

Devuelve todos los atributos (aspects) que eBay requiere u ofrece para una categoría específica. Es necesario para saber qué campos de `aspects` incluir en el `inventory_item`.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category` |
| Auth | Application token |

**Query params:**
| Parámetro | Descripción |
|-----------|-------------|
| `category_id` | ID de la categoría obtenida de `getCategorySuggestions` |
| `marketplace_id` | `"EBAY_US"` |

**Response:** Lista de aspectos con `aspectConstraint.aspectRequired`, `aspectConstraint.aspectMode` (FREE_TEXT / SELECTION_ONLY), y `aspectValues` permitidos.

---

## Endpoints — Sell Metadata API

> Estos endpoints están en el servicio `EbayTaxonomyService` aunque pertenecen a una API diferente: **Sell Metadata API** (`/sell/metadata/v1/`). Requieren **user token** a diferencia de los de Taxonomy.

### 4. `getItemConditionPolicies`
**Usado en el flujo de listing: SÍ**

Devuelve las condiciones de item permitidas (New, Used, Refurbished, etc.) para una o varias categorías. Necesario para saber qué valor de `condition` usar en el `inventory_item`.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/metadata/v1/marketplace/{marketplaceId}/get_item_condition_policies` |
| Auth | User token |

**Query params:**
| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `filter` | Lista de categoryIds | `categoryIds:{9355,9394}` |

---

### 5. `getHazardousMaterialsLabels`
**Usado en el flujo de listing: No (compliance feature)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/metadata/v1/marketplace/{marketplaceId}/get_hazardous_materials_labels` |

---

### 6. `getProductSafetyLabels`
**Usado en el flujo de listing: No (compliance feature)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/metadata/v1/marketplace/{marketplaceId}/get_product_safety_labels` |

---

### 7. `getRegulatoryPolicies`
**Usado en el flujo de listing: No (compliance feature)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/metadata/v1/marketplace/{marketplaceId}/get_regulatory_policies` |

---

### 8. `getExtendedProducerResponsibilityPolicies`
**Usado en el flujo de listing: No (compliance feature)**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/metadata/v1/marketplace/{marketplaceId}/get_extended_producer_responsibility_policies` |

---

## Notas para v2

- `getCategoryTree` devuelve demasiados datos para llamarse en runtime. En v2 considerar caché local o una tabla en DB que se sincronice periódicamente.
- Los aspectos requeridos (`aspectRequired: true`) que no se envíen en el `inventory_item` pueden causar que el listing no se publique o aparezca incompleto — validar antes de hacer `createOffer`.
- El `categoryTreeId = 0` es para EBAY_US. Si en v2 se soportan otros marketplaces (UK, DE, etc.) hay que usar IDs distintos.
