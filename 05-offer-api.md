# 05 — eBay Sell Inventory API (Offers & Publishing)

**Orden en el flujo de listing:** Pasos 5 y 6 — Después de crear el inventory item, se crea el offer (vincula el item al marketplace con precio y políticas) y luego se publica para que sea visible en eBay.

## Información general

| Campo | Valor |
|-------|-------|
| eBay API Name | **Sell Inventory API** (recursos de Offer) |
| Base URL | `https://api.ebay.com` / `https://api.sandbox.ebay.com` |
| Base Path | `/sell/inventory/v1/` |
| Auth requerida | User token (`getValidToken`) |
| Servicio en CRM | `EbayOfferService` |
| Archivo | `src/ecommerce/modules/ebay-offer/ebay-offer.service.ts` |

> Los recursos de Offer son parte de la misma **Sell Inventory API** que los inventory items, pero se documentan por separado por ser el siguiente paso del flujo.

---

## Flujo offer: Crear → Publicar

```
createOffer  →  publishOffer  →  listing visible en eBay
    ↓
  offerId
```

Un offer vincula un `inventory_item` (SKU) a:
- Un marketplace (ej. EBAY_US)
- Un precio
- Las políticas del vendedor
- Una categoría
- Una location (merchantLocationKey)

---

## Endpoints de creación

### 1. `createOffer`
**Usado en el flujo de listing: SÍ**

Crea un offer para un SKU en un marketplace específico.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer` |

**Request Body (ejemplo):**
```json
{
  "sku": "PROD-SKU-001",
  "marketplaceId": "EBAY_US",
  "format": "FIXED_PRICE",
  "availableQuantity": 5,
  "categoryId": "9355",
  "listingDescription": "<p>Descripción HTML del listing...</p>",
  "listingPolicies": {
    "fulfillmentPolicyId": "6XXX",
    "paymentPolicyId": "6XXX",
    "returnPolicyId": "6XXX"
  },
  "pricingSummary": {
    "price": {
      "currency": "USD",
      "value": "299.99"
    }
  },
  "merchantLocationKey": "WAREHOUSE-001",
  "tax": {
    "applyTax": true,
    "vatPercentage": 0
  }
}
```

**Response:**
```json
{
  "offerId": "1234567890"
}
```

---

### 2. `bulkCreateOffer`
**Usado en el flujo de listing: No (batch)**

Crea hasta 25 offers en una sola llamada.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/bulk_create_offer` |

---

## Endpoints de publicación

### 3. `publishOffer`
**Usado en el flujo de listing: SÍ — convierte el offer en un listing activo**

Una vez creado el offer, este endpoint lo publica en eBay. Devuelve el `listingId` del listing resultante.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}/publish` |
| Body | Vacío `{}` |

**Response:**
```json
{
  "listingId": "194379224010"
}
```

> El `listingId` es el ID del listing en eBay (el que aparece en la URL de la página del producto).

---

### 4. `bulkPublishOffer`
**Usado en el flujo de listing: No (batch)**

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/bulk_publish_offer` |

---

### 5. `publishOfferByInventoryItemGroup`
**Usado en el flujo de listing: No (variaciones)**

Para publicar listings multi-variación.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/publish_by_inventory_item_group` |

---

## Endpoints de consulta

### 6. `getOffer`
**Usado en flujos de actualización de stock: SÍ**

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}` |

---

### 7. `getOffers`
**Usado en flujos de actualización de stock: SÍ**

Lista los offers para un SKU específico.

| Campo | Valor |
|-------|-------|
| Método | `GET` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer` |

**Query params:**
| Parámetro | Descripción |
|-----------|-------------|
| `sku` | SKU del inventory item |
| `marketplace_id` | (opcional) |
| `format` | (opcional) |
| `limit` | default 100 |
| `offset` | default 0 |

---

## Endpoints de actualización y eliminación

### 8. `updateOffer`

| Campo | Valor |
|-------|-------|
| Método | `PUT` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}` |

---

### 9. `deleteOffer`

| Campo | Valor |
|-------|-------|
| Método | `DELETE` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}` |

---

## Endpoints de withdraw (retirar listing)

### 10. `withdrawOffer`
**Usado en flujo de stock = 0: SÍ**

Retira el listing sin eliminarlo. El offer queda en estado `UNPUBLISHED`.

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/{offerId}/withdraw` |
| Body | `{}` |

---

### 11. `withdrawOfferByInventoryItemGroup`
**Usado en el flujo de listing: No (variaciones)**

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/withdraw_by_inventory_item_group` |

---

## Otros endpoints

### 12. `getListingFees`
**Usado en el flujo de listing: No (consulta de costos)**

| Campo | Valor |
|-------|-------|
| Método | `POST` |
| Endpoint | `https://api.ebay.com/sell/inventory/v1/offer/get_listing_fees` |

---

## Estados de un offer

```
(creado) → UNPUBLISHED → (publish) → PUBLISHED → (withdraw) → UNPUBLISHED
                                        ↓
                                      ENDED  (expiró o se vendió todo)
```

El CRM maneja estos estados con lógica en `updateInventoryAndOfferQuantityWithWithdraw`:
- **PUBLISHED + stock > 0** → actualizar cantidad
- **PUBLISHED + stock = 0** → `withdrawOffer`
- **UNPUBLISHED + stock > 0** → `updateOffer` + `publishOffer`
- **ENDED + stock > 0** → `createOffer` (nuevo) + `publishOffer`

---

## Notas para v2

- El `listingDescription` acepta HTML. En v2 considerar un template system para generar HTML consistente.
- Un offer ENDED no se puede re-publicar directamente — hay que crear un offer nuevo con los mismos datos.
- La relación es: 1 SKU puede tener múltiples offers (uno por marketplace), pero en la práctica se usa solo EBAY_US.
- El `categoryId` del offer y los `aspects` del inventory item deben ser consistentes — si los aspects no coinciden con la categoría, eBay puede rechazar la publicación.
