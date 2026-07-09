# Campos Sales Orders y Shipments - verificación contra tabla


#### Notas:

Nota 01: Como manejar el customer
La respuesta de eBay contiene DOS bloques de direccion distintos. Es importante entender cual usar en cada contexto:
- `buyer.buyerRegistrationAddress` → direccion registrada del comprador en eBay (puede ser diferente a la de entrega).
- `fulfillmentStartInstructions[0].shippingStep.shipTo` → direccion real de entrega del pedido. **Este es el bloque que se usa siempre** para buscar y crear el usuario.

Para la asociacion del cliente se requiere un registro en la tabla `users`:

- Caso 1: Buscar si el usuario ya existe en la tabla `users`
  Ejecutar la siguiente consulta usando los datos del bloque `shipTo`:

  ```sql
  SELECT id FROM users
  WHERE CONCAT(name, ' ', surname) = '[shipTo.fullName]'
  AND address = '[shipTo.contactAddress.addressLine1]'
  AND companies_id = 1293
  AND activo = '1'
  LIMIT 1;
  ```

  - `[shipTo.fullName]` → `fulfillmentStartInstructions[0].shippingStep.shipTo.fullName` (ej. `"Cody Hood"`)
  - `[shipTo.contactAddress.addressLine1]` → `fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1` (ej. `"2200 S Old Missouri Rd"`)

  Si se encuentra un registro usar su `id`. Si hay más de uno, usar el primero.

- Caso 2: Si el Caso 1 no retorna ningún registro, crear un usuario nuevo en la tabla `users`.

  **Notas sobre tipos de campo y constraints (DDL):**
  - `company`, `address2`, `zip_code` y `forgot_code` son `NOT NULL` sin valor por defecto → deben enviarse siempre aunque sea con `''`.
  - `zip_code` es `varchar(10)` → el valor de eBay `postalCode` puede venir como `"72764-8719"` (10 chars, cabe exacto). Si el valor excediera 10 caracteres, truncar.
  - `address2` es `NOT NULL` → si `addressLine2` no viene en eBay, usar `''`.
  - Los campos con `DEFAULT` en DDL (como `first_login`, `activo`, `send_email`) pueden omitirse; se listan aquí con su valor explícito por claridad.

  **Fuente de datos — splitear `fullName`:**
  Tomar `fulfillmentStartInstructions[0].shippingStep.shipTo.fullName` y dividir en el primer espacio:
  - `name` → todo antes del primer espacio (ej. `"Cody"`)
  - `surname` → todo después del primer espacio (ej. `"Hood"`)

  **Campos a insertar:**

  | Campo | Valor | Fuente |
  |-------|-------|--------|
  | `role` | `'customer'` | fijo |
  | `name` | primera palabra de `fullName` | `shipTo.fullName` |
  | `surname` | resto de `fullName` (desde segundo token) | `shipTo.fullName` |
  | `email` | email del shipTo | `shipTo.email` |
  | `password` | `'f9dd628540cd4a5689406f258cc12fb1b9b80cb8401513b70ce0d3d731ee7474'` | hash fijo para clientes externos |
  | `company` | `'EBAY'` ⚠️ NOT NULL | fijo |
  | `birth_date` | `'1779-01-01'` | fijo (placeholder) |
  | `recommended_by` | `NULL` | — |
  | `gender` | `1` | fijo |
  | `estado_civil` | `''` | fijo |
  | `ocupation` | `''` | fijo |
  | `born_city` | `''` | fijo |
  | `nationality` | `''` | fijo |
  | `address` | `addressLine1` | `shipTo.contactAddress.addressLine1` |
  | `address2` | `addressLine2` o `''` si no viene ⚠️ NOT NULL | `shipTo.contactAddress.addressLine2` |
  | `colonia` | `stateOrProvince` (ej. `"AR"`) | `shipTo.contactAddress.stateOrProvince` |
  | `city` | `city` | `shipTo.contactAddress.city` |
  | `zip_code` | `postalCode` truncado a 10 chars ⚠️ NOT NULL varchar(10) | `shipTo.contactAddress.postalCode` |
  | `country` | `countryCode` (ej. `"US"`) | `shipTo.contactAddress.countryCode` |
  | `phone` | `phoneNumber` | `shipTo.primaryPhone.phoneNumber` |
  | `mobile_phone` | `NULL` | — |
  | `contacto_nombre_emergencia` | `''` | fijo |
  | `contacto_telefono_emergencia` | `''` | fijo |
  | `motivo_consulta` | `''` | fijo |
  | `grupo_sanguineo` | `''` | fijo |
  | `principio_evolucion_padecimiento` | `''` | fijo |
  | `antecedentes_psiquiatricos` | `''` | fijo |
  | `blacklist` | `''` | fijo |
  | `comision_ventas` | `0.00` | fijo |
  | `created_at` | datetime actual | timestamp de inserción |
  | `user_tag` | `NULL` | — |
  | `first_login` | `1` | fijo (DDL default: `0`) |
  | `activo` | `'1'` | fijo (DDL default: `'1'`) |
  | `managed_by` | id del rep que creó el listing | ver Nota 02 |
  | `managed_by_string` | `"name + surname"` del rep | ver Nota 02 |
  | `email_frequency` | `''` | fijo |
  | `send_email` | `0` | fijo (DDL default: `0`) |
  | `companies_id` | `1293` | fijo |
  | `forgot_code` | `''` ⚠️ NOT NULL | fijo |
  | `forgot_code_expires_at` | `NULL` | — |
  | `enable_as_driver` | `'0'` | fijo (DDL default: `'0'`) |
  | `enable_as_accounting` | `NULL` | fijo (DDL: int default 0, nullable) |
  | `enable_as_bill_to` | `NULL` | fijo (DDL: int default 0, nullable) |
  | `last_activity` | datetime actual | timestamp de inserción |
  | `customer_type` | `'Wholesaler'` | fijo |
  | `customer_pricing` | `0` | fijo |
  | `customer_response_time` | `0` | fijo |
  | `customer_payment_on_time` | `0` | fijo |
  | `customer_easy_to_work_with` | `0` | fijo |
  | `customer_average` | `NULL` | — |
  | `holiday_hours` | `0.00` | fijo |
  | `horas_pagadas_usadas` | `NULL` | — |
  | `horas_nopagadas_usadas` | `NULL` | — |
  | `new_notifications` | `0` | fijo (DDL default: `0`) |
  | `conditions_id` | `9` | fijo (USED) |
  | `terms_id` | `19` | fijo |
  | `warehouse_default_id` | `NULL` | — |
  | `currencies_id` | `1` | fijo |
  | `location_default_id` | `NULL` | — |
  | `master_id` | `1` | fijo |
  | `clientuser_id` | `NULL` | — |
  | `join_to_work` | `'1779-01-01'` | fijo (placeholder) |
  | `uneda` | `0` | fijo (DDL default: `0`) |
  | `location_id` | `NULL` | — |
  | `internal_location_id` | `NULL` | — |
  | `logo_redirect` | `NULL` | — |
  | `type_location_selected` | `NULL` | — |
  | `depto_to_count` | `NULL` | DDL: varchar(100) DEFAULT NULL |
  | `permissions` | `NULL` | DDL: varchar(855) DEFAULT NULL |
  | `welcome_sent` | `NULL` | DDL: int DEFAULT 1, nullable |
  | `iq_initials` | `NULL` | DDL: varchar(10) DEFAULT NULL |
  | `is_phone_auth` | `NULL` | DDL: varchar(10) DEFAULT '0', nullable |
  | `phone_auth` | `NULL` | — |
  | `code_phone_auth` | `NULL` | — |
  | `page_limit` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `sidebar_favorites` | `NULL` | — |
  | `enabled_dev` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `label_barcode` | `0` | fijo (DDL default: `0`) |
  | `barcode_type` | `NULL` | DDL: varchar(20) DEFAULT NULL |
  | `bug_ticket_notify` | `0` | fijo (DDL default: `0`) |
  | `enable_inventory` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `permissions_livereporting` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `enabled_visitors` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `status_column` | `NULL` | DDL: int DEFAULT 0, nullable |
  | `purchase_order_settings` | `NULL` | — |
  | `sales_order_settings` | `NULL` | — |
  | `packing_list_settings` | `NULL` | — |
  | `invoice_settings` | `NULL` | — |
  | `commercial_invoice_settings` | `NULL` | — |
  | `signature` | `NULL` | — |
