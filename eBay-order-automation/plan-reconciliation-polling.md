# Plan: Job de Reconciliación — Polling `getOrders` (eBay Fulfillment API)

**Fecha:** 2026-07-03
**Estado:** Diseño — Implementado
**Contexto:** El webhook `ORDER_CONFIRMATION` ya está operativo y procesado end-to-end. Este plan cubre el **job de reconciliación** identificado como pendiente en `proceso.md` (sección de "Pendientes de endurecimiento"): consultar `getOrders` cada 6 horas para capturar órdenes que eBay no notificó (internacionales/eIS, fallas de red, reintentos agotados).

---

## Validación con datos reales (2026-07-03)

Se consultó `GET /sell/fulfillment/v1/order?filter=creationdate:[2026-07-01T00:00:00.000Z..]` contra la cuenta `greenteksolutions` y se obtuvieron 7 órdenes. Hallazgos clave que informan el diseño:

| orderId | `orderPaymentStatus` | `cancelState` | Tipo | Acción |
|---|---|---|---|---|
| `08-14854-46782` | `PAID` | `NONE_REQUESTED` | Nacional | ✅ Procesar |
| `21-14831-34975` | `PAID` | `NONE_REQUESTED` | Nacional | ✅ Procesar |
| `18-14836-71109` | `PAID` | `NONE_REQUESTED` | Nacional | ✅ Procesar |
| `02-14864-31511` | `PAID` | `NONE_REQUESTED` | Nacional | ✅ Procesar |
| `17-14836-03840` | `PAID` | `IN_PROGRESS` | Nacional (comprador Perú, envío a FL) | ⏳ Omitir por ahora |
| `19-14832-68853` | `FULLY_REFUNDED` | `CANCELED` | Prueba interna | ❌ Excluir |
| `27-14817-31037` | `PAID` | `NONE_REQUESTED` | **eIS / Internacional (Tailandia)** | ✅ Procesar |

**Confirmación crítica:** `getOrders` **sí retorna órdenes eIS** (último registro: comprador en Bangkok, envía a warehouse de eBay en Illinois con `ebaySupportedFulfillment: true`). El polling captura exactamente lo que el webhook no notifica.

---

## Problema a resolver

El webhook depende de que eBay entregue la notificación. Existen dos escenarios donde la notificación no llega:

1. **Órdenes internacionales / eIS (eBay International Shipping):** confirmado con datos reales — `getOrders` las incluye pero el webhook no las notifica.
2. **Fallas de entrega del API de notificaciones:** red, timeouts, `publishAttemptCount` agotado sin éxito.

El resultado es una SO que no se crea en el CRM aunque la orden ya fue pagada y confirmada en eBay.

---

## Solución

Un **job de reconciliación** que:

- Consulta `GET /sell/fulfillment/v1/order` (filtro `lastmodifieddate` o `creationdate`) para las **4 cuentas** cada 6 horas.
- Intenta procesar cada orden encontrada con **la misma lógica y la misma idempotencia** que el webhook (`orderId + orderLineItemId`): si la SO ya existe, se omite. Si no existe, se crea.
- Expone un **endpoint manual** (`POST /ebay/reconciliation/run`) que ejecuta el mismo flujo on-demand desde el frontend.

No se crea una segunda ruta de procesamiento; se **reutiliza `EbayOrdersService.processOrderConfirmation`**. El webhook y el job convergen en el mismo punto y la idempotencia garantiza cero duplicados.

---

## Arquitectura y componentes

### Módulo nuevo: `ebay-reconciliation`

Ubicación: `api-nestjs/src/ecommerce/modules/ebay-reconciliation/`

Sigue el mismo patrón de módulos que `ebay-notifications`: controller + service + módulo. No es monolítico; se apoya en los módulos existentes.

```
ebay-reconciliation/
  ebay-reconciliation.controller.ts   ← endpoint POST manual
  ebay-reconciliation.service.ts      ← lógica del job (loop por cuentas)
  ebay-reconciliation.module.ts
```

### Módulo afectado (extensión): `ebay-fulfillment`

Se agrega el método `getOrders(token, filter)` al `EbayFulfillmentService` existente. No se crea un nuevo cliente HTTP; se extiende el ya existente.

### Módulo sin cambios: `ebay-orders`

`EbayOrdersService.processOrderConfirmation(account, order)` se usa tal cual. Idempotencia ya implementada.

---

## Flujo del job por ejecución

