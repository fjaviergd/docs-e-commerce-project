# Flujo de creación de listing con variaciones

Documento de referencia para v2. Compara el flujo con el de un listing simple ([00-listing-creation-flow.md](./00-listing-creation-flow.md)) y describe qué está implementado, qué está incompleto y cómo debería quedar en v2.

---

## ¿Qué es un listing con variaciones en eBay?

Un listing con variaciones es **un solo listing visible en eBay** que agrupa múltiples SKUs que varían en uno o más atributos (ej. talla, color, capacidad de almacenamiento). El comprador ve una sola página de producto y elige su variación desde un selector.

**Ejemplo:** iPhone 13 Pro en colores Space Gray, Gold, Sierra Blue y en capacidades 128GB, 256GB, 512GB → 9 SKUs en 1 listing.

### Modelo de datos en eBay

```
Listing (1 URL pública en eBay)
  └── InventoryItemGroup  (agrupa las variaciones, contiene título e imágenes del grupo)
        ├── InventoryItem SKU-001  (Space Gray 128GB)  ← con su propio Offer
        ├── InventoryItem SKU-002  (Space Gray 256GB)  ← con su propio Offer
        └── InventoryItem SKU-003  (Gold 128GB)        ← con su propio Offer
```

---

## Comparación: Single vs Variaciones

| Aspecto | Single | Variaciones |
|---------|--------|-------------|
| SKUs | 1 | 2 o más (mínimo 2) |
| InventoryItems creados | 1 | N (uno por variación) |
| InventoryItemGroup | No | Sí (obligatorio) |
| Offers creados | 1 | N (uno por variación) |
| Cómo se publica | `publishOffer` | `publishOfferByInventoryItemGroup` |
| Listings resultantes en eBay | 1 | 1 (agrupa todas las variaciones) |
| Imágenes | En el InventoryItem | En el InventoryItemGroup (compartidas) + opcionalmente en cada InventoryItem |

---

## Estado actual en el CRM (v1)

| Componente | Estado |
|------------|--------|
| `EbayOrchestratorService.processVariations()` | ✅ Implementado en código |
| `createOrReplaceInventoryItem` por variación | ✅ Implementado |
| `createOrReplaceInventoryItemGroup` | ✅ Implementado |
| `createOffer` por variación | ✅ Implementado |
| `publishOfferByInventoryItemGroup` | ✅ Implementado |
| Ruta `POST /store/create-listing/:ebayAccountId/:userId` | ✅ Conectada (detecta `variation: true`) |
| Frontend / consultas de catálogo para variaciones | ❌ No cubierto |
| Subida de imágenes por variación | ❌ No cubierto |
| Validación de que `variantSKUs` coincide con los SKUs enviados | ❌ No implementada |
| `bestOfferTerms` en el DTO de Offer | ⚠️ Se construye en el orquestador pero no está en el DTO |

---

## Flujo completo de variaciones (cómo debería quedar en v2)

Las fases 1, 2 y parte de la 3 son **idénticas** al listing simple. Las diferencias empiezan en la fase 3 cuando se configuran los atributos de variación.

---

## Fase 1 — Cargar cuentas vinculadas

**Igual que el listing simple.**

### `GET api/store/ebay-oauth/linked-accounts?userId=4`
- eBay API: **Ninguna** — CRM DB
- Se llama igual, devuelve las cuentas disponibles

---

## Fase 2 — Consultas de catálogo

**Igual que el listing simple.**

### `GET api/ebay-taxonomy/category-suggestions?query=iphone`
- eBay API: **Taxonomy API**
- eBay Endpoint: `GET /commerce/taxonomy/v1/category_tree/0/get_category_suggestions`
- Se obtiene el `categoryId` que usarán **todas** las variaciones

### `GET api/ebay-browse/search?q=iphone&limit=10`
- eBay API: **Browse API** — solo referencia, no parte del listing

---

## Fase 3 — Cargar datos del formulario