---

Nota 02: Como manejar el rep
Para poder asignar un rep se podra hacer en dos escenerios:
Caso 1: Tomar el valos del sku [data.lineItems[0].sku] y buscarlo en la tabla ecommerce_listings de la base de datos central, si encontramos ese registro tomamos el valor de dashboard_user_id ese sera nuestro valor de rep_id en la tabla so_info.
Caso 2: Si no encontramos el sku del paso 1 entonces vamos a consultar una tabla hardcoded en la que vamos a mapear las inciales y el id de 3 usuarios, quedaria algo asi:

const users = [
  {
    id: 100,
    initials: 'AA',
    name: 'Allan',
    surname: 'Arciga',
  },
  {
    id: 101,
    initials: 'WB',
    name: 'William',
    surname: 'Birch',
  },
  {
    id: 8636,
    initials: 'UO',
    name: 'Ushie',
    surname: 'Ogar',
  },
];
La forma en que funcionara es que tomaremos el SKU de [data.lineItems[0].sku] y vamos a usar los primeros dos caracteres que usualmente son las initials del usuario y las vamos a bscar en ese array map y sabremos que usuario es el rep_id. En caso de que no sea ninguno de esos 3 el rep_id por defecto sera WB, es decir William Birch.

En cualquiera de los dos casos vamos a saber el id del usuario rep, con eso podemos buscar el registro en la tabla users mediante la columna id y sabremos mas datos como el name, surname, email, role, phone, etc. Tomalo en cuanta para los campos donde requerimos de mas informacion del rep.

---

Nota 03: Como manejar la reserva de productos
El proceso de reserva de productos consiste en asociar los productos/registros de la tabla inventory con el registro que se hara en so_info. La forma en que podemos saber cuales registros o item se van a asociar puede ser de varias formas.

Caso 1: Al buscar el [data.lineItems[0].sku] en ecommerce_listings SI se encontro podemos saber cuales son esos items. 
- La tabla ecommerce_listings esta relacionada con ecommerce_listings_inventory. Tomaremos en valor del id de ecommerce_listings y buscaremos todos los registros de ecommerce_listings_inventory mediante su campo listing_id. Tomaremos o buscaremos la cantidad que diga en [data.lineItems[0].quantity]. Por ejemplo puede que el listing tenga 10 productos pero solo compraron 5 entonces buscaremos los primeros 5. Este proceso esta ligado a que valor se le asignara al campo status del so_info, en caso de que se encuentren todos los items es decir que se encuentren/reserven la cantidad que dice [data.lineItems[0].quantity] a status se le asignara el valor "Reserved". Si solo se encuentran/reservan algunos items por ejemplo de los 5 solo se encuentran de 1 a 4 entonces se asignara a status el valor "Partially Reserved". Si no se encuentra/reserva ningun item entonces el status se le asignara el valor "Open".
- Otro campo que se tiene que definir con el primer producto que se reserve es el valor del warehouse_id de la so_info, a este campo se le pone el valor que el primer producto tenga en su campo warehouse_id.
Caso 2: Al buscar el [data.lineItems[0].sku] en ecommerce_listings NO se encontro entonces no haremos la reserva y el status quedara solo como "Open". Aqui como no hay productos se tiene que asignar la warehouse_id de la so_info con el valor 3 por defecto.  

**SO en status "Reserved" o "Partially Reserved" — valores financieros se calculan con los items reservados:**
Cuando se reserva al menos un item, los campos financieros se calculan usando los registros de `inventory` que fueron efectivamente reservados.

> ⚠️ **Precio de venta (actualización 2026-07-03):** antes de estos cálculos, a cada item reservado se le asigna `unitprice = lineItemCost / quantity` del line item de eBay (precio realmente vendido; el `lineItemCost` es el total de la línea). Se hace **siempre** (Best Offer puede cambiar el precio). Ver campo `unitprice` en la sección `inventory`.

- `extendedcost` → suma de `unitprice` de los items reservados
- `estimated_cost` → suma de `purchasecost` de los items reservados
- `gross_margin`, `margin_percentage` y `profit` → calculados con la fórmula de margen sobre los items reservados (ver descripción de esos campos en `so_info`)
- `subtotal` → `extendedcost + extracost + freight + serviches_charge + misc_charge` (sin tax)
- `total` → `extendedcost + extracost + freight + serviches_charge + misc_charge + tax`

**SO en status "Open" (sin reserva) — valores financieros en 0:**
Cuando no se reserva ningún item, todos los campos financieros que dependen del inventory reservado quedan en `0`: `extendedcost`, `estimated_cost`, `gross_margin`, `margin_percentage`, `profit`, `subtotal` y `total`. La reserva se hará de forma **manual** más adelante.

---
Nota 04: Como saber la ubicación de origen
A lo largo de todo el proceso en diferentes tablas se requiere saber la direccion de donde salen las cosas, o de donde esta la compañia que envia el paquete o para saber su contacto. En esos casos se va a tomar el warehouse_id y se buscara mediante el id el registro en la tabla locations, el registro que se encuentre tiene datos como: name, address, address2, country, state, city, phone, sip_code, etc, todos esos campos se van a mapear a algunos campos especificos que ya te documentare. Tambien se puede revisar la descripcion de la tabla locations para saber todos los campos que tiene.

**Nombre de la company (shipping from):** el nombre que va en `shipfromcompany` / `from_company` NO es `locations.name`. Se obtiene de la company asociada al location: el registro de `locations` tiene un campo `companies_id` que apunta a la tabla `companies`; se toma el campo `name` de ese registro de `companies`. Ruta: `locations.companies_id` → `companies.id` → `companies.name`.