```
EbayReconciliationService.runForAllAccounts()
  └── Para cada cuenta vinculada (gobig_ebay_linked_accounts):
        1. getSystemTokenByAccountId(account.id)           ← EbayOauthService (existente)
        2. getOrders(token, { lastmodifieddate: [desde..hasta] })  ← EbayFulfillmentService (nuevo método)
           └── Paginar: limit=200, offset incremental hasta total agotado
        3. Para cada Order obtenida:
              ① Filtrar: solo procesar si pasa TODOS los criterios (ver sección abajo)
              ② processOrderConfirmation(account, order)   ← EbayOrdersService (existente)
                 └── Idempotencia interna: si SO ya existe → omite. Si no → crea.
        4. Log: cuenta, total órdenes, elegibles, nuevas SOs creadas, omitidas por idempotencia, descartadas por filtro.
```

### Criterios de elegibilidad (filtro client-side)

La API de eBay no permite filtrar por `orderPaymentStatus` directamente. El filtrado se aplica en el service después de recibir la respuesta paginada:

```
order es elegible si:
  (order.orderPaymentStatus === 'PAID' OR order.orderPaymentStatus === 'PARTIALLY_REFUNDED')
  AND order.cancelStatus.cancelState !== 'CANCELED'
  AND order.cancelStatus.cancelState !== 'IN_PROGRESS'
```

**Justificación por caso (datos reales):**

| Condición | Campo | Acción | Razón |
|---|---|---|---|
| `orderPaymentStatus === 'PAID'` | Campo raíz de la orden | ✅ Requerido | Solo procesar compras confirmadas y pagadas |
| `orderPaymentStatus === 'FULLY_REFUNDED'` | — | ❌ Descartar | Orden reembolsada, no se despacha (ej: `19-14832-68853`) |
| `cancelState === 'CANCELED'` | `cancelStatus.cancelState` | ❌ Descartar | Cancelación completada, no debe generar SO |
| `cancelState === 'IN_PROGRESS'` | `cancelStatus.cancelState` | ⏳ Omitir | Cancelación pendiente de resolución — en la siguiente ejecución del job el estado ya habrá cambiado a `CANCELED` (se descarta) o `NONE_REQUESTED` (se procesa) |
| `cancelState === 'NONE_REQUESTED'` | — | ✅ Elegible | Estado normal de una orden activa |
| eIS / `ebaySupportedFulfillment: true` | `fulfillmentStartInstructions[].ebaySupportedFulfillment` | ✅ Procesar igual | La lógica de procesamiento ya maneja el `shipTo` que apunta al warehouse de eBay; el `finalDestinationAddress` es informativo |

> **Nota sobre eIS:** la orden internacional (`27-14817-31037`) tiene `orderPaymentStatus: 'PAID'` y `cancelState: 'NONE_REQUESTED'`, por lo que pasa el filtro correctamente. El `shipTo` apunta al warehouse de eBay en Illinois (no al comprador final en Tailandia), que es exactamente la dirección de envío que el vendedor debe usar — se procesa igual que una orden nacional.

### Filtro de fecha

- **Primera ejecución / manual sin parámetro:** `lastmodifieddate:[<ahora - 24h>..]` (ventana conservadora para no perder nada entre inicios).
- **Ejecuciones automáticas (cada 6h):** `lastmodifieddate:[<ahora - 7h>..]` (ventana de 7h para solapar la ejecución anterior con margen de 1h contra delays).
- **Manual con rango explícito desde el frontend:** se recibe `dateFrom` / `dateTo` como body del POST.

> **Por qué `lastmodifieddate` y no `creationdate`:** una orden puede crearse y modificarse (pago completado) en momentos distintos. `lastmodifieddate` captura el estado final pagado aunque hayan pasado horas desde la creación.

### Paginación

`getOrders` devuelve máximo 200 por página. El job itera con `offset` hasta que `orders.length < limit` o `total === 0`.

---

## Endpoint manual (frontend)

```
POST /ebay/reconciliation/run
Body (opcional): { "dateFrom": "2026-07-01T00:00:00Z", "dateTo": "2026-07-03T23:59:59Z" }
Response: { "status": "ok", "accounts": 4, "ordersChecked": N, "newSosCreated": M }
```

- Si no se envía body, usa la ventana por defecto (últimas 24h).
- Responde con el resumen del resultado (sincrónico o con timeout razonable).
- **No requiere autenticación adicional** más allá del guard ya existente en la API (mismo nivel que otros endpoints internos). Verificar qué guard usa el proyecto y aplicar el mismo.

> **Consideración de tiempo de respuesta:** si hay muchas órdenes, el proceso puede tardar. Dos opciones:
> - **Opción A (recomendada para este plan):** respuesta sincrónica con timeout de 30s por cuenta; si tarda más, devolver `202 Accepted` con un `jobId` y exponer `GET /ebay/reconciliation/status/:jobId`. Se confirma el uso de la opción A.
> - **Opción B:** respuesta inmediata `202`, el job corre en background (requiere BullMQ o similar).
>
> Se recomienda **Opción A** primero (más simple, sin nueva infraestructura). Si el volumen de órdenes crece, migrar a Opción B.

---

## Scheduler automático (cada 6 horas)

