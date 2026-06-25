# Campos Sales Orders y Shipments - verificación contra tabla


#### Notas:

Nota 01: Como manejar el customer
Para la asociacion del cliente o customer se requiere de un registro en la tabla user, este registro puede ser que exista o que se requiera crear. Describo los dos casos aqui:
- Caso 1:  
  Si [fulfillmentStartInstructions[0].shippingStep.shipTo.fullName] de la response de ebay coincide con name + surname de la tabla users
  y la direccion [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.addressLine1] de la response de ebay coincide con address de la tabla users
  Entonces usar el id del usuario encontrado, si se encuentra mas de uno usar el primero.
- Caso 2: Si con el caso 1 no se encuentra ningun registros entonces
	  Crear un usuario nuevo en users
	- Asignar en el campo companies_id el id=1293 de la tabla companies
	- Asignar en el campo role el valor "CUSTOMER" 
	- Asignar en el campo managed_by el id del rep que creo el listing 
	- Asignar en el campo managed_by_string el "name + surname" del rep que creo el listing

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

---
Nota 04: Como saber la ubicación de origen
A lo largo de todo el proceso en diferentes tablas se requiere saber la direccion de donde salen las cosas, o de donde esta la compañia que envia el paquete o para saber su contacto. En esos casos se va a tomar el warehouse_id y se buscara mediante el id el registro en la tabla locations, el registro que se encuentre tiene datos como: name, address, address2, country, state, city, phone, sip_code, etc, todos esos campos se van a mapear a algunos campos especificos que ya te documentare. Tambien se puede revisar la descripcion de la tabla locations para saber todos los campos que tiene.

---
En caso de que sea un listing que se publico con nuestro metodo vamos a buscar el sku y encontraremos los product inventory, vamos a revisar cuales fueron los producto inventory que entraron primero al listing y esos vamos a reservar.
En caso de no encontrarlos es porque se enlistaron con el metodo viejo y no vamos a poder reservarlos, tendra que quedarse la so como open.


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
- **Decision:**  Campo campo states_id se llena de la siguiente forma, el valor que venga en [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.stateOrProvince] se va a tomar y se buscara en la tabla state de crm por el campo abbr. ✅ ✅ 

### `tax`
- **Descripción:** Valor del tax.
- **Notas:** Tomamos el valor del tax de acuerdo al states_id que identificamos
- **Decision:** Campo tax se llena con "0" ✅ ✅  

### `subtotal`
- **Descripción:** Valor de total antes de taxes.
- **Notas:** Pondemos el valor total que nos da ebay?
  o desglosamos tomando el valor total de ebay y si tiene un state con tax le quitamos ese monto de tax y ponemos el valor calculado de esa operacion?
  ebayResponse: {pricingSummary.priceSubtotal.value}
- **Decision:** Campo subtotal se llena con el valor de pricingSummary.priceSubtotal.value que viene de ebay ✅ ✅

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
- **Notas:** de la forma que dices? si
- **Decision:** Campo extendedcost se le asigna la suma del campo unitprice de cada uno de los items reservados de la tabla inventory ✅ ✅

### `estimated_cost`
- **Descripción:** Sumar el campo `purchasecost` de todos los solines (inventories) y asignar el valor final a `estimated_cost`.
- **Notas:** Este paso se hace con la formula? yes
- **Decision:** Campo estimated_cost se le asigna la suma del campo `purchasecost` de cada uno de los items reservados de la tabla inventory ✅ ✅

### `cleartax`
- **Descripción:** Ajustar el valor a `0` (indicamos al sistema que los taxes están activos).
- **Notas:** 0 si los taxes estan aplicados, 1 si hay alguna excepcion y no se tienen que aplicar taxes
- **Decision:**  Campo cleartax se llena con "1" ✅ ✅  

### `warehouse_id`
- **Descripción:** Id del warehouse de la SO. `3`: Houston. `243`: Site 10135.
- **Notas:** Caso 1: items de una sola locacion poner esa locacion
  Caso 2: items de varias locaciones poner el id de la primera locacion
- **Decision:** Campo warehouse_id se llena de acuerdo a como se menciona en la "Nota 03" ✅ ✅

### `reference`
- **Descripción:** Referencia de la SO.
- **Notas:** No aplica
- **Decision:** Campo reference se le asigna NULL  ✅✅

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
 
- **Decision:** Al campo `gross_margin`le asignamos el valor de `$estimated_margin`. ✅✅

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

- **Decision:** Asignamos al campo `margin_percentage` el valor de `$margin_percentage`. ✅✅

### `profit`
- **Descripción:** Variable `$profit_total` de la fórmula de margen.
- **Notas:** Seguir formula de arriba 
- **Decision:** Al campo profit se le asigna el valor de la variable $profit_total de la formula de arriba ✅✅

