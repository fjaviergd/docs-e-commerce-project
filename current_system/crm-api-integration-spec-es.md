# Especificación de Integración API CRM — Módulo de Autenticación E-Commerce

**Para:** Equipo Backend del Sistema Actual CRM (Symfony4)
**De:** Equipo Backend E-Commerce (NestJS)
**Fecha:** 2026-05-09
**Versión:** 1.0

---

## Resumen

La nueva plataforma e-commerce GTS (NestJS) requiere que el sistema actual CRM (Symfony4) exponga tres endpoints REST. Estos son necesarios para soportar dos flujos distintos:

1. **Autenticación de administradores** — El personal del CRM inicia sesión en el backoffice de e-commerce usando sus credenciales existentes del CRM. El sistema e-commerce no almacena contraseñas de administradores; delega la validación completamente al CRM.
2. **Vinculación de cuenta CRM del cliente** — Los clientes registrados en e-commerce pueden, de forma opcional, vincular su cuenta de la tienda con su registro de cliente en el CRM. Esto habilita precios personalizados y visibilidad del historial de pedidos en versiones futuras.

Estos endpoints no existen en la API actual del CRM. Este documento especifica exactamente lo que el sistema e-commerce espera, para que el equipo CRM pueda implementarlos.

---

## Autenticación

Todas las solicitudes del sistema e-commerce al CRM incluyen un encabezado con una clave API estática:

```
x-api-key: <CRM_API_KEY>
```

El valor de la clave se acuerda fuera de banda y se configura como variable de entorno en el lado del e-commerce (`CRM_API_KEY`). Las solicitudes sin este encabezado, o con una clave inválida, deben retornar `401 Unauthorized`.

---

## URL Base

El sistema e-commerce se configura mediante la variable de entorno `CRM_API_URL`. Todas las rutas a continuación son relativas a esa URL base.

Ejemplo: si `CRM_API_URL = https://www.greenteksolutions.com/web`, entonces la URL completa para el endpoint 1 es:
```
POST https://www.greenteksolutions.com/web/api/auth/login
```

---

## Endpoints

### 1. Login de Administrador

**Propósito:** Validar las credenciales del personal del CRM y retornar su identidad y roles.