NestJS incluye `@nestjs/schedule` (si ya está instalado en el proyecto, confirmarlo en `package.json`). Se agrega un `@Cron` dentro del service:

```ts
// En EbayReconciliationService
@Cron('0 */6 * * *')  // cada 6 horas en punto
async scheduledRun(): Promise<void> {
  await this.runForAllAccounts({ windowHours: 7 });
}
```

Si `@nestjs/schedule` no está instalado: `npm install @nestjs/schedule` y registrar `ScheduleModule.forRoot()` en `AppModule`.

---

## Idempotencia — garantía de no duplicados

La idempotencia **ya existe** en `EbayOrdersService`: antes de crear cada SO verifica si existe una fila en `so_info` con `client_PO_Number = orderId` AND `reference = orderLineItemId`. Si existe → omite. Esta llave cubre exactamente el escenario del job de reconciliación.

**No se necesita ninguna tabla nueva** de control de "órdenes procesadas". El estado de verdad es `so_info` misma.

### Conflicto con SOs creadas manualmente (`ebay_account_id IS NULL`)

**Hallazgo (2026-07-15):** la llave `(client_PO_Number, reference)` solo detecta SOs creadas por nuestra propia automatización (webhook o reconciliación) — son las únicas que llenan `reference` con el `orderLineItemId`. Una SO creada **manualmente** en el CRM para una orden de eBay comparte el mismo `client_PO_Number` pero normalmente **nunca** llena `reference` (queda `NULL`). El pre-check `existsByOrderLine` no la ve, así que la reconciliación puede crear una SO duplicada para una orden que un humano ya procesó a mano.

Caso real que expuso esto: orden `01-14883-00228` (cuenta `greenteksolutions-b`), creada el 2026-07-07 y procesada manualmente el mismo día (`so_info.reference = NULL`). El 2026-07-15 cambió su `lastModifiedDate` (se agregó fulfillment/tracking), entró en la ventana de 7h del job automático, y la reconciliación creó una **segunda** SO para la misma orden.

**Fix:** antes de tocar cualquier línea de una orden, `EbayReconciliationService.processOrderWithCounts` verifica si ya existe alguna fila de `so_info` para ese `client_PO_Number` con `ebay_account_id IS NULL` — columna que solo llena nuestra propia automatización (`SoInfo.ebayAccountId`, agregada para `plan-auto-actualizacion-tracking-ebay.md`; `NULL` = SO no originada por el flujo de eBay). Si existe una fila así, se trata **toda la orden** como conflicto manual y **no se crea ninguna SO nueva para ninguna de sus líneas** — una SO manual normalmente cubre la orden completa sin desglosarse por línea, y no hay forma confiable de saber cuál(es) línea(s) ya cubre.

- Nuevo método: `GtsCrmSalesOrdersService.hasManualSoForOrder(orderId)` — `COUNT(*) WHERE client_PO_Number = orderId AND ebay_account_id IS NULL`.
- Nuevo contador en el resumen (por cuenta y agregado): `skippedManual`, separado de `errors` — no es una falla, es una decisión correcta de no duplicar trabajo humano.
- Se reporta en `errorDetails` con `orderId`, todos los SKUs de la orden y el motivo, para revisión manual.
- **Trade-off aceptado:** en una orden multi-línea donde un humano solo cubrió una línea manualmente y la otra genuinamente falta, la reconciliación tampoco crea automáticamente la línea faltante — queda para revisión humana en vez de arriesgarse a adivinar cuál línea cubre la SO manual.

---

## Extensión de `EbayFulfillmentService` — método `getOrders`

```ts
// Firma propuesta en ebay-fulfillment.service.ts
async getOrders(
  token: string,
  filter: { lastmodifieddate?: string; creationdate?: string },
  limit = 200,
  offset = 0,
): Promise<EbayOrdersResponse>
```

- Construye el query string con el filtro ISO 8601 codificado (`%5B`, `%5D`, etc. — ver spec).
- Retorna `{ orders: Order[], total: number, next: string | null }`.
- El paginador del job llama este método en loop incrementando `offset`.

---

## Logging y monitoreo

Cada ejecución (automática o manual) registra:

```
[EbayReconciliationService] Run START — accounts: 4, window: [2026-07-03T00:00:00Z..2026-07-03T07:00:00Z]
[EbayReconciliationService] Account greenteksolutions — 12 orders checked, 1 new SO created, 11 skipped
[EbayReconciliationService] Account greenteksolutions-b — 3 orders checked, 0 new SOs created, 3 skipped
...
[EbayReconciliationService] Run END — total: 18 orders, 1 new SO, 17 skipped, duration: 4.2s
```

---

## Frontend — botón de ejecución manual

El frontend ya tiene acceso a la API interna. Se agrega un botón en la sección de administración de eBay (donde se gestionan cuentas y notificaciones):

