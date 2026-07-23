# Actualización de R2V3 en items de inventario al crear listing

Al crear, agendar o guardar como borrador un listing en `gts-ecommerce-backend`, refleja la condición R2V3 y la asignación del listing en los items de inventario del CRM (`gts_crm_db.inventory`) que quedaron vinculados — sin exponer un endpoint independiente para esto.

> **ID de tarea:** `BE-INV-R2V3` · **Creada por:** Javier (`javier@ha-software.com`) · **Repos afectados:** `gts-ecommerce-backend`, `gts_crm_db`.
>
> **Estado: Diseño ✅ CERRADO (2 decisiones nuevas sobre el contrato original, ver §9) · Implementación 🟡 CONSTRUIDA, sin desplegar ni validar E2E contra un CRM real.**
>
> **Construcción (2026-07-23):** implementado como último paso de `ListingsService.create()` (rama `feature/r2v3`). Cubre condición R2V3, asignación (`ecommerce_listing_id`), forzado de `testing_status`/`receivestatus`, y preservación de los 8 campos de auditoría/timestamps. **No implementado:** el proceso inverso de limpieza al eliminar/desasociar un listing (§7) — hoy no existe ningún flujo de eliminación de `inventoryLinks` en el backend al que enganchar esa limpieza.
>
> **Decisión de arquitectura (2026-07-23) — `crm_listing_ref`:** el contrato original asumía que `ecommerce_listing_id` (INT en el CRM/MySQL) podía recibir el ID del listing recién creado. `Listing.id` en este backend es UUID (Postgres) — no cabe en una columna `INT`. Se agregó `Listing.crmListingRef` (`Int @unique @default(autoincrement())`, migración `20260723000001_add_listing_crm_ref`) como surrogate numérico dedicado. Ver §9.1.
>
> **Decisión de arquitectura (2026-07-23) — iniciales de usuario:** el contrato original asumía que el frontend envía `userId`/`userInitials` en el payload. Ninguno de los dos existe: no hay campo `initials` en ningún modelo de usuario de este backend ni de la guardia CRM (`CrmAdminGuard`). Se usa `createdBy` (ya existente, numérico, viene de `req.user.sub`) para `testedbyuser_id`/`receivedbyuser_id`, y las iniciales se derivan de `firstName`/`lastName` (ej. "Javier Rodriguez" → "JR") para `testedby`/`receivedby`. Ver §9.2.

---

## 1. Cuándo se ejecuta

No es un endpoint independiente ni una llamada separada del frontend. Ocurre **dentro de la transacción Prisma** que ya crea el listing (`ListingsService.create()`), como su último paso:

| Acción del usuario | ¿Se actualiza R2V3 en el CRM? |
|---|---|
| **Publish** (`status: 'ready'` + canal) | Sí |
| **Schedule** (`ebay.scheduledAt`) | Sí |
| **Save as Draft** (`status: 'draft'`) | Sí — los items quedan marcados como asignados al listing en borrador |

Si no hay ningún `inventoryLinks` (ni a nivel listing ni dentro de las variaciones), el paso se omite sin error.

## 2. De dónde vienen los datos (mapeo real vs. contrato original)

El contrato original de esta spec proponía un payload dedicado (`r2v3FoundItems`, `r2v3DataSanitization`, `r2v3CosmeticDescription`, `r2v3ProductFunction`, `userId`, `userInitials`). El DTO real (`create-listing.dto.ts`) ya cubre lo mismo con nombres distintos — no se agregó ningún campo nuevo al contrato de la API:

| Dato necesario | Campo real en `CreateListingDto` |
|---|---|
| Items a actualizar | `inventoryLinks[]` (nivel listing) + `variations[].inventoryLinks[]` (nivel variación) — mismo `CreateInventoryLinkDto` que ya alimenta `listingInventoryLink` en Postgres |
| `data_sanitization_status` | `r2v3DataSanitization` (`NON_DATA` \| `PRE_SANITIZATION`) |
| `cosmetic_description` | `r2v3Cosmetic` (`C0`–`C9`) |
| `product_func_description` | `r2v3Functionality` (`F1`–`F6`) |
| Usuario que ejecuta la acción | `createdBy` (parseado de `req.user.sub` en `CrmAdminGuard`) + `actingUser.firstName/lastName` (mismo `req.user`) |

