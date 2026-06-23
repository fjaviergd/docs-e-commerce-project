# Campos Sales Orders y Shipments - verificación contra tabla

_Hasta que punto quieren que se haga esta implementacion?_
Tenemos que hacer la reserva de productos?
Comenzamos el proceso del shipment?
_Vamos a reemplazar el uso de shiprush? esa herramienta solo da la direccion del cliente de ebay y genera la label?_
_Con la automatizacion lo que haremos es saber en que momento se hace la compra, traer en ese momento mediante su api de ebay los datos de esa compra como la direccion y datos generales del envio._
_Si tenemos toda esa informacion practicamente tendriamos los datos completos para generar la label. Solo haria falta alguna informacion extra que tiene que ser manual como la medida de los paquetes, etc._

---

Notas:
En caso de que sea un listing que se publico con nuestro metodo vamos a buscar el sku y encontraremos los product inventory, vamos a revisar cuales fueron los producto inventory que entraron primero al listing y esos vamos a reservar.
En caso de no encontrarlos es porque se enlistaron con el metodo viejo y no vamos a poder reservarlos, tendra que quedarse la so como open.

---

Este archivo contiene solo el nombre del campo, su descripción, notas y si el campo existe en la tabla de base de datos correspondiente.

---

## Campos en `so_info`

### `id`
- **Descripción:** Automático, incrementable.
- **Notas:** ✅
- **Decision:** ✅

### `so`
- **Descripción:** Número de SO. Tienen que poner un número más uno al más reciente.
- **Notas:** ✅
- **Decision:** ✅

### `customer_id`
- **Descripción:** Id de cliente, referente a su registro en la tabla `users`.
- **Notas:** 
  Caso 1:  Si el nombre del usuario y la direccion de envio es exacatamente la misma a algun usuario ya registrado usar ese usuario.
  Caso 2: Crear un usuario nuevo si no se encontro y ligarlo a la company de ebay, el rol sera customer y ligarlo al rep que creo el listing (NOTA REP01: si no se tiene el id del usuario que creo el listing mapearlo mediante las inciales del SKU, ejemplo AA es Allan Arciga (tenemos que crearnos nuestro map de iniciales y ids, mencionaron que era como 3 usuarios normalmente y si es alguien mas asignarloa a william que es el jefe de esa area), llenar campos managed_by y managed_by_string(name+surname)).
- **Decision:** ✅

### `clientuser_id`
- **Descripción:** Id de cliente, referente a su registro en la tabla `users` (el mismo que `customer_id`).
- **Notas:** Mismo tema de arriba ✅
- **Decision:** Mismo tema de arriba ✅

### `terms_id`
- **Descripción:** Id de terms, referente a su registro en la tabla `terms`.
- **Notas:** Siempre va Paypal (id 20)? Yes
- **Decision:** Paypal ✅

### `rep_id`
- **Descripción:** Id del vendedor (rep), referente a su registro en la tabla `users`.
- **Notas:** 
  Caso 1: Tomaremos el sku del producto y vamos a buscar en los listing para identificar el rep_id
  Caso 2: si no lo encontramos entonces aplicar NOTA "REP01"
- **Decision:**  ✅

### `contactcontactuser_id`
- **Descripción:** Id de contacto de compra (puede ser el mismo de `customer_id`), referente a su registro en la tabla `users`.
- **Notas:** Le ponemos el mismo de customer_id?
- **Decision:** Si ✅

### `conditions_id`
- **Descripción:** Id de la condición de venta, referente a su registro en la tabla `conditions`.
- **Notas:** Ponemos siempre USED(id:9)?
- **Decision:** USED ✅

### `shipfromcontactuser_id`
- **Descripción:** Id del usuario de contacto de la sección Shipping From, referente a su registro en la tabla `users`.
- **Notas:** la persona que hizo la so, es decir el rep_id
- **Decision:** rep_id ✅

### `shiptoclientuser_id`
- **Descripción:** Id del usuario de contacto de la sección Shipping To, referente a su registro en la tabla `users`.
- **Notas:** Le ponemos el mismo de customer_id?
- **Decision:** Si customer_id ✅

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
- **Decision:**  ✅

### `shipstatus`
- **Descripción:** Status del Shipment
  Default para un SO nuevo: `Open`
  Cuando ya tiene un shipment agendado: `Scheduled`.
