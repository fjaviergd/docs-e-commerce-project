# Flujo de Sales Orders y Shipments

Documento editable generado a partir de `Flujo de Sales Orders y Shipments.pdf`.

## Sales Orders

Se crean en la tabla `so_info`.

### Campos mínimos para crear un `so_info`

| Campo                    | Descripción                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `id`                     | Automático, incrementable.                                                                                   |
| `so`                     | Número de SO. Tienen que poner un número más uno al más reciente.                                            |
| `customer_id`            | Id de cliente, referente a su registro en la tabla `users`.                                                  |
| `clientuser_id`          | Id de cliente, referente a su registro en la tabla `users` (el mismo que `customer_id`).                     |
| `terms_id`               | Id de terms, referente a su registro en la tabla `terms`.                                                    |
| `rep_id`                 | Id del vendedor (rep), referente a su registro en la tabla `users`.                                          |
| `contactcontactuser_id`  | Id de contacto de compra (puede ser el mismo de `customer_id`), referente a su registro en la tabla `users`. |
| `conditions_id`          | Id de la condición de venta, referente a su registro en la tabla `conditions`.                               |
| `Shipfromcontactuser_id` | Id del usuario de contacto de la sección Shipping From, referente a su registro en la tabla `users`.         |
| `Shiptoclientuser_id`    | Id del usuario de contacto de la sección Shipping To, referente a su registro en la tabla `users`.           |
| `status`                 | Status de la Sale Order.                                                                                     |

Valores de `status`:

| Status               | Descripción                            |
| -------------------- | -------------------------------------- |
| `Open`               | Status inicial.                        |
| `Reserved`           | Cuando todos los items están Reserved. |
| `Partially Reserved` | Cuando hay al menos un item Reserved.  |
| `Invoiced`           | Cuando todos los items están Invoiced. |
| `Voided`             | Cuando hacen void al SO.               |

| Campo | Descripción |
| --- | --- |
| `shipstatus` | Status del Shipment. Default para un SO nuevo: `Open`. Cuando ya tiene un shipment agendado: `Scheduled`. |
| `states_id` | Estado para la aplicación de taxes. Va el id del state relacionado con el `state` del `shipment to`. Los states están en la tabla `states`. |

Ejemplo visual de la tabla `states` mostrado en el PDF:

| `id` | `country_id` | `name` | `abbr` | `tax` | `freight` |
| ---: | ---: | --- | --- | ---: | ---: |
| 7 | 2 | Jalisco | Jal | 14.50 | 0 |
| 61 | 1 | Texas | TX | 8.25 | 0 |
| 19 | 1 | Alabama | AL | 0.00 | 0 |
| 20 | 1 | Alaska | AK | 0.00 | 0 |
| 21 | 1 | Arizona | AZ | 0.00 | 0 |
| 22 | 1 | Arkansas | AR | 0.00 | 0 |
| 23 | 1 | California | CA | 0.00 | 0 |
| 24 | 1 | Colorado | CO | 0.00 | 0 |
| 25 | 1 | Connecticut | CT | 0.00 | 0 |
| 26 | 1 | Delaware | DE | 0.00 | 0 |
| 27 | 1 | Florida | FL | 0.00 | 0 |
| 28 | 1 | Georgia (U.S. state) | GA | 0.00 | 0 |
| 29 | 1 | Hawaii | HI | 0.00 | 0 |
| 30 | 1 | Idaho | ID | 0.00 | 0 |
| 31 | 1 | Illinois | IL | 0.00 | 0 |
| 32 | 1 | Indiana | IN | 0.00 | 0 |

Ahí mismo sacamos el porcentaje de tax a aplicar desde el campo `tax`.

