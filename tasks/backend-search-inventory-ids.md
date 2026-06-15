# Backend Spec: Search Inventory IDs Endpoint

> **Para:** Equipo de Backend — `gts-ecommerce-backend`
> **Contexto:** Este endpoint existe actualmente en `api-nestjs`. Se necesita portarlo a `gts-ecommerce-backend` con mejoras en los nombres de campos y lógica adicional de validación.

---

## 1. Para qué sirve este endpoint

El wizard de creación de listings (`e-commerce/create-listing`) necesita que el usuario asocie items de inventario del CRM al nuevo listing antes de publicarlo. El endpoint recibe términos de búsqueda (rangos de PO, rangos de IQ ID, IDs específicos), busca los items en la base de datos del CRM, y devuelve cuáles están disponibles para ser usados y cuáles ya están asignados a otro listing.

---

## 2. Referencia: endpoint actual en `api-nestjs`

El equipo puede revisar la implementación completa aquí:

| Archivo      | Ruta en `api-nestjs`                                                               |
| ------------ | ---------------------------------------------------------------------------------- |
| Controller   | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory.controller.ts`          |
| Service      | `src/ecommerce/modules/gts-crm-inventory/gts-crm-inventory.service.ts`             |
| Entity       | `src/ecommerce/modules/gts-crm-inventory/entities/gts-crm-inventory.entity.ts`     |
| Request DTO  | `src/ecommerce/modules/gts-crm-inventory/dto/search-inventory-ids.dto.ts`          |
| Response DTO | `src/ecommerce/modules/gts-crm-inventory/dto/search-inventory-ids-response.dto.ts` |

**Endpoint actual:** `POST /api/gts-crm-inventory/search-inventory-ids`

---

## 3. Base de datos que consulta actualmente

- **Datasource:** `gts_crm_db` (base de datos secundaria del CRM, no la principal de ecommerce)
- **Tabla:** `inventory`

### Columnas relevantes de la tabla `inventory`

| Columna DB                 | Entity property          | Tipo        | Descripción                                                                            |
| -------------------------- | ------------------------ | ----------- | -------------------------------------------------------------------------------------- |
| `id`                       | `id`                     | INT         | PK — identificador interno del registro                                                |
| `poid`                     | `poId`                   | INT         | Purchase Order ID                                                                      |
| `poline`                   | `poLine`                 | VARCHAR(11) | Purchase Order Line                                                                    |
| `inventoryid`              | `iqId`                   | INT         | IQ ID (identificador de inventario)                                                    |
| `ecommerce_listing_id`     | `ecommerceListingId`     | INT         | Si es `NULL`, el item está disponible; si tiene valor, ya está asignado a otro listing |
| `ebay_listing_id`          | `ebayListingId`          | VARCHAR     | ID del listing en eBay (si aplica)                                                     |
| `gts_store_listing_id`     | `gtsStoreListingId`      | INT         | ID del listing en GTS Store (si aplica)                                                |
| `data_sanitization_status` | `dataSanitizationStatus` | VARCHAR(50) | Estado de sanitización R2V3                                                            |
| `cosmetic_description`     | `cosmeticDescription`    | VARCHAR(50) | Descripción cosmética R2V3                                                             |
| `product_func_description` | `productFuncDescription` | VARCHAR(50) | Descripción funcional R2V3                                                             |

> **Nota:** No hay ningún campo de warehouse en la entidad actual. Ver §6 para el nuevo campo `crmWarehouseId` requerido.

### Queries SQL equivalentes que ejecuta actualmente

**Búsqueda por PO Line range** (`poid = X AND poline IN (...)`):

```sql
SELECT id, poid, poline, inventoryid, ecommerce_listing_id, ebay_listing_id, gts_store_listing_id
FROM inventory
WHERE poid = :poId AND poline IN (:lines)
```

**Búsqueda por IQ ID range o IDs específicos** (`inventoryid IN (...)`):

```sql
SELECT id, poid, poline, inventoryid, ecommerce_listing_id, ebay_listing_id, gts_store_listing_id
FROM inventory
WHERE inventoryid IN (:ids)
```

**Fetch R2V3 data** (solo cuando `numberOfItems = 1` y se encontró exactamente 1 item):

```sql
SELECT data_sanitization_status, cosmetic_description, product_func_description
FROM inventory
WHERE id = :id
LIMIT 1
```

---

## 4. Lógica actual del endpoint

### Request body

```typescript
{
  numberOfItems: number,      // Requerido. Total de items esperados (1–900). Debe coincidir exactamente con la suma de todos los rangos e IDs.
  rangePOLine?: string[],     // Opcional. Formato: "poId-start-end" ej. ["1234-1-5"]. Max 100 rangos.
  rangeIQId?: string[],       // Opcional. Formato: "start-end" ej. ["12345-12349"]. Max 100 rangos.
  iQId?: number[],            // Opcional. IDs específicos ej. [989898, 123456]. Max 900.
  checkAvailability?: boolean // Opcional. Si true, separa items disponibles de no disponibles.
}
```

### Flujo de validación

1. Calcula el total de items que representan todos los rangos e IDs enviados.
2. Valida que ese total sea igual a `numberOfItems`. Si no coincide → `400 BadRequest`.
3. Ejecuta las búsquedas por cada tipo de término.
4. Si `checkAvailability = true`, categoriza los resultados:
   - **Disponible:** `ecommerce_listing_id IS NULL`
   - **No disponible:** `ecommerce_listing_id IS NOT NULL` (ya asignado a otro listing)
5. Si `checkAvailability = true` y `numberOfItems = 1` y se encontró exactamente 1 item → incluye datos R2V3 del item.

### Response actual

```typescript
{
  itemsFound: [                         // Items disponibles (ecommerce_listing_id NULL)
    { id, poId, poLine, iqId }
  ],
  itemsNotFound: string[],              // Términos que no se encontraron en la DB
  itemsFoundUnavailable?: [            // Solo cuando checkAvailability=true
    { id, poId, poLine, iqId, ecommerceListingId, ebayListingId, gtsStoreListingId }
  ],
  r2v3Data?: {                          // Solo cuando checkAvailability=true y numberOfItems=1 con 1 resultado
    dataSanitizationStatus?: string,
    cosmeticDescription?: string,
    productFunctionalityDescription?: string
  }
}
```

---

## 5. Lo que debe hacer el nuevo endpoint en `gts-ecommerce-backend`

El comportamiento general es el mismo. Los cambios son:

### 5.1 Renombrar los campos de respuesta

Los nombres actuales mezclan convenciones. En el nuevo endpoint todos los campos del objeto de item llevan el prefijo `crm` para dejar claro que son IDs provenientes de la base del CRM.

**Antes (actual):**

```json
{
  "id": 480383,
  "poId": 10214,
  "poLine": "9",
  "iqId": 0
}
```

**Después (nuevo):**

```json
{
  "crmInventoryId": 480383,
  "crmPoId": 10214,
  "crmPoLine": "9",
  "crmIqId": 0,
  "crmWarehouseId": 1
}
```

Este renombramiento aplica a todos los objetos de item en la respuesta: `itemsFound`, `itemsFoundUnavailable`.

### 5.2 Agregar `crmWarehouseId`

Cada item encontrado debe incluir el warehouse al que pertenece. El equipo de backend debe investigar:

- En la tabla `inventory` del CRM, ¿existe alguna columna de warehouse? (revisar columnas no mapeadas en la entidad actual)
- Si no existe en `inventory` directamente, ¿hay una tabla relacionada (ej. `warehouse`, `po_warehouse`, o similar) desde la cual se pueda obtener el warehouse a través del `poid` o `inventoryid`?

Una vez identificada la fuente, incluir `crmWarehouseId` en la respuesta de cada item.

### 5.3 Agregar validación de reserva de items

Actualmente el endpoint solo verifica si un item está **asignado** a un listing (`ecommerce_listing_id IS NOT NULL`). La nueva versión también debe verificar si el item está **reservado**.

El equipo de backend debe investigar:

- ¿Existe en `gts_crm_db` (o en `gts-ecommerce-backend`) alguna tabla o campo que indique reserva de items? (ej. tabla `inventory_reservations`, flag `reserved`, `reservation_id`, o similar)
- Definir la lógica: un item reservado, ¿debe caer en `itemsFoundUnavailable` o en una nueva categoría `itemsFoundReserved`?

> **Sugerencia:** Coordinar con el equipo que gestiona el proceso de reserva para entender el modelo de datos. Si no existe aún, definir el esquema antes de implementar.

---

## 6. Nuevo contrato del endpoint

### Ruta sugerida

```
POST /api/inventory/search-inventory-ids
```

_(o la convención de rutas que use `gts-ecommerce-backend`)_

### Request body (sin cambios respecto al actual)

```typescript
{
  numberOfItems: number,       // 1–900, debe coincidir con el total de rangos + IDs
  rangePOLine?: string[],      // ["poId-start-end"], max 100
  rangeIQId?: string[],        // ["start-end"], max 100
  iQId?: number[],             // [id1, id2, ...], max 900
  checkAvailability?: boolean
}
```

### Response (con nuevos nombres de campos)

```typescript
{
  itemsFound: [
    {
      crmInventoryId: number,  // era: id
      crmPoId: number,         // era: poId
      crmPoLine: string,       // era: poLine
      crmIqId: number,         // era: iqId
      crmWarehouseId: number   // NUEVO — requiere investigación
    }
  ],
  itemsNotFound: string[],
  itemsFoundUnavailable?: [    // Items con ecommerce_listing_id != null O reservados
    {
      crmInventoryId: number,
      crmPoId: number,
      crmPoLine: string,
      crmIqId: number,
      crmWarehouseId: number,
      ecommerceListingId: number,
      ebayListingId: string | null,
      gtsStoreListingId: number | null
    }
  ],
  r2v3Data?: {                 // Sin cambios — solo cuando checkAvailability=true y numberOfItems=1 con 1 resultado
    dataSanitizationStatus?: string,
    cosmeticDescription?: string,
    productFunctionalityDescription?: string
  }
}
```

---

## 7. Auth y entorno

- El endpoint debe estar protegido con Bearer token (igual que los demás endpoints de `gts-ecommerce-backend`)
- La conexión a `gts_crm_db` ya existe en `api-nestjs`. Confirmar si `gts-ecommerce-backend` ya tiene acceso a esa misma base de datos o si se necesita configurar un datasource adicional.

---

## 8. Preguntas abiertas para el equipo de backend

| #   | Pregunta                                                   | Quién debe responder                   |
| --- | ---------------------------------------------------------- | -------------------------------------- |
| 1   | ¿`gts-ecommerce-backend` ya tiene conexión a `gts_crm_db`? | Si, con estas varibles GTS_CRM_DB_HOST |

GTS_CRM_DB_PORT
GTS_CRM_DB_NAME
GTS_CRM_DB_USERNAME
GTS_CRM_DB_PASSWORD|
| 2 | ¿Dónde se almacena el warehouse de un item de inventario en el CRM? | en la tabla inventory hay una llave foranea del warehouse (warehouse_id) con referencia a la tabla locations |
| 3 | ¿Existe un mecanismo de reserva de items? ¿Qué tabla/columna? | tabla inventory campo (status 2 valores, Available y Reserved)|
| 4 | ~~Un item reservado ¿va en `itemsFoundUnavailable` o en una categoría nueva?~~ **Resuelto:** los items reservados van en `itemsFoundUnavailable`. El frontend mostrará al usuario que no están disponibles, igual que los ya listados. | — |