- **Notas:** Scheduled porque vamos a crear el shipment
- **Decision:** Scheduled  ✅

### `states_id`
- **Descripción:** Estado para la aplicación de taxes. Va el id del state relacionado con el `state` del `shipment to`.
- **Notas:** ✅ Hacer match entre el state que de ebay con el de esta tabla para establecer el id
  ebayResponse: {buyer.taxAddress.stateOrProvince}
- **Decision:**  Si  ✅

### `tax`
- **Descripción:** Valor del tax.
- **Notas:** ✅ Tomamos el valor del tax de acuerdo al states_id que identificamos
- **Decision:** 0 ✅

### `subtotal`
- **Descripción:** Valor de total antes de taxes.
- **Notas:** Pondemos el valor total que nos da ebay?
  o desglosamos tomando el valor total de ebay y si tiene un state con tax le quitamos ese monto de tax y ponemos el valor calculado de esa operacion?
  ebayResponse: {pricingSummary.priceSubtotal.value}
- **Decision:** pricingSummary.priceSubtotal.value ✅

### `serviches_charge`
- **Descripción:** Valor de services a aumentar a la orden, campo Services.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** 0.00 ✅

### `misc_charge`
- **Descripción:** Valor de Misc. Charge a aumentar a la orden, campo Misc. Charge.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** 0.00 ✅

### `extracost`
- **Descripción:** Valor de servicios de instalación a aumentar a la orden, campo Installation Cost.
- **Notas:** 0 por default o no podemos nada?
- **Decision:** 0.00 ✅

### `extendedcost`
- **Descripción:** Suma del valor `unitprice` de todos los solines (inventarios).
- **Notas:** de la forma que dices? si
- **Decision:** Sumar el unitprice de cada uno de los items reservados ✅

### `estimated_cost`
- **Descripción:** Sumar el campo `purchasecost` de todos los solines (inventories) y asignar el valor final a `estimated_cost`.
- **Notas:** Este paso se hace con la formula? yes
- **Decision:** Sumar el `purchasecost` de cada uno de los items reservados ✅

### `cleartax`
- **Descripción:** Ajustar el valor a `0` (indicamos al sistema que los taxes están activos).
- **Notas:** 0 si los taxes estan aplicados, 1 si hay alguna excepcion y no se tienen que aplicar taxes
- **Decision:**  Aplicar 1 porque ninguna order va a manejar tax en listings de ebay  ✅

### `warehouse_id`
- **Descripción:** Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.
- **Notas:** Caso 1: items de una sola locacion poner esa locacion
  Caso 2: items de varias locaciones poner el id de la primera locacion
- **Decision:** De acuerdo a la locacion del producto asi como dice en las notas ✅

### `reference`
- **Descripción:** Referencia de la SO.
- **Notas:** No aplica
- **Decision:** Null o vaciio ✅

### `gross_margin`
- **Descripción:** Margen calculado usando el `suppliermargin` del PO para cada soline (inventory).
- **Notas:** Se calcula con los items ✅
- **Decision:** Si ✅

### `margin_percentage`
- **Descripción:** Porcentaje de margen calculado acumulando el profit de todos los inventories.
- **Notas:** Seguir formula ✅
- **Decision:** Si ✅

### `profit`
- **Descripción:** Variable `$profit_total` de la fórmula de margen.
- **Notas:** Seguir formula ✅
- **Decision:** Si ✅

### `total`
- **Descripción:** Valor total de la orden.
- **Notas:** Seguir formula ✅
- **Decision:** Si ✅

### `created_at`
- **Descripción:** Fecha de creación de la SO, tipo de dato `datetime`.
- **Notas:** Fecha automatica en datetime ✅
- **Decision:** Si ✅

### `updated_at`
- **Descripción:** Fecha de actualización de la SO, tipo de dato `datetime`.
- **Notas:** Fecha automatica en datetime ✅
- **Decision:** Si ✅

### `date`
- **Descripción:** Fecha de creación de la SO en string `YYYY-mm-dd`, ejemplo: `2026-06-12`.
- **Notas:** Fecha de creación de la SO en string `YYYY-mm-dd`, ejemplo: `2026-06-12`. ✅
- **Decision:** Si ✅