| Campo              | Descripción                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `tax`              | Valor del tax.                                                                                                         |
| `subtotal`         | Valor de total antes de taxes.                                                                                         |
| `serviches_charge` | Valor de services a aumentar a la orden, campo Services.                                                               |
| `misc_charge`      | Valor de Misc. Charge a aumentar a la orden, campo Misc. Charge.                                                       |
| `extracost`        | Valor de servicios de instalación a aumentar a la orden, campo Installation Cost.                                      |
| `extendedcost`     | Suma del valor `unitprice` de todos los solines (inventarios).                                                         |
| `estimated_cost`   | Formula: Sumar el campo `purchasecost` de todos los solines (inventories) y asignar el valor final a `estimated_cost`. |
| `cleartax`         | Ajustar el valor a `0` (indicamos al sistema que los taxes están activos).                                             |
| `warehouse_id`     | Id del warehouse de la SO:<br>`3`: Houston. <br>`243`: Site 10135.                                                     |
| `reference`        | Referencia de la SO.                                                                                                   |

Ejemplos visuales mostrados en el PDF para el bloque de costos:

| Campo UI          | Valor de ejemplo |
| ----------------- | ---------------- |
| Services          | 10               |
| Installation Cost | 0                |
| Misc. Charge      | 0.00             |
| Tax               | $0.00            |
| Total             | $10.00           |
| Margin            | 74.36 %          |

### `gross_margin`

Fórmula para sacar el `gross_margin`:

1. Obtenemos el `suppliermargin` del PO para cada soline (inventory).

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

Asignamos al campo `gross_margin` el valor de `$estimated_margin`.

### `margin_percentage`

Fórmula para sacar el `margin_percentage`:

Iteramos cada item dentro de los solines (inventories).

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

Asignamos al campo `margin_percentage` el valor de `$margin_percentage`.

| Campo | Descripción |
| --- | --- |
| `profit` | Variable `$profit_total` de la fórmula de arriba. |
| `total` | Valor total de la orden. |

```php
$total = floatval($extendCost)
    + floatval($extracost)
    + floatval($freight)
    + floatval($servichesCharge)
    + floatval($misCcharge)
    + floatval($tax);
```

| Campo              | Descripción                                                                                                    |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| `created_at`       | Fecha de creación de la SO, tipo de dato `datetime`.                                                           |
| `updated_at`       | Fecha de creación de la SO, tipo de dato `datetime`.                                                           |
| `date`             | Fecha de creación de la SO en string `YYYY-mm-dd`, ejemplo: `2026-06-12`.                                      |
| `soline`           | Contador de line items de la SO. Iniciar en `0`; al agregar un line item a la orden aumentar este número `+1`. |
| `client_PO_Number` | Campo para agregar client PO del cliente.                                                                      |
| `type`             | Establecer el valor: `so`.                                                                                     |

## Campos Customer Information

Ejemplo visual mostrado en el PDF:

| Campo UI     | Valor de ejemplo   |
| ------------ | ------------------ |
| Company Name | Apple, Inc.        |
| Address 1    | One Apple Park Way |
| Address 2    |                    |
| City         | Cupertino          |
| Country      | United States      |
| State        | CA - California    |
| Postal Code  | 95014              |
| Contact      | Adrik Garcia       |
| Phone        | 408-609-6298       |
| Email        | anuargts@gmail.com |

| Campo | Descripción |
| --- | --- |
| `Contactcontact` | Nombre de cliente para el campo Contact del bloque Customer Information. |
| `contactemail` | Email de cliente para el campo Email del bloque Customer Information. |
| `contactphone` | Teléfono de cliente para el campo Phone del bloque Customer Information. |
| `contactaddress1` | Dirección de cliente para el campo Address 1 del bloque Customer Information. |
| `contactaddress2` | Dirección de cliente para el campo Address 2 del bloque Customer Information. |
| `contactcity` | Ciudad de cliente para el campo City del bloque Customer Information. |
| `contactcompany` | Company Name del cliente para el campo Company Name del bloque Customer Information. |
| `contactcountry` | Country del cliente para el campo Country del bloque Customer Information. |
| `contactpostalcode` | Postal Code del cliente para el campo Postal Code del bloque Customer Information. |
| `contactstate` | Estado del cliente para el campo State del bloque Customer Information. Poner abreviación en mayúsculas, ejemplo: `TX`. |
| `currency` | Currency de la SO, ejemplo: `USD`. |
| `customer` | Nombre del cliente. |
| `freight` | Costo del envío. |
| `saledate` | Fecha de venta. |
| `master_id` | Id de la master company, asignar el valor `1`. |