**Igual al listing simple** para stores, policies y locations. La diferencia está en los **aspects**: para variaciones, hay que identificar cuáles aspects son los "especificadores" de variación (ej. Color, Storage Capacity).

### `GET api/store/ebay-oauth/linked-accounts?userId=4`
- eBay API: **Ninguna** — CRM DB

### `GET api/ebay-stores/categories/2/4`
- eBay API: **Sell Stores API** → `GET /sell/stores/v1/store/categories`
- El `storeCategoryNames` aplica al grupo, no a cada variación individualmente

### `GET api/ebay-taxonomy/category/9355/aspects`
- eBay API: **Taxonomy API** → `GET /commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category`
- **Diferencia en variaciones:** De los aspects devueltos, el frontend debe identificar cuáles son los `aspectsImageVariesBy` (ej. `["Color"]`) y los `specifications` (ej. `Color: [Gray, Gold]`, `Storage: [128GB, 256GB]`)
- Estos se mandan en el `inventoryItemGroup.variesBy`

### `GET api/ebay-policies/fulfillment/2/4`
### `GET api/ebay-policies/payment/2/4`
### `GET api/ebay-policies/return/2/4`
- eBay API: **Sell Account API** — igual que single listing
- Las mismas políticas aplican a **todos** los offers del grupo

### `GET api/ebay-inventory/locations/2/4`
- eBay API: **Sell Inventory API** → `GET /sell/inventory/v1/location`
- El mismo `merchantLocationKey` se usa en todos los offers

---

## Fase 4 — Descripción

### `GET/POST api/ecommerce-catalog-descriptions`
- eBay API: **Ninguna** — CRM interno
- La descripción va en el `inventoryItemGroup.description`, no en cada variación individualmente
- En variaciones, el `listingDescription` del offer puede omitirse (eBay usa el del grupo)

---

## Fase 5 — Subir imágenes

**Esta es la diferencia más importante respecto al listing simple.**

En un listing con variaciones hay **dos niveles de imágenes**:

### Nivel 1 — Imágenes del grupo (compartidas, obligatorias)

Son las imágenes principales del listing. Van en `inventoryItemGroup.imageUrls`.

```
Paso 5a: POST https://api.sm_imageserve_priv.com/upload    (imagen principal del grupo)
Paso 5b: POST api/ebay-media/image/create-from-url/2/4
         → eBay Media API: POST /commerce/media/v1_beta/image/create_image_from_url
         → Resultado: URL de eBay → va en inventoryItemGroup.imageUrls[]
```

### Nivel 2 — Imágenes por variación (opcionales pero recomendadas)

Si las variaciones difieren en imagen (ej. cada color tiene su foto), cada `inventoryItem` también puede tener sus propias `imageUrls`. El aspect que diferencia las imágenes se declara en `aspectsImageVariesBy`.

```
Por cada variación con imagen diferente:
Paso 5a: POST https://api.sm_imageserve_priv.com/upload    (imagen de esa variación)
Paso 5b: POST api/ebay-media/image/create-from-url/2/4
         → eBay Media API: POST /commerce/media/v1_beta/image/create_image_from_url
         → Resultado: URL de eBay → va en inventoryItem[N].product.imageUrls[]
```

> **En v1 esto NO está cubierto.** El frontend no tiene flujo para subir imágenes múltiples por variación. En v2 hay que agregar ese paso para cada variación que lo requiera.

---

## Fase 6 — Crear el listing con variaciones

### `POST api/store/create-listing/2/4`

El mismo endpoint que el listing simple. El orquestador detecta `configuration.variation = true` y ejecuta `processVariations()` en lugar de `processSingleProduct()`.

**Llamadas a eBay en secuencia — N variaciones:**

---

