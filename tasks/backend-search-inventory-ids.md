# Endpoint de búsqueda de IDs de inventario (CRM)

Porta a `gts-ecommerce-backend` el endpoint de búsqueda de items de inventario del CRM que ya existía en `api-nestjs`, con nombres de campo con prefijo `crm`, un nuevo campo `crmWarehouseId`, y validación de reserva de items.

> Consumido por el wizard de creación de listings (`e-commerce/create-listing`) para asociar items de inventario del CRM a un listing antes de publicarlo.
>
> **Estado: Diseño ✅ CERRADO · Implementación ✅ MERGEADA a `develop`** (commit `00f57c4 feat: search inventory ids`, parte del PR #6 ya integrado).

---

## 1. Referencia original (`api-nestjs`)

| Archivo | Ruta en `api-nestjs` |
|---|---|
| Controller | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory.controller.ts` |
| Service | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory.service.ts` |
| Entity | `src/ecommerce/modules/gts-crm-inventory/entities/gts-crm-inventory.entity.ts` |

Endpoint original: `POST /api/gts-crm-inventory/search-inventory-ids`.

## 2. Base de datos (`gts_crm_db.inventory`)

| Columna DB | Descripción |
|---|---|
| `id` | PK interna |
| `poid` / `poline` | Purchase Order ID / línea |
| `inventoryid` | IQ ID |
| `warehouse_id` | FK a `locations` — resuelve `crmWarehouseId` |
| `ecommerce_listing_id` | `NULL` = disponible; con valor = ya asignado a un listing |
| `status` | `Available` \| `Reserved` — resuelve la validación de reserva |
| `data_sanitization_status` / `cosmetic_description` / `product_func_description` | R2V3, devueltos solo cuando `numberOfItems = 1` |

## 3. Contrato implementado

`POST /api/inventory/search-inventory-ids` (`CrmInventoryController` / `CrmInventoryService`):

```typescript
// Request — sin cambios respecto al original
{
  numberOfItems: number,       // 1–900
  rangePOLine?: string[],      // ["poId-start-end"], max 100
  rangeIQId?: string[],        // ["start-end"], max 100
  iQId?: number[],             // max 900
  checkAvailability?: boolean
}

// Response — nombres con prefijo `crm` + crmWarehouseId + reserva incluida en itemsFoundUnavailable
{
  itemsFound: [{ crmInventoryId, crmPoId, crmPoLine, crmIqId, crmWarehouseId }],
  itemsNotFound: string[],
  itemsFoundUnavailable?: [{ crmInventoryId, crmPoId, crmPoLine, crmIqId, crmWarehouseId, ecommerceListingId, ebayListingId, gtsStoreListingId }],
  r2v3Data?: { dataSanitizationStatus?, cosmeticDescription?, productFunctionalityDescription? }
}
```

Un item se marca `itemsFoundUnavailable` si `ecommerce_listing_id IS NOT NULL` **o** `status = 'Reserved'` (`CrmInventoryService.isUnavailable()`).

## 4. Decisiones cerradas (preguntas originales resueltas)

| # | Pregunta | Resuelta |
|---|---|---|
| 1 | ¿Ya hay conexión a `gts_crm_db`? | Sí, vía `GTS_CRM_DB_HOST/PORT/NAME/USERNAME/PASSWORD` — `CrmDatabaseService`, global, MySQL. |
| 2 | ¿Dónde vive el warehouse de un item? | `inventory.warehouse_id` → FK a `locations`. |
| 3 | ¿Existe mecanismo de reserva? | Sí — `inventory.status` con 2 valores: `Available` / `Reserved`. |
| 4 | ¿Un item reservado va en `itemsFoundUnavailable` o en una categoría nueva? | **Resuelto:** va en `itemsFoundUnavailable`, igual que los ya asignados a otro listing. El frontend los muestra como no disponibles sin distinguir el motivo. |

## 5. Relación con otras tareas

- `backend-update-inventory-r2v3.md` reutiliza `crmInventoryId` (aquí acuñado) como identificador de los items a actualizar al crear un listing.
- El `status` (`Available`/`Reserved`) que resuelve la reserva aquí es el mismo campo que `backend-update-inventory-r2v3.md` §7 documenta como **no tocado** por el flujo de creación de listing.
