# Proceso de automatización de órdenes eBay

Documentación del flujo completo para interceptar ventas de eBay y registrarlas automáticamente en el CRM (tablas `so_info`, `inventory`, `shipment`).

> **Nota:** este documento es el **plan/diseño**. Nada está implementado todavía; los estados se refieren al avance del diseño y, por separado, al de la implementación.

### Leyenda de estados

Cada fase indica dos dimensiones: estado del **diseño** y estado de la **implementación**.

- ✅ Diseño completado — definición cerrada, lista para implementar.
- 🔄 Diseño en curso — definición en proceso.
- ⏳ Diseño pendiente — aún sin definir.
- ⏳ Implementación pendiente — todavía no se construye/configura.

---

## Fase 1 — Configuración de notificaciones en eBay

**Diseño: ✅ Completado · Implementación: ⏳ Pendiente** (configurar suscripciones en eBay)

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

Configuración a mantener por cada una de las 4 cuentas:

| Campo | Uso |
|---|---|
| `userId` | **Llave** de identificación (inmutable) |
| `username` / `sellerId` | Referencia y validación contra Fulfillment |
| OAuth refresh/access token | Autenticar la llamada a Fulfillment API |

**Casos defensivos:**
- Si `data.user` no viene en la notificación (ocurrió en el payload de prueba inicial), hacer fallback: consultar Fulfillment e identificar por `sellerId`, o descartar el evento.

---

## Fase 2 — Endpoint para recibir notificaciones

**Diseño: ✅ Completado · Implementación: ⏳ Pendiente**

Se creará **un endpoint único** (webhook) que reciba los eventos HTTP POST que eBay envía para las 4 cuentas. El endpoint aceptará el payload de notificación y lo pondrá en cola para su procesamiento.

- El payload contiene: `data.user` (`userId`, `username`) y `data.order` (`orderId`, `orderLineItems[]` con `listingId` y `quantity`).
- `data.user.userId` identifica la cuenta vendedora y, con ello, el OAuth token a usar (ver Fase 1 — *Identificación de la cuenta vendedora*).
- Con el `orderId` se consulta la Fulfillment API para obtener el detalle completo de la orden.
- Referencia del payload completo de fulfillment: [`response_example.md`](response_example.md) — Sección 2.

**Idempotencia (requisito):** eBay reenvía notificaciones (reintentos con `publishAttemptCount` > 1, y se observaron duplicados con el mismo `notificationId` en los logs). El endpoint/procesamiento **debe ser idempotente**: deduplicar por `orderId` (y/o `notificationId`) para no crear SOs duplicadas ante notificaciones repetidas de la misma orden.

---

## Fase 3 — Procesamiento de la orden

**Diseño: 🔄 En curso · Implementación: ⏳ Pendiente**

Esta fase se divide en las siguientes sub-fases:

### 3.1 — Revisión y confirmación del mapeo de datos

**Diseño: 🔄 En curso · Implementación: ⏳ Pendiente**

Definir con exactitud qué campo de la respuesta de eBay va a cada campo de las tablas del CRM, y tomar las decisiones sobre valores por defecto, lógica de fallback y campos pendientes de confirmar.

- Incluir el mapeo de `sellerId` → cuenta del CRM, y validar que coincide con la cuenta identificada por `data.user.userId` en la notificación (ver Fase 1).
- Referencia: [`Mapeo de datos.md`](Mapeo%20de%20datos.md)

### 3.2 — Diseño del procedimiento

**Diseño: ⏳ Pendiente · Implementación: ⏳ Pendiente**

Una vez confirmado el mapeo, diseñar el flujo de operaciones:

- Qué tablas consultar y en qué orden.
- Cómo obtener la información que no viene directamente de eBay (e.g. `rep_id` a partir del SKU, `states_id` a partir del state, datos del warehouse para shipping from).
- Rutas alternas cuando no se encuentra cierta información (e.g. listing publicado con método viejo, teléfono no disponible, inventory insuficiente).
- Definir si se genera la SO con status `Open`, `Reserved` o `Partially Reserved` dependiendo de la disponibilidad de inventory.

### 3.3 — Implementación

**Diseño: ⏳ Pendiente · Implementación: ⏳ Pendiente**

Desarrollo del servicio que, al recibir el `orderId`:

1. Consulta la Fulfillment API de eBay para obtener el detalle de la orden.
2. Crea el registro en `so_info`.
3. Busca y reserva los `inventory` correspondientes al SKU del listing.
4. Crea el registro en `shipment`.

> **Alcance:** el proceso termina al dejar creados/actualizados los registros en `so_info`, `shipment` e `inventory` (estos últimos solo en los pocos campos que se modifican al reservar). **No** incluye generación de etiquetas de envío, cotización de carriers ni integración con ShipEngine; eso queda fuera del alcance.
