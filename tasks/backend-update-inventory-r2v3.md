# Backend Spec: Actualización de R2V3 en Items de Inventario al Crear Listing

> **Para:** Equipo de Backend — `gts-ecommerce-backend`
> **Contexto:** Esta tarea es parte del flujo de creación de listings en `e-commerce-v2`. Cuando el usuario publica, agenda o guarda como borrador un listing, el backend debe actualizar los valores de condición R2V3 en los items de inventario del CRM que fueron asociados al listing.

## Metadata de la tarea

| Campo | Valor |
|---|---|
| **ID de tarea** | `BE-INV-R2V3` |
| **Estado** | Pendiente (To Do) |
| **Prioridad** | Media |
| **Creada por** | Javier (`javier@ha-software.com`) |
| **Asignada a** | Equipo Backend — `gts-ecommerce-backend` |
| **Fecha de creación** | 2026-07-21 |
| **Última modificación** | 2026-07-21 |
| **Sprint / Milestone** | _(por definir)_ |
| **Repos afectados** | `gts-ecommerce-backend`, `gts_crm_db` |
| **Docs relacionados** | `backend-search-inventory-ids.md` |

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

  // Usuario que ejecuta la acción — usado para los campos de auditoría (tested/received)
  // OBLIGATORIOS: siempre hay un usuario creando el listing.
  userId: number,                    // ID del usuario en el CRM
  userInitials: string,              // iniciales del usuario, ej. "JR"
}
```

> Si `r2v3FoundItems` llega vacío, no hay items que actualizar — omitir este paso sin error.
> `userId` y `userInitials` son **obligatorios**: siempre existe un usuario que crea el listing. Si no llegan, el request debe rechazarse (400).

---

## 3. Qué debe hacer el backend

Al procesar la creación del listing, después de crear el registro del listing y **dentro de la misma transacción**:

1. Tomar los `crmInventoryId` de `r2v3FoundItems`
2. En la tabla `inventory` de `gts_crm_db`, actualizar esos registros con:

   **Condición R2V3**
   - `data_sanitization_status` ← `r2v3DataSanitization`
   - `cosmetic_description` ← `r2v3CosmeticDescription`
   - `product_func_description` ← `r2v3ProductFunction`

   **Asignación al listing (siempre se sobrescribe)**
   - `ecommerce_listing_id` ← ID del listing recién creado

   **Estado por defecto (se fuerza al valor indicado si aún no lo tiene)**
   - `testing_status` ← `'TESTED'` — si el valor actual no es `'TESTED'`, ponerlo
   - `receivestatus` ← `'Received'` — si el valor actual no es `'Received'`, ponerlo

   > ⚠️ **Regla de preservación (importante):** los 8 campos de las dos secciones siguientes (las 4 fechas y los 4 de auditoría) **solo se escriben si el registro NO tiene ya un valor** (columna `NULL` o cadena vacía). Si el item ya fue recibido/testeado antes, esos valores originales **NO deben sobrescribirse** — hacerlo perdería la información real de cuándo y por quién se recibió/testeó el item.

   **Timestamps (solo si están vacíos)**
   - `datereceived` ← fecha-hora actual como string, formato `MM/DD/YYYY hh:mm:ss AM/PM`
   - `datereceived2` ← fecha-hora actual como `DATETIME`
   - `datetest` ← misma fecha-hora que `datereceived` (string)
   - `datetest2` ← misma fecha-hora que `datereceived2` (`DATETIME`)

   **Auditoría de usuario (solo si están vacíos — `userId` / `userInitials` son obligatorios en el payload)**
   - `testedbyuser_id` ← `userId`
   - `receivedbyuser_id` ← `userId`
   - `testedby` ← `userInitials`
   - `receivedby` ← `userInitials`

3. Si falla cualquier parte de la transacción → rollback completo. No puede quedar el listing creado con items sin actualizar, ni items actualizados sin listing.

### SQL equivalente

Los campos R2V3 + asignación se sobrescriben siempre; `testing_status` y `receivestatus` se fuerzan a su valor por defecto (equivale a asignarlo siempre). Los 8 campos restantes usan `COALESCE` / `NULLIF` para escribir **solo si están vacíos** (preservan el valor existente):

```sql
UPDATE inventory
SET
  -- Siempre se sobrescriben
  data_sanitization_status = :r2v3DataSanitization,
  cosmetic_description      = :r2v3CosmeticDescription,
  product_func_description  = :r2v3ProductFunction,
  ecommerce_listing_id      = :newListingId,

  -- Valor por defecto forzado (si no lo tiene ya)
  testing_status            = 'TESTED',
  receivestatus             = 'Received',

  -- Solo si están vacíos (NULL o cadena vacía) — preservar valor existente
  datereceived      = COALESCE(NULLIF(datereceived, ''), :nowText),   -- 'MM/DD/YYYY hh:mm:ss AM/PM'
  datereceived2     = COALESCE(datereceived2, :now),                  -- DATETIME
  datetest          = COALESCE(NULLIF(datetest, ''), :nowText),
  datetest2         = COALESCE(datetest2, :now),
  testedbyuser_id   = COALESCE(testedbyuser_id, :userId),
  receivedbyuser_id = COALESCE(receivedbyuser_id, :userId),
  testedby          = COALESCE(NULLIF(testedby, ''), :userInitials),
  receivedby        = COALESCE(NULLIF(receivedby, ''), :userInitials)
