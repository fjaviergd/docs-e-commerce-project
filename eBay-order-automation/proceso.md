# Proceso de automatización de órdenes eBay

Documentación del flujo completo para interceptar ventas de eBay y registrarlas automáticamente en el CRM (tablas `so_info`, `inventory`, `shipment`).

> **Nota:** este documento fue el **plan/diseño**; la implementación **ya está construida y validada end-to-end** (2026-07-03). El código vive en `crm-api-nestjs`, rama `feature/ebay-order-automation` (subida a origin para revisión del equipo). Los estados de cada fase reflejan diseño + implementación.
>
> **Estado de implementación (2026-07-03):** el webhook único está operativo; se procesaron **órdenes reales** (nacionales e internacionales/eIS) creando `so_info` + reserva de `inventory` + `shipment`, con idempotencia (`orderId + orderLineItemId`) y numeración de `so` validadas. El **precio de venta** se toma del line item de eBay (`lineItemCost / quantity`, ver `Mapeo de datos 1.md`). **Pendientes de endurecimiento (no bloqueantes):** ACK rápido + procesamiento asíncrono (cola), job de reconciliación (polling `getOrders`) para notificaciones que eBay no logre entregar, endpoint público estable e índice único en `so_info(client_PO_Number, reference)`.

### Leyenda de estados

Cada fase indica dos dimensiones: estado del **diseño** y estado de la **implementación**.

- ✅ Diseño completado — definición cerrada, lista para implementar.
- 🔄 Diseño en curso — definición en proceso.
- ⏳ Diseño pendiente — aún sin definir.
- ⏳ Implementación pendiente — todavía no se construye/configura.

---

## Documentos de referencia

Todo lo necesario para implementar está en estos archivos:

- [`Mapeo de datos 1.md`](Mapeo%20de%20datos%201.md) — **mapeo campo por campo** (canónico): qué valor va a cada columna de `so_info`, `shipment` e `inventory`, con las Notas 01–07 (customer, rep, reserva, locations, carrier, multi-line, cuentas).
- [`Manejo de multi-line-items.md`](Manejo%20de%20multi-line-items.md) — decisión y análisis de la estrategia multi-line (Opción B).
- [`Arquitectura del codigo.md`](Arquitectura%20del%20codigo.md) — cómo organizar el código en módulos (ingreso compartido, orquestadores por evento, dominio CRM) con diagrama; guía para reutilizar al agregar más webhooks/eventos.
- [`tables_description.md`](tables_description.md) — **DDL de todas las tablas** involucradas (CRM `gts_crm_db` y Central), incluidas `gobig_ebay_linked_accounts` y `gobig_ebay_tokens`.
- [`response_example.md`](response_example.md) — ejemplos de notificación (Sección 1), Fulfillment (Sección 2) y casos multi-line (Sección 3).
- [`ebay-orders.jsonl`](ebay-orders.jsonl) — logs reales de notificaciones y respuestas de Fulfillment de las 4 cuentas.
- `../docs-ebay/` — specs oficiales de eBay (OAuth/Identity, Fulfillment `sell_fulfillment_v1_oas3.yaml`, Notification `commerce_notification_v1_oas3.yaml`).

---

## Fase 1 — Configuración de notificaciones en eBay

**Diseño: ✅ Completado · Implementación: ✅ Completada** (las 4 cuentas suscritas a `ORDER_CONFIRMATION` → destino del webhook, ENABLED)

Se registrarán las 4 cuentas de vendedor en la Notification API de eBay para que eBay envíe notificaciones automáticas al ocurrir una venta. La suscripción filtrará únicamente eventos del topic `ORDER_CONFIRMATION`, que corresponde a compras con pago completado.

Este proceso se realiza una sola vez por cuenta. No requiere mantenimiento salvo que se agreguen nuevas cuentas de vendedor.

