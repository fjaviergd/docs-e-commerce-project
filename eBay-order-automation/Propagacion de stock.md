# Propagación de stock al sistema de listings (post-orden)

Diseño de la funcionalidad que, tras crear una SO de eBay, refleja la venta en el sistema de listings/stock (DBCentral, GTS Store, CRM eBay Items y relaciones de inventory), **sin empujar stock a eBay**.

> Corresponde a la **Fase 4** de [`proceso.md`](proceso.md) (el "proceso posterior" anticipado en la Fase 3.3). La creación de la SO (Fases 1–3) queda intacta; esto se ejecuta **después** de crearla.
>
> **Estado: Diseño ✅ CERRADO · Implementación ✅ EN PRODUCCIÓN (validada e2e, flag activo).**
>
> **Go-live (2026-07-17):** validada end-to-end contra los 3 mirrors y activada en prod (`EBAY_STOCK_PROPAGATION_ENABLED=true`). Primera venta automática confirmada (so 75911). Desde ahí, las SOs de eBay con `listing_stock_deducted` no-NULL son la "era automática".
>
> **Revisión (2026-07-16) — cambio de comportamiento a pedido de negocio:**
> 1. **`Partially Reserved` también descuenta** su subconjunto reservado (antes: solo `Reserved`).
> 2. **El descuento tiene prioridad sobre la reserva:** si el descuento falla, la reserva se **libera** (SO → `Open`) para rehacerla manualmente (reserva + descuento juntos). Esto revisa las decisiones 4 y 5 originales. Ver §6–§8 y §10.
>
> **UI (2026-07-18):** indicador visual del estado de stock en el detalle de la SO (dashboard). Ver §13 y §14.

---

## 1. Objetivo

Después de crear una SO de eBay, descontar la venta del sistema interno de stock reutilizando el orquestador existente:

- **Servicio existente:** `UpdateStockLeadService.updateStock` (`src/ecommerce/orchestrators/update-stock/update-stock-lead.service.ts`), endpoint `POST /api/update-stock-listing/lead`.
- **Fases del orquestador:** 0) validaciones · 1) transacciones coordinadas (**DBCentral** + **CRM inventory** + **GTS Store** + **CRM eBay Items**) · 2) **push best-effort a eBay** · 3) finalización.

## 2. Diferencia clave: NO empujar stock a eBay (overselling)

Se ejecuta todo el orquestador **excepto la interacción con eBay**. Todo lo demás (DBCentral, CRM inventory, GTS Store, CRM eBay Items) sí procede.

**Motivo:** eBay descuenta las unidades en cuanto se vende, **incluso en `Awaiting Payment`** (las trata como reservadas). Nuestro sistema solo crea la SO cuando el pago se completa. Si además empujáramos nuestra cantidad (calculada solo desde ventas pagadas) a eBay, **sobrescribiríamos el disponible correcto** que eBay ya calculó y reabriríamos unidades reservadas → sobreventa.

## 3. Punto de partida (hoy)

La creación de la SO **solo reserva `inventory` en el CRM** (Fase 3): escribe `so`/`so_id`/`soline`/`status='Reserved'`/`shipment_id`/`unitprice`. **No** reduce stock en DBCentral, GTS Store, eBay Items ni eBay. Esta funcionalidad cierra ese hueco, menos el push a eBay.

## 4. Enfoque: flag `skipEbaySync`

Flag `skipEbaySync?: boolean` (default `false`) en `UpdateStockLeadDto`. El flujo de órdenes lo invoca en `true`; el resto de flujos (increment/restock, reactivación de listings 0→N, ediciones manuales) siguen empujando a eBay sin cambios. **No** se elimina la Fase 2 globalmente.

> **`skipEbaySync=true` = "sin ninguna interacción con eBay".** No basta con saltar la Fase 2: la **Fase 0, Step 2** llama `ebayOauthService.getValidToken(ebayAccountId, userId)`, que valida token de eBay y **depende de un `userId` humano** que este flujo (a nivel sistema) no tiene. Por eso el flag salta **el `getValidToken` de Fase 0 Y todo el bloque de Fase 2** (incl. Fase 2.1 de reactivación).

## 5. Hallazgo que simplifica el diseño (convención de IDs)

`ecommerce_listings_inventory.inventoryId` (Central) **==** `inventory.id` (CRM). La reserva ya se apoya en esa convención (`GtsCrmInventoryReservationService.selectCandidates`). Por tanto **el `id` de cada fila de `inventory` reservada ES el `inventoryId` que espera el endpoint**; no hay mapeo cross-DB adicional. En **DECREMENT**, el endpoint solo usa `inventoryItems[].inventoryId`; los campos `iqId`/`poId`/`poLine` **solo se usan en INCREMENT** → aquí son opcionales/ignorados.