## 3. Qué hace el backend (paso 10 de `create()`)

Después de los pasos 1–9 (listing, pricing, stock, variaciones, imágenes, canales) y **antes de que la transacción de Postgres haga commit**:

1. Junta los `crmInventoryId` de `dto.inventoryLinks` y de cada `variations[].inventoryLinks`.
2. Si la lista queda vacía → omite el paso.
3. Ejecuta un único `UPDATE` en `gts_crm_db.inventory` (vía `CrmDatabaseService`, MySQL) para todos los IDs recolectados.

Si el `UPDATE` falla, la excepción se propaga y **Prisma revierte toda la transacción** (steps 1–9 incluidos) — nunca queda un listing creado en Postgres con sus items sin reflejar en el CRM. Ver la limitación inversa en §9.3.

## 4. Columnas que se escriben en `gts_crm_db.inventory`

| Columna DB | Origen | Condición | Notas |
|---|---|---|---|
| `data_sanitization_status` | `dto.r2v3DataSanitization` | Solo si el DTO lo envía (ver §9.4) | VARCHAR(50) |
| `cosmetic_description` | `dto.r2v3Cosmetic` | Solo si el DTO lo envía | VARCHAR(50) |
| `product_func_description` | `dto.r2v3Functionality` | Solo si el DTO lo envía | VARCHAR(50) |
| `ecommerce_listing_id` | `listing.crmListingRef` | Siempre (sobrescribe) | INT — ver §9.1 |
| `testing_status` | `'TESTED'` (fijo) | Forzado siempre | VARCHAR(50) |
| `receivestatus` | `'Received'` (fijo) | Forzado siempre | VARCHAR(80) |
| `datereceived` | fecha-hora actual (string `MM/DD/YYYY hh:mm:ss AM/PM`, UTC) | Solo si está vacío (`NULL`/`''`) | VARCHAR(100) |
| `datereceived2` | fecha-hora actual (DATETIME) | Solo si está vacío | DATETIME |
| `datetest` | igual a `datereceived` | Solo si está vacío | VARCHAR(100) |
| `datetest2` | igual a `datereceived2` | Solo si está vacío | DATETIME |
| `testedbyuser_id` | `createdBy` | Solo si está vacío | INT |
| `receivedbyuser_id` | `createdBy` | Solo si está vacío | INT |
| `testedby` | iniciales derivadas de `actingUser` | Solo si está vacío | VARCHAR(20) |
| `receivedby` | iniciales derivadas de `actingUser` | Solo si está vacío | VARCHAR(20) |

> **Regla de preservación:** los 8 campos "solo si está vacío" nunca sobrescriben un valor existente — si el item ya fue recibido/testeado antes, se conserva su información real.

## 5. SQL implementado

```sql
UPDATE inventory
SET
  data_sanitization_status = COALESCE(?, data_sanitization_status),
  cosmetic_description      = COALESCE(?, cosmetic_description),
  product_func_description  = COALESCE(?, product_func_description),
  ecommerce_listing_id      = ?,

  testing_status            = 'TESTED',
  receivestatus             = 'Received',

  datereceived      = COALESCE(NULLIF(datereceived, ''), ?),
  datereceived2     = COALESCE(datereceived2, ?),
  datetest          = COALESCE(NULLIF(datetest, ''), ?),
  datetest2         = COALESCE(datetest2, ?),
  testedbyuser_id   = COALESCE(testedbyuser_id, ?),
  receivedbyuser_id = COALESCE(receivedbyuser_id, ?),
  testedby          = COALESCE(NULLIF(testedby, ''), ?),
  receivedby        = COALESCE(NULLIF(receivedby, ''), ?)
WHERE id IN (?, ?, ...)
```

Implementado en `ListingsService.updateCrmInventoryR2V3()` (`listings.service.ts`), usando `CrmDatabaseService.execute()` (mismo cliente MySQL que ya usa `CrmInventoryService`/`ebay-auth.service.ts`).

## 6. Proceso inverso — pendiente, sin implementar

El contrato original pedía limpiar `ecommerce_listing_id`/`ebay_listing_id`/`gts_store_listing_id` cuando un listing se elimina o sus items se desasocian:

```sql
UPDATE inventory
SET ecommerce_listing_id = NULL, ebay_listing_id = NULL, gts_store_listing_id = NULL
WHERE id IN (:crmInventoryIds)
```

