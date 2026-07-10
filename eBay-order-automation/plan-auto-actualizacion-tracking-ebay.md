# Plan: Actualización automática de tracking en eBay al generar la etiqueta

**Fecha:** 2026-07-09
**Estado:** Diseño — Propuesta (pendiente de decisiones abiertas, ver sección final)
**Contexto:** La ingesta de órdenes de eBay (webhook + reconciliación) ya está operativa y crea la SO en el CRM. Este plan cubre el **tramo final del flujo**: una vez generada la etiqueta de envío, notificar a eBay el tracking number para eliminar el paso manual actual.

---

## Problema a resolver

Flujo actual (100% manual en el último paso):

1. La orden de eBay entra automáticamente y crea la SO (`so_info`) — ya automatizado.
2. Un operador genera la etiqueta de envío desde el dashboard (`gtsdashboard/src/app/shipments/process/process.component.ts`, y también desde `so-crud/shipping/shipping.component.ts`), que llama al backend **Symfony/PHP** (`itaderp.com/backend/crm/web/shipment/shipengine_create_label` o `.../shipenginecreatelabeldirectly`). Ese backend llama a ShipEngine, genera el PDF y devuelve `tracking_number` + `label_download_pdf`.
3. **Paso manual:** el operador va a Seller Hub de eBay, busca la orden y pega a mano el `tracking_number` y el carrier para marcarla como enviada (captura 2).

El objetivo es eliminar el paso 3: que al completarse el paso 2, eBay se actualice solo.

**Restricción de diseño confirmada:** el endpoint nuevo que habla con eBay debe vivir en `api-nestjs/src/ecommerce/modules/` (no en el backend Symfony). El backend Symfony/ShipEngine **no se modifica**.

---

## Hallazgo crítico — prerrequisito bloqueante

Se revisó cómo NestJS resuelve el token de eBay por cuenta (`EbayOauthService.getSystemTokenByAccountId(ebayAccountId)` / `getSystemTokenByEbayUserId(ebayUserId)`, `api-nestjs/src/ecommerce/modules/ebay-oauth/ebay-oauth.service.ts:236-303`) y cómo se crea la SO desde la orden de eBay (`EbayOrdersService.processOrderConfirmation`, `ebay-orders.service.ts:67-70`).

**El parámetro `account: GobigEbayLinkedAccount` que identifica qué cuenta vendedora de eBay recibió la orden se recibe, pero nunca se persiste en `so_info` ni en `shipment`.** `so_info.master_id` es una constante fija (`MASTER_ID = 1`, `ebay-orders.service.ts:30`) que no distingue entre las 4 cuentas eBay vinculadas mencionadas en `plan-reconciliation-polling.md`.

**Consecuencia:** hoy, dado un `so_id`/`shipment_id`, no hay forma de saber a qué cuenta de eBay pertenece esa orden para pedir el access token correcto. Esto **bloquea** la función de sincronizar tracking si hay más de una cuenta eBay activa.

**Opciones:**

| Opción | Descripción | Trade-off |
|---|---|---|
| **A — Persistir el vínculo (recomendada)** | Agregar columna `ebay_account_id` a `so_info` (o tabla puente) y poblarla en `EbayOrdersService.processLineItem` al crear la SO. Migración simple, una sola escritura adicional. | Requiere tocar el flujo de creación de SO (ya construido y probado) y una migración de esquema. |
| **B — Resolución por prueba** | Al sincronizar tracking, probar `getOrder(orderId)` contra el token de cada cuenta vinculada hasta que una responda 200. | Cero cambios al flujo existente, pero N llamadas a eBay por sync (N = cuentas vinculadas) y más latencia/rate-limit. Válido como parche temporal si hay presión de tiempo. |

Se recomienda **Opción A**, ejecutada como primer paso de este plan (antes o junto con Fase 1) — dado que el proyecto ya está evolucionando el mapeo de SO↔eBay (`Mapeo de datos 1.md`), es más barato cerrarlo ahora que rehacerlo después.