WHERE id IN (:crmInventoryIds)
```

> `NULLIF(col, '')` convierte la cadena vacía en `NULL` para que `COALESCE` la trate como "sin valor". Para columnas numéricas / `DATETIME` basta `COALESCE(col, :nuevo)`.

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

| Columna DB | Campo del payload / valor | Condición | Notas |
|---|---|---|---|
| `data_sanitization_status` | `r2v3DataSanitization` | Siempre (sobrescribe) | VARCHAR(50) |
| `cosmetic_description` | `r2v3CosmeticDescription` | Siempre (sobrescribe) | VARCHAR(50) |
| `product_func_description` | `r2v3ProductFunction` | Siempre (sobrescribe) | VARCHAR(50) |
| `ecommerce_listing_id` | ID del listing creado | Siempre (sobrescribe) | INT — marca el item como "no disponible" para otros listings |
| `testing_status` | `'TESTED'` (fijo) | Valor por defecto forzado (si no es `'TESTED'`) | VARCHAR(50) |
| `receivestatus` | `'Received'` (fijo) | Valor por defecto forzado (si no es `'Received'`) | VARCHAR(80) |
| `datereceived` | fecha-hora actual (string) | **Solo si está vacío** | VARCHAR(100) — formato `MM/DD/YYYY hh:mm:ss AM/PM` |
| `datereceived2` | fecha-hora actual | **Solo si está vacío** | DATETIME |
| `datetest` | igual a `datereceived` | **Solo si está vacío** | VARCHAR(100) |
| `datetest2` | igual a `datereceived2` | **Solo si está vacío** | DATETIME |
| `testedbyuser_id` | `userId` | **Solo si está vacío** | INT |
| `receivedbyuser_id` | `userId` | **Solo si está vacío** | INT |
| `testedby` | `userInitials` | **Solo si está vacío** | VARCHAR(20) |
| `receivedby` | `userInitials` | **Solo si está vacío** | VARCHAR(20) |

> **Regla de preservación:** los 8 campos marcados "Solo si está vacío" nunca sobrescriben un valor existente. Si el item ya fue recibido/testeado, se conserva su información original (fecha y usuario reales). Ver SQL con `COALESCE`/`NULLIF` en §3.
> **Excepción:** `testing_status` y `receivestatus` sí se fuerzan a su valor por defecto (`'TESTED'` / `'Received'`) aunque ya tengan otro valor.

> **Nota:** el proceso legacy también escribe `ebay_listing_id` y `gts_store_listing_id`. Por decisión de este flujo **NO se incluyen** en el update de creación (se dejan fuera de alcance). El proceso inverso (§5) sí los limpia por seguridad.

---

## 7. Consideración sobre items reservados

Cuando se implemente la lógica de reserva (ver `backend-search-inventory-ids.md` §5.3), este mismo proceso de update deberá también **liberar la reserva** del item al asignarlo definitivamente al listing. El mecanismo exacto depende de cómo el equipo implemente las reservas.

---

## 8. Preguntas abiertas

| #   | Pregunta                                                                                                    |
| --- | ----------------------------------------------------------------------------------------------------------- |
| 1   | ¿`gts-ecommerce-backend` accede directamente a `gts_crm_db` o llama a `crm-api-nestjs` vía HTTP?            |
| 2   | ¿El proceso de creación de listing ya usa transacciones? Si no, este es un buen momento para introducirlas. |
| 3   | Cuando se implemente reservas: ¿el update R2V3 también libera la reserva en la misma transacción?           |