### `soline`
- **Descripción:** Contador de line items de la SO. Iniciar en `0`; al agregar un line item a la orden aumentar este número `+1`.
- **Notas:** Siempre sumar al hacer la reserva de los items, practicamente es la cantidad de items reservados, pero no se resta en caso de quitar siempre suma, nunca resta.
- **Decision:**  Revisar la nota ✅

### `client_PO_Number`
- **Descripción:** Campo para agregar client PO del cliente.
- **Notas:** El id de la orden que viene de ebay
- **Decision:** id de ebay  ✅

### `type`
- **Descripción:** Establecer el valor `so` para la SO.
- **Notas:** Valor "so" por default ✅
- **Decision:** Si

### `contactcontact`
- **Descripción:** Nombre de cliente para el campo Contact del bloque Customer Information.
- **Notas:** nombre del cliente que nos de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.fullName]
- **Decision:** Si  ✅

### `contactemail`
- **Descripción:** Email de cliente para el campo Email del bloque Customer Information.
- **Notas:** email del cliente que nos de ebay (email haseado) ✅
  ebayResponse: [buyer.buyerRegistrationAddress.email]
- **Decision:** Si  ✅

### `contactphone`
- **Descripción:** Teléfono de cliente para el campo Phone del bloque Customer Information.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible dejamos N/A o null?
  ebayResponse: [buyer.buyerRegistrationAddress.primaryPhone.phoneNumber]
- **Decision:** asi como en la nota indica  ✅

### `contactaddress1`
- **Descripción:** Dirección de cliente para el campo Address 1 del bloque Customer Information.
- **Notas:** addressLine1 de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.addressLine1]
- **Decision:** Si  ✅

### `contactaddress2`
- **Descripción:** Dirección de cliente para el campo Address 2 del bloque Customer Information.
- **Notas:** Si viene el addressLine2 de ebay se lo ponemos, si no va vacío.
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.addressLine2]
- **Decision:** Si  ✅

### `contactcity`
- **Descripción:** Ciudad de cliente para el campo City del bloque Customer Information.
- **Notas:** city de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.city]
- **Decision:** Si  ✅

### `contactcompany`
- **Descripción:** Company Name del cliente para el campo Company Name del bloque Customer Information.
- **Notas:** "EBAY" por defecto?
- **Decision:** "EBAY" ✅

### `contactcountry`
- **Descripción:** Country del cliente para el campo Country del bloque Customer Information.
- **Notas:** countryCode de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.countryCode]
- **Decision:** Si

### `contactpostalcode`
- **Descripción:** Postal Code del cliente para el campo Postal Code del bloque Customer Information.
- **Notas:** postalCode de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.postalCode]
- **Decision:** Si

### `contactstate`
- **Descripción:** Estado del cliente para el campo State del bloque Customer Information. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** stateOrProvince de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.contactAddress.stateOrProvince]
- **Decision:** Si

### `currency`
- **Descripción:** Currency de la SO, ejemplo: `USD`.
- **Notas:** USD por default?
  Lo podemos sacar de ebay
  ebayResponse: [pricingSummary.total.currency]
- **Decision:** Si  ✅

### `customer`
- **Descripción:** Nombre del cliente.
- **Notas:** fullName de ebay ✅
  ebayResponse: [buyer.buyerRegistrationAddress.fullName]
- **Decision:** Si

### `freight`
- **Descripción:** Costo del envío.
- **Notas:** Le pondemos 0 porque ebay no lo cobro o este lo insertamos de acuerdo a la implementaicon que se hara al generar la label?
- **Decision:** 0  ✅

### `saledate`
- **Descripción:** Fecha de venta.
- **Notas:** Fecha al momento de crear el registro o la que viene de ebay?
  ebayResponse: [creationDate]
- **Decision:** la fecha que da ebay  ✅

### `master_id`
- **Descripción:** Id de la master company, asignar el valor `1`.
- **Notas:** 1 por default ✅
- **Decision:** Si  ✅

### `shipfromlocation_id`
- **Descripción:** Id de la location referente al shipping from. Puede ser `headq`, un id de `locations` o `NULL` para dirección one-time.
- **Notas:** usamos el mismo de `warehouse_id`? yes
  valores probables (Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.)