---

## Diseño de la solución

### Punto de disparo — quién llama al nuevo endpoint

| Opción | Descripción | Trade-off |
|---|---|---|
| **1 — Frontend (recomendada para Fase 1)** | Justo después de que `generateLabel()` / `generateLabelDirectly()` (`process.component.ts:1183` y `:1290`) devuelvan `status: success`, el frontend llama al nuevo endpoint NestJS con `tracking_number`, `carrier` y `so_id`/`shipment_id`. | No toca el backend Symfony. Depende de que el navegador siga conectado tras generar la etiqueta — si falla, eBay queda desactualizado en silencio. |
| **2 — Backend Symfony (server-to-server)** | El backend Symfony, tras persistir el tracking en su propia tabla `shipment`, llama al endpoint NestJS. | Más confiable (no depende del navegador), pero requiere tocar el backend legado, que el alcance actual busca evitar. |

**Recomendación:** Fase 1 con Opción 1 (mínimo alcance, sin tocar Symfony) + Fase 2 con un **job de reconciliación** (mismo patrón que `plan-reconciliation-polling.md`) que detecte shipments con tracking generado pero no confirmado en eBay, y reintente. Esto cubre el caso de falla silenciosa de la Opción 1 sin necesidad de tocar el backend legado.

### Arquitectura y componentes

Sigue el mismo patrón ya usado por `ebay-reconciliation`: extender el cliente HTTP existente + un módulo orquestador nuevo.

```
api-nestjs/src/ecommerce/modules/
  ebay-fulfillment/
    ebay-fulfillment.service.ts     ← EXTENDER: nuevo método createShippingFulfillment()
  ebay-shipment-sync/                ← NUEVO módulo
    ebay-shipment-sync.controller.ts   ← POST /ebay/shipment-sync/tracking
    ebay-shipment-sync.service.ts      ← orquesta: resuelve SO → cuenta → token → llama a eBay
    ebay-shipment-sync.module.ts
    dto/sync-tracking.dto.ts
```

#### 1. Extensión de `EbayFulfillmentService` (nuevo método, cliente puro)

```ts
// POST /sell/fulfillment/v1/order/{orderId}/shipping_fulfillment
async createShippingFulfillment(
  orderId: string,
  token: string,
  payload: {
    lineItems?: { lineItemId: string; quantity?: number }[];
    shippedDate: string;          // ISO 8601
    shippingCarrierCode: string;  // ej. "UPS", "FedEx", "USPS"
    trackingNumber: string;
  },
): Promise<{ fulfillmentId: string }>
```

- Mismo patrón de logging/errores que `getOrder`/`getOrders` (sin loguear el token, sí el `orderId` y el body de error de eBay).
- Si `lineItems` se omite, eBay marca como enviada toda la cantidad pendiente del line item — válido en este modelo porque **1 SO = 1 orderLineItemId completo** (decisión ya tomada en `Manejo de multi-line-items.md`, Opción B). No se necesita consultar `inventory` para la cantidad.

#### 2. Módulo nuevo `EbayShipmentSyncService`

```
EbayShipmentSyncService.syncTracking(dto: SyncTrackingDto)
  1. Cargar so_info por soId → obtener clientPoNumber (orderId), reference (orderLineItemId), ebay_account_id (Opción A del hallazgo crítico)
  2. getSystemTokenByAccountId(ebay_account_id)         ← EbayOauthService (existente)
  3. Mapear carrier interno → shippingCarrierCode de eBay (ver sección siguiente)
  4. createShippingFulfillment(orderId, token, { lineItems: [{ lineItemId: reference }], shippedDate, shippingCarrierCode, trackingNumber })  ← EbayFulfillmentService (nuevo método)
  5. Registrar el resultado (fulfillmentId de eBay) — ver "Idempotencia" abajo
```