> **Cuentas con ejemplos disponibles:** en los logs ([`ebay-orders.jsonl`](ebay-orders.jsonl)) aparecen 3 de las 4 cuentas: `greenteksolutions`, `greenteksolutions-b` y `greenteksolutions-d`. La **cuenta `greenteksolutions-c** aún no tiene órdenes de ejemplo; se recibirán más adelante. El mecanismo de identificación por `userId` aplica igual para esa cuenta una vez configurada.

- Referencia del payload que llega: [`response_example.md`](response_example.md) — Sección 1.

#### Identificación de la cuenta vendedora

La notificación de `ORDER_CONFIRMATION` **sí incluye la cuenta vendedora** en `payload.notification.data.user`:

```json
"data": {
  "user": { "userId": "TFHVhLbkQtu", "username": "greenteksolutions" },
  "order": { "orderId": "...", "orderLineItems": [...] }
}
```

Esto se confirmó contra los logs reales del backend ([`ebay-orders.jsonl`](ebay-orders.jsonl)): el `username` de la notificación coincide siempre con el `sellerId` de la respuesta de Fulfillment.

**Mecanismo definido — endpoint único:**

1. **Un solo webhook** para las 4 cuentas (no se requieren 4 destinos separados).
2. Al llegar la notificación se lee `data.user.userId` → se identifica la cuenta → se selecciona el OAuth token correspondiente para llamar a Fulfillment.
3. **Confirmación secundaria:** la respuesta de Fulfillment incluye `sellerId`, que se usa para validar que se llamó con el token correcto y para registrar la cuenta.

> **Mapear por `userId`, no por `username`.** El `userId` es inmutable; el `username` puede cambiar si el vendedor renombra la tienda. Se guardan ambos, pero `userId` es la llave de la config cuenta→token.

**Resolución cuenta → token (tablas):**

1. **Identificar la cuenta** — buscar el `userId` de la notificación en la tabla `gobig_ebay_linked_accounts`, columna **`ebay_user_id`** (ya existe en la tabla y está poblada con los `userId` de las cuentas). El registro encontrado da el `id` de la cuenta vinculada.
2. **Obtener el token** — con ese `id` buscar en la tabla `gobig_ebay_tokens` por `ebay_account_id` (FK → `gobig_ebay_linked_accounts.id`) y tomar el `refresh_token` / `token` (access token) para autenticar la llamada a Fulfillment. Revisar `expired` / `access_token_expires` y refrescar el access token si está vencido.
3. **Confirmación secundaria** — validar que el `sellerId` de la respuesta de Fulfillment corresponde a la cuenta identificada.

Mapeo de las 4 cuentas (`ebay_user_id` es la llave inmutable):

| Cuenta | `username` | `ebay_user_id` (llave) |
|---|---|---|
| A | greenteksolutions | TFHVhLbkQtu |
| B | greenteksolutions-b | DU5zAC4LSIy |
| C | greenteksolutions-c | tF7soxK5TPG |
| D | greenteksolutions-d | LECXHKWWRzO |

`gobig_ebay_linked_accounts` — campos relevantes: `id` (PK), `name`, `companies_id`, `master_id`, **`ebay_user_id`** (ya existe y poblada).

`gobig_ebay_tokens` — campos relevantes: `ebay_account_id` (FK → `gobig_ebay_linked_accounts.id`), `token`, `refresh_token`, `access_token_expires`, `expired`.

**Casos defensivos:**
- Si el `userId` no existe en `gobig_ebay_linked_accounts.ebay_user_id`, descartar el evento (cuenta no vinculada) y registrar la incidencia.
- Si `data.user` no viene en la notificación (ocurrió en el payload de prueba inicial), hacer fallback: consultar Fulfillment e identificar por `sellerId`, o descartar el evento.

---

## Fase 2 — Endpoint para recibir notificaciones

**Diseño: ✅ Completado · Implementación: ✅ Completada** (endpoint único + challenge validados en producción)

Se creará **un endpoint único** (webhook) que reciba los eventos HTTP POST que eBay envía para las 4 cuentas. El endpoint aceptará el payload de notificación y lo pondrá en cola para su procesamiento.

- El payload contiene: `data.user` (`userId`, `username`) y `data.order` (`orderId`, `orderLineItems[]` con `listingId` y `quantity`).
- `data.user.userId` identifica la cuenta vendedora y, con ello, el OAuth token a usar (ver Fase 1 — *Identificación de la cuenta vendedora*).
- Con el `orderId` se consulta la Fulfillment API para obtener el detalle completo de la orden.
- Referencia del payload completo de fulfillment: [`response_example.md`](response_example.md) — Sección 2.

**Validación del endpoint (challenge de eBay):** al registrar el destino, eBay valida la URL con un `GET` que incluye `?challenge_code=...`. El endpoint debe responder `200` con JSON `{ "challengeResponse": <hash> }`, donde:

```
challengeResponse = SHA-256( challengeCode + verificationToken + endpointURL )   // hex
```

- `verificationToken` lo defines tú al crear el destino (string secreto, se guarda en config/env).
- `endpointURL` es la URL pública exacta del webhook.
- Se debe responder con `Content-Type: application/json`.

**Ack y reproceso:** responder `200` rápido a eBay y procesar (idealmente en cola). Si el endpoint responde error, eBay **reintenta** (se observó `publishAttemptCount` hasta 3). Por eso el procesamiento se apoya en la idempotencia (abajo) para que los reintentos/duplicados no generen SOs repetidas.

**Idempotencia (requisito):** eBay reenvía notificaciones (reintentos con `publishAttemptCount` > 1, y se observaron duplicados con el mismo `notificationId` en los logs). El endpoint/procesamiento **debe ser idempotente**.

Como se genera **una SO por line item** (ver Fase 3 y [`Manejo de multi-line-items.md`](Manejo%20de%20multi-line-items.md)), la llave de deduplicación es **`orderId + orderLineItemId`** (no basta `orderId`, porque un mismo `orderId` produce varias SOs). Cada SO guarda su `orderLineItemId` en el campo `reference`, lo que permite verificar si una línea ya fue procesada antes de crear su SO.

---

## Fase 3 — Procesamiento de la orden

**Diseño: ✅ Completado · Implementación: ✅ Completada**

> **Estrategia (decidida):** se genera **una SO por cada line item** — *Opción B*. Una orden de eBay con N line items produce N SOs. El análisis y la justificación de esta decisión (vs. la alternativa de combinar en una sola SO) están en [`Manejo de multi-line-items.md`](Manejo%20de%20multi-line-items.md).

Esta fase se divide en las siguientes sub-fases:

### 3.1 — Revisión y confirmación del mapeo de datos

**Diseño: ✅ Completado · Implementación: ✅ Completada**

Definir con exactitud qué campo de la respuesta de eBay va a cada campo de las tablas del CRM, y tomar las decisiones sobre valores por defecto, lógica de fallback y campos pendientes de confirmar.

- Incluir el mapeo de `sellerId` → cuenta del CRM, y validar que coincide con la cuenta identificada por `data.user.userId` en la notificación (ver Fase 1).
- Referencia: [`Mapeo de datos 1.md`](Mapeo%20de%20datos%201.md) (archivo canónico).

### 3.2 — Diseño del procedimiento

**Diseño: ✅ Completado · Implementación: ✅ Completada**

#### Ubicación y arquitectura

- **Módulos nuevos** dentro de `crm-api-nestjs/src/ecommerce/modules/`, siguiendo la organización **canónica** de [`Arquitectura del codigo.md`](Arquitectura%20del%20codigo.md): ingreso compartido (`ebay-notifications`), cliente Fulfillment (`ebay-fulfillment`), orquestador de la feature (`ebay-orders`) y dominio CRM (`gts-crm-*`). Se ubican en `ecommerce` porque ahí ya viven las conexiones, entidades, `EbayOauthService` y el patrón de llamadas a eBay. *(Nota: NO es un único módulo `ebay-orders` monolítico — ver la guía de arquitectura para la separación.)*
- **Escritura directa** a la BD del CRM vía TypeORM (decisión confirmada). Las reglas del mapeo se implementan en los servicios de dominio `gts-crm-*`.
- **Bases de datos involucradas** (conexiones ya configuradas en `app.module.ts`):
  - **`default` (Central)** — *lectura*: `ecommerce_listings` y `ecommerce_listings_inventory` (resolver rep y qué inventory reservar).
  - **`gts_crm_db` (CRM)** — *escritura*: `so_info`, `inventory` (reserva), `shipment`; *lectura*: `users`, `locations`, `carriers`, `states`, `po_info`, y `gobig_ebay_linked_accounts` / `gobig_ebay_tokens`.

#### Flujo end-to-end

1. **Webhook** recibe la notificación `ORDER_CONFIRMATION` (endpoint único; ver Fase 2) y responde el challenge de validación de eBay.
2. **Identificar cuenta y token:** `data.user.userId` → `gobig_ebay_linked_accounts.ebay_user_id` → `id` → `gobig_ebay_tokens` por `ebay_account_id` → access token (refrescar si vencido). *Resolución a nivel sistema, sin `userId` humano* (ver nota de reuso en 3.3).
3. **Fulfillment:** `GET /sell/fulfillment/v1/order/{orderId}` con `Authorization: Bearer` → detalle con `lineItems[]`.
4. **Customer** (nivel orden, una sola vez): resolver/crear desde `shipTo` (Nota 01) → `customer_id` reutilizado en las N SOs.
5. **Por cada `lineItem`** (Opción B, una SO por producto):
   1. Idempotencia: si ya existe SO con `client_PO_Number = orderId` y `reference = orderLineItemId`, omitir.
   2. Resolver rep, reservar inventory, crear `so_info`, crear `shipment`.
6. **Status** por SO según lo reservado (Reserved / Partially Reserved / Open, Nota 03).

#### Resolución de datos que no vienen de eBay (con tablas reales)

- **`rep_id`:** `sku` → `ecommerce_listings.dashboard_user_id` (Central); fallback por iniciales del SKU (Nota 02). Con el id → `users` (CRM) para name/email/phone.
- **Reserva:** `ecommerce_listings` → `ecommerce_listings_inventory` (Central) → `inventory_id`s → reservar esos registros en `inventory` (CRM). Es **cross-DB**: se leen ids en Central y se actualizan filas en el CRM.
- **`states_id`:** `shipTo.stateOrProvince` → `states` por `abbr` + `master_id` (CRM); NULL si no hay match (campos de estado en texto sí se guardan).
- **Shipping from:** `warehouse_id` → `locations` (CRM); company = `locations.companies_id` → `companies.name` (Nota 04).
- **Carrier:** `shippingCarrierCode` → `CARRIER_MAP` (env) → `carriers` (CRM) (Nota 05).

#### Rutas alternas

- Listing no encontrado (método viejo): no se reserva → SO `Open`, `warehouse_id = 3`.
- Inventory insuficiente: `Partially Reserved`.
- Estado no encontrado: `states_id = NULL`.

#### Concurrencia y consistencia

- **Idempotencia:** llave `(client_PO_Number, reference)` = `(orderId, orderLineItemId)`, verificada antes de crear cada SO. Cubre los reenvíos/duplicados de eBay vistos en los logs.
- **Número `so`:** `último so + 1`, calculado al final dentro de una transacción con lock para evitar colisiones (especialmente con N SOs creadas en ráfaga de una misma orden).
- **Transacción:** las escrituras al CRM (`so_info` + `inventory` + `shipment` de una SO) van en una transacción de `gts_crm_db`. ⚠️ TypeORM no hace transacción distribuida con la BD Central; las lecturas al Central ocurren antes y fuera de esa transacción.

### 3.3 — Implementación

**Diseño: ✅ Completado · Implementación: ✅ Completada**

#### Componentes a construir (distribuidos en módulos — ver [`Arquitectura del codigo.md`](Arquitectura%20del%20codigo.md))

- **Controller** — endpoint del webhook (POST notificación) + manejo del challenge de validación (GET).
- **Servicios:**
  - *Account/token resolver a nivel sistema* — `ebay_user_id` → cuenta → token (con refresh), **sin** `userId`.
  - *Fulfillment client* — `getOrder(orderId, token)`.
  - *Orquestador* — flujo por orden y loop por `lineItem` (Opción B) dentro de transacción.
  - *Resolvers* — customer (Nota 01), rep (Nota 02), reserva (Nota 03), shipping-from/locations (Nota 04), carrier (Nota 05), states.
- **Entidades nuevas (`gts_crm_db`):** `SoInfo`, `Shipment` (la del CRM, distinta de la de buybacks), `Location`, `Carrier`, `State`, `PoInfo`; **extender `GtsCrmInventory`** con las columnas de reserva (`so`, `so_id`, `soline`, `status`, `datereserved`, `datereserved2`, `reservedby`, `reservedbyuser_id`, `unitprice`, etc.).
- **Columna `ebay_user_id`:** ya existe en la tabla `gobig_ebay_linked_accounts` y está poblada con los `userId` de las cuentas; solo falta mapearla en la entidad `GobigEbayLinkedAccount`.
- **DTOs:** payload de notificación y respuesta de Fulfillment.
- **Config (env):** `CARRIER_MAP`, `EBAY_ENVIRONMENT`, verification token del webhook.

#### Orden sugerido de construcción

1. Mapear la columna `ebay_user_id` (ya existe y poblada) en la entidad `GobigEbayLinkedAccount`.
2. Token resolver a nivel sistema (sin `userId`).
3. Cliente Fulfillment `getOrder`.
4. Webhook controller (challenge + recepción + idempotencia + encolado).
5. Entidades CRM y extensión de `inventory`.
6. Resolvers (customer, rep, reserva, carrier, states, locations).
7. Orquestador por `lineItem` con transacción y numeración de `so`.
8. Pruebas con los ejemplos reales ([`response_example.md`](response_example.md) — Secciones 1–3).

#### Reuso explícito del código existente

- **Refresh de token:** replicar la mecánica de `EbayOauthService.refreshToken` (librería `ebay-oauth-nodejs-client`, scopes con `sell.fulfillment` ya incluidos), pero en un resolver propio que entra por `ebay_account_id` **sin** validar `userId`. **No** usar `getValidToken` (depende de `userId` humano).
- **Llamadas HTTP a eBay:** mismo patrón de los módulos existentes (`@nestjs/axios` `HttpService`, `baseUrl` por `EBAY_ENVIRONMENT`, `getHeaders()` con `Bearer`).

> **Alcance:** el proceso termina al dejar creados/actualizados los registros en `so_info`, `shipment` e `inventory` (estos últimos solo en los pocos campos que se modifican al reservar). **No** incluye generación de etiquetas de envío, cotización de carriers ni integración con ShipEngine; eso queda fuera del alcance. Tampoco escribe en la BD Central: habrá un **proceso posterior** (que actualizará la Central) a implementar **después** de esta entrega; sus detalles se definirán en ese momento.

> **Decisiones cerradas:**
> 1. **Escritura directa a `gts_crm_db`** vía TypeORM — confirmado.
> 2. **Transacción solo en el CRM** (no distribuida): en este flujo a la Central solo se lee, así que todas las escrituras (`so_info` + `inventory` + `shipment`) caben en una transacción atómica del CRM. La escritura de vuelta en Central queda para el proceso posterior (ver Alcance).
> 3. **Catálogo `states`**: confirmado que ya están todos los estados de US y MX (`master_id = 1`). El fallback a `states_id = NULL` se mantiene solo como defensa.

---

## Fase 4 — Propagación al sistema de listings / stock (funcionalidad posterior)

**Diseño: ⏳ Pendiente · Implementación: ⏳ Pendiente**

> **Alcance:** esta fase es el **"proceso posterior"** anticipado en la Fase 3.3 (ver nota de *Alcance*). Es una funcionalidad **adicional a la principal ya entregada**: la creación de la SO (Fases 1–3) queda intacta; esto se ejecuta **después** de crearla para reflejar la venta en el sistema de listings/stock. Se documenta como pendiente; su diseño se cerrará en una sesión dedicada antes de programar.

### Objetivo

Después de crear una orden **por cualquier método** (webhook, reconciliación programada o manual), disparar la actualización de stock reutilizando el orquestador existente:

- **Endpoint existente:** `POST /api/update-stock-listing/lead` (`UpdateStockLeadService.updateStock`, en `crm-api-nestjs/src/ecommerce/orchestrators/update-stock/update-stock-lead.service.ts`).
- **Fases del orquestador:** 0) validaciones · 1) transacciones coordinadas (**DBCentral** + **CRM inventory** + **GTS Store** + **CRM eBay Items**) · 2) **push best-effort a eBay** · 3) finalización.

### Diferencia clave: NO empujar stock a eBay (evitar overselling)

Se debe ejecutar todo el orquestador **excepto la Fase 2 (push a eBay)**. Todo lo demás (DBCentral, CRM inventory, GTS Store, CRM eBay Items) sí procede.

**Motivo (overselling):** eBay descuenta las unidades en cuanto se vende, **incluso en `Awaiting Payment`** (las trata como reservadas). Nuestro sistema solo crea la SO cuando el pago se completa. Si además empujamos nuestra cantidad (calculada solo desde ventas pagadas) a eBay, **sobrescribimos el disponible correcto** que eBay ya había calculado y reabrimos unidades reservadas → riesgo de sobreventa. eBay ya lleva bien su disponible; no debemos pisarlo desde este flujo.

**Enfoque propuesto:** un flag con alcance (p. ej. `skipEbaySync?: boolean`, default `false`) que salte **solo la Fase 2**. El flujo de órdenes lo invoca en `true`; el resto de flujos (increment/restock, reactivación de listings 0→N, ediciones manuales) siguen empujando a eBay sin cambios. **No** eliminar la Fase 2 globalmente.

### Estado actual (punto de partida)

Hoy la creación de la SO **solo reserva `inventory` en el CRM** (Fase 3); **no** reduce stock en DBCentral, GTS Store, eBay Items ni eBay. Esta fase cierra ese hueco de forma automática, menos el push a eBay.

### Decisiones de diseño por cerrar (antes de programar)

1. **Armado del payload:** de los `inventory` reservados en CRM → resolver `listingId` de Central + `inventoryItems` (`inventoryId`, `iqId`, `poId`, `poLine`) que espera el endpoint.
2. **Reserva vs. decremento:** conciliar el "reservar" del flujo actual con el "decrementar + quitar relaciones" de update-stock para no doble-contar.
3. **Idempotencia:** webhook + reconciliación (y re-runs) no deben decrementar dos veces la misma línea; apoyarse en la llave `(orderId, orderLineItemId)`.
4. **Solo líneas reservadas:** las SO que quedan `Open` (sin inventario) no deben decrementar stock.
5. **Política de fallo:** la creación de la orden y el decremento son transacciones separadas; definir qué ocurre si una falla (reintento, marcado, alerta).
