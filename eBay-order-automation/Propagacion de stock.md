# Propagación de stock al sistema de listings (post-orden)

Diseño de la funcionalidad que, tras crear una SO de eBay, refleja la venta en el sistema de listings/stock (DBCentral, GTS Store, CRM eBay Items y relaciones de inventory), **sin empujar stock a eBay**.

> Corresponde a la **Fase 4** de [`proceso.md`](proceso.md) (el "proceso posterior" anticipado en la Fase 3.3). La creación de la SO (Fases 1–3) queda intacta; esto se ejecuta **después** de crearla.
>
> **Estado: Diseño ✅ CERRADO (versión simplificada, sin dudas pendientes) · Implementación ⏳ pendiente.**

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

## 6. Arquitectura (solo inline, sin cron ni tabla)

**Método** `propagateStockForSo(soId)` en el módulo `ebay-orders`, enganchado en `EbayOrdersService.processLineItem` **tras el commit de la transacción de la SO**, en `try/catch` best-effort (un fallo **no** rompe la creación de la orden). Como `skipEbaySync` elimina el push lento a eBay, es solo trabajo de BD → rápido. Cubre webhook y reconciliación a la vez, porque ambos entran por `EbayOrdersService.processOrderConfirmation`.

Pasos:
1. **Guard por la bandera:** si `so.listing_stock_deducted = 1` → return (ya hecho).
2. Si la SO **no** está totalmente reservada (`Partial`/`Open`) → dejar `listing_stock_deducted = 0` (manual) y return.
3. Reconstruir payload desde estado persistido: `inventory WHERE so_id = :soId` → `listingId`, `inventoryItems = [{ inventoryId: row.id }]`, `quantity = nº de filas`.
4. `updateStock(dto, { skipEbaySync: true })` con `action = decrement`.
5. Si `response.success === true` → `listing_stock_deducted = 1`. Si no → queda `0` (manual).

> **Sin tabla de idempotencia ni cron de reintento.** La bandera en `so_info` **es** el guard (hay una SO por `(orderId, orderLineItemId)`), y el reintento es **manual**: el operador ve las SO con `listing_stock_deducted = 0` y hace la actualización completa. Diseño **compatible a futuro**: si más adelante se quiere reintento automático, un cron que barra `listing_stock_deducted = 0` se agrega **sin cambiar el esquema**.

## 7. Garantía "todo o nada"

Para una SO totalmente reservada, `updateStock` descuenta como transacciones coordinadas con rollback conjunto en la Fase 1: **o commitea todo, o no cambia nada**. DBCentral borra las relaciones con un solo DELETE sobre todos los `inventoryId` y decrementa el stock con un solo UPDATE, dentro de transacción → **no existe el estado "quité unos ítems y otros no"**. El caso "vendió 10, solo hay 5" es **reserva parcial**, que se enruta a manual (ver §8), nunca se auto-descuenta a medias.

**Limitaciones conocidas (documentadas, no bloqueantes):**

1. **Commit no distribuido (raro).** Las 3 DBs commitean en secuencia (sin transacción distribuida). Si DBCentral commitea bien pero el commit de CRM falla justo después, podría quedar DBCentral descontado y CRM no. Poco probable (fallos *post-commit* son raros); es inherente al orquestador existente. Mitigación: **loguear fuerte** esa condición para que soporte la detecte antes de un redo manual (que en ese caso re-descontaría DBCentral).
2. **Store legacy (por diseño).** Si el registro no existe en GTS Store, DBCentral+CRM **sí** se descuentan y la store se **salta** (marcado parcial en la respuesta). No es un descuento parcial de ítems: es "en la store no había nada que descontar". El descuento real de la venta (DBCentral+CRM) queda completo, por lo que `listing_stock_deducted = 1` es correcto.

## 8. Qué SOs se propagan

| Estado de la SO | Acción | Bandera |
|---|---|---|
| **Reserved** (todo reservado) | **Auto-propaga** el descuento | `1` si `success`, `0` si falla |
| **Partially Reserved** | **Manual** (no auto, para no cruzar información) | `0` |
| **Open** (nada reservado) | **Manual** (nada que descontar automáticamente) | `0` |

El worklist de pendientes manuales es un query simple, scopeado a SOs de eBay para no arrastrar históricas:

```sql
SELECT id, client_PO_Number, reference, status
FROM so_info
WHERE ebay_account_id IS NOT NULL   -- solo SOs originadas en eBay
  AND listing_stock_deducted = 0;             -- pendientes de descuento manual
```