- **Decision:** `warehouse_id` ✅

### `shipfromaddress1`
- **Descripción:** Dirección de shipping from, campo Address del bloque Shipping From.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** Si  ✅

### `shipfromaddress2`
- **Descripción:** Dirección 2 de shipping from, campo Address 2 del bloque Shipping From.
- **Notas:** usamos los datos del registro de la tabla location?
- **Decision:** si, de acuerdo con shipfromlocation_id  ✅

### `shipfromcity`
- **Descripción:** City de shipping from, campo City del bloque Shipping From.
- **Notas:** "Stafford" por default?
- **Decision:** la ciudad del registro de acuerdo al shipfromlocation_id  ✅

### `shipfromcompany`
- **Descripción:** Company de shipping from, campo Company del bloque Shipping From.
- **Notas:** "GreenTek Solutions, LLC" por default?
- **Decision:** "GreenTek Solutions, LLC"  ✅

### `shipfromcontact`
- **Descripción:** Contact de shipping from, campo Contact del bloque Shipping From.
- **Notas:** es el nombre del shipfromcontactuser_id
- **Decision:** shipfromcontactuser_id pero el nombre "name + surname" buscar el campos exactos en la tabla users ⚠️

### `shipfromemail`
- **Descripción:** Email de shipping from, campo Email del bloque Shipping From.
- **Notas:** de acuerdo a shipfromcontactuser_id
- **Decision:** buscar el campo exacto en la tabla users ⚠️

### `shipfromphone`
- **Descripción:** Phone de shipping from, campo Phone del bloque Shipping From.
- **Notas:** de acuerdo a shipfromcontactuser_id
- **Decision:** buscar el campo exacto en la tabla users ⚠️

### `shipfromcountry`
- **Descripción:** Country de shipping from, campo Country del bloque Shipping From.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** buscar el campo exacto en la tabla locations ⚠️

### `shipfrompostalcode`
- **Descripción:** Postal Code de shipping from, campo Postal Code del bloque Shipping From.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** buscar el campo exacto en la tabla locations ⚠️

### `shipfromstate`
- **Descripción:** Estado del Shipping From para el campo State del bloque Shipping From. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** Es de acuerdo al warehouse_id
- **Decision:** buscar el campo exacto en la tabla locations ⚠️

### `shiptolocation_id`
- **Descripción:** Id de la location referente al shipping to. Puede ser `headq`, un id de `locations` o `NULL` para dirección one-time.
- **Notas:** NULL
- **Decision:** NULL ✅
### `shiptoaddress1`
- **Descripción:** Address 1 de shipping to, campo Address del bloque Shipping To.
- **Notas:** addressLine1 de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1]
- **Decision:** Si ✅

### `shiptoaddress2`
- **Descripción:** Address 2 de shipping to, campo Address 2 del bloque Shipping To.
- **Notas:** Si viene el adress 2 de ebay se lo ponemos
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine2]
- **Decision:** Si ✅

### `shiptocity`
- **Descripción:** City de shipping to, campo City del bloque Shipping To.
- **Notas:** city de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.city]
- **Decision:** Si ✅

### `shiptocompany`
- **Descripción:** Nombre de compañía del cliente a quien le hacen el envío, campo Company del bloque Shipping To.
- **Notas:** "EBAY" por defecto? YES
- **Decision:** "EBAY" ✅

### `shiptocontact`
- **Descripción:** Nombre de compañía del cliente a quien le hacen el envío, campo Company del bloque Shipping To.
- **Notas:** nombre del cliente
- **Decision:** fullName de respuesta de ebay  ✅

### `shiptocountry`
- **Descripción:** País del cliente a quien le hacen el envío, campo Country del bloque Shipping To.
- **Notas:** countryCode de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode]
- **Decision:** si ✅

### `shiptoemail`
- **Descripción:** Email del cliente a quien le hacen el envío, campo Email del bloque Shipping To.
- **Notas:** email del cliente que nos de ebay (email haseado) ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email]
- **Decision:** si ✅

### `shiptophone`
- **Descripción:** Teléfono del cliente a quien le hacen el envío, campo Phone del bloque Shipping To.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible no lo ponemos?
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.primaryPhone.phoneNumber]
- **Decision:** si ✅