### `total`
- **Descripción:** Valor total de la orden.
- **Notas:** Seguir formula 
- **Decision:** TODO: revisar con la response ⚠️ ⚠️ ⚠️

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
- **Notas:** El id de la orden que viene de ebay
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
  En caso de no estar dispoonible dejamos N/A o null?
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
- **Descripción:** Country del cliente para el campo Country del bloque Customer Information.
- **Notas:** countryCode de ebay 
- **Decision:**   ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode] ✅✅

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
- **Notas:** "GreenTek Solutions, LLC" por default?
- **Decision:**  Campo shipfromcompany se le asigna "GreenTek Solutions, LLC" por defecto ✅✅ 

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
- **Descripción:** País del cliente a quien le hacen el envío, campo Country del bloque Shipping To.
- **Notas:** countryCode de ebay
- **Decision:** ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode] ✅ ✅

### `shiptoemail`
- **Descripción:** Email del cliente a quien le hacen el envío, campo Email del bloque Shipping To.
- **Notas:** email del cliente que nos de ebay (email haseado) 
- **Decision:**   ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.email] ✅✅

### `shiptophone`
- **Descripción:** Teléfono del cliente a quien le hacen el envío, campo Phone del bloque Shipping To.
- **Notas:** phoneNumber que viene de ebay.
  En caso de no estar dispoonible no lo ponemos?
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
- **Notas:** 53 - UPS External por default
- **Decision:** ids =51 y 53
- **Columna referencia:** id

### `carrier_string `✅
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** UPS por defecto
- **Decision:** FedEx, UPS
- **Columna referencia:** name

### `carrier_code` ✅
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** ups default
- **Decision:** fedex, ups
- **Columna referencia:** external_carrier_code

### `service_code` ✅
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** ups_ground por defecto
- **Decision:** [{"service_code":"ups_next_day_air_early_am","name":"UPS Next Day Air\u00ae Early","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_ground_international","name":"UPS Ground\u00ae (International)","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_worldwide_express","name":"UPS Worldwide Express\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_next_day_air","name":"UPS Next Day Air\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_worldwide_express_plus","name":"UPS Worldwide Express Plus\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_next_day_air_saver","name":"UPS Next Day Air Saver\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_2nd_day_air_am","name":"UPS 2nd Day Air AM\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_2nd_day_air_international","name":"UPS 2nd Day Air\u00ae (International)","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_2nd_day_air","name":"UPS 2nd Day Air\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_ground","name":"UPS\u00ae Ground","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_express_early_am","name":"UPS Express Early A.M. to the U.S.","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_next_day_air_international","name":"UPS Next Day Air\u00ae (International)","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_worldwide_saver","name":"UPS Worldwide Saver\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"ups_3_day_select","name":"UPS 3 Day Select\u00ae","domestic":true,"international":true,"is_multi_package_supported":true,"is_return_supported":true}], [{"service_code":"fedex_international_priority_express","name":"FedEx International Priority\u00ae Express","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_ground","name":"FedEx Ground\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_home_delivery","name":"FedEx Home Delivery\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_2day","name":"FedEx 2Day\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_2day_am","name":"FedEx 2Day\u00ae A.M.","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_express_saver","name":"FedEx Express Saver\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_standard_overnight","name":"FedEx Standard Overnight\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_priority_overnight","name":"FedEx Priority Overnight\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_first_overnight","name":"FedEx First Overnight\u00ae","domestic":true,"international":false,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_economy_international","name":"FedEx International Economy\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_ground_international","name":"FedEx International Ground\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_international_economy","name":"FedEx International Economy\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_international_priority","name":"FedEx International Priority\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true},{"service_code":"fedex_international_first","name":"FedEx International First\u00ae","domestic":false,"international":true,"is_multi_package_supported":true,"is_return_supported":true}]
- **Columna referencia:** service_type objeto service_code

### `service_string` ✅
- **Descripción:** Se obtiene de su registro de `carriers`.
- **Notas:** UPS® Ground por defecto?
- **Decision:** preguntar a anuar, FedEx Ground®
- **Columna referencia:** service_type objeto name

### `bill_account_number `✅
- **Descripción:** Bill account de envío.
- **Notas:** valor de external_account_number en tabla carriers
- **Decision:** preguntar a anuar, ups=XJ2887, fedex=341701198
- **Columna referencia:** external_account_number

### `payment_type`
- **Descripción:** `"Sender"` o `"Recipient"`.
- **Notas:** Sender por defecto, campo de la tabla carriers
- **Decision:** `"Sender"` ✅✅
- **Columna referencia:** payment_type

### `declared_value`
- **Descripción:** Opcional si se quiere establecer un valor de mercancía. Por default `0.00`.
- **Notas:** `0.00` por default
- **Decision:** Cuando sea mayor de 999 se declara el valor del total de la orden de venta, y si es menor entonces `0.00` ✅✅
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
- **Descripción:** País de destino.
- **Notas:** countryCode de ebay 
  ebayResponse: [fulfillmentStartInstructions[0].shippingStep.shipTo.contactAddress.countryCode]
- **Decision:** Si ✅✅
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
  En caso de no estar dispoonible no lo ponemos?
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
- **Notas:** "GreenTek Solutions, LLC" por default
- **Decision:** Campo from_company se le asigna "GreenTek Solutions, LLC" por defecto ✅✅ 
- **Columna:**

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

### `unitprice`
- **Descripción:** Precio de venta del inventory reservado.
- **Notas:** query ony
- **Decision:** Si ✅ ✅
- **Columna referencia:**

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
