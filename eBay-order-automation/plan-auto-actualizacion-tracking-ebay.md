# Plan: Actualización automática de tracking en eBay al generar la etiqueta

**Fecha:** 2026-07-09
**Actualizado:** 2026-07-10 — mecanismo de sincronización cerrado (outbox + trigger), hallazgos de la Logistics API incorporados, opciones descartadas removidas.
**Estado:** Diseño — Confirmado. **Alcance activo: solo el envío automático del tracking (camino ShipEngine).** El comparador de precios (camino Logistics de eBay) queda **PENDIENTE**, en pausa hasta que eBay apruebe el acceso Limited Release (solicitud enviada — ver "Restricciones de la Logistics API").
**Contexto:** La ingesta de órdenes de eBay (webhook + reconciliación) ya crea la SO en el CRM. Este plan cubre el tramo final: generar la etiqueta y que eBay quede actualizado con el tracking **sin el paso manual actual** (captura 2).

---

## Dos caminos, dos problemas distintos

El componente de envío (`process.component.ts` / `shipping.component.ts`) genera etiquetas por dos vías. Este plan las trata por separado porque el mecanismo para actualizar eBay es distinto en cada una:

1. **Camino ShipEngine (el actual, UPS/FedEx) — ✅ ALCANCE ACTIVO:** Symfony genera la etiqueta y el `tracking_number` vía ShipEngine. eBay **no se entera** → hay que informarle el tracking. Es el 100% del volumen hoy (las capturas muestran tracking UPS `1ZXJ...`). **Este es el único entregable en construcción por ahora.**
2. **Camino Logistics de eBay (comparador de tarifas) — ⏸️ PENDIENTE / EN PAUSA:** comprar la etiqueta a través de eBay. eBay genera el tracking → queda actualizado por construcción. **Bloqueado por aprobación de eBay (Limited Release) y limitado a USPS.** No se construye hasta desbloquear. Las secciones de este camino se conservan en el documento como diseño listo para retomar. Ver restricciones abajo.

---

## Decisiones confirmadas (2026-07-10)

| #   | Tema                                  | Decisión                                                                                                                                                                                                                                                                                                                       |
| --- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Vínculo SO ↔ cuenta eBay              | Se persiste `ebay_account_id` en `so_info`, poblado al crear la SO. Es también el guard de "¿es SO de eBay?".                                                                                                                                                                                                                  |
| 2   | Mecanismo de sync (camino ShipEngine) | **Tabla outbox + trigger de BD.** El frontend, al imprimir, dispara un endpoint NestJS que inserta la fila en `ebay_tracking_outbox`; un trigger MySQL agrega el `tracking_number` cuando Symfony lo escribe; un consumer NestJS hace polling y llama a eBay. Ni Symfony ni el navegador cargan la garantía de sincronización. |
| 3   | Columna de tracking en Symfony        | `shipment.tracking_number`.                                                                                                                                                                                                                                                                                                    |
| 4   | Varias etiquetas por SO               | Una SO puede generar varios `tracking_number`; **a eBay solo se informa el primero.** El consumer agrupa por orden y descarta los siguientes sin llamar a eBay.                                                                                                                                                                |
| 5   | Expiración de cotización eBay         | Si la cotización expiró al momento de imprimir, **re-cotizar en silencio** antes de comprar (sin pedir acción al operador).                                                                                                                                                                                                    |

---

## Validación obligatoria — la SO debe ser de eBay

El componente se usa también para **compras directas** (venta manual, sin eBay). Todo este plan aplica **solo si la SO se originó en eBay**. Criterio único: `so_info.ebay_account_id IS NOT NULL`. No cuesta un campo nuevo — es la misma columna de la Decisión #1.

Se aplica en cada punto de entrada:

| Punto | Comportamiento si NO es SO de eBay |
|---|---|
| Frontend — `onCalculateClick()` | No pide cotización a eBay. La tabla de tarifas se comporta como hoy (solo ShipEngine). Se decide con un flag `isEbayOrder` cargado junto con los datos del shipment. |
| Backend — endpoint que crea la fila en outbox | Resuelve `ebay_account_id` desde `so_info`; si es `NULL`, responde `not_applicable` y **no inserta nada**. |
| Backend — endpoints Logistics (`quote` / `purchase`) | Si se invocan igual, responden `not_applicable`; nunca llaman a eBay con un `orderId` nulo/ajeno. |
| Backend — consumer del outbox | Solo procesa filas del outbox, que por construcción ya son de órdenes eBay. Verificación defensiva: si `ebay_account_id` viene nulo, cierra la fila como error y loguea. |

Sin este guard, una compra directa con `client_PO_Number` vacío o con formato de `orderId` podría disparar una llamada a eBay con datos inválidos o tocar la orden equivocada.

---

## Mecanismo de sincronización — outbox + trigger (camino ShipEngine)

Flujo confirmado:

```
1. Operador empaca, captura medidas, presiona "Print Label" (process.component.ts).
2. Frontend, en paralelo a generateLabel()/generateLabelDirectly() (Symfony/ShipEngine):
      POST /ebay/tracking-outbox   { shipmentId }
   → NestJS resuelve shipment.so_id → so_info (ebay_account_id, client_PO_Number=orderId, reference=lineItemId)
   → si ebay_account_id IS NULL: responde not_applicable, no inserta (compra directa)
   → si es de eBay: INSERT ebay_tracking_outbox
        (shipment_id, so_id, order_id, line_item_id, ebay_account_id,
         tracking_number=NULL, status='PENDING_TRACKING', created_at)
3. Symfony/ShipEngine genera la etiqueta y escribe shipment.tracking_number (asíncrono al paso 2).
4. Trigger MySQL  AFTER UPDATE ON shipment  (tracking_number pasa de NULL a valor):
      UPDATE ebay_tracking_outbox
         SET tracking_number = NEW.tracking_number, status = 'READY'
       WHERE shipment_id = NEW.id AND tracking_number IS NULL;
   (las compras directas nunca tienen fila en outbox → el trigger no hace nada para ellas)
5. Consumer NestJS (@Cron cada ~15 s, patrón de ebay-reconciliation con flag isRunning):
      SELECT * FROM ebay_tracking_outbox WHERE status = 'READY'
      Por cada fila:
        a. ¿Ya se sincronizó otra fila del mismo order_id con éxito? (regla Decisión #4)
             → sí: status='SKIPPED', no llama a eBay.
        b. getSystemTokenByAccountId(ebay_account_id)              ← EbayOauthService (existente)
        c. createShippingFulfillment(orderId, token, {...})        ← EbayFulfillmentService (nuevo)
        d. éxito → status='SYNCED', synced_at=now()
           error → status='ERROR', attempts++, last_error (reintenta hasta N)
```

**Por qué resuelve las 3 restricciones a la vez:**
- **No depende del navegador:** el navegador solo *inserta la intención*. Si se cierra después, el trigger + consumer terminan el trabajo igual.
- **No toca código de Symfony:** el trigger y la tabla son objetos de esquema; Symfony ni se entera.
- **Casi tiempo real:** el consumer hace polling sobre una tabla trivial (no escanea `shipment`), latencia de segundos.

### Respuesta a "¿de dónde traigo el número de cuenta de eBay?"