#### 3. Mapeo de carrier interno → código de carrier de eBay

Ya existe la tabla `carriers` (`gts-crm-lookups/entities/carrier.entity.ts`) con `external_carrier_code` (código ShipEngine) usada hoy para el mapeo **eBay → interno** en `GtsCrmLookupsService.resolveCarrier`. Para el sentido inverso (interno → eBay) se reutiliza la misma tabla, buscando por `external_carrier_code` (el que el backend Symfony/ShipEngine ya guardó en `shipment.carrier_code`) y devolviendo `carrier.name`.

**Riesgo a validar en construcción:** `carrier.name` debe calzar con los valores que eBay acepta en `shippingCarrierCode` (`UPS`, `FedEx`, `USPS`, `DHL`, `OnTrac`, etc., o `Other` + `otherFulfillmentProviderName`). Si no calzan 1:1, se necesita una tabla de mapeo explícita (2–3 filas, no un problema estructural).

---

## Contrato del endpoint nuevo

```
POST /ebay/shipment-sync/tracking
Body: {
  "shipmentId": 123,        // o soId, a definir según qué identificador ya tiene el frontend en el callback de generateLabel
  "trackingNumber": "1ZXJ28870313781042",
  "carrierCode": "ups",     // código interno (ShipEngine), el mismo que ya devuelve/persiste Symfony
  "shippedDate": "2026-07-10T02:49:34Z"   // opcional, default: ahora
}

Response 200: { "status": "ok", "ebayFulfillmentId": "...", "orderId": "21-14854-94058" }
Response 4xx: { "status": "error", "msg": "..." }
```

- Autenticación: mismo guard interno que el resto de endpoints de `ecommerce` (confirmar cuál usan `ebay-reconciliation`/`ebay-notifications`).
- Es **idempotente por diseño de eBay**: reenviar el mismo `trackingNumber` para el mismo `orderId` no duplica el envío (eBay actualiza el fulfillment existente). No se necesita tabla de control adicional para evitar duplicados, pero sí es recomendable loguear el `ebayFulfillmentId` devuelto para auditoría.

---

## Fase 2 (opcional, recomendada) — Reconciliación de tracking no sincronizado

Mismo patrón que `plan-reconciliation-polling.md`: un job (`@Cron`, cada N horas) que recorra shipments con `tracking_number` seteado (columna que hoy sólo existe en el backend Symfony/tabla `shipment` real — **confirmar el nombre exacto de columna al construir**, ya que el `Shipment` entity de NestJS no la mapea todavía) y sin confirmación de sync a eBay, y reintente la Opción 1 (llamar `EbayShipmentSyncService.syncTracking`). Cubre el caso donde el navegador se cierra o falla la llamada del frontend.

No es indispensable para el primer entregable, pero cierra el único punto de falla silenciosa de la Opción 1 de disparo.

---

## Orden de construcción