## 6. Arquitectura (inline, sin cron ni tabla)

**Método** `propagateStockForSo(soId)` en el módulo `ebay-orders`, enganchado en `EbayOrdersService.processLineItem` **tras el commit de la transacción de la SO** (que reserva primero), en `try/catch` best-effort (un fallo **no** rompe la creación de la orden). Cubre webhook y reconciliación a la vez, porque ambos entran por `EbayOrdersService.processOrderConfirmation`.

Pasos:
1. **Guard por la bandera:** si `so.listing_stock_deducted = 1` → return (ya hecho, idempotente).
2. Cargar el subconjunto reservado: `inventory WHERE so_id = :soId`. Si **0 filas** (SO `Open`, nada reservado) → `listing_stock_deducted = 0` y return.
3. Armar payload: `listingId = ecommerce_listing_id`, `inventoryItems = [{ inventoryId: row.id }]`, `quantity = nº de filas reservadas` (aplica a `Reserved` **y** `Partial`).
4. `updateStock(dto, { skipEbaySync: true })` con `action = decrement`.
5. **Éxito** → `listing_stock_deducted = 1`.
6. **Fallo (flujo automático)** → **liberar la reserva**: limpiar `so`/`so_id`/`soline`/`status`/`shipment_id` y campos de reserva en las filas de `inventory` (quedan **disponibles**), SO → `Open`, `listing_stock_deducted = 0`.

> **Prioridad del descuento (por qué liberamos):** si el descuento no se puede aplicar, los items **no** deben quedar reservados; se liberan para que se rehaga manual (reserva + descuento juntos). Clave: los items **solo se desenlazan del listing si el descuento tuvo éxito** — en el caso de fallo la reserva se revierte y los items quedan **disponibles y enlazados**, así el operador los encuentra normalmente. (Reservar primero y liberar-si-falla da el mismo resultado que "descontar primero" sin el problema de desenlazar items que luego no se encontrarían.)

> **Disparo manual / reproceso:** `POST /ebay/stock-propagation/:soId` ejecuta la propagación de una sola SO **saltando el gate global** (`force`). **No** libera la reserva en caso de fallo (solo reporta el resultado). Sirve para el worklist manual y para pruebas puntuales de una SO. ⚠️ **Seguridad:** decrementa stock real y no tiene auth guard (como el resto de `ecommerce`) → protegerlo a nivel gateway (IP allowlist / no exponerlo público).

> **Sin tabla de idempotencia ni cron de reintento.** La bandera en `so_info` **es** el guard (hay una SO por `(orderId, orderLineItemId)`), y el reintento es **manual**: el operador ve las SO con `listing_stock_deducted = 0` y hace la actualización completa. Diseño **compatible a futuro**: si más adelante se quiere reintento automático, un cron que barra `listing_stock_deducted = 0` se agrega **sin cambiar el esquema**.

## 7. Garantía "reservado ⟺ descontado"

El objetivo es que **nunca** quede una SO "reservada sin descontar". Se logra con la prioridad del descuento:

- `updateStock` descuenta el subconjunto reservado como transacciones coordinadas con **rollback conjunto** en la Fase 1: **o commitea todo, o no cambia nada** (no existe "quité unos ítems y otros no"). Para un `Partial`, descuenta exactamente el subconjunto reservado; el **remanente no reservado** de la línea nunca se toca → sigue enlazado y disponible para reserva manual.
- Si el descuento **falla**, el flujo automático **libera la reserva** → la SO queda `Open` y los items disponibles → se rehace manual. Los items **solo se desenlazan del listing si el descuento tuvo éxito**.

**Limitaciones conocidas (documentadas, no bloqueantes):**

1. **Commit no distribuido (raro).** Las 3 DBs commitean en secuencia (sin transacción distribuida). Si DBCentral commitea bien pero el commit de CRM falla justo después, podría quedar DBCentral descontado y CRM no. Poco probable (fallos *post-commit* son raros); inherente al orquestador existente. Mitigación: **loguear fuerte**.
2. **Store legacy (por diseño).** Si el registro no existe en GTS Store, DBCentral+CRM **sí** se descuentan y la store se **salta** (marcado parcial). No es un descuento parcial de ítems: es "en la store no había nada que descontar". El descuento real (DBCentral+CRM) queda completo → `listing_stock_deducted = 1` es correcto.
3. **Descuento falla Y la liberación también falla (muy raro).** La liberación es una escritura simple en CRM; si fallara, quedaría "reservado sin descontar" — comportamiento benigno (items enlazados/findable, solo falta el stock) y la bandera en `0` lo deja en el worklist.

## 8. Qué SOs se propagan