### `shiptopostalcode`
- **Descripción:** Código postal del cliente a quien le hacen el envío, campo Postal Code del bloque Shipping To.
- **Notas:** postalCode de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.postalCode]
- **Decision:** si ✅

### `shiptostate`
- **Descripción:** Estado del Shipping To para el campo State del bloque Shipping To. Poner abreviación en mayúsculas, ejemplo: `TX`.
- **Notas:** stateOrProvince de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince]
- **Decision:** si ✅

---

## Campos en `shipment`

### `id`
- **Descripción:** Automático, auto incrementable.
- **Notas:** campo so de so_info ✅
- **Decision:**  ✅

### `so_id`
- **Descripción:** Id de su SO referente a la tabla `so_info`.
- **Notas:** campo id de so_info ✅
- **Decision:** ✅

### `rep_id`
- **Descripción:** Id de la persona que crea el shipment, referente a la tabla `users`.
- **Notas:** Quien seria?
- **Decision:** rep_id de la so_info ✅

### `type`
- **Descripción:** Establecerlo como `"MANUAL"`.
- **Notas:** `"MANUAL"` por defecto ✅
- **Decision:** si ✅

### `status`
- **Descripción:** Establecerlo como `"Scheduled"`.
- **Notas:** `"Scheduled"` por defecto y si la so queda es diferente a Reserved que status
- **Decision:**  `"Scheduled"` ✅

### `created_at`
- **Descripción:** Fecha de creación del shipment, en formato datetime. Ejemplo: `2026-06-12 19:51:42`.
- **Notas:** Fecha de creacion automatica ✅
- **Decision:** si ✅

### `carrier_id` ⚠️
- **Descripción:** Id del carrier referente a la tabla `carriers`.
- **Notas:** 53 - UPS External por default?
- **Decision:** preguntar a anuar, 51

### `carrier_string ⚠️`
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** UPS por defecto?
- **Decision:** preguntar a anuar, FedEx

### `carrier_code` ⚠️
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** ups
- **Decision:** ,""
### `service_code` ⚠️
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** ups_ground por defecto?
- **Decision:** preguntar a anuar, fedex_ground

### `service_string` ⚠️
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** UPS® Ground por defecto?
- **Decision:** preguntar a anuar, FedEx Ground®

### `bill_account_number ⚠️`
- **Descripción:** Bill account de envío.
- **Notas:** valor de external_account_number en tabla carriers ???
- **Decision:** preguntar a anuar, ups=XJ2887, fedex=341701198

### `payment_type`
- **Descripción:** `"Sender"` o `"Recipient"`.
- **Notas:** Sender por defecto?
- **Decision:** `"Sender"` ✅

### `declared_value`
- **Descripción:** Opcional si se quiere establecer un valor de mercancía. Por default `0.00`.
- **Notas:** `0.00` por default?
- **Decision:** Cuando sea mayor de 999 se declara el valor del total de la orden de venta, y si es menor entonces `0.00` ✅

### `unit_measurement`
- **Descripción:** Establecer `"Lbs"`.
- **Notas:** "Lbs" por default?
- **Decision:** "Lbs" ✅

### `unit_dimension`
- **Descripción:** Establecer `"inch"`.
- **Notas:** `"inch"` por default?
- **Decision:** `"inch"` ✅

### `locations_id`
- **Descripción:** De dónde sale el envío. `3`: Houston. `243`: Site 10135.
- **Notas:** usamos el mismo de `warehouse_id`? YES
  Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.
- **Decision:** `warehouse_id` la misma logica ✅

### `signature`
- **Descripción:** Establecer `"No Signature"`.
- **Notas:** `"No Signature"` por default ✅
- **Decision:** `"No Signature"` ✅

### `to_address`
- **Descripción:** Dirección línea 1 de destino.
- **Notas:** addressLine1 de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1]
- **Decision:** Si ✅

### `to_address_2`
- **Descripción:** Dirección línea 2 de destino.
- **Notas:** Si viene el addressLine2 de ebay se lo ponemos, si no va null.
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine2]
- **Decision:** Si ✅

### `to_city`
- **Descripción:** Ciudad de destino.
- **Notas:** city de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.city]
- **Decision:** Si ✅