## Campos Shipping From

Ejemplo visual mostrado en el PDF:

| Campo UI | Valor de ejemplo |
| --- | --- |
| Location | Houston |
| Company | GreenTek Solutions, LLC |
| Address | 12315sss Parc Crest Dr. |
| Address 2 | STE 160 |
| City | Stafford |
| Country | United States |
| State | TX - Texas |
| Postal Code | 77477 |
| Contact | Admin Admin |
| Phone | 713-590-9720 |
| Email | admin@admin.com |

| Campo | Descripción |
| --- | --- |
| `shipfromlocation_id` | Id de la location referente al shipping from. Puede ser: `headq` si la locación seleccionada es la headquarter; numérico (`id`) si es id de la locación referente a la tabla `locations`; `NULL` (vacío) si la dirección es one-time y no se tiene que guardar en el sistema. |
| `shipfromaddress1` | Dirección de shipping from, campo Address de bloque Shipping From. |
| `shipfromaddress2` | Dirección 2 de shipping from, campo Address 2 de bloque Shipping From. |
| `shipfromcity` | City de shipping from, campo City de bloque Shipping From. |
| `shipfromcompany` | Company de shipping from, campo Company de bloque Shipping From. |
| `shipfromcontact` | Contact de shipping from, campo Contact de bloque Shipping From. |
| `shipfromcountry` | Country de shipping from, campo Country de bloque Shipping From. |
| `shipfromemail` | Email de shipping from, campo Email de bloque Shipping From. |
| `shipfromphone` | Phone de shipping from, campo Phone de bloque Shipping From. |
| `shipfrompostalcode` | Postal Code de shipping from, campo Postal Code de bloque Shipping From. |
| `shipfromstate` | Estado del Shipping From para el campo State del bloque Shipping From. Poner abreviación en mayúsculas, ejemplo: `TX`. |

## Campos Shipping To

Ejemplo visual mostrado en el PDF:

| Campo UI | Valor de ejemplo |
| --- | --- |
| Company Location | Headquarters |
| Company | Apple, Inc. |
| Address | One Apple Park Way3 |
| Address 2 |  |
| City | Cupertino |
| Country | United States |
| State |  |
| Postal Code | 95014 |
| Contact | Adrik Garcia |
| Phone | 408-609-6298 |
| Email | anuargts@gmail.com |

| Campo | Descripción |
| --- | --- |
| `shiptolocation_id` | Id de la location referente al shipping to. Puede ser: `headq` si la locación seleccionada es la headquarter; numérico (`id`) si es id de la locación referente a la tabla `locations`; `NULL` (vacío) si la dirección es one-time y no se tiene que guardar en el sistema. |
| `shiptoaddress1` | Address 1 de shipping to, campo Address de bloque Shipping To. |
| `shiptoaddress2` | Address 2 de shipping to, campo Address 2 de bloque Shipping To. |
| `shiptocity` | City de shipping to, campo City de bloque Shipping To. |
| `shiptocompany` | Nombre de compañía del cliente a quien le hacen el envío, campo Company de bloque Shipping To. |
| `shiptocontact` | Nombre de compañía del cliente a quien le hacen el envío, campo Company de bloque Shipping To. |
| `shiptocountry` | País del cliente a quien le hacen el envío, campo Country de bloque Shipping To. |
| `shiptoemail` | Email del cliente a quien le hacen el envío, campo Email de bloque Shipping To. |
| `shiptophone` | Teléfono del cliente a quien le hacen el envío, campo Phone de bloque Shipping To. |
| `shiptopostalcode` | Código postal del cliente a quien le hacen el envío, campo Postal Code de bloque Shipping To. |
| `shiptostate` | Estado del Shipping To para el campo State del bloque Shipping To. Poner abreviación en mayúsculas, ejemplo: `TX`. |

## Reservar Item

Instrucciones para reservar un inventory a una SO.

El campo `status` de cada inventory puede tener dos estados:

| Estado | Descripción |
| --- | --- |
| `Available` | Disponible. |
| `Reserved` | Reservado. |

