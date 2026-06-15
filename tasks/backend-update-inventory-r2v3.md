# Backend Spec: Actualización de R2V3 en Items de Inventario al Crear Listing

> **Para:** Equipo de Backend — `gts-ecommerce-backend`
> **Contexto:** Esta tarea es parte del flujo de creación de listings en `e-commerce-v2`. Cuando el usuario publica, agenda o guarda como borrador un listing, el backend debe actualizar los valores de condición R2V3 en los items de inventario del CRM que fueron asociados al listing.

---

## 1. Cuándo debe ejecutarse

Esta actualización **no es un endpoint independiente**. Debe ocurrir **dentro del proceso de creación del listing**, como parte de la misma transacción. No es una llamada separada del frontend.

| Acción del usuario | ¿Se actualiza R2V3? |
|---|---|
| **Publish** | Sí |
| **Schedule** | Sí |
| **Save as Draft** | Sí (los items quedan marcados como asignados al listing en borrador) |

---

## 2. Qué datos envía el frontend

Cuando el usuario hace submit del listing, el payload incluye (entre otros campos) la sección R2V3:

```typescript
{
  // ... resto del payload del listing ...

  // Sección R2V3 — viene de CreateListingFormService
  r2v3FoundItems: [                  // Items disponibles que el usuario buscó y validó
    {
      crmInventoryId: number,        // PK del registro en tabla inventory de gts_crm_db
      crmPoId: number,
      crmPoLine: string,
      crmIqId: number,
      crmWarehouseId: number
    },
    // ... más items
  ],
  r2v3DataSanitization: string,      // ej. "Non-Data" | "Pre-Sanitization"
  r2v3CosmeticDescription: string,   // ej. "C3", "C5", "C8", etc.
  r2v3ProductFunction: string,       // ej. "F3", "F4", "F6", etc.
}
```

> Si `r2v3FoundItems` llega vacío, no hay items que actualizar — omitir este paso sin error.

---

## 3. Qué debe hacer el backend

Al procesar la creación del listing, después de crear el registro del listing y **dentro de la misma transacción**:

1. Tomar los `crmInventoryId` de `r2v3FoundItems`
2. En la tabla `inventory` de `gts_crm_db`, actualizar esos registros con:
   - `data_sanitization_status` ← `r2v3DataSanitization`
   - `cosmetic_description` ← `r2v3CosmeticDescription`
   - `product_func_description` ← `r2v3ProductFunction`
   - `ecommerce_listing_id` ← ID del listing recién creado
   - `testing_status` ← `'TESTED'` (valor fijo, siempre)
3. Si falla cualquier parte de la transacción → rollback completo. No puede quedar el listing creado con items sin actualizar, ni items actualizados sin listing.

### SQL equivalente

```sql
UPDATE inventory
SET
  data_sanitization_status = :r2v3DataSanitization,
  cosmetic_description      = :r2v3CosmeticDescription,
  product_func_description  = :r2v3ProductFunction,
  ecommerce_listing_id      = :newListingId,
  testing_status            = 'TESTED'
WHERE id IN (:crmInventoryIds)
```

---

## 4. Referencia: cómo lo hace el endpoint actual en `crm-api-nestjs`

Existe un endpoint que ya hace este trabajo. El equipo puede revisarlo como referencia:

| Archivo | Ruta en `crm-api-nestjs` |
|---|---|
| Controller | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory.controller.ts` |
| Service (update) | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory-update-stock.service.ts` |
| DTO de request | `src/ecommerce/modules/gts-crm-inventory/dto/update-inventory-stock.dto.ts` |

**Endpoint de referencia:** `POST /api/gts-crm-inventory/update-inventory-stock`

**Request body actual:**
```typescript
{
  inventoryIds: number[],        // Array de IDs (equivalente a los crmInventoryId)
  actionType: 'increment',       // 'increment' = asignar al listing, 'decrement' = desasociar
  valueData?: string,            // data_sanitization_status
  valueC?: string,               // cosmetic_description
  valueF?: string,               // product_func_description
  ecommerceListingId?: number,   // ID del listing
  ebayListingId?: string,
  gtsStoreListingId?: number,
}
```

También tiene una variante `updateInventoryStockWithManager()` que acepta un `EntityManager` para correr dentro de una transacción existente — exactamente el patrón que se necesita aquí.

> El equipo de `gts-ecommerce-backend` puede optar por llamar a este endpoint vía HTTP o replicar la lógica directamente si ya tienen acceso a `gts_crm_db`.

---

## 5. Proceso inverso: cuando se elimina o se revierte el listing

Cuando un listing es eliminado o sus items son desasociados, los campos deben limpiarse:

```sql
UPDATE inventory
SET
  ecommerce_listing_id = NULL,
  ebay_listing_id      = NULL,
  gts_store_listing_id = NULL
WHERE id IN (:crmInventoryIds)
```

En `crm-api-nestjs` esto está implementado como `actionType: 'decrement'` en el mismo endpoint de referencia.

---

## 6. Tabla afectada

| Dato | Valor |
|---|---|
| Base de datos | `gts_crm_db` |
| Tabla | `inventory` |
| PK usada para el update | columna `id` (= `crmInventoryId` en el nuevo contrato) |

### Columnas que se escriben

| Columna DB | Campo del payload | Notas |
|---|---|---|
| `data_sanitization_status` | `r2v3DataSanitization` | VARCHAR(50) |
| `cosmetic_description` | `r2v3CosmeticDescription` | VARCHAR(50) |
| `product_func_description` | `r2v3ProductFunction` | VARCHAR(50) |
| `ecommerce_listing_id` | ID del listing creado | INT — marca el item como "no disponible" para otros listings |
| `testing_status` | `'TESTED'` (fijo) | VARCHAR(50) |

---

## 7. Consideración sobre items reservados

Cuando se implemente la lógica de reserva (ver `backend-search-inventory-ids.md` §5.3), este mismo proceso de update deberá también **liberar la reserva** del item al asignarlo definitivamente al listing. El mecanismo exacto depende de cómo el equipo implemente las reservas.

---

## 8. Preguntas abiertas

| # | Pregunta |
|---|---|
| 1 | ¿`gts-ecommerce-backend` accede directamente a `gts_crm_db` o llama a `crm-api-nestjs` vía HTTP? |
| 2 | ¿El proceso de creación de listing ya usa transacciones? Si no, este es un buen momento para introducirlas. |
| 3 | Cuando se implemente reservas: ¿el update R2V3 también libera la reserva en la misma transacción? |