---
En caso de que sea un listing que se publico con nuestro metodo vamos a buscar el sku y encontraremos los product inventory, vamos a revisar cuales fueron los producto inventory que entraron primero al listing y esos vamos a reservar.
En caso de no encontrarlos es porque se enlistaron con el metodo viejo y no vamos a poder reservarlos, tendra que quedarse la so como open.

---
Nota 05: Como buscar y asignar el carrier
El proceso para identificar y asignar el carrier se basa en leer el carrier que indica eBay en su respuesta y mapearlo a un registro de la tabla `carriers` usando variables de entorno. Esto permite agregar nuevos carriers sin modificar el código.

**Paso 1 — Leer el carrier desde eBay**
Tomar el valor de [fulfillmentStartInstructions[0].shippingStep.shippingCarrierCode] de la respuesta de eBay.
Ejemplo: `"UPS"`, `"FEDEX"`.

**Paso 2 — Resolver el carrier_id mediante variable de entorno**
Se define una variable de entorno tipo mapa que relaciona el nombre del carrier (en el formato que usa eBay) con el id del registro en la tabla `carriers`:
```
CARRIER_MAP={"UPS": 53, "FEDEX": 51}
```
Con el valor leído de eBay se busca en este mapa para obtener el `carrier_id`.
Si el carrier que viene de eBay no existe en el mapa, usar el carrier por defecto: `UPS` (id=53).

**Paso 3 — Consultar la tabla `carriers`**
Con el `carrier_id` resuelto, buscar el registro completo en la tabla `carriers` mediante su `id`. De ese registro se toman:
- `name` → carrier_string
- `external_carrier_code` → carrier_code
- `external_account_number` → bill_account_number
- `payment_type` → payment_type
- `service_type` → array JSON del que se obtiene service_code y service_string

**Paso 4 — Resolver el service_code**
Tomar el valor de [fulfillmentStartInstructions[0].shippingStep.shippingServiceCode] de la respuesta de eBay.
Ejemplo eBay: `"UPSGround"`, `"FedExGround"`.

Para encontrar la coincidencia en el array `service_type` del carrier, aplicar esta normalización:
- Convertir el valor de eBay a minúsculas sin separadores → `"upground"` → `"upsground"`
- Para cada objeto en el array `service_type`, tomar su `service_code`, eliminar guiones bajos y comparar → `"ups_ground"` → `"upsground"`
- El que coincida es el service a usar.

Si no se encuentra coincidencia, usar `ups_ground` (UPS) o `fedex_ground` (FedEx) como fallback según el carrier.


---
Nota 06: Una SO por line item (estrategia Opción B)
Una orden de eBay **puede** traer varios `lineItems[]` (productos distintos). Se confirmó en pruebas que eBay es inconsistente: a veces separa la compra en varias órdenes (1 line item cada una) y a veces la combina en una sola orden con varios line items.

**Decisión del equipo:** generar **una `so_info` por cada line item** (una SO por producto). Así el resultado en el CRM es el mismo sin importar cómo agrupe eBay. Ver análisis completo en [`Manejo de multi-line-items.md`](Manejo%20de%20multi-line-items.md).

Implicaciones para este mapeo:
- Se itera `data.lineItems[]`; **cada `lineItem` produce una SO independiente** con su propio listing, rep, reserva y shipment. Las referencias a `data.lineItems[0]` en este documento aplican, por SO, al line item que se está procesando.
- La `quantity` de un line item puede ser mayor a 1 (ej. 3 unidades del mismo producto); eso se maneja en la reserva (Nota 03) desglosando una `soline` por unidad dentro de esa misma SO.
- El **customer** se resuelve/crea **una sola vez** por orden (desde `shipTo`, nivel orden) y se reutiliza su `id` en todas las SOs de la orden.
- **Idempotencia:** la llave es `orderId + orderLineItemId` (ver `proceso.md` — Fase 2). Cada SO guarda `orderId` en `client_PO_Number` y `orderLineItemId` en `reference`.

---
Nota 07: Cuentas de eBay y entidad en el CRM
Las 4 cuentas de vendedor de eBay corresponden a **la misma entidad en el CRM**. Por lo tanto, los valores de entidad son fijos e iguales para cualquier cuenta que origine la venta:

- `master_id = 1`
- `companies_id = 1293` (para el customer en `users`)
- `shipfromcompany` / `from_company` / `to_company` → ver decisiones de cada campo (dinámico vía `companies.name`, ver Nota 04).

La identificación de la cuenta (vía `data.user.userId` de la notificación, endpoint único — ver `proceso.md` — Fase 1) se usa para autenticar la llamada a Fulfillment, **no** para cambiar la entidad ni la company de la SO.

---
---

## Campos en `so_info`

### `id`
- **Descripción:** Automático, incrementable.
- **Notas:** 
- **Decision:** Campo `id` se llena de forma automatica ✅ ✅

### `so`
- **Descripción:** Número de SO. Tienen que poner un número más uno al más reciente.
- **Notas:** 
- **Decision:** Campo `so` se llna con el resultado de consultar el numero de `so` del registro de so_info mas reciente y se le suma 1 (hacerlo en el ultimo momento para no tardar demasiado y minimizar el riesgo de repetir) ✅ ✅

### `customer_id`
- **Descripción:** Id de cliente, referente a su registro en la tabla `users`.
- **Notas:** 
- **Decision:** Campo customer_id se llena de acuerdo con "Nota 01: Como manejar el customer" ✅ ✅

### `clientuser_id`
- **Descripción:** Id de cliente, referente a su registro en la tabla `users` (el mismo que `customer_id`).
- **Notas:** 
- **Decision:** Campo clientuser_id se llena con el valor que se asigno a customer_id ✅ ✅

### `terms_id`
- **Descripción:** Id de terms, referente a su registro en la tabla `terms`.
- **Notas:** Siempre va Paypal (id 20)? Yes
- **Decision:** Campo terms_id se llena con el valor 20 ✅ ✅

### `rep_id`
- **Descripción:** Id del vendedor (rep), referente a su registro en la tabla `users`.
- **Notas:** 
- **Decision:** Campo rep_id se llena con el valor de "Nota 02: Como manejar el rep" ✅ ✅

### `contactcontactuser_id`
- **Descripción:** Id de contacto de compra (puede ser el mismo de `customer_id`), referente a su registro en la tabla `users`.
- **Notas:** Le ponemos el mismo de customer_id? YES
- **Decision:** Campo contactcontactuser_id se llena con el valor que se asigno a customer_id ✅ ✅

### `conditions_id`
- **Descripción:** Id de la condición de venta, referente a su registro en la tabla `conditions`.
- **Notas:** Ponemos siempre USED(id:9)? YES
- **Decision:** Campos conditions_id se llena con el valor 9 ✅✅

### `shipfromcontactuser_id`
- **Descripción:** Id del usuario de contacto de la sección Shipping From, referente a su registro en la tabla `users`.
- **Notas:** la persona que hizo la so, es decir el rep_id
- **Decision:** Campo shipfromcontactuser_id se llena con el valor que se asigno a rep_id ✅ ✅