### Llamada 1 a N — `createOrReplaceInventoryItem` (por cada variación)

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `PUT` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item/{sku}` |
| Se llama | **N veces** (una por variación) |
| Doc detallado | [04-inventory-api.md](./04-inventory-api.md) |

Cada variación tiene su propio SKU y sus propios `aspects` específicos (ej. `{ "Color": ["Gold"], "Storage Capacity": ["256 GB"] }`). El título, descripción e imágenes del grupo van en el `inventoryItemGroup`, no aquí.

**Request Body por variación:**
```json
{
  "availability": {
    "shipToLocationAvailability": { "quantity": 3 }
  },
  "condition": "NEW",
  "product": {
    "title": "iPhone 13 Pro 256GB Gold",
    "aspects": {
      "Color": ["Gold"],
      "Storage Capacity": ["256 GB"]
    },
    "imageUrls": ["https://i.ebayimg.com/...gold-photo.jpg"]
  }
}
```

---

### Llamada N+1 — `createOrReplaceInventoryItemGroup` (una sola vez)

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `PUT` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |
| Se llama | **1 vez** |
| Doc detallado | [04-inventory-api.md](./04-inventory-api.md) |

Este es el "contenedor" del listing. Agrupa todos los SKUs y define qué aspectos diferencian las variaciones.

**Request Body:**
```json
{
  "title": "Apple iPhone 13 Pro - Unlocked - All Colors & Storage",
  "description": "<p>Descripción HTML compartida del listing...</p>",
  "aspects": {
    "Brand": ["Apple"],
    "Model": ["iPhone 13 Pro"],
    "Network": ["Unlocked"]
  },
  "imageUrls": [
    "https://i.ebayimg.com/.../group-main-photo.jpg",
    "https://i.ebayimg.com/.../group-photo-2.jpg"
  ],
  "variantSKUs": ["SKU-GRAY-128", "SKU-GRAY-256", "SKU-GOLD-128"],
  "variesBy": {
    "aspectsImageVariesBy": ["Color"],
    "specifications": [
      {
        "name": "Color",
        "values": ["Space Gray", "Gold"]
      },
      {
        "name": "Storage Capacity",
        "values": ["128 GB", "256 GB"]
      }
    ]
  }
}
```

> **Nota importante:** `variantSKUs` debe contener exactamente los mismos SKUs que se crearon en las llamadas anteriores. En v1 no hay validación de esto — es un punto de fallo silencioso.

---

### Llamada N+2 a 2N+1 — `createOffer` (por cada variación)

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `POST` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/offer` |
| Se llama | **N veces** (una por variación) |
| Doc detallado | [05-offer-api.md](./05-offer-api.md) |

Cada variación tiene su propio offer con su propio precio y cantidad. Comparten las mismas políticas y location.

**Request Body por variación:**
```json
{
  "sku": "SKU-GOLD-256",
  "marketplaceId": "EBAY_US",
  "format": "FIXED_PRICE",
  "availableQuantity": 3,
  "categoryId": "9355",
  "merchantLocationKey": "WAREHOUSE-001",
  "pricingSummary": {
    "price": { "currency": "USD", "value": "849.99" }
  },
  "listingPolicies": {
    "fulfillmentPolicyId": "6XXX",
    "paymentPolicyId": "6XXX",
    "returnPolicyId": "6XXX",
    "bestOfferTerms": { "bestOfferEnabled": true }
  },
  "storeCategoryNames": ["Smartphones"]
}
```

> **Diferencia vs single:** En variaciones, el `listingDescription` del offer normalmente **se omite** porque la descripción vive en el `inventoryItemGroup`. Si se incluye, eBay puede ignorarla.

---

### Llamada final — `publishOfferByInventoryItemGroup` (una sola vez)