1. **Prerrequisito — vínculo SO ↔ cuenta eBay:** migración + cambio en `EbayOrdersService.processLineItem` para persistir `ebay_account_id` en `so_info` (Opción A del hallazgo crítico). Sin esto, el resto del plan solo funciona con una cuenta eBay activa.
2. **`EbayFulfillmentService.createShippingFulfillment`** — método nuevo, con test unitario mockeando `HttpService` (mismo patrón que `getOrder`).
3. **Mapeo carrier interno → eBay** en `GtsCrmLookupsService` (o servicio nuevo pequeño) — validar contra los valores reales que devuelve ShipEngine vs. el enum de eBay.
4. **`EbayShipmentSyncModule`** (controller + service + DTO) — importa `EbayOauthModule`, `EbayFulfillmentModule`, `GtsCrmSalesOrdersModule`, `GtsCrmLookupsModule`. Registrar en `EcommerceModule`.
5. **Documentación Swagger** (`@ApiTags`, `@ApiOperation`, `@ApiProperty` en el DTO) — mismo estándar que el resto de módulos `ebay-*`.
6. **Frontend:** agregar la llamada al nuevo endpoint en los callbacks `next` de `printLabel()` / `printLabelDirectly()` (`process.component.ts:1183-1208`, `:1290-1317`) y en `createShipment()` (`shipping.component.ts:206-247`), inmediatamente después de mostrar "Label generated". Mostrar feedback (éxito/error de sync a eBay) sin bloquear el flujo de impresión de etiqueta si el sync falla.
7. **Prueba end-to-end en sandbox** (`EBAY_ENVIRONMENT=sandbox`, mismo ambiente de las capturas): generar etiqueta real, confirmar que la orden aparece marcada como enviada con el tracking correcto en Seller Hub sandbox.
8. **(Opcional) Fase 2** — job de reconciliación de tracking no sincronizado.

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| No hay vínculo SO↔cuenta eBay persistido (hallazgo crítico) | Bloqueante — resolver primero (paso 1 de construcción). Sin esto, funciona solo con una cuenta activa. |
| Fallo silencioso si el navegador se cierra tras generar la etiqueta (disparo por frontend) | Fase 2 (reconciliación) como red de seguridad; en el corto plazo, mostrar error visible en el dashboard si el POST al nuevo endpoint falla. |
| Mismatch entre `carrier.name` interno y el enum `shippingCarrierCode` de eBay | Validar con casos reales en sandbox antes de producción; agregar tabla de mapeo explícita si no calzan. |
| Un shipment podría, en teoría, empaquetar items de más de una SO (multi-line-item) | Según `Manejo de multi-line-items.md` (Opción B, decidida), cada `shipment.so_id` es singular → 1 shipment = 1 SO = 1 orderId+lineItemId. Confirmar en construcción que la UI de "add items to box" no permite mezclar SOs distintas en un mismo shipment; si lo permite, el endpoint necesita soportar N `lineItems` en un solo POST a eBay. |
| Rate limit de eBay en `shipping_fulfillment` | Volumen esperado es 1 llamada por etiqueta generada (no es un job masivo) — riesgo bajo. |
| Ambiente sandbox vs producción | El cliente ya resuelve `baseUrl` por `EBAY_ENVIRONMENT` (mismo patrón que `EbayFulfillmentService` existente) — sin cambio necesario. |

---

## Lo que NO cambia

- El backend Symfony/PHP (`itaderp.com`) y la integración con ShipEngine: no se toca. Sigue generando la etiqueta y el `tracking_number` exactamente igual que hoy.
- Los módulos `ebay-orders`, `ebay-oauth`, `ebay-notifications`, `ebay-reconciliation`: sin cambios (solo se extiende `ebay-fulfillment` con un método nuevo, mismo patrón ya usado para `getOrders`).
- El modelo de datos "1 SO por producto" (`Manejo de multi-line-items.md`): no se revisita.

---

## Preguntas / decisiones abiertas antes de construir

1. ¿Se aprueba la migración para persistir `ebay_account_id` en `so_info` (Opción A del hallazgo crítico), o se prefiere la Opción B (resolución por prueba) como parche temporal?
2. ¿El disparo debe ser solo desde el frontend (Fase 1), o se quiere de entrada la Fase 2 (reconciliación) para no depender de la confiabilidad del navegador?
3. ¿Cuál es el nombre real de la(s) columna(s) de tracking en la tabla `shipment` del backend Symfony? Necesario para diseñar la consulta de reconciliación (Fase 2) y confirmar qué campos exactos devuelve `generateLabel`/`generateLabelDirectly` más allá de `tracking_number` y `label_download_pdf`.
4. ¿Confirmа que ningún shipment actual mezcla items de más de una SO en el mismo paquete/etiqueta? (afecta si el endpoint necesita soportar múltiples `lineItems` por llamada).