### `shiptoclientuser_id`
- **Descripción:** Id del usuario de contacto de la sección Shipping To, referente a su registro en la tabla `users`.
- **Notas:** Le ponemos el mismo de customer_id?
- **Decision:** Campo shiptoclientuser_id se llena con el valor que se asigno a customer_id ✅ ✅

### `status`
- **Descripción:** Status de la Sale Order.
  Open
  Reserved
  Partially Reserved
  Invoiced
  Voided
- **Notas:**
  Caso 1: Reserved si reservamos todos los items
  Caso 2: Partially Reserved si solo unos items se reservan
  Caso 3: Open si no logramos reservarlos porque no identificamos que items se tienen que reservar
- **Decision:**  Campo status se llena de acuerdo a lo que se dice en la "Nota 03" ✅ ✅

### `shipstatus`
- **Descripción:** Status del Shipment
  Default para un SO nuevo: `Open`
  Cuando ya tiene un shipment agendado: `Scheduled`.
- **Notas:** Scheduled porque vamos a crear el shipment
- **Decision:** Campo shipstatus se llena con el valor "Scheduled"  ✅ ✅

### `states_id`
- **Descripción:** Estado para la aplicación de taxes. Va el id del state relacionado con el `state` del `shipment to`.
- **Notas:** Hacer match entre el state que de ebay con el de esta tabla para establecer el id
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince] ✅ ✅
- **Decision:**  Campo states_id se llena de la siguiente forma: el valor que venga en [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince] se toma y se busca en la tabla `states` del CRM por el campo `abbr` y `master_id = 1`. ✅ ✅

  **Fallback cuando no se encuentra el state:** si el `abbr` no existe en la tabla `states`, dejar `states_id = NULL` (el campo es nullable). No afecta nada aguas abajo porque `tax = 0` y `cleartax = 1` (no se aplican taxes), y `states_id` solo sirve para la lógica de impuestos.

  **Importante — los campos de estado en texto sí se registran siempre:** `contactstate`, `shiptostate` (so_info) y `to_state` (shipment) se llenan directo con `shipTo.contactAddress.stateOrProvince` de eBay, **independientemente** de si hubo match en `states`. Son la dirección de envío real y nunca se dejan vacíos.

  Contexto: eBay maneja los envíos internacionales; nosotros solo registramos la dirección de envío dentro de USA (locaciones/forwarders de eBay), por lo que en la práctica el `shipTo` siempre debería traer un estado US válido. El fallback a `NULL` es manejo defensivo de un caso borde.

### `tax`
- **Descripción:** Valor del tax.
- **Notas:** Tomamos el valor del tax de acuerdo al states_id que identificamos
- **Decision:** Campo tax se llena con "0" ✅ ✅  

### `subtotal`
- **Descripción:** Valor de total antes de taxes.
- **Notas:** Se calcula con la fórmula interna del CRM (misma que `total` pero sin `tax`). ⚠️ **Aclaración (2026-07-03):** el insumo `extendedcost` = suma de `unitprice` de los items reservados, y ese `unitprice` **sí proviene del precio vendido en eBay** (`lineItemCost / quantity`), asignado al item antes de calcular (ver campo `unitprice` en la sección `inventory`). Es decir: el precio de venta viene de eBay, pero se escribe primero en `inventory.unitprice` y la SO se calcula con la fórmula del CRM sobre ese valor.
- **Decision:** Campo subtotal se calcula así:

```php
$subtotal = floatval($extendCost)   // suma de unitprice de los inventories reservados (extendedcost)
+ floatval($extracost)
+ floatval($freight)
+ floatval($servichesCharge)
+ floatval($misCcharge);
// (sin tax)
```

No se puede si no hay items de inventory reservados; hacerlo solo con los items reservados que se encuentren. Si no hay ningún item reservado, poner 0. ✅ ✅

### `serviches_charge`
- **Descripción:** Valor de services a aumentar a la orden, campo Services.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** Campo serviches_charge se le asigna "0.00" ✅ ✅

### `misc_charge`
- **Descripción:** Valor de Misc. Charge a aumentar a la orden, campo Misc. Charge.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** Campo misc_charge se le asigna "0.00" ✅ ✅

### `extracost`
- **Descripción:** Valor de servicios de instalación a aumentar a la orden, campo Installation Cost.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** Campo extracost se le asigna "0.00" ✅ ✅

### `extendedcost`
- **Descripción:** Suma del valor `unitprice` de todos los solines (inventarios).
- **Notas:** No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0. ⚠️ El `unitprice` de cada item se asigna con el precio vendido en eBay (`lineItemCost / quantity`) **antes** de esta suma (ver campo `unitprice` en la sección `inventory`).
- **Decision:** Campo extendedcost se le asigna la suma del campo unitprice de cada uno de los items reservados de la tabla inventory ✅ ✅

### `estimated_cost`
- **Descripción:** Sumar el campo `purchasecost` de todos los solines (inventories) y asignar el valor final a `estimated_cost`.
- **Notas:** No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0.
- **Decision:** Campo estimated_cost se le asigna la suma del campo `purchasecost` de cada uno de los items reservados de la tabla inventory ✅ ✅

### `cleartax`
- **Descripción:** Ajustar el valor a `1` (indicamos al sistema que NO se aplican taxes en esta orden).
- **Notas:** 0 si los taxes estan aplicados, 1 si hay alguna excepcion y no se tienen que aplicar taxes. En este flujo siempre va 1 (tax = 0).
- **Decision:**  Campo cleartax se llena con "1" ✅ ✅  

### `warehouse_id`
- **Descripción:** Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.
- **Notas:** Caso 1: items de una sola locacion poner esa locacion
  Caso 2: items de varias locaciones poner el id de la primera locacion
- **Decision:** Campo warehouse_id se llena de acuerdo a como se menciona en la "Nota 03" ✅ ✅

### `reference`
- **Descripción:** Referencia de la SO.
- **Notas:** Se usa para guardar el identificador del line item de eBay (estrategia Opción B, ver Nota 06).
- **Decision:** Campo reference se llena con el `orderLineItemId` del line item que origina la SO (`data.lineItems[].lineItemId`, equivalente al `orderLineItemId` de la notificación). Junto con `client_PO_Number` (= `orderId`) forma la llave de idempotencia `orderId + orderLineItemId`. ✅✅

### `gross_margin`
- **Descripción:** Margen calculado usando el `suppliermargin` del PO para cada soline (inventory). Se usa formula para sacar el gross margin.
- **Notas:** Obtenemos el `suppliermargin` del PO para cada soline (inventory). 

```php
$po_id = po_id del registro inventory;

SELECT id, suppliermargin, po
FROM po_info
WHERE id = '$po_id'
LIMIT 1;

// Dividimos el margen del proveedor por 100 para convertirlo a porcentaje
$suppliermargin_percentage = $suppliermargin_po / 100;

// Calculamos el margen estimado
$diff = $inventory_unitprice - $inventory_unitcost;

if ($suppliermargin_percentage > 0) {
    if ($diff > 0) {
        $estimated_margin = $diff * ($suppliermargin_percentage);
    } else {
        $estimated_margin = $estimated_margin + $diff;
    }
} else {
    $estimated_margin = 0;
}
```
 
