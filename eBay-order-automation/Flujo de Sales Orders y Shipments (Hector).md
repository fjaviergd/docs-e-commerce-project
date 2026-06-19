
**Sales Orders**

Se crean en la tabla so_info

Campos minimos para crear un so_info:

id
Automático, incrementable

so
Número de SO, tienen que poner un número más uno al más reciente.

customer_id
Id de cliente, referente a su registro en la tabla users

clientuser_id
Id de cliente, referente a su registro en la tabla users (el mismo que customer_id)

terms_id

_

Id de terms, referente a su registro en la tabla terms

rep

id

_

Id del vendedor (rep), referente a su registro en la tabla users

contactcontactuser

id

_

Id de contacto de compra (puede ser el mismo de customer

_

id), referente a su registro en la

tabla users

conditions

id

_

Id de la condicion de venta, referente a su registro en la tabla conditions

Shipfromcontactuser

id

_

Id del usuario de contacto de la seccion Shipping From, referente a su registro en la tabla users

Shiptoclientuser

id

_

Id del usuario de contacto de la seccion Shipping To, referente a su registro en la tabla users

status

Status de la Sale Order,

Open: Status Inicial

Reserved: Cuando todos los items estan Reserved

Partially Reserved: Cuando hay al menos un item Reserved

Invoiced: cuando todos los items estan InvoicedVoided: cuando hacen void al SO

shipstatus

Status del Shipment,

default para un SO nuevo: **Open**

Cuando ya tiene un shipment agendado: **Scheduled**

states

_

id

Estado para la aplicacion de taxes, va el id del state relacionado con el **state** del **shipment to**.

Los states estan en la tabla **states**

 