## 9. Cambio de esquema requerido — columna `listing_stock_deducted` en `so_info` (CRM)

Única modificación de BD. La agrega el **equipo de backend** en `gts_crm_db.so_info` (MySQL/MariaDB):

```sql
ALTER TABLE so_info
  ADD COLUMN listing_stock_deducted TINYINT(1) NULL DEFAULT NULL
  COMMENT 'Propagación de stock al listing tras la venta eBay: 1=descontado OK (DBCentral+CRM); 0=pendiente/falló, hacer manual; NULL=no aplica (SO no eBay)';
```

- **Nullable, default `NULL`**: solo se puebla en SOs originadas en eBay (`NULL` = no aplica). Así el worklist (`listing_stock_deducted = 0`) no arrastra SOs no-eBay ni históricas.
- Al crear la SO de eBay se inicializa en `0` (dentro de la transacción de la SO); la propagación inline la voltea a `1` si tiene éxito.
- (Opcional) un índice sobre `(ebay_account_id, listing_stock_deducted)` aceleraría el worklist; queda a criterio del equipo de backend por tratarse de una tabla legacy grande.

## 10. Decisiones de diseño (cerradas)

1. **Armado del payload.** Desde estado persistido: `inventory WHERE so_id = :soId` → `listingId = ecommerce_listing_id` (una SKU por SO), `inventoryItems = [{ inventoryId: row.id }]`, `quantity = nº de filas`. `userId = rep.repId`, `ebayAccountId = so_info.ebay_account_id` (columna ya persistida por la feature de tracking); ambos irrelevantes al saltar eBay pero satisfacen la validación del DTO. `iqId`/`poId`/`poLine` no se usan en decrement.
2. **Reserva vs. decremento (sin doble-conteo).** Reserva y decremento tocan columnas/contadores disjuntos. El único riesgo de doble-conteo es re-ejecutar la propagación → cubierto por la bandera `listing_stock_deducted` (el endpoint `update-stock` no es idempotente por sí mismo).
3. **Idempotencia.** La bandera booleana `so_info.listing_stock_deducted` es el guard, respaldada por "una SO por `(orderId, orderLineItemId)`". Sin tabla dedicada.
4. **Solo reservas completas.** `Reserved` → auto. `Partial`/`Open` → `listing_stock_deducted = 0`, actualización **manual** completa (evita cruzar información al descontar solo unos ítems).
5. **Todo o nada + política de fallo.** `listing_stock_deducted = 1` solo si `response.success` (DBCentral+CRM commiteados). Cualquier fallo rollea la Fase 1 → nada cambia → queda `0` → manual. **Nunca** se revierte la SO (la venta es real). Reintento manual; sin cron. Ver limitaciones conocidas en §7.

## 11. Plan de implementación

1. **Backend team:** `ALTER TABLE so_info` (§9).
2. **Flag `skipEbaySync`** en `UpdateStockLeadDto` (`@IsOptional`, default `false`) y en `updateStock`: envolver el `getValidToken` de Fase 0 y todo el bloque de Fase 2/2.1 en `if (!dto.skipEbaySync)`. Cuando se salta: `response.ebay.message = 'Skipped (skipEbaySync)'` y **no** agregar `partialFailures`. Cero cambios para los flujos actuales.
3. **Inicializar `listing_stock_deducted = 0`** en la creación de SO de eBay (dentro de la transacción, en `buildSoData`/`createWithManager`).
4. **`propagateStockForSo(soId)`** en `ebay-orders` (§6), enganchado tras el commit en `processLineItem`, en `try/catch`.
5. **Entidad `SoInfo`:** mapear la nueva columna `listing_stock_deducted`.

## 12. Dudas resueltas

- ✅ **RESUELTA — Efecto de nulificar el linaje.** Se **conserva el comportamiento actual**: `update-stock` DECREMENT nulifica `ecommerce_listing_id`/`ebay_listing_id`/`gts_store_listing_id` en las filas de `inventory` vendidas. Hoy no se usa esa trazabilidad unidad→listing una vez vendida (el rastro unidad→SO→orden sí se conserva). Mejora futura fuera de alcance.
- ✅ **RESUELTA — Órdenes previas a esta feature.** **Sin backfill.** Se arranca limpio desde el despliegue: las SOs creadas antes no se propagan ni se ajustan. Solo las órdenes nuevas (post-despliegue) auto-propagan.