- **Decision:** Al campo `gross_margin`le asignamos el valor de `$estimated_margin. No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0. ✅✅
  📌 **Nota para backend:** en la rama `else` del pseudocódigo (`$estimated_margin = $estimated_margin + $diff`) se usa `$estimated_margin` antes de inicializarla. Revisar/validar esta lógica al portar el código (aplica también a la fórmula de `margin_percentage`).

### `margin_percentage`
- **Descripción:** Porcentaje de margen calculado acumulando el profit de todos los inventories.
- **Notas:** Iteramos cada item dentro de los solines (inventories).

```php
$po_id = po_id del registro inventory;

SELECT id, suppliermargin, po
FROM po_info
WHERE id = '$po_id'
LIMIT 1;

// Dividimos el margen del proveedor por 100 para convertirlo a porcentaje
$suppliermargin_percentage = $suppliermargin_po / 100;

// Calculamos el margen estimado
$diff = $inventory_unitprice - $inventory_unitcost;

if ($suppliermargin_percentage > 0) {
    if ($diff > 0) {
        $estimated_margin = $diff * ($suppliermargin_percentage);
    } else {
        $estimated_margin = $estimated_margin + $diff;
    }
} else {
    $estimated_margin = 0;
}

// Sumamos el unitprice total de todos los inventories de la SO
$inventory_unitprice = $dt_inventory_data['unitprice'];
$totalsales_sum += $inventory_unitprice;

if ($profit_total > 0) {
    $margin_percentage = $profit_total / $totalsales_sum;
    $margin_percentage = $margin_percentage * 100;
} else {
    $margin_percentage = 0;
}

$margin_percentage = number_format($margin_percentage, 2, '.', '');

$profit_interno = $profit_interno + $estimated_margin;
$profit_interno = number_format($profit_interno, 2, '.', '');

// Acumulamos el profit de todos los inventories
$profit_total = $profit_interno;

if ($profit_total > 0) {
    $margin_percentage = $profit_total / $totalsales_sum;
    $margin_percentage = $margin_percentage * 100;
} else {
    $margin_percentage = 0;
}

$margin_percentage = number_format($margin_percentage, 2, '.', '');
```

- **Decision:** Asignamos al campo `margin_percentage` el valor de `$margin_percentage`. No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0. ✅✅

### `profit`
- **Descripción:** Variable `$profit_total` de la fórmula de margen.
- **Notas:** Seguir formula de arriba 
- **Decision:** Al campo profit se le asigna el valor de la variable $profit_total de la formula de arriba. No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0. ✅✅

### `total`
- **Descripción:** Valor total de la orden.
- **Notas:** Seguir formula 
```php
$total = floatval($extendCost)

+ floatval($extracost)

+ floatval($freight)

+ floatval($servichesCharge)

+ floatval($misCcharge)