**Sí es necesario** (el consumer lo requiere para pedir el token correcto con `getSystemTokenByAccountId`), pero **el frontend no lo resuelve**: el endpoint NestJS lo obtiene de `so_info.ebay_account_id` (Decisión #1) vía `shipment.so_id`, y lo guarda denormalizado en la fila del outbox. Ventajas: el frontend solo manda `shipmentId`, no se confía un dato sensible al cliente, y el consumer queda autocontenido (no re-consulta `so_info` al sincronizar).

### Estructura de `ebay_tracking_outbox`

| Columna | Tipo | Nota |
|---|---|---|
| `id` | PK | |
| `shipment_id` | INT NOT NULL | ligado a `shipment.id` |
| `so_id` | INT NOT NULL | para agrupar por orden |
| `order_id` | VARCHAR | `so_info.client_PO_Number` (orderId de eBay) |
| `line_item_id` | VARCHAR | `so_info.reference` (para el payload de eBay) |
| `ebay_account_id` | INT NOT NULL | resuelto de `so_info`, define el token |
| `tracking_number` | VARCHAR NULL | lo llena el trigger |
| `status` | ENUM | `PENDING_TRACKING` → `READY` → `SYNCED`/`SKIPPED`/`ERROR` |
| `attempts` | INT default 0 | reintentos del consumer |
| `last_error` | TEXT NULL | diagnóstico |
| `created_at` / `synced_at` | DATETIME | auditoría |

> Con este diseño **no se necesita** la columna `shipment.ebay_synced_at` que se había propuesto: el estado vive en el outbox.

### Extensión de `EbayFulfillmentService` (camino ShipEngine)

Método nuevo, cliente puro (mismo patrón de logging/errores que `getOrder`/`getOrders`):

```ts
// POST /sell/fulfillment/v1/order/{orderId}/shipping_fulfillment
async createShippingFulfillment(orderId, token, {
  lineItems: [{ lineItemId }],   // 1 SO = 1 lineItem (Opción B, decidida)
  shippedDate,                    // ISO 8601
  shippingCarrierCode,            // mapeo carrier interno → eBay
  trackingNumber,
}): Promise<{ fulfillmentId: string }>
```

Mapeo de carrier: reutilizar la tabla `carriers` (`external_carrier_code` → `name`), validando que `name` calce con el enum de eBay (`UPS`, `FedEx`, `USPS`...); si no calza 1:1, tabla de mapeo explícita (2–3 filas).

---

## Comparador de tarifas ShipEngine vs. eBay (camino Logistics) — ⏸️ PENDIENTE

> **Fuera del alcance activo.** Esta sección queda en pausa hasta que eBay apruebe el acceso Limited Release (solicitud enviada 2026-07-10). Se conserva como diseño listo para retomar. No hay tareas de construcción abiertas para este camino mientras siga bloqueado.

**Requerimiento:** al presionar "Calcular" (`getRates()`, `process.component.ts:1447-1610`), agregar a la tabla `ratesList` la tarifa que eBay ofrece para el mismo envío y **preseleccionar la más barata** de toda la lista (hoy el default es coincidencia por `serviceString`; ese comportamiento cambia a "menor precio").

### Restricciones de la Logistics API (críticas — leídas de `docs-ebay/logistics_api.json`)

| Restricción | Impacto |
|---|---|
| **Limited Release** — solo apps/cuentas aprobadas por eBay | **Bloqueante — CONFIRMADO empíricamente** (ver abajo). Requiere solicitar acceso al programa a eBay; no se resuelve por código. |
| **Solo USPS** — "The Logistics API only supports USPS shipping rates and labels" | La tarifa de eBay en la tabla será **siempre USPS**. Para envíos UPS/FedEx (el patrón actual) no habrá competencia de eBay. El comparador aporta valor solo en envíos donde USPS es competitivo (paquetes pequeños/ligeros). |
| **Sin sandbox** — la spec solo declara host de producción (`https://api.ebay.com`) | No se puede probar en sandbox. La validación y las pruebas E2E del camino Logistics son en producción, y solo tras la aprobación. |
| **Scope OAuth requerido** `https://api.ebay.com/oauth/api_scope/sell.logistics` | Es un scope de *user token* (authorization code). Los refresh tokens existentes deben re-consentirse incluyendo este scope. |

**Resultado de la prueba real (2026-07-10, producción):** `POST /sell/logistics/v1_beta/shipping_quote` devolvió `errorId 1100 / domain ACCESS / "Insufficient permissions to fulfill the request"`. Es un rechazo de **permisos**, no de payload — no está relacionado con que la prueba se hiciera sin `orderId` (un `orderId` inválido daría un error de validación en `domain REQUEST`/`BUSINESS`, no `ACCESS`). Dos causas posibles, a descartar en orden:

1. **El token no lleva el scope `sell.logistics`** → re-consentir el OAuth agregando ese scope y re-autorizar la cuenta.
2. **La app no está en el Limited Release** → solicitar acceso a eBay. Si eBay ni siquiera permite otorgar el scope durante el consentimiento, es esta causa.

**Desambiguación:** mintear un user token para una cuenta pidiendo explícitamente `sell.logistics`. Si el scope no puede ni solicitarse, o la llamada sigue en `1100` con el scope presente → falta aprobación (causa 2).

**Conclusión:** el camino Logistics (comparador + compra vía eBay) queda **en pausa hasta obtener aprobación de eBay**. No bloquea el camino ShipEngine, que es el entregable principal y cubre el 100% del volumen actual.

### Endpoint a probar para confirmar disponibilidad

**`POST /sell/logistics/v1_beta/shipping_quote`** (`createShippingQuote`). Ya probado (ver arriba): actualmente devuelve `1100 ACCESS`. Re-probar una vez resuelto el scope y/o la aprobación.

Payload mínimo de prueba (con una orden pagada real):
```
{
  "orders": [{ "channel": "EBAY", "orderId": "<orderId real>" }],
  "packageSpecification": { "weight": { "unit": "POUND", "value": "1" },
                            "dimensions": { "unit": "INCH", "length":"6","width":"4","height":"2" } },
  "shipFrom": { "fullName", "companyName", "primaryPhone", "contactAddress{...}" },
  "shipTo":   { "fullName", "primaryPhone", "contactAddress{...}" }
}
```
Respuesta esperada: `shippingQuoteId`, `expirationDate`, y `rates[]` con `rateId` + `baseShippingCost`. Con eso se confirma aprobación **y** se obtiene el `expirationDate` real (Decisión #5).

### Endpoints Logistics del flujo

- `POST /sell/logistics/v1_beta/shipping_quote` → cotizar (devuelve `shippingQuoteId`, `rates[].rateId`, `expirationDate`).
- `POST /sell/logistics/v1_beta/shipment/create_from_shipping_quote` → comprar con `{ shippingQuoteId, rateId }`; devuelve `shipmentTrackingNumber` + `labelDownloadUrl`.

### Arquitectura backend (nuevo módulo `ebay-logistics`)

```
ebay-logistics/
  ebay-logistics.service.ts     ← cliente puro: createShippingQuote(), createFromShippingQuote()
  ebay-logistics.controller.ts
    POST /ebay/logistics/quote      { soId, packages[] }  → normaliza rates al shape de ratesList
    POST /ebay/logistics/purchase   { soId, shippingQuoteId, rateId }
  ebay-logistics.module.ts
```

- `quote` resuelve `soId → so_info` (guard eBay + `orderId`), arma el `ShippingQuoteRequest` y devuelve `{ status, shippingQuoteId, expirationDate, quotes[] }` con cada quote normalizado a `{ source:'ebay', rateId, service_type, shipping_amount:{amount,currency} }`.
- `purchase` llama `createFromShippingQuote`; con el `shipmentTrackingNumber` + `labelDownloadUrl` que devuelve eBay, persiste el tracking/label en la tabla `shipment` del CRM (método nuevo `GtsCrmShipmentsService.saveTrackingInfo(...)`, porque hoy eso solo lo escribe Symfony). En este camino **no** se pasa por el outbox: eBay ya generó el tracking, la orden queda fulfilled por construcción.

### Cambios en el frontend

- `onCalculateClick()`: si `isEbayOrder`, dispara **en paralelo** `getRates()` (ShipEngine) y `POST /ebay/logistics/quote`. Concatena ambos resultados en `ratesList` (badge "ShipEngine" / "eBay" por fila) y **preselecciona el de menor `shipping_amount.amount`**.
- Guardar `shippingQuoteId` + `expirationDate` de la cotización eBay.
- `printLabel()` / `printLabelDirectly()` bifurcan por `selectedRate.source`:
  - `shipengine` → flujo actual + `POST /ebay/tracking-outbox { shipmentId }` (mecanismo de sync).
  - `ebay` → si `Date.now() > expirationDate`, **re-cotizar en silencio** y usar el nuevo `rateId`; luego `POST /ebay/logistics/purchase`.

---

## Orden de construcción

1. **Migración `so_info.ebay_account_id`** + poblarla en `EbayOrdersService.processLineItem`. Es el guard base de todo el plan.
2. **Tabla `ebay_tracking_outbox` + trigger `AFTER UPDATE ON shipment`** (llena `tracking_number` y pone `status='READY'`).
3. **`EbayFulfillmentService.createShippingFulfillment`** + mapeo carrier interno → eBay. Test unitario con `HttpService` mockeado.
4. **Endpoint `POST /ebay/tracking-outbox`** (resuelve cuenta desde `so_info`, inserta la fila, guard eBay).
5. **Consumer `@Cron`** del outbox: polling `status='READY'`, regla "primer tracking por orden", token, `createShippingFulfillment`, transición de estados y reintentos.
6. **Frontend camino ShipEngine:** disparar `POST /ebay/tracking-outbox` al imprimir.
7. **Swagger** en los endpoints/DTOs nuevos del alcance activo.
8. **Prueba end-to-end:** (a) ShipEngine → outbox → trigger → consumer → tracking visible en Seller Hub; (b) compra directa NO genera fila en outbox ni llama a eBay; (c) SO con varias etiquetas → solo el primer tracking se sincroniza (resto `SKIPPED`).

**— Hasta aquí el alcance activo. Elimina el paso manual para el 100% del volumen actual. —**

### ⏸️ Pendiente — camino Logistics (retomar solo tras aprobación de eBay)

9. Resolver aprobación Limited Release + scope `sell.logistics`; luego `EbayLogisticsService` (cliente + endpoints `quote`/`purchase`) + `GtsCrmShipmentsService.saveTrackingInfo`. Sin sandbox: se valida en producción tras aprobación.
10. Frontend comparador: cotización eBay en paralelo, normalización, preselección por precio, badge de origen, bifurcación de `printLabel` con re-cotización silenciosa.

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Componente compartido con compras directas | Guard `ebay_account_id IS NOT NULL` en los 4 puntos de entrada. |
| Logistics API es Limited Release | Confirmar aprobación por cuenta con `createShippingQuote` antes de construir el paso 7–8; degradación limpia si una cuenta no está aprobada. |
| Logistics solo soporta USPS | El comparador aporta valor acotado (paquetes chicos); no reemplaza UPS/FedEx. El camino ShipEngine cubre el resto y es el entregable principal. |
| Varias etiquetas por SO | El consumer agrupa por `order_id` y sincroniza solo la primera (`SKIPPED` para el resto). Orden determinístico por `created_at`/`id`. |
| Cotización eBay expira antes de imprimir | Re-cotizar en silencio usando `expirationDate` (Decisión #5). |
| El trigger corre en cada UPDATE de `shipment` | Condición estricta `tracking_number` NULL→valor + `WHERE ... AND tracking_number IS NULL` en el outbox → costo despreciable y sin doble inserción. |
| Consumer y mantenimiento de BD simultáneos | Flag `isRunning` en memoria (mismo patrón que `ebay-reconciliation`). |
| Camino eBay: NestJS escribe en `shipment` (hoy solo Symfony) | Ya hay precedente (`GtsCrmShipmentsService.createWithManager`). Confirmar que Symfony no tenga lógica extra atada a esa escritura (facturación, correos). |

---

## Lo que NO cambia

- Backend Symfony/PHP y su integración con ShipEngine: sin cambios de código (solo se agregan objetos de esquema que ignora: la tabla outbox y el trigger).
- Módulos `ebay-orders`, `ebay-oauth`, `ebay-notifications`, `ebay-reconciliation`: sin cambios funcionales (se extiende `ebay-fulfillment` y se agregan módulos nuevos).
- Modelo "1 SO por producto" (`Manejo de multi-line-items.md`).
- Control humano: la preselección por precio es solo un default; el operador puede elegir otra tarifa antes de imprimir.