- **Label:** "Sincronizar órdenes eBay"
- **Acción:** `POST /ebay/reconciliation/run` (sin body para usar ventana por defecto, o con selector de fechas).
- **Feedback:** spinner mientras corre → mensaje con el resumen (`N órdenes revisadas, M SOs nuevas creadas`).
- **Habilitación:** el botón se deshabilita mientras hay una ejecución en curso (evitar doble-clic). Si el scheduler está corriendo, el intento manual simplemente resulta en 0 SOs nuevas (idempotencia).

---

## Documentación Swagger

Todo el código nuevo debe documentarse con decoradores de `@nestjs/swagger`, siguiendo el mismo patrón de los módulos existentes:

- **Controller:** `@ApiTags`, `@ApiOperation`, `@ApiResponse` en cada endpoint.
- **DTOs de request/response:** `@ApiProperty` en cada campo (incluyendo el body opcional `{ dateFrom, dateTo }` y el response con el resumen).
- **Módulo:** verificar que `EbayReconciliationModule` quede incluido en el setup de Swagger de `AppModule` si hay lista de módulos explícita.

---

## Orden de construcción

1. **`EbayFulfillmentService.getOrders`** — método nuevo con paginación y filtro de fecha. Unit test con mock de HttpService.
2. **`EbayReconciliationService`** — loop por cuentas, llama `getOrders` + `processOrderConfirmation`. Verificar que `@nestjs/schedule` está disponible.
3. **`EbayReconciliationController`** — endpoint `POST /ebay/reconciliation/run` con body opcional `{ dateFrom, dateTo }`.
4. **`EbayReconciliationModule`** — registrar imports: `EbayOauthModule`, `EbayFulfillmentModule`, `EbayOrdersModule`. Importar en `EcommerceModule` (o donde se registren los módulos de eBay).
5. **Scheduler `@Cron`** — agregar al service. Confirmar que `ScheduleModule.forRoot()` esté en `AppModule`.
6. **Frontend** — botón con call al endpoint manual y display del resumen.
7. **Prueba end-to-end** — ejecutar manual contra sandbox con una orden conocida que no llegó por webhook; verificar SO creada. Ejecutar de nuevo → verificar que no se duplica.

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Rate limit de eBay en `getOrders` (límite por cuenta) | **Implementado.** `EbayFulfillmentService.getOrders` reintenta con backoff exponencial + jitter ante `429` (1 intento inicial + 3 reintentos), respetando el header `Retry-After` de eBay si viene. Otros errores (401/403/404/5xx) se propagan sin reintentar. |
| Job automático y manual corren simultáneamente | Flag en memoria (`isRunning`) que bloquea una segunda ejecución concurrente. Si el scheduler está corriendo, el endpoint manual devuelve `409 Conflict`. |
| Ventana de fecha demasiado corta y se pierden órdenes | Ventana de 7h para ejecuciones cada 6h da 1h de margen. Para el arranque inicial, ejecutar manual con rango amplio (ej. últimas 72h). |
| `getOrders` no retorna órdenes eIS | **Descartado** — confirmado con datos reales (2026-07-03) que `getOrders` sí incluye órdenes eIS. No requiere manejo especial. |
| Orden `cancelState: IN_PROGRESS` que luego se reactiva | El filtro la omite en la ejecución actual. Si la cancelación se revierte, en la siguiente ejecución del job aparecerá con `cancelState: NONE_REQUESTED` y `orderPaymentStatus: PAID`, y se procesará normalmente. |
| Orden reembolsada parcialmente (`PARTIALLY_REFUNDED`) | **Decisión confirmada:** tratar igual que `PAID`. El pago original existió, el producto se despacha; el reembolso parcial es una transacción financiera separada que no afecta la SO. |
| `dateTo` en el futuro (manual) tumba `getOrders` en las 4 cuentas | **Implementado.** `resolveWindow` descarta cualquier `dateTo >= ahora` y deja la ventana abierta (`[from..]`), que es el comportamiento nativo que espera eBay. Se loguea un warning cuando se ajusta. |
| SO creada manualmente en el CRM (sin `reference`) → la reconciliación no la detecta y crea un duplicado | **Implementado (2026-07-15).** Gate por `ebay_account_id IS NULL` antes de procesar cualquier línea de la orden — ver "Conflicto con SOs creadas manualmente" arriba. |

---

## Lo que NO cambia

- El webhook sigue siendo el camino principal (tiempo real, menor latencia).
- El código de `ebay-notifications`, `ebay-orders`, `ebay-oauth`, `ebay-fulfillment` no se modifica (solo se extiende `ebay-fulfillment` con el nuevo método `getOrders`).
- La idempotencia en `so_info(client_PO_Number, reference)` sigue siendo la única fuente de verdad para deduplicación.