+ floatval($tax);
```
- **Decision:** Seguir formula. No se puede si no hay items de inventory reservados, hacerlo solo con los items reservados que se encuentren, en caso de no haber ningun item reservado poner 0.

### `created_at`
- **Descripción:** Fecha de creación de la SO, tipo de dato `datetime`.
- **Notas:** Fecha automatica en datetime 
- **Decision:** Campo created_at se le asigna el valor de la fecha en que se crea el registro ✅ ✅

### `updated_at`
- **Descripción:** Fecha de actualización de la SO, tipo de dato `datetime`.
- **Notas:** Fecha automatica en datetime 
- **Decision:** Campo created_at se le asigna el valor de la fecha en que se crea el registro ✅ ✅

### `date`
- **Descripción:** Fecha de creación de la SO en string `YYYY-mm-dd`, ejemplo: `2026-06-12`.
- **Notas:** Fecha de creación de la SO en string `YYYY-mm-dd`, ejemplo: `2026-06-12`.
- **Decision:** Campo date se le asigna el valor de la fecha en que se crea el registro pero en formato string `YYYY-mm-dd` ✅ ✅

### `soline`
- **Descripción:** Contador de line items de la SO. Iniciar en `0`; al agregar un line item a la orden aumentar este número `+1`.
- **Notas:** Siempre sumar al hacer la reserva de los items, practicamente es la cantidad de items reservados, pero no se resta en caso de quitar siempre suma, nunca resta.
- **Decision:**  Campo soline es la caantidad de los items que se reservaron de acuerdo a la "Nota 03"  ✅ ✅

### `client_PO_Number`
- **Descripción:** Campo para agregar client PO del cliente.
- **Notas:** El id de la orden que viene de ebay. Con la estrategia Opción B (una SO por line item), este valor **se repite** entre las N SOs que se generan de una misma compra de eBay; lo que las distingue es el `reference` (= `orderLineItemId`).
- **Decision:** Campo client_PO_Number se llena con el valor de campo [orderId] que viene en la response de ebay  ✅ ✅

### `type`
- **Descripción:** Establecer el valor `so` para la SO.
- **Notas:** Valor "so" por default
- **Decision:** El campo type se llena con el valor "so" por default  ✅ ✅

### `contactcontact`
- **Descripción:** Nombre de cliente para el campo Contact del bloque Customer Information.
- **Notas:** nombre del cliente que nos de ebay 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName] ✅ ✅

### `contactemail`
- **Descripción:** Email de cliente para el campo Email del bloque Customer Information.
- **Notas:** email del cliente que nos de ebay (email haseado) 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email] ✅✅

### `contactphone`
- **Descripción:** Teléfono de cliente para el campo Phone del bloque Customer Information.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible dejamos N/A o null? NULL
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.primaryPhone.phoneNumber] ✅✅

### `contactaddress1`
- **Descripción:** Dirección de cliente para el campo Address 1 del bloque Customer Information.
- **Notas:** addressLine1 de ebay
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1]  ✅✅

### `contactaddress2`
- **Descripción:** Dirección de cliente para el campo Address 2 del bloque Customer Information.
- **Notas:** Si viene el addressLine2 de ebay se lo ponemos, si no va vacío.
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine2]
- **Decision:** Si  ✅✅

### `contactcity`
- **Descripción:** Ciudad de cliente para el campo City del bloque Customer Information.
- **Notas:** city de ebay 
- **Decision:**  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.city] ✅✅

### `contactcompany`
- **Descripción:** Company Name del cliente para el campo Company Name del bloque Customer Information.
- **Notas:** "EBAY" por defecto
- **Decision:** Campo contactcompany se le asigna "EBAY" por defecto ✅✅

### `contactcountry`
- **Descripción:** Country del cliente para el campo Country del bloque Customer Information, campo Country que viene en ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode] se debe usar el valor name de la tabla country el valor de ebay debe ser equivalente al valor del campo iso.
- **Notas:** countryCode de ebay (actualización 2026-07-09: misma resolución que `shiptocountry` y `to_country`, no se guarda el código crudo).
- **Decision:** valor name de la tabla country ✅ ✅

### `contactpostalcode`
- **Descripción:** Postal Code del cliente para el campo Postal Code del bloque Customer Information.
- **Notas:** postalCode de ebay
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.postalCode] ✅✅

### `contactstate`
- **Descripción:** Estado del cliente para el campo State del bloque Customer Information. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** stateOrProvince de ebay 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince] ✅✅

### `currency`
- **Descripción:** Currency de la SO, ejemplo: `USD`.
- **Notas:**  Sacar de ebay  
- **Decision:** ebayResponse: [pricingSummary.total.currency]  ✅✅

### `customer`
- **Descripción:** Nombre del cliente.
- **Notas:** fullName de ebay 
- **Decision:**   ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName] ✅✅

### `freight`
- **Descripción:** Costo del envío.
- **Notas:** Le pondemos 0 porque ebay no lo cobro o este lo insertamos de acuerdo a la implementaicon que se hara al generar la label?
- **Decision:** Campo freight se le asignara el valor "0" por defecto  ✅✅

### `saledate`
- **Descripción:** Fecha de venta.
- **Notas:** Fecha que viene de ebay
- **Decision:** Campo saledate se le asigna el valor de [timestamp] que viene de ebay (revisar que los formatos sean correctos o convertir) ✅✅

### `master_id`
- **Descripción:** Id de la master company, asignar el valor `1`.
- **Notas:** 1 por default 
- **Decision:** Campo master_id se le asignara el valor 1 por defecto ✅✅

### `shipfromlocation_id`
- **Descripción:** Id de la location referente al shipping from. Puede ser `headq`, un id de `locations` o `NULL` para dirección one-time.
- **Notas:** usamos el mismo de `warehouse_id`? yes
  valores probables (Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.)
- **Decision:** Campo shipfromlocation_id se le asignara el valor de `warehouse_id`, revisar "Nota 04" ✅✅

### `shipfromaddress1`
- **Descripción:** Dirección de shipping from, campo Address del bloque Shipping From.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** Campo shipfromaddress  se llena con el campo address de la tabla locations, revisar "Nota 04" ✅✅

### `shipfromaddress2`
- **Descripción:** Dirección 2 de shipping from, campo Address 2 del bloque Shipping From.
- **Notas:** usamos los datos del registro de la tabla location?
- **Decision:** Campo shipfromaddress2  se llena con el campo address2 de la tabla locations, revisar "Nota 04" ✅✅

### `shipfromcity`
- **Descripción:** City de shipping from, campo City del bloque Shipping From.
- **Notas:** "Stafford" por default?
- **Decision:** Campo shipfromcity se llena con el campo city de la tabla locations, revisar "Nota 04" ✅✅

### `shipfromcompany`
- **Descripción:** Company de shipping from, campo Company del bloque Shipping From.
- **Notas:** Dinámico según el location de origen, no hardcodeado.
- **Decision:** Campo shipfromcompany se llena con el `name` de la company asociada al location: `locations.companies_id` → `companies.name`. Revisar "Nota 04". ✅✅ 

### `shipfromcontact`
- **Descripción:** Contact de shipping from, campo Contact del bloque Shipping From.
- **Notas:** es el nombre del shipfromcontactuser_id
- **Decision:** Campo shipfromcontact se llena con el "name + surname" que se encontro de la tabla users. Revisar "Nota 02". ✅✅ 

### `shipfromemail`
- **Descripción:** Email de shipping from, campo Email del bloque Shipping From.
- **Notas:** de acuerdo a shipfromcontactuser_id
- **Decision:** Campo shipfromemail se llena con el "mail" que se encontro de la tabla users. Revisar "Nota 02". ✅✅ 

### `shipfromphone`
- **Descripción:** Phone de shipping from, campo Phone del bloque Shipping From.
- **Notas:** de acuerdo a shipfromcontactuser_id
- **Decision:** Campo shipfromphone se llena con el "phone" que se encontro de la tabla users. Revisar "Nota 02". ✅✅ 

### `shipfromcountry`
- **Descripción:** Country de shipping from, campo Country del bloque Shipping From.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** Campo shipfromcountry se llena con el campo country de la tabla locations, revisar "Nota 04" ✅✅

### `shipfrompostalcode`
- **Descripción:** Postal Code de shipping from, campo Postal Code del bloque Shipping From.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** Campo shipfrompostalcode se llena con el campo zip_code de la tabla locations, revisar "Nota 04" ✅✅

### `shipfromstate`
- **Descripción:** Estado del Shipping From para el campo State del bloque Shipping From. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** Campo shipfromstate se llena con el campo state de la tabla locations, revisar "Nota 04" ✅✅

### `shiptolocation_id`
- **Descripción:** Id de la location referente al shipping to. Puede ser `headq`, un id de `locations` o `NULL` para dirección one-time.
- **Notas:** NULL
- **Decision:** campo shiptolocation_id se le asigna NULL por default✅✅
### `shiptoaddress1`
- **Descripción:** Address 1 de shipping to, campo Address del bloque Shipping To.
- **Notas:** addressLine1 de ebay 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1] ✅✅

### `shiptoaddress2`
- **Descripción:** Address 2 de shipping to, campo Address 2 del bloque Shipping To.
- **Notas:** Si viene el adress 2 de ebay se lo ponemos
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine2] ✅✅

### `shiptocity`
- **Descripción:** City de shipping to, campo City del bloque Shipping To.
- **Notas:** city de ebay 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.city] ✅✅

### `shiptocompany`
- **Descripción:** Nombre de compañía del cliente a quien le hacen el envío, campo Company del bloque Shipping To.
- **Notas:** "EBAY" por defecto? YES
- **Decision:** Campo shiptocompany se le asigna "EBAY" por defecto ✅✅

### `shiptocontact`
- **Descripción:** Nombre de compañía del cliente a quien le hacen el envío, campo Company del bloque Shipping To.
- **Notas:** nombre del cliente
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName] ✅ ✅

### `shiptocountry`
- **Descripción:** País del cliente a quien le hacen el envío, campo Country del bloque Shipping To que viene en ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode] se debe usar el valor name de la tabla country, el valor de ebay debe ser equivalente al valor del campo iso.
- **Notas:** countryCode de ebay 
- **Decision:** valor name de la tabla country ✅ ✅

### `shiptoemail`
- **Descripción:** Email del cliente a quien le hacen el envío, campo Email del bloque Shipping To.
- **Notas:** email del cliente que nos de ebay (email haseado) 
- **Decision:**   ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email] ✅✅

### `shiptophone`
- **Descripción:** Teléfono del cliente a quien le hacen el envío, campo Phone del bloque Shipping To.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible no lo ponemos? NULL
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.primaryPhone.phoneNumber] ✅ ✅

### `shiptopostalcode`
- **Descripción:** Código postal del cliente a quien le hacen el envío, campo Postal Code del bloque Shipping To.
- **Notas:** postalCode de ebay
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.postalCode] ✅ ✅

### `shiptostate`
- **Descripción:** Estado del Shipping To para el campo State del bloque Shipping To. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** stateOrProvince de ebay
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince] ✅ ✅

---


## Campos en `shipment`

> **Alcance:** este flujo crea el registro de `shipment` con los datos de origen/destino y carrier, pero **no** genera la etiqueta de envío (label). Por eso los campos relacionados con la generación de label y paquete (weight, dimensiones, `package_quantity`, `num_packages`, `items`, tracking, costos, etc.) no se mapean: corresponden a un proceso posterior que no está en el alcance actual.

### `id`
- **Descripción:** Automático, auto incrementable.
- **Notas:**
- **Decision:** ✅ ✅
- **Columna referencia:** 

### `so_id`
- **Descripción:** Id de su SO referente a la tabla `so_info`.
- **Notas:** 
- **Decision:** Campo so_id se le asigna el campo id de so_info✅ ✅
- **Columna referencia:** id

### `rep_id`
- **Descripción:** Id de la persona que crea el shipment, referente a la tabla `users`.
- **Notas:**
- **Decision:** Campo rep_id de shipment se le asigna el valor que tenga el rep_id de la so_info ✅✅
- **Columna referencia:**  rep_id

### `type`
- **Descripción:** Establecerlo como `"MANUAL"`.
- **Notas:** `"MANUAL"` por defecto ✅
- **Decision:** si ✅✅
- **Columna referencia:**

### `status`
- **Descripción:** Establecerlo como `"Scheduled"`.
- **Notas:** `"Scheduled"` por defecto y si la so queda es diferente a Reserved que status
- **Decision:** `"Scheduled"` ✅✅
- **Columna referencia:**

### `created_at`
- **Descripción:** Fecha de creación del shipment, en formato datetime. Ejemplo: `2026-06-12 19:51:42`.
- **Notas:** Fecha de creacion automatica ✅
- **Decision:** si ✅✅
- **Columna referencia:**

### `carrier_id` ✅
- **Descripción:** Id del carrier referente a la tabla `carriers`.
- **Notas:** Carriers activos: UPS (id=53), FedEx (id=51). Los ids se configuran via variable de entorno `CARRIER_MAP`.
- **Decision:** Campo carrier_id se resuelve de acuerdo a la "Nota 05". ✅✅
- **Columna referencia:** id

### `carrier_string` ✅
- **Descripción:** Nombre del carrier obtenido de su registro en la tabla `carriers`.
- **Notas:** Campo `name` del registro del carrier. Ejemplo: `"UPS"`, `"FedEx"`.
- **Decision:** Campo carrier_string se llena de acuerdo a la "Nota 05", campo `name` de la tabla `carriers`. ✅✅
- **Columna referencia:** name

### `carrier_code` ✅
- **Descripción:** Código externo del carrier obtenido de su registro en la tabla `carriers`.
- **Notas:** Campo `external_carrier_code` del registro del carrier. Ejemplo: `"ups"`, `"fedex"`.
- **Decision:** Campo carrier_code se llena de acuerdo a la "Nota 05", campo `external_carrier_code` de la tabla `carriers`. ✅✅
- **Columna referencia:** external_carrier_code

### `service_code` ✅
- **Descripción:** Código del servicio de envío. Se obtiene parseando el array `service_type` del registro de `carriers`.
- **Notas:** eBay envía el servicio en [shippingStep.shippingServiceCode] en formato PascalCase sin separadores (ej. `"UPSGround"`). El array `service_type` en `carriers` usa snake_case (ej. `"ups_ground"`). Para hacer el match: normalizar ambos valores a minúsculas sin separadores y comparar. Fallback: `ups_ground` para UPS, `fedex_ground` para FedEx. Revisar "Nota 05".
- **Decision:** Campo service_code se llena de acuerdo a la "Nota 05". ✅✅
- **Columna referencia:** service_type → objeto → service_code

### `service_string` ✅
- **Descripción:** Nombre legible del servicio de envío. Se obtiene del mismo objeto del array `service_type` que se identificó en `service_code`.
- **Notas:** Una vez encontrado el objeto del servicio en `service_type`, tomar su campo `name`. Ejemplo: `"UPS® Ground"`, `"FedEx Ground®"`. Revisar "Nota 05".
- **Decision:** Campo service_string se llena de acuerdo a la "Nota 05". ✅✅
- **Columna referencia:** service_type → objeto → name

### `bill_account_number` ✅
- **Descripción:** Número de cuenta externa de facturación del carrier. Se obtiene del registro de `carriers`.
- **Notas:** Campo `external_account_number` de la tabla `carriers`. UPS: `XJ2887`, FedEx: `341701198`. Revisar "Nota 05".
- **Decision:** Campo bill_account_number se llena de acuerdo a la "Nota 05", campo `external_account_number` de la tabla `carriers`. ✅✅
- **Columna referencia:** external_account_number

### `payment_type`
- **Descripción:** `"Sender"` o `"Recipient"`.
- **Notas:** Sender por defecto, campo de la tabla carriers
- **Decision:** `"Sender"` ✅✅
- **Columna referencia:** payment_type

### `declared_value`
- **Descripción:** Opcional si se quiere establecer un valor de mercancía. Por default `0.00`.
- **Notas:** `0.00` por default. El "total de la orden" es el `total` de la SO (calculado con valores del CRM), **no** el monto de eBay.
- **Decision:** Si el `total` de la SO es mayor a 999, se declara ese valor de `total`; si es menor o igual, `0.00`. ✅✅
- **Columna referencia:**

### `unit_measurement`
- **Descripción:** Establecer `"Lbs"`.
- **Notas:** "Lbs" por default
- **Decision:** "Lbs" ✅✅
- **Columna referencia:**

### `unit_dimension`
- **Descripción:** Establecer `"inch"`.
- **Notas:** `"inch"` por default?
- **Decision:** `"inch"` ✅✅
- **Columna referencia:**

### `locations_id`
- **Descripción:** De dónde sale el envío.  campo en la tabla locations y se obtiene desde la tabla inventory
- **Notas:** usamos el mismo de `warehouse_id`del producto
  Id del warehouse del inventory
- **Decision:** Campo locations_id se le asignara el valor de `warehouse_id` del registro creado en so_info. ✅✅
- **Columna referencia:**

### `signature`
- **Descripción:** Establecer `"No Signature"`.
- **Notas:** `"No Signature"` por default
- **Decision:** `"No Signature"` ✅✅
- **Columna referencia:**

### `to_address`
- **Descripción:** Dirección línea 1 de destino.
- **Notas:** addressLine1 de ebay 
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_address_2`
- **Descripción:** Dirección línea 2 de destino.
- **Notas:** Si viene el addressLine2 de ebay se lo ponemos, si no va null.
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine2]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_city`
- **Descripción:** Ciudad de destino.
- **Notas:** city de ebay 
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.city]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_company`
- **Descripción:** Company de destino.
- **Notas:** "EBAY" por defecto?
- **Decision:** "EBAY" ✅✅
- **Columna referencia:**