Tenemos que verificar que el `status` esté en `Available`. Al reservar, cambiar a `Reserved` y hacer lo siguiente en los siguientes campos de `inventory`:

| Campo | Descripción |
| --- | --- |
| `so` | Poner el número de orden de la SO. |
| `so_id` | El id de la SO referente a su tabla `so_info`. |
| `unitprice` | El precio de venta. |
| `status` | `Reserved`. |
| `datereserved` | Ponerle la fecha de cuando fue reservado. |
| `datereserved2` | Ponerle la fecha de cuando fue reservado. |
| `reservedbyuser_id` | Id del usuario que está reservando, referente a la tabla `users`. |
| `reservedby` | Iniciales del usuario que está reservando. Ejemplo: Anuar Garcia = `AG`. |
| `soline` | Número de su línea en la SO. Aquí obtienes el valor `soline` de la SO a asignar, le sumas `+1`, y también aumentas `+1` en el campo `soline` de la `so_info` relacionada. |
| `quantity` | Número de productos. Generalmente se le pone `1`; si tienes 20 laptops, se desglosan y a cada una se le asigna una `soline`. |

## Crear un Shipment

Crear el registro en la tabla `shipment`.

| Campo | Descripción |
| --- | --- |
| `id` | Automático, auto incrementable. |
| `so_id` | Id de su SO referente a la tabla `so_info`. |
| `rep_id` | Id de la persona que crea el shipment, referente a la tabla `users`. |
| `type` | Establecerlo como `"MANUAL"`. |
| `status` | Establecerlo como `"Scheduled"`. |
| `created_at` | Fecha de creación del shipment, en formato datetime. Ejemplo: `2026-06-12 19:51:42`. |
| `carrier_id` | Id de su carrier referente a la tabla `carriers`. |
| `carrier_string` | Se obtiene de su registro de `carriers`. |
| `service_code` | Se obtiene de su registro de `carriers`. |
| `service_string` | Se obtiene de su registro de `carriers`. |
| `bill_account_number` | Bill account de envío (platicarlo con Anuar). |
| `payment_type` | `"Sender"` o `"Recipient"`. |

`carrier_id`, `carrier_string`, `service_code`, `service_string`, `bill_account_number` y `payment_type` podemos platicarlo con Anuar y dejar ya unos predefinidos.

| Campo                 | Descripción                                                                   |
| --------------------- | ----------------------------------------------------------------------------- |
| `declared_value`      | Opcional si se quiere establecer un valor de mercancía. Por default `0.00`.   |
| `unit_measurement`    | Establecer `"Lbs"`.                                                           |
| `unit_dimension`      | Establecer `"inch"`.                                                          |
| `locations_id`        | De donde sale el envío. `3`: Houston. `243`: Site 10135.                      |
| `signature`           | Establecer `"No Signature"`.                                                  |
| `to_address`          | Dirección línea 1 de destino.                                                 |
| `to_address_2`        | Dirección línea 2 de destino.                                                 |
| `to_city`             | Ciudad de destino.                                                            |
| `to_company`          | Company de destino.                                                           |
| `to_country`          | País de destino.                                                              |
| `to_name`             | Persona que recibe.                                                           |
| `to_phone`            | Teléfono de destino.                                                          |
| `to_state`            | Estado de recibe. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.       |
| `to_postalcode`       | Código postal de destino.                                                     |
| `from_address`        | Dirección línea 1 remitente.                                                  |
| `from_address_2`      | Dirección línea 2 remitente.                                                  |
| `from_city`           | Ciudad remitente.                                                             |
| `from_company`        | Compañía remitente.                                                           |
| `from_country`        | País remitente.                                                               |
| `from_name`           | Nombre remitente.                                                             |
| `from_phone`          | Teléfono remitente.                                                           |
| `from_state`          | Estado remitente. Tiene que ser abreviatura, ejemplo: `NY`, `CA`, `TX`.       |
| `from_postalcode`     | Código postal remitente.                                                      |
| `email`               | Email para envío (email cliente).                                             |
| `shipfromlocation_id` | Si se envía desde Houston poner `3`; si se envía desde Site10135 poner `243`. |
| `master_id`           | Id de la master company, poner `1`.                                           |