### `to_company`
- **Descripción:** Company de destino.
- **Notas:** "EBAY" por defecto?
- **Decision:** "EBAY" ✅

### `to_country`
- **Descripción:** País de destino.
- **Notas:** countryCode de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode]
- **Decision:** Si ✅

### `to_name`
- **Descripción:** Persona que recibe.
- **Notas:** fullName de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName]
- **Decision:** Si ✅

### `to_phone`
- **Descripción:** Teléfono de destino.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible no lo ponemos?
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.primaryPhone.phoneNumber]
- **Decision:** Si ✅

### `to_state`
- **Descripción:** Estado de destino. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.
- **Notas:** stateOrProvince de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince]
- **Decision:** Si ✅

### `to_postalcode`
- **Descripción:** Código postal de destino.
- **Notas:** postalCode de ebay ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.postalCode]
- **Decision:** Si ✅

### `from_address`
- **Descripción:** Dirección línea 1 remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_address_2`
- **Descripción:** Dirección línea 2 remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_city`
- **Descripción:** Ciudad remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_company`
- **Descripción:** Compañía remitente.
- **Notas:** "GreenTek Solutions, LLC" por default?
- **Decision:** ⚠️

### `from_country`
- **Descripción:** País remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_name`
- **Descripción:** Nombre remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_phone`
- **Descripción:** Teléfono remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_state`
- **Descripción:** Estado remitente. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `from_postalcode`
- **Descripción:** Código postal remitente.
- **Notas:** usamos los datos del registro de la tabla location de acuerdo al shipfromlocation_id?
- **Decision:** ⚠️

### `email`
- **Descripción:** Email para envío (email cliente).
- **Notas:** email del cliente que nos de ebay (email haseado) ✅
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email]
- **Decision:** Si ✅

### `shipfromlocation_id`
- **Descripción:** Si se envía desde Houston poner `3`; si se envía desde Site10135 poner `243`.
- **Notas:** usamos el mismo de `warehouse_id`?
  Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.
- **Decision:** ⚠️

### `master_id`
- **Descripción:** Id de la master company, poner `1`.
- **Notas:** 1 por default?
- **Decision:** Si ✅

---

## Campos en `inventory`

Estos campos aparecen en las instrucciones de reservar item y existen en la tabla `inventory`.

### `so`
- **Descripción:** Poner el número de orden de la SO.
- **Notas:** ✅
- **Decision:** Si ✅

### `so_id`
- **Descripción:** El id de la SO referente a su tabla `so_info`.
- **Notas:** ✅
- **Decision:** Si ✅

### `unitprice`
- **Descripción:** Precio de venta del inventory reservado.
- **Notas:** query ony
- **Decision:** Si ✅

### `status`
- **Descripción:** Cambiar a `Reserved` al reservar el item.
- **Notas:** ✅
- **Decision:** Si ✅

### `datereserved`
- **Descripción:** Fecha de cuando fue reservado el inventory.
- **Notas:** ✅
- **Decision:** Si ✅

### `datereserved2`
- **Descripción:** Fecha de cuando fue reservado el inventory.
- **Notas:** ✅
- **Decision:** Si ✅

### `reservedbyuser_id`
- **Descripción:** Id del usuario que está reservando, referente a la tabla `users`.
- **Notas:** id del rep que creo el listing? YES
- **Decision:** rep_id ✅

### `reservedby`
- **Descripción:** Iniciales del usuario que está reservando. Ejemplo: Anuar Garcia = `AG`. Si usamos usuario sistema iran esas iniciales
- **Notas:** ✅
- **Decision:**  De acuerdo al rep_id de la so_info ✅

### `soline`
- **Descripción:** Número de su línea en la SO. Se obtiene el valor `soline` de la SO, se suma `+1`, y también se incrementa `soline` en la `so_info` relacionada.
- **Notas:** Es la linea que respresenta en la so, si es el primer producto que se agrego a la so tendra el 1, si es el 2 tendra el 2 y asi sucesivamente, es para identificar que producto de todos los que se agregaron a la so es.
- **Decision:** Revisar notas ✅

### `quantity`
- **Descripción:** Número de productos. Generalmente se pone `1`; si hay 20 laptops se desglosan y a cada una se le asigna una `soline`.
- **Notas:** query ony ✅
- **Decision:** ✅