### `to_country`
- **Descripción:** País de destino, campo Country del bloque Shipping To que viene en ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode] se debe usar el valor name de la tabla country el valor de ebay debe ser equivalente al valor del campo iso.
- **Notas:** countryCode de ebay (actualización 2026-07-09: misma resolución que `so_info.shiptocountry`, no se guarda el código crudo).
- **Decision:** valor name de la tabla country ✅ ✅
- **Columna referencia:**

### `to_name`
- **Descripción:** Persona que recibe.
- **Notas:** fullName de ebay
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_phone`
- **Descripción:** Teléfono de destino.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible no lo ponemos? NULL
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.primaryPhone.phoneNumber]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_state`
- **Descripción:** Estado de destino. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.
- **Notas:** stateOrProvince de ebay
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `to_postalcode`
- **Descripción:** Código postal de destino.
- **Notas:** postalCode de ebay 
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.postalCode]
- **Decision:** Si ✅✅
- **Columna referencia:**

### `from_address`
- **Descripción:** Dirección línea 1 remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_address se llena con el campo shipfromaddress1 del registro creado en la so_info. ✅✅
- **Columna:** shipfromaddress1

### `from_address_2`
- **Descripción:** Dirección línea 2 remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_address_2 se llena con el campo shipfromaddress2 del registro creado en la so_info. ✅✅
- **Columna:** shipfromaddress2