| Estado de la SO | Acción automática | Bandera |
|---|---|---|
| **Reserved** (todo reservado) | **Descuenta todo** | `1` si éxito; si falla → se **libera** la reserva (SO → `Open`), `0` |
| **Partially Reserved** | **Descuenta el subconjunto reservado** | `1` si éxito; si falla → se **libera** la reserva (SO → `Open`), `0` |
| **Open** (nada reservado) | Nada que descontar | `0` (manual) |

En un `Partial`, el **remanente no reservado** queda para reserva manual (nunca se tocó, sigue enlazado y disponible). El worklist de pendientes manuales, scopeado a SOs de eBay:

```sql
SELECT id, client_PO_Number, reference, status
FROM so_info
WHERE ebay_account_id IS NOT NULL   -- eBay-originated SOs only
  AND listing_stock_deducted = 0;             -- pending manual deduction
```

## 9. Cambio de esquema requerido — columna `listing_stock_deducted` en `so_info` (CRM)

Única modificación de BD. La agrega el **equipo de backend** en `gts_crm_db.so_info` (MySQL/MariaDB):

```sql
ALTER TABLE so_info
  ADD COLUMN listing_stock_deducted TINYINT(1) NULL DEFAULT NULL
  COMMENT 'Stock propagation to listing after eBay sale: 1=deducted OK (DBCentral+CRM); 0=pending/failed, handle manually; NULL=not applicable (non-eBay SO)';
```

- **Nullable, default `NULL`**: solo se puebla en SOs originadas en eBay (`NULL` = no aplica). Así el worklist (`listing_stock_deducted = 0`) no arrastra SOs no-eBay ni históricas.
- Al crear la SO de eBay se inicializa en `0` (dentro de la transacción de la SO); la propagación inline la voltea a `1` si tiene éxito.
- (Opcional) un índice sobre `(ebay_account_id, listing_stock_deducted)` aceleraría el worklist; queda a criterio del equipo de backend por tratarse de una tabla legacy grande.

> **Estado:** la columna (y `ebay_account_id`) **ya existen en el CRM de producción**.

## 10. Decisiones de diseño (cerradas)

1. **Armado del payload.** Desde estado persistido: `inventory WHERE so_id = :soId` → `listingId = ecommerce_listing_id` (una SKU por SO), `inventoryItems = [{ inventoryId: row.id }]`, `quantity = nº de filas`. `userId = rep.repId` (`reservedbyuser_id`), `ebayAccountId = so_info.ebay_account_id`; ambos irrelevantes al saltar eBay pero satisfacen la validación del DTO. `iqId`/`poId`/`poLine` no se usan en decrement.
2. **Reserva vs. decremento (sin doble-conteo).** Reserva y decremento tocan columnas/contadores disjuntos. El único riesgo de doble-conteo es re-ejecutar la propagación → cubierto por la bandera `listing_stock_deducted` (el endpoint `update-stock` no es idempotente por sí mismo).
3. **Idempotencia.** La bandera booleana `so_info.listing_stock_deducted` es el guard, respaldada por "una SO por `(orderId, orderLineItemId)`". Sin tabla dedicada.
4. **Descuenta `Reserved` y `Partial`** (el subconjunto realmente reservado); solo `Open` no descuenta. *(Revisa la decisión original de "solo `Reserved`"; el `Partial` ahora descuenta lo reservado y su remanente queda manual.)*
5. **Prioridad del descuento + liberación en fallo.** Si el descuento falla en el flujo automático, se **libera la reserva** (SO → `Open`, items disponibles) para rehacer manual — el descuento gobierna a la reserva. `updateStock` es atómico en su Fase 1. **Nunca** se revierte la venta/SO (queda `Open`). Reintento manual; sin cron. El disparo manual (`force`) **no** libera. Ver limitaciones en §7.

## 11. Implementación (construida, gated)

Todo detrás del flag `EBAY_STOCK_PROPAGATION_ENABLED` (default `false` → comportamiento actual intacto).

1. **Columna** `so_info.listing_stock_deducted` (§9) — aplicada en prod; mapeada en la entidad `SoInfo` con `select: false` (ningún SELECT normal la toca → sin dependencia dura mientras el flag esté apagado).
2. **Flag `skipEbaySync`** en `UpdateStockLeadDto` + `updateStock` (salta `getValidToken` de Fase 0 y toda la Fase 2/2.1).
3. **Inicialización `listing_stock_deducted = 0`** en la creación de SO de eBay (gated), en `buildSoData`.
4. **`EbayOrderStockPropagationService.propagateStockForSo(soId, { force?, releaseOnFailure? })`** (§6): descuenta `Reserved`/`Partial`; en fallo con `releaseOnFailure` libera la reserva (`releaseReservation`). El enganche inline pasa `releaseOnFailure: true`.
5. **Endpoint manual** `POST /ebay/stock-propagation/:soId` (usa `force`, no libera) para worklist/pruebas.
6. **Rollout:** deploy con el flag en `false`; prueba e2e con el endpoint manual sobre 1 SO (contra mirrors consistentes de las 3 BDs: Central, CRM, Store); luego encender el flag.