| Campo | Valor |
|-------|-------|
| eBay API | **Sell Inventory API** |
| Método | `POST` |
| eBay Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/publish_by_inventory_item_group` |
| Se llama | **1 vez** (publica todo el grupo) |
| Doc detallado | [05-offer-api.md](./05-offer-api.md) |

**Request Body:**
```json
{
  "inventoryItemGroupKey": "IPHONE13PRO-GROUP",
  "marketplaceId": "EBAY_US"
}
```

**Response:**
```json
{
  "listingId": "194379224011"
}
```

> Un solo `listingId` para todas las variaciones. Este es el ID del listing en eBay que aparece en la URL pública.

---

## Resumen de llamadas a eBay para variaciones (N = número de variaciones)

| Orden | eBay Endpoint | Veces |
|-------|--------------|-------|
| 1 a N | `PUT /sell/inventory/v1/inventory_item/{sku}` | N |
| N+1 | `PUT /sell/inventory/v1/inventory_item_group/{key}` | 1 |
| N+2 a 2N+1 | `POST /sell/inventory/v1/offer` | N |
| 2N+2 | `POST /sell/inventory/v1/offer/publish_by_inventory_item_group` | 1 |
| + | `POST /commerce/media/v1_beta/image/create_image_from_url` | 1 grupo + hasta N variaciones |

**Ejemplo con 3 variaciones:**
- 3 × createOrReplaceInventoryItem
- 1 × createOrReplaceInventoryItemGroup
- 3 × createOffer
- 1 × publishOfferByInventoryItemGroup
- = **8 llamadas a Sell Inventory API** + imágenes

---

## Tabla comparativa completa: Single vs Variaciones

| # | CRM Endpoint | Single | Variaciones | eBay Endpoint |
|---|-------------|--------|-------------|---------------|
| 1 | linked-accounts | ✅ | ✅ | CRM DB |
| 2 | category-suggestions | ✅ | ✅ | Taxonomy API |
| 3 | browse/search | ✅ | ✅ | Browse API (ref) |
| 4 | ebay-stores/categories | ✅ | ✅ | Stores API |
| 5 | taxonomy/aspects | ✅ | ✅ + selección de variation specs | Taxonomy API |
| 6 | policies/fulfillment | ✅ | ✅ | Account API |
| 7 | policies/payment | ✅ | ✅ | Account API |
| 8 | policies/return | ✅ | ✅ | Account API |
| 9 | inventory/locations | ✅ | ✅ | Inventory API |
| 10 | catalog-descriptions | ✅ | ✅ (va en el grupo) | CRM interno |
| 11 | imagen server privado | ✅ 1x | ⚠️ 1x grupo + Nx variación | Servidor privado |
| 12 | ebay-media/create-from-url | ✅ 1x | ⚠️ 1x grupo + Nx variación | Media API |
| 13a | create-listing → inventoryItem | ✅ 1x | ✅ Nx | `PUT /inventory_item/{sku}` |
| 13b | create-listing → itemGroup | ❌ No aplica | ✅ 1x | `PUT /inventory_item_group/{key}` |
| 13c | create-listing → offer | ✅ 1x | ✅ Nx | `POST /offer` |
| 13d | create-listing → publish | ✅ publishOffer | ✅ publishByGroup | `POST /offer/{id}/publish` o `publish_by_inventory_item_group` |

---

## Lo que falta implementar en v2 para variaciones

### 1. Frontend — Selector de atributos de variación
El formulario necesita una sección donde el usuario defina:
- Qué aspects son los "ejes" de variación (ej. Color y Storage)
- Los valores de cada eje (ej. Gray, Gold, Blue / 128GB, 256GB)
- Que el sistema genere automáticamente los N SKUs del producto cartesiano

### 2. Frontend — Precios por variación
Cada variación puede tener un precio diferente. El formulario actual (single) solo tiene un precio. En variaciones se necesita una tabla con precio y stock por cada combinación.

### 3. Frontend — Imagen por variación
El flujo de upload actual sube una sola imagen. Para variaciones:
- 1 imagen principal del grupo (obligatoria)
- Hasta N imágenes adicionales, una por variación (si el aspect que varía es visual, como Color)

### 4. Backend — Validación de `variantSKUs`
En `EbayOrchestratorService.processVariations()` no se valida que los SKUs en `inventoryItemGroup.variantSKUs` coincidan con los SKUs de `inventoryItemVariations`. Si hay mismatch, eBay rechaza el `publishOfferByInventoryItemGroup` con un error críptico.

### 5. Backend — Limpieza del DTO
El campo `bestOfferTerms` se construye en `buildOfferData()` pero no está declarado en la clase `ListingPolicies` del DTO. Hay que agregar la sub-clase con validación.

### 6. Backend — Manejo de error parcial en variaciones
Si 2 de 3 `createOrReplaceInventoryItem` fallan, el orquestador sigue adelante e intenta crear el grupo y publicar. En v2 debería abortar si hay errores en los inventory items.

---

## Payload completo de ejemplo para `POST /store/create-listing/2/4` con variaciones

```json
{
  "configuration": {
    "publishOnEbay": true,
    "publishOnGTSStore": false,
    "variation": true
  },
  "inventoryItemVariations": [
    {
      "sku": "IPHONE13PRO-GRAY-128",
      "availability": { "shipToLocationAvailability": { "quantity": 5 } },
      "condition": "NEW",
      "product": {
        "title": "Apple iPhone 13 Pro 128GB Space Gray Unlocked",
        "description": "...",
        "aspects": { "Color": ["Space Gray"], "Storage Capacity": ["128 GB"] },
        "imageUrls": ["https://i.ebayimg.com/.../gray.jpg"]
      }
    },
    {
      "sku": "IPHONE13PRO-GOLD-256",
      "availability": { "shipToLocationAvailability": { "quantity": 3 } },
      "condition": "NEW",
      "product": {
        "title": "Apple iPhone 13 Pro 256GB Gold Unlocked",
        "description": "...",
        "aspects": { "Color": ["Gold"], "Storage Capacity": ["256 GB"] },
        "imageUrls": ["https://i.ebayimg.com/.../gold.jpg"]
      }
    }
  ],
  "inventoryItemGroup": {
    "sku": "IPHONE13PRO-GROUP",
    "title": "Apple iPhone 13 Pro - All Colors & Storage - Unlocked",
    "description": "<p>Descripción compartida del listing...</p>",
    "aspects": {
      "Brand": ["Apple"],
      "Model": ["iPhone 13 Pro"],
      "Network": ["Unlocked"]
    },
    "imageUrls": ["https://i.ebayimg.com/.../group-main.jpg"],
    "variantSKUs": ["IPHONE13PRO-GRAY-128", "IPHONE13PRO-GOLD-256"],
    "variesBy": {
      "aspectsImageVariesBy": ["Color"],
      "specifications": [
        { "name": "Color", "values": ["Space Gray", "Gold"] },
        { "name": "Storage Capacity", "values": ["128 GB", "256 GB"] }
      ]
    }
  },
  "offerGroup": [
    {
      "sku": "IPHONE13PRO-GRAY-128",
      "marketplaceId": "EBAY_US",
      "format": "FIXED_PRICE",
      "availableQuantity": 5,
      "categoryId": "9355",
      "merchantLocationKey": "WAREHOUSE-001",
      "pricingSummary": { "price": { "currency": "USD", "value": "699.99" } },
      "listingPolicies": {
        "fulfillmentPolicyId": "6XXX",
        "paymentPolicyId": "6XXX",
        "returnPolicyId": "6XXX"
      },
      "listingDuration": "GTC"
    },
    {
      "sku": "IPHONE13PRO-GOLD-256",
      "marketplaceId": "EBAY_US",
      "format": "FIXED_PRICE",
      "availableQuantity": 3,
      "categoryId": "9355",
      "merchantLocationKey": "WAREHOUSE-001",
      "pricingSummary": { "price": { "currency": "USD", "value": "849.99" } },
      "listingPolicies": {
        "fulfillmentPolicyId": "6XXX",
        "paymentPolicyId": "6XXX",
        "returnPolicyId": "6XXX"
      },
      "listingDuration": "GTC"
    }
  ],
  "additionalInformation": {
    "categories": {
      "category": { "categoryId": "9355", "categoryName": "Cell Phones & Smartphones" },
      "categoryTreeNodeLevel": 3,
      "categoryTreeNodeAncestors": []
    }
  },
  "templateInformation": {}
}
```
