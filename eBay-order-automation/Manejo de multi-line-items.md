# Manejo de órdenes multi-line-item — opciones a decidir

Documento sobre cómo registrar en el CRM una orden de eBay que contiene **más de un producto distinto** (varios line items).

**Estado: ✅ Decidido.**

## Decisión tomada

El equipo eligió la **Opción B — Dividir: 1 SO por producto**, con la identidad de line item por **Opción A**:
- `client_PO_Number = orderId` (se repite entre las SOs de una misma compra).
- `orderLineItemId` guardado en el campo `reference`.
- **Idempotencia** con llave **`orderId + orderLineItemId`**.
- El **customer** se crea una sola vez por orden y se referencia en las N SOs.

El resto del documento se conserva como registro del análisis comparativo que llevó a la decisión.

---

## Contexto

Una orden de eBay puede traer varios `lineItems[]` (productos distintos). Se confirmó en pruebas un comportamiento **inconsistente** de eBay:

- A veces separa la compra de 2 productos en **2 órdenes** distintas (1 line item cada una).
- A veces la manda como **1 orden con 2 line items**.

Ejemplos reales en [`response_example.md`](response_example.md) — Sección 3 (órdenes `19-14819-32278` y `25-14809-32185`, cada una con 2 line items).

El modelo del CRM permite ambos enfoques: una `so_info` (cabecera) puede tener varios `soline` (varios registros de `inventory`). La pregunta es **cómo mapear una orden multi-line**: una sola SO con varias líneas, o una SO por producto.

Regla base común a ambas opciones: **el procesamiento se dispara por `orderId`**, iterando sus `lineItems[]`.

---

## Opción A — Combinar: 1 SO con N líneas

Una orden de eBay con N line items → **una `so_info`** con N `soline` (N registros de `inventory` reservados).

**Ventajas**
- Mapeo 1:1 entre orden de eBay y SO.
- El pago de eBay (`paymentReferenceId`, `totalDueSeller`) corresponde a una sola SO → conciliación directa.
- Un solo `shipment` (un destino, un envío).
- Idempotencia simple: deduplicar por `orderId`.

**Problemas**
- **`rep_id` (cabecera singular):** `so_info` tiene un solo `rep_id`, pero cada line item puede tener un rep distinto (vía `ecommerce_listings.dashboard_user_id`). Hay que elegir uno (ej. el del primer line item). Cascadea a `shipfromcontactuser_id`, `shipfromcontact/email/phone` e `inventory.reservedbyuser_id`.
- **`warehouse_id` / multi-origen (problema estructural):** `so_info.warehouse_id` y el origen del `shipment` son únicos. Si los items están en warehouses distintos, **un solo shipment no puede tener dos orígenes**. Es el bloqueo principal de esta opción.
- **`status`:** hay que generalizar la regla a todas las líneas (ver más abajo).
- **Comportamiento dependiente de eBay:** si eBay separa la orden, se generan 2 SOs; si la combina, 1 SO. Estructura inconsistente para el mismo escenario de negocio.

---

## Opción B — Dividir: 1 SO por producto

Una orden de eBay con N line items → **N `so_info`**, cada una con un solo line item.

**Ventajas**
- **`rep_id` resuelto:** cada SO tiene un producto = un listing = un rep. Sin conflicto.
- **`warehouse_id` / multi-origen resuelto:** cada SO/shipment tiene un producto = un warehouse = un origen correcto. Modela mejor la realidad si los productos están en bodegas distintas.
- **Reutiliza el diseño actual tal cual:** todo el mapeo (que ya asume `lineItems[0]`) funciona por-SO sin cambios.
- **Comportamiento uniforme:** sin importar si eBay separa o combina, el resultado en el CRM es el mismo (2 productos = 2 SOs, siempre). Normaliza el capricho de eBay.

**Problemas**
- **Idempotencia (crítico):** si un `orderId` genera N SOs, deduplicar por `orderId` solo rompería. La llave debe ser **`orderId + orderLineItemId`**. La notificación ya trae `orderLineItemId` por línea, así que la llave es estable, pero hay que ajustarlo en el endpoint (Fase 2).
- **Customer:** Nota 01 busca/crea el cliente por `shipTo`. Hay que crearlo **una vez** por orden y referenciar su `id` en las N SOs (evitar duplicado por carrera).
- **`client_PO_Number` repetido:** las N SOs comparten el mismo `orderId`. Aceptable, o anexar índice de línea si se requiere unicidad.
- **Pago de eBay 1 → N SOs:** eBay cobra/paga una vez por orden; contabilidad lo verá fragmentado entre N SOs (atenuado porque usamos precios internos, no los de eBay).
- **Más shipments/paquetes:** N envíos al mismo destino (si están en la misma bodega, fuerza paquetes separados que quizás irían juntos).
- **Consumo de números `so`:** N SOs consumen N números consecutivos; el "último `so` + 1" debe ser seguro ante inserciones rápidas.

---

## Tabla de comparación

| | Opción A — Combinar (1 SO, N líneas) | Opción B — Dividir (1 SO por producto) |
|---|---|---|
| `rep_id` | ⚠️ Elegir uno | ✅ Resuelto |
| Multi-warehouse / origen del shipment | ❌ Origen único incorrecto | ✅ Resuelto |
| Reusa diseño actual | ⚠️ Generalizar a sumas | ✅ Sí |
| Comportamiento vs eBay (separa/combina) | ❌ Depende de eBay | ✅ Uniforme |
| Idempotencia | ✅ Por `orderId` | ⚠️ Llave `orderId + orderLineItemId` |
| Customer | ✅ Natural | ⚠️ Crear 1, referenciar N |
| Pago eBay ↔ SO | ✅ 1→1 | ⚠️ 1→N |
| `client_PO_Number` | ✅ Único por SO | ⚠️ Repetido entre SOs |
| # de shipments | 1 | N |
| Cálculos financieros y márgenes | ✅ Suma/iteración | ✅ Por SO (sin cambio) |

---

## Cálculos que NO son problema en ninguna opción

Los campos financieros ya están definidos como suma sobre los items reservados, así que generalizan solos (en A se suman en una SO; en B cada SO calcula los suyos):
`extendedcost`, `estimated_cost`, `gross_margin`, `margin_percentage`, `profit`, `subtotal`, `total`. La fórmula de margen consulta `po_info` por cada item según su `po_id`, así que items de POs distintas funcionan igual.

Campos a nivel orden (no cambian en ningún caso): customer/`shipTo`, carrier/servicio, `saledate`, `currency`, fechas.

---

## Regla de `status` (aplica a la opción elegida)

- **Reserved:** se reservaron todas las unidades.
- **Partially Reserved:** se reservó al menos una unidad, pero no todas (en opción A incluye "línea 1 completa, línea 2 sin encontrar").
- **Open:** no se reservó ninguna.

---

## Recomendación

Inclinación hacia la **Opción B (dividir)**: elimina los dos problemas estructurales duros (`rep_id` y multi-warehouse), reutiliza el diseño ya cerrado y normaliza el comportamiento sin importar cómo agrupe eBay. Los problemas que introduce son más numerosos pero acotados; el único innegociable es la **idempotencia con llave `orderId + orderLineItemId`** (ya se observaron notificaciones duplicadas en los logs).

**Pregunta que decide el empate:** ¿contabilidad/operación necesita ver la compra de eBay como una sola unidad?
- **Sí** → Opción A (combinar).
- **No** (cada producto se trata como venta independiente, común en reventa de hardware con bodegas distintas) → Opción B (dividir).