### `from_city`
- **Descripción:** Ciudad remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_city se llena con el campo shipfromcity del registro creado en la so_info, revisar. ✅✅
- **Columna:** shipfromcity

### `from_company`
- **Descripción:** Compañía remitente.
- **Notas:** Dinámico, igual que `shipfromcompany` de la so_info.
- **Decision:** Campo from_company se llena con el campo `shipfromcompany` del registro creado en la so_info (que a su vez sale de `locations.companies_id` → `companies.name`). Revisar "Nota 04". ✅✅ 
- **Columna:** shipfromcompany

### `from_country`
- **Descripción:** País remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_country se llena con el campo shipfromcountry del registro creado en la so_info.✅✅
- **Columna:** shipfromcountry

### `from_name`
- **Descripción:** Nombre remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo `from_name` se llena con el campo shipfromcontact del registro creado en la so_info, es decir el "name + surname" que se encontro de la tabla users de acuerdo al rep_id. Revisar "Nota 04" ✅✅
- **Columna:** shipfromcontact

### `from_phone`
- **Descripción:** Teléfono remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_phone se llena con el campo shipfromphone del registro creado en la so_info. ✅✅
- **Columna:** phone

### `from_state`
- **Descripción:** Estado remitente. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_state se llena con el campo `shipfromstate` del registro creado en la so_info. ✅✅
- **Columna:** `shipfromstate`

### `from_postalcode`
- **Descripción:** Código postal remitente.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo from_postalcode se llena con el campo `shipfrompostalcode` del registro creado en la so_info. ✅✅
- **Columna:** shipfrompostalcode

### `email`
- **Descripción:** Email para envío (email cliente).
- **Notas:** email del cliente que nos de ebay (email haseado) 
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email] ✅✅
- **Columna:** 

### `shipfromlocation_id`
- **Descripción:** Si se envía desde Houston poner `3`; si se envía desde Site10135 poner `243`.
- **Notas:** usamos los datos del registro de la tabla location (id) de acuerdo al warehouse_id en la tabla inventoy
- **Decision:** Campo shipfromlocation_id se le asignara el valor de `warehouse_id`del registro creado en la so_info ✅✅
- **Columna referencia:** warehouse_id

### `master_id`
- **Descripción:** Id de la master company, poner `1`.
- **Notas:** 1 por default?
- **Decision:** Campo master_id asignar 1 por default ✅✅
- **Columna referencia:**

---

## Campos en `inventory`

Estos campos aparecen en las instrucciones de reservar item y existen en la tabla `inventory`.

### `so`
- **Descripción:** Poner el número de orden (so) de la tabla so_info.
- **Notas:** 
- **Decision:** Si ✅✅
- **Columna referencia:** id 

### `so_id`
- **Descripción:** El id de la SO referente a su tabla `so_info`.
- **Notas:** 
- **Decision:** Si ✅✅
- **Columna referencia:** id de so_info

### `shipment_id`
- **Descripción:** El id del shipment referente a su tabla `shipment`.
- **Notas:** 
- **Decision:** Si ✅✅
- **Columna referencia:** id

### `unitprice`
- **Descripción:** Precio de venta del inventory reservado.
- **Notas:** ⚠️ **Actualización (2026-07-03):** el `unitprice` de cada item reservado **se asigna con el precio realmente vendido en eBay**, tomado del line item de la orden: `unitprice = lineItemCost / quantity` (el `lineItemCost` de la Fulfillment API es el **total de la línea**, por eso se divide entre la cantidad). Se asigna **siempre**, aunque el item ya tenga un `unitprice`, porque con Best Offer el precio final de venta puede diferir del listing. La asignación ocurre **antes** de calcular los campos financieros de la SO (`extendedcost`, `subtotal`, `total`, márgenes), y se persiste junto con la reserva.
- **Decision:** Si — `unitprice` = precio unitario vendido en eBay (`lineItemCost / quantity`), asignado antes de los cálculos. ✅ ✅
- **Columna referencia:** eBay `lineItems[].lineItemCost` ÷ `lineItems[].quantity`

### `status`
- **Descripción:** Cambiar a `Reserved` al reservar el item.
- **Notas:**
- **Decision:** Si, revisar "Nota 03" ✅✅
- **Columna referencia:**

### `datereserved`
- **Descripción:** Fecha de cuando fue reservado el inventory en formato string
- **Notas:** Ejemplo 06/25/2026 12:13:12 PM
- **Decision:** Si ✅ ✅
- **Columna referencia:**

### `datereserved2`
- **Descripción:** Fecha de cuando fue reservado el inventory en formato datetime
- **Notas:** Ejemplo: 2026-06-25 12:13:12
- **Decision:** Si ✅✅
- **Columna referencia:**

### `reservedbyuser_id`
- **Descripción:** Id del usuario que está reservando, referente a la tabla `users`.
- **Notas:** id del rep que creo el listing
- **Decision:** Campo reservedby se llena con el valor de rep_id de la so_info ✅✅
- **Columna referencia:** rep_id

### `reservedby`
- **Descripción:** Iniciales del usuario que está reservando. 
- **Notas:** 
- **Decision:** Campo reservedby se llena con el valor de rep_id de la so_info, se va a buscar el id del usuario identificado y se tomara su name y surname y se pondran sus inciales, ejemplo: Anuar Garcia = `AG`. Si usamos usuario sistema iran esas iniciales ✅✅
- **Columna referencia:** rep_id, name y surname

### `soline`
- **Descripción:** Número de su línea en la SO. Se obtiene el valor `soline` de la SO, se suma `+1`, y también se incrementa `soline` en la `so_info` relacionada.
- **Notas:** Es la linea que respresenta en la so, si es el primer producto que se agrego a la so tendra el 1, si es el 2 tendra el 2 y asi sucesivamente, es para identificar que producto de todos los que se agregaron a la so es.
- **Decision:** Revisar notas ✅✅
- **Columna referencia:**

### `quantity`
- **Descripción:** Número de productos. Siempre se pone `1`; si hay 20 laptops se desglosan y a cada una se le asigna una `soline`.
- **Notas:** query ony 
- **Decision:** ✅✅
- **Columna referencia:**
