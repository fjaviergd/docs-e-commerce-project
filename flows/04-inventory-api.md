# 04 — eBay Sell Inventory API (Inventory Items & Locations)

**Orden en el flujo de listing:** Paso 4 — Se crea el `inventory_item` con SKU, datos del producto, imágenes (obtenidas en paso 1) y disponibilidad. Sin este paso no se puede crear el offer.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Sell Inventory API** |
| Base URL | `https://api.ebay.com` / `https://api.sandbox.ebay.com` |
| Base Path | `/sell/inventory/v1/` |
| Auth requerida | User token (`getValidToken`) |
| Servicio en CRM | `EbayInventoryService` |
| Archivo | `src/ecommerce/modules/ebay-inventory/ebay-inventory.service.ts` |

---

## Endpoints — Inventory Items

### 1. `createOrReplaceInventoryItem`
**Usado en el flujo de listing: SÍ — es el paso central**

Crea un nuevo inventory item o lo reemplaza si ya existe el SKU. Usa método `PUT` (idempotente).

| Campo | Valor |
|-------|-------|
| Método | `PUT` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item/{sku}` |

**Request Body (ejemplo):**
```json
{
  "availability": {
    "shipToLocationAvailability": {
      "quantity": 5,
      "allocationByFormat": {
        "fixedPrice": 5,
        "auction": 0
      }
    }
  },
  "condition": "NEW",
  "product": {
    "title": "iPhone 13 Pro 256GB Space Gray",
    "description": "Descripción del producto...",
    "imageUrls": [
      "https://i.ebayimg.com/images/g/XXXX/s-l1600.jpg"
    ],
    "aspects": {
      "Brand": ["Apple"],
      "Storage Capacity": ["256 GB"],
      "Color": ["Space Gray"]
    }
  },
  "packageWeightAndSize": {
    "weight": {
      "value": 1.5,
      "unit": "POUND"
    }
  }
}
```

> **Importante:** Las `imageUrls` deben ser las URLs de eBay Picture Services (obtenidas en el paso 1 con Media API), no URLs externas directas.

**Response:** HTTP 204 No Content si exitoso.

---

### 2. `getInventoryItem`
**Usado en el flujo de listing: No directamente — sí en actualización de stock**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item/{sku}` |

---

### 3. `getInventoryItems`
**Usado en el flujo de listing: No**

Lista todos los inventory items de la cuenta con paginación.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item` |

**Query params:** `limit` (default 100), `offset` (default 0)

---

### 4. `deleteInventoryItem`
**Usado en el flujo de listing: No (operación de mantenimiento)**

| Campo | Valor |
|-------|-------|
| Método | `DELETE` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item/{sku}` |

---

### 5. `bulkCreateOrReplaceInventoryItems`
**Usado en el flujo de listing: No (batch operation)**

Crea o reemplaza hasta 25 inventory items en una sola llamada.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/bulk_create_or_replace_inventory_item` |

---

## Endpoints — Inventory Item Groups (Variaciones)

### 6. `createOrReplaceInventoryItemGroup`
**Usado en el flujo de listing: No (listings con variaciones)**

Para listings multi-variación (ej. misma camiseta en tallas S, M, L).

| Campo | Valor |
|-------|-------|
| Método | `PUT` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |

---

### 7. `getInventoryItemGroup` / `deleteInventoryItemGroup`

| Método | Endpoint |
|--------|----------|
| `GET` | `https://api.ebay.com/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |
| `DELETE` | `https://api.ebay.com/sell/inventory/v1/inventory_item_group/{inventoryItemGroupKey}` |

---

## Endpoints — Inventory Locations

Las locations representan el almacén/ubicación desde donde se envían los productos. El `merchantLocationKey` se incluye en el offer.

### 8. `createInventoryLocation`
**Usado en el flujo de listing: Prerequisito (setup de cuenta)**

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}` |

**Request Body (ejemplo):**
```json
{
  "location": {
    "address": {
      "addressLine1": "2055 Hamilton Ave",
      "city": "San Jose",
      "stateOrProvince": "CA",
      "postalCode": "95125",
      "country": "US"
    }
  },
  "locationTypes": ["WAREHOUSE"],
  "name": "Main Warehouse",
  "merchantLocationStatus": "ENABLED"
}
```

---

### 9. `updateInventoryLocation`

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}/update_location_details` |

---

### 10. `getInventoryLocation` / `getInventoryLocations` / `deleteInventoryLocation`

| Método | Endpoint |
|--------|----------|
| `GET` | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}` |
| `GET` | `https://api.ebay.com/sell/inventory/v1/location` |
| `DELETE` | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}` |

---

### 11. `enableInventoryLocation` / `disableInventoryLocation`

| Método | Endpoint |
|--------|----------|
| `POST` | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}/enable` |
| `POST` | `https://api.ebay.com/sell/inventory/v1/location/{merchantLocationKey}/disable` |

> No se puede eliminar una location de tipo `FULFILLMENT_CENTER` — se debe deshabilitar en su lugar.

---

## Endpoints usados en actualización de stock (no listing creation)

Estos endpoints están en `EbayInventoryService` pero se usan en el flujo de sincronización de stock, no en la creación inicial:

| Método | Endpoint | Propósito |
|--------|----------|-----------|
| `GET` | `/sell/inventory/v1/offer/{offerId}` | Obtener offer actual para validar stock |
| `GET` | `/sell/inventory/v1/offer` | Listar offers por SKU |
| `POST` | `/sell/inventory/v1/offer/{offerId}/withdraw` | Retirar listing (stock = 0) |
| `POST` | `/sell/inventory/v1/offer/{offerId}/publish` | Re-publicar listing (stock > 0) |

---

## Notas para v2

- El método `PUT` en `createOrReplaceInventoryItem` es idempotente — se puede llamar múltiples veces con el mismo SKU sin crear duplicados. Ideal para sincronización.
- eBay requiere al menos una imagen en `imageUrls` para poder publicar un listing.
- El `merchantLocationKey` en el offer es obligatorio — debe existir una location configurada antes de poder hacer listing.
- En v2, el campo `packageWeightAndSize` afecta el cálculo de shipping. Asegurarse de enviarlo correctamente.