**No se implementó.** `ListingsService.softDelete()` (el único "delete" que existe hoy) solo cambia `status = 'inactive'` en Postgres — no toca `listingInventoryLink` ni el CRM. No hay ningún endpoint de desasociación de items sobre el que enganchar esta limpieza todavía. Queda como trabajo futuro cuando ese flujo exista.

## 7. Relación con la reserva de items

`backend-search-inventory-ids.md` §8 ya resolvió que la reserva vive en `gts_crm_db.inventory.status` (`Available`/`Reserved`), **no** en el `InventoryReservation`/`ReservationService` de Postgres de este backend (ese es un sistema de reservas de checkout completamente distinto, sin relación con esta tabla). Este paso de creación de listing **no libera ni toca `status`** — solo escribe `ecommerce_listing_id` y las columnas R2V3. Si un item llega aquí con `status = 'Reserved'`, esa reserva queda intacta; liberarla (si aplica) es responsabilidad de quien gestione ese estado, no de este flujo.

## 8. Decisiones de diseño (cerradas)

1. **`crm_listing_ref` como surrogate numérico.** `Listing.id` es UUID; `inventory.ecommerce_listing_id` es `INT`. Se agregó `Listing.crmListingRef Int @unique @default(autoincrement())` (migración `20260723000001_add_listing_crm_ref`) — se puebla solo, Postgres lo asigna al crear la fila, disponible dentro de la misma transacción sin round-trip adicional.
2. **Iniciales derivadas, no enviadas por el frontend.** Sin campo `initials` en ningún modelo de usuario. `deriveInitials(firstName, lastName)` toma la primera letra de cada uno (ej. "JR"); si ambos vienen vacíos, escribe `'NA'` en vez de fallar la creación del listing por un campo puramente informativo.
3. **Orden de escritura: CRM al final de la transacción Postgres.** Si el `UPDATE` al CRM falla, Postgres revierte todo (steps 1–9) — nunca queda un listing sin sus items reflejados. **Limitación conocida (no distribuida):** el caso inverso — CRM ya actualizado, pero Postgres falla al hacer commit *después* — no se puede cerrar sin una transacción distribuida entre Postgres y MySQL; es el mismo tipo de límite que documenta `Propagacion de stock.md` §7.1 para el flujo de eBay. Mitigación: los logs de `CrmDatabaseService`/Nest deben quedar visibles para detectar el caso raro manualmente.
4. **Columnas R2V3 con `COALESCE(?, col)`, no sobrescritura incondicional.** El contrato original decía "siempre se sobrescriben" asumiendo que el frontend siempre envía los tres campos junto con los items. En el DTO real son opcionales (`@IsOptional()`); si el request no los envía, se preserva el valor que ya tenga el item en el CRM en vez de escribir `NULL` encima de un dato real.

## 9. Preguntas abiertas

| # | Pregunta | Estado |
|---|---|---|
| 1 | ¿`gts-ecommerce-backend` accede directo a `gts_crm_db` o vía `crm-api-nestjs`? | **Resuelta** — acceso directo, `CrmDatabaseService` (MySQL) ya es global en el módulo. |
| 2 | ¿La creación de listing ya usa transacciones? | **Resuelta** — sí, `Prisma.$transaction`; el paso de CRM se agregó como su último statement. |
| 3 | ¿El riesgo de colisión entre `crmListingRef` (secuencia nueva, arranca en 1) y valores legacy ya presentes en `ecommerce_listing_id`? | **Abierta** — sin visibilidad desde este repo del rango de IDs legacy en uso en `gts_crm_db`; confirmar con el equipo de CRM antes de desplegar a producción. |
| 4 | ¿Si el CRM está caído durante la creación, debe fallar toda la creación del listing (comportamiento actual, rollback total) o degradar a un worklist de reintento manual, como hace `Propagacion de stock.md` para eBay? | **Abierta** — hoy no hay reintento; decisión de producto pendiente. |
| 5 | Liberar la reserva del item al asignarlo definitivamente al listing (mencionado en la versión original de esta spec) | **Resuelta por alcance** — no aplica: la reserva (`status` en CRM) y la asignación (`ecommerce_listing_id`) son ortogonales; ver §7. |