```
POST /api/auth/login
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Cuerpo de la solicitud:**

```json
{
  "email": "admin@greentek.com",
  "password": "their-crm-password"
}
```

**Respuesta exitosa — `200 OK`:**

```json
{
  "id": 42,
  "email": "admin@greentek.com",
  "firstName": "Carlos",
  "lastName": "Mendoza",
  "roles": ["ADMINISTRATOR"]
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `integer` | ID único del usuario en el CRM. Se usa como el claim `sub` en el JWT emitido por el sistema e-commerce. |
| `email` | `string` | Debe coincidir con el email enviado en la solicitud. |
| `firstName` | `string` | Se usa para visualización en la interfaz del backoffice. |
| `lastName` | `string` | Se usa para visualización en la interfaz del backoffice. |
| `roles` | `string[]` | Uno o más roles. Ver valores válidos a continuación. |

**Valores de rol válidos:**

| Valor | Descripción |
|-------|-------------|
| `ADMINISTRATOR` | Acceso completo a todos los módulos del backoffice |
| `MANAGER` | Acceso a pedidos, listados e inventario |
| `PURCHASINGREP` | Acceso a los módulos de compras e inventario |
| `SALESREP` | Acceso a los módulos de pedidos y clientes |

> Los strings de rol son **sensibles a mayúsculas**. El sistema e-commerce los compara exactamente como son retornados. Utilice los valores en mayúsculas indicados arriba.

**Respuestas de error:**

| Código HTTP | Cuándo |
|-------------|--------|
| `401 Unauthorized` | Credenciales inválidas (contraseña incorrecta o email no encontrado) |
| `401 Unauthorized` | Encabezado `x-api-key` ausente o inválido |
| `5xx` | Cualquier error del lado del servidor (el e-commerce mostrará "servicio no disponible" al usuario) |

**Notas:**
- **No** retornar `200` con un payload de error ante un login fallido. El sistema e-commerce solo verifica códigos de estado HTTP.
- El sistema e-commerce **no** crea sesiones en el lado del CRM. Esta es una verificación de credenciales sin estado.
- El sistema e-commerce emite su propio JWT después de que esta llamada sea exitosa. Las solicitudes posteriores del administrador van directamente a la API e-commerce con ese JWT — no se realizan más llamadas al CRM por solicitud.

---

### 2. Iniciar Vinculación de Cliente CRM

**Propósito:** Iniciar el flujo de vinculación de cuentas. El CRM envía un código de verificación a la dirección de email del cliente registrada en el CRM.

```
POST /api/customers/link/initiate
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Cuerpo de la solicitud:**

```json
{
  "email": "customer@example.com"
}
```

Este es el email que el cliente utilizó para registrarse en la tienda e-commerce. El CRM debe verificar si existe un registro de cliente con ese email y enviarle un código de verificación de corta duración.

**Respuesta exitosa — `200 OK` o `202 Accepted`:**

Cuerpo vacío o cualquier cuerpo — el sistema e-commerce ignora el cuerpo de la respuesta en caso de éxito. Solo importa el estado HTTP.

**Respuestas de error:**

| Código HTTP | Cuándo |
|-------------|--------|
| `401 Unauthorized` | Encabezado `x-api-key` ausente o inválido |
| `404 Not Found` | *(Opcional)* No se encontró ningún cliente CRM con ese email |
| `5xx` | Cualquier error del lado del servidor |

**Notas:**
- El sistema e-commerce **no** diferencia un `404` ante el usuario. Desde la perspectiva del cliente, si no llega ningún código, simplemente no continúa. Puede optar por retornar `200` de forma silenciosa aunque el email no se encuentre (para evitar exponer la existencia de clientes en el CRM).
- El código de verificación debe expirar en **10 a 15 minutos**.
- El mecanismo de entrega del código (plantilla de email, remitente) es responsabilidad del equipo CRM.

---

### 3. Verificar Vinculación de Cliente CRM

**Propósito:** Validar el código recibido por el cliente y retornar su ID de referencia CRM para que el sistema e-commerce pueda almacenar la asociación.

```
POST /api/customers/link/verify
Content-Type: application/json
x-api-key: <CRM_API_KEY>
```

**Cuerpo de la solicitud:**

```json
{
  "email": "customer@example.com",
  "code": "483920"
}
```

**Respuesta exitosa — `200 OK`:**

```json
{
  "crmReferenceId": "CUST-00042"
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `crmReferenceId` | `string` | El identificador interno del CRM para este cliente. Se almacena en la base de datos del e-commerce como referencia — no se interpreta ni se utiliza para realizar más llamadas al CRM en V1. |

**Respuestas de error:**

| Código HTTP | Cuándo |
|-------------|--------|
| `400 Bad Request` | El código es incorrecto, ha expirado o ya fue usado |
| `422 Unprocessable Entity` | Alternativa para código inválido o expirado |
| `401 Unauthorized` | Encabezado `x-api-key` ausente o inválido |
| `5xx` | Cualquier error del lado del servidor |

**Notas:**
- El sistema e-commerce trata tanto `400` como `422` como "código inválido" y retorna una `UnauthorizedException` al cliente.
- Tras una verificación exitosa, el código debe ser invalidado (uso único).

---

## Tabla Resumen

| # | Endpoint | Método | Disparador |
|---|----------|--------|------------|
| 1 | `/api/auth/login` | `POST` | El administrador hace clic en "Iniciar sesión" en el backoffice |
| 2 | `/api/customers/link/initiate` | `POST` | El cliente hace clic en "Vincular mi cuenta CRM" |
| 3 | `/api/customers/link/verify` | `POST` | El cliente envía el código de verificación |

---

## Requisitos No Funcionales

| Requisito | Valor |
|-----------|-------|
| **Timeout** | El sistema e-commerce agota el tiempo de espera tras **5 segundos**. El CRM debe responder dentro de ese margen o el e-commerce retornará `503 Service Unavailable` al usuario. |
| **Content-Type** | Todas las respuestas deben ser `application/json`. |
| **HTTPS** | Requerido en producción. La URL del CRM configurada en e-commerce usará `https://`. |
| **Disponibilidad** | El endpoint 1 (login de administrador) está en la ruta crítica de cada sesión de administrador. Los endpoints 2 y 3 son iniciados por el usuario y menos frecuentes. |

---

## Preguntas para el Equipo CRM

Antes de la implementación, por favor confirmar:

1. **Roles** — ¿Son `ADMINISTRATOR`, `MANAGER`, `PURCHASINGREP`, `SALESREP` los identificadores de rol exactos usados en el CRM, o difieren en mayúsculas/minúsculas o nomenclatura?
2. **Usuarios con múltiples roles** — ¿Puede un usuario del CRM tener más de un rol simultáneamente? De ser así, ¿deben retornarse todos los roles en el array `roles`?
3. **Formato de `crmReferenceId`** — ¿Cuál es el formato del identificador de cliente que el CRM retornará en el endpoint 3? (entero, cadena, código con prefijo). El e-commerce lo almacena como `varchar(100)`.
4. **Coincidencia de email del cliente** — Para el endpoint 2, ¿debe el CRM buscar el email en el campo de `so_info`, en la tabla `customers`, o en otra tabla?
5. **Entorno de pruebas** — ¿Hay una URL de staging del CRM disponible para pruebas de integración antes de producción?

---

## Contacto

Equipo Backend E-Commerce — ante cualquier duda sobre esta especificación, comuníquese antes de la implementación para evitar desalineaciones.