## 12. Dudas resueltas

- ✅ **Efecto de nulificar el linaje.** Se **conserva el comportamiento actual**: `update-stock` DECREMENT nulifica `ecommerce_listing_id`/`ebay_listing_id`/`gts_store_listing_id` en las filas vendidas. No se usa esa trazabilidad unidad→listing una vez vendida (el rastro unidad→SO→orden sí se conserva).
- ✅ **Órdenes previas a esta feature.** **Sin backfill.** Se arranca limpio desde el despliegue.
- ✅ **Items desenlazados no findables al reservar manual.** Resuelto por diseño: los items **solo se desenlazan si el descuento tuvo éxito**; si falla, la reserva se libera y quedan enlazados/disponibles (§6–§7).

## 13. Indicador en la UI (chip de estado de stock)

Añadido (2026-07-18) para que los usuarios vean, en el detalle de la SO, el estado del stock relacionado. **Es informativo** (sin botón/link; la actualización manual la hace el usuario cuando aplica).

### Endpoint de lectura (crm-api-nestjs)

`GET /api/ebay/stock-propagation/so/:soId` — solo lectura. Respuesta:

```jsonc
{
  "applies": true,                 // false si la SO no es de eBay -> la UI no muestra nada
  "state": "deducted",             // pre_feature | deducted | partial | pending
  "listingStockDeducted": true,    // valor de so_info.listing_stock_deducted (bool | null)
  "soStatus": "Reserved",          // so_info.status
  "orderId": "07-14923-80489",     // so_info.client_PO_Number (eBay orderId)
  "lineItemId": "10087574343007",  // so_info.reference (eBay lineItemId)
  "ebayAccount": { "id": 6, "name": "greenteksolutions-b", "label": "B" }
}
```

- `applies = (ebay_account_id != null)`. Para no-eBay devuelve `{ "applies": false }`.
- `state`: `pre_feature` = `listing_stock_deducted` NULL (SO eBay previa a la automatización); `deducted` = flag 1 + status `Reserved`; `partial` = flag 1 + status `Partially Reserved`; `pending` = flag 0.
- `ebayAccount.label` (A/B/C/D) se deriva del sufijo de `gobig_ebay_linked_accounts.name` (`greenteksolutions` = A, `...-b` = B, etc.).
- Implementado en `EbayOrderStockPropagationService.getStockStatus` + `EbayStockPropagationController` (GET). Sin cambios de esquema.

### Chip en el dashboard (crm-gtsdashboard)

En `sales-orders/so-crud` se muestra un chip (servicio `SoStockStatusService` → el endpoint de arriba). Al hacer **hover** despliega un tooltip (`customTooltip`) con: descripción del estado, **cuenta eBay** (letra + nombre), **orderId**, **line item** y **status de la SO**.

| Chip | `state` | Significado | ¿Acción del usuario? |
|---|---|---|---|
| 🟢 Stock deducted | `deducted` | Stock descontado automáticamente del listing | No |
| 🟠 Partially deducted | `partial` | Se descontó el subconjunto reservado; el remanente sigue manual | Sí (el resto) |
| 🔴 Stock not deducted | `pending` | No se descontó (SO `Open` o el descuento falló) | Sí (manual) |
| ⚪ Before auto-stock | `pre_feature` | SO de eBay previa a la automatización | Manual (histórica) |
| (sin chip) | — | SO no originada en eBay | N/A |

## 14. Worklist / corte para ventas

El campo `so_info.listing_stock_deducted` define el corte y las listas de trabajo (scopear siempre con `ebay_account_id IS NOT NULL`):

- `NULL` = SO previa a la automatización (manual).
- `1` = descontado automáticamente (nada que hacer). Ojo: en `partial`, se descontó lo reservado pero el **remanente** sigue manual.
- `0` = no se descontó (Open/falló) → **manual**.

```sql
-- Primera SO de la era automática (el "corte" para ventas):
SELECT MIN(so) AS primera_so_auto
FROM so_info
WHERE ebay_account_id IS NOT NULL AND listing_stock_deducted IS NOT NULL;

-- Worklist: SOs de la era automática que el sistema NO pudo descontar (manual):
SELECT so, id, status FROM so_info
WHERE ebay_account_id IS NOT NULL AND listing_stock_deducted = 0;

-- Backlog histórico (previas a la automatización, manual):
SELECT so, id, status FROM so_info
WHERE ebay_account_id IS NOT NULL AND listing_stock_deducted IS NULL;
```
