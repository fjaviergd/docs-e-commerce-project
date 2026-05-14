# Requerimiento: Endpoint de Validación de Tokens para eCommerce Admin

**Para:** Equipo Backend PHP / CRM  
**De:** Equipo Backend eCommerce (NestJS)  
**Versión:** 1.0  
**Fecha:** 2026-05-11  
**Estado:** Pendiente de implementación

---

## 1. Contexto

El proyecto **GTS eStore** es una plataforma de eCommerce construida en NestJS (Node.js) que opera de forma independiente al CRM actual. Su panel administrativo estará integrado dentro de la aplicación Angular del CRM, lo que significa que los usuarios administrativos (managers, sales reps, purchasing reps, etc.) operarán el eCommerce **desde la misma app del CRM donde ya están autenticados**.

**El problema que este endpoint resuelve:**

Los usuarios admin ya inician sesión en el CRM y el CRM les emite un JWT. Cuando ese mismo usuario navega al módulo de administración del eCommerce dentro del CRM y realiza una acción (crear una categoría, actualizar un pedido, etc.), la app Angular enviará ese JWT al API de NestJS.

NestJS no conoce los JWTs del CRM — no fue quien los emitió y no tiene el secreto de firma. Por lo tanto, **necesita pedirle al CRM que valide el token en su nombre** antes de procesar cualquier solicitud administrativa.

---

## 2. Flujo de integración

```
┌─────────────────┐          ┌──────────────────────┐          ┌──────────────────┐
│  Angular (CRM)  │          │  NestJS (eCommerce)  │          │   PHP (CRM API)  │
└────────┬────────┘          └──────────┬───────────┘          └────────┬─────────┘
         │                              │                                │
         │  POST /admin/categories      │                                │
         │  Authorization: Bearer <JWT> │                                │
         │─────────────────────────────▶│                                │
         │                              │                                │
         │                              │  POST /api/auth/validate-token │
         │                              │  x-api-key: <SERVICE_KEY>      │
         │                              │  { "token": "<JWT>" }          │
         │                              │───────────────────────────────▶│
         │                              │                                │
         │                              │    { "valid": true, "user": …} │
         │                              │◀───────────────────────────────│
         │                              │                                │
         │                              │  [procesa la solicitud]        │
         │                              │                                │
         │  201 Created { … }           │                                │
         │◀─────────────────────────────│                                │
         │                              │                                │
         │  — — — — — — — caso inválido — — — — — —                      │
         │                              │                                │
         │                              │  POST /api/auth/validate-token │
         │                              │───────────────────────────────▶│
         │                              │                                │
         │                              │   { "valid": false, "reason":  │
         │                              │     "expired" }                │
         │                              │◀───────────────────────────────│
         │                              │                                │
         │  401 Unauthorized            │                                │
         │  { "message": "Token inválido o expirado" }                   │
         │◀─────────────────────────────│                                │
```

Cuando Angular recibe un `401` con código de token inválido, debe cerrar la sesión del usuario y redirigirlo al login.

---

## 3. Especificación del endpoint

### 3.1 Definición

| Campo             | Valor                              |
| ----------------- | ---------------------------------- |
| **Método**        | `POST`                             |
| **Ruta**          | `/api/auth/validate-token`         |
| **Autenticación** | Header `x-api-key` (ver sección 5) |
| **Content-Type**  | `application/json`                 |

### 3.2 Request

**Headers requeridos:**

```
x-api-key: <SERVICE_API_KEY>
Content-Type: application/json
```

**Body:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

| Campo   | Tipo     | Requerido | Descripción                                                                  |
| ------- | -------- | --------- | ---------------------------------------------------------------------------- |
| `token` | `string` | Sí        | El JWT del usuario tal como fue emitido por el CRM. Sin el prefijo `Bearer`. |

### 3.3 Response — Token válido

**HTTP 200 OK**

```json
{
  "user": {
    "id": "123",
    "email": "admin@greentek.com",
    "firstName": "John",
    "lastName": "Doe",
    "role": "MANAGER"
  }
}
```

| Campo            | Tipo     | Descripción                                                            |
| ---------------- | -------- | ---------------------------------------------------------------------- |
| `user.id`        | `string` | Identificador único del usuario en el CRM.                             |
| `user.email`     | `string` | Email del usuario.                                                     |
| `user.firstName` | `string` | Nombre del usuario.                                                    |
| `user.lastName`  | `string` | Apellido del usuario.                                                  |
| `user.role`      | `string` | Rol asignado al usuario en el CRM. Ver sección 4 para valores válidos. |

### 3.4 Response — Token inválido

Cada caso de rechazo retorna su propio HTTP status con el campo `reason` en el body para mayor detalle.

**401 Unauthorized** — problemas con el token mismo:

```json
{ "reason": "expired" }
```

**403 Forbidden** — token válido pero usuario sin acceso:

```json
{ "reason": "user_inactive" }
```

**404 Not Found** — el usuario referenciado en el token no existe:

```json
{ "reason": "not_found" }
```

| HTTP Status | `reason`            | Descripción                                                                  |
| ----------- | ------------------- | ---------------------------------------------------------------------------- |
| `401`       | `invalid_signature` | La firma del token no corresponde — token malformado o manipulado.           |
| `401`       | `expired`           | El token es criptográficamente válido pero ya expiró.                        |
| `401`       | `revoked`           | El token fue invalidado explícitamente (logout, cambio de contraseña, etc.). |
| `403`       | `user_inactive`     | El usuario existe pero está desactivado o suspendido en el CRM.              |
| `404`       | `not_found`         | El token no corresponde a ningún usuario conocido.                           |

### 3.5 Response — Sin API Key o API Key inválida

**HTTP 401 Unauthorized** — este `401` es diferente a los de la sección 3.4: indica que la llamada no proviene de un servicio autorizado, no que el token del usuario sea inválido.

```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing API key"
}
```

---

## 4. Roles válidos esperados

NestJS utilizará el rol devuelto en `user.role` para autorizar operaciones específicas del eCommerce. Se espera que el campo contenga uno de los siguientes valores (en mayúsculas):

| Rol             | Acceso esperado en eCommerce                                                   |
| --------------- | ------------------------------------------------------------------------------ |
| `ADMINISTRATOR` | Acceso total, incluyendo configuración global (precios, descuentos, carriers). |
| `MANAGER`       | Gestión de listings, órdenes, clientes, inventario, FAQ.                       |
| `SALESREP`      | Gestión de órdenes y clientes.                                                 |
| `PURCHASINGREP` | Gestión de inventario y listings.                                              |

> Si en el futuro se agregan roles nuevos, notificar al equipo de NestJS para actualizar las reglas de autorización.

---

## 5. Seguridad del endpoint (service-to-service)

Este endpoint **no es público**. Solo debe responder a llamadas provenientes del API de NestJS del eCommerce.

**Mecanismo de autenticación:** Header `x-api-key`

- La API Key es **generada por el equipo de eCommerce (NestJS)** y compartida con el equipo CRM para que la configuren en sus variables de entorno. El equipo CRM no la define, solo la recibe y la valida en cada request entrante.
- Si la key está ausente o es incorrecta, responder `401` inmediatamente sin procesar el body.
- La key debe tener al menos 32 caracteres aleatorios (recomendado: UUID v4 o similar).
- **Rotación:** se recomienda rotar la key cada 90 días o de forma inmediata ante cualquier sospecha de compromiso. El equipo de eCommerce generará la nueva key y la coordinará con el equipo CRM para que ambos lados la actualicen al mismo tiempo.

---

## 6. Casos de validación requeridos

PHP debe validar las siguientes condiciones **en este orden** y retornar el primer `reason` que aplique:

1. **Firma criptográfica** — ¿El token fue firmado con la clave secreta del CRM? Si no → `invalid_signature`
2. **Expiración** — ¿El campo `exp` del JWT ya pasó? Si sí → `expired`
3. **Revocación** — ¿El token fue invalidado (logout, cambio de contraseña, etc.)? Si sí → `revoked`
4. **Estado del usuario** — ¿El usuario asociado al token está activo en el CRM? Si no → `user_inactive`
5. **Todo lo anterior OK** → responder `valid: true` con datos del usuario

---

## 7. SLA y consideraciones de rendimiento

| Métrica                     | Requerimiento                            |
| --------------------------- | ---------------------------------------- |
| **Tiempo de respuesta p95** | < 200ms                                  |
| **Tiempo de respuesta p99** | < 500ms                                  |
| **Disponibilidad**          | Igual o mayor a la del CRM API existente |

---

## 8. Ejemplo de implementación sugerida (PHP)

Este ejemplo es orientativo — el equipo PHP puede implementarlo de la manera que considere más adecuada dentro de su arquitectura.

```php
// config/routes.yaml
# POST /api/auth/validate-token  →  App\Controller\AuthController::validateToken

// src/Controller/AuthController.php
namespace App\Controller;

use App\Repository\UserRepository;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class AuthController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly string $jwtSecret,
    ) {}

    #[Route('/api/auth/validate-token', methods: ['POST'])]
    public function validateToken(Request $request): JsonResponse
    {
        $body  = json_decode($request->getContent(), true);
        $token = $body['token'] ?? null;

        if (!$token) {
            return new JsonResponse(['reason' => 'invalid_signature'], 401);
        }

        // 1. Decodificar y verificar firma
        try {
            $payload = JWT::decode($token, new Key($this->jwtSecret, 'HS256'));
        } catch (ExpiredException) {
            return new JsonResponse(['reason' => 'expired'], 401);
        } catch (SignatureInvalidException|\Exception) {
            return new JsonResponse(['reason' => 'invalid_signature'], 401);
        }

        // 2. Verificar revocación (si aplica, ej: entidad TokenBlacklist en Doctrine)
        // if ($this->tokenBlacklistRepository->isRevoked($token)) {
        //     return new JsonResponse(['reason' => 'revoked'], 401);
        // }

        // 3. Verificar estado del usuario
        $user = $this->userRepository->find($payload->sub);
        if (!$user) {
            return new JsonResponse(['reason' => 'not_found'], 404);
        }
        if (!$user->isActive()) {
            return new JsonResponse(['reason' => 'user_inactive'], 403);
        }

        // 4. Token válido — retornar datos del usuario
        return new JsonResponse([
            'user' => [
                'id'        => (string) $user->getId(),
                'email'     => $user->getEmail(),
                'firstName' => $user->getFirstName(),
                'lastName'  => $user->getLastName(),
                'role'      => $user->getRole(),
            ],
        ]);
    }
}
```

---

## 9. Preguntas frecuentes

**¿Por qué NestJS no valida el JWT localmente con el secreto compartido?**  
Compartir el `jwt_secret` entre dos sistemas acopla sus ciclos de vida de seguridad. Si el CRM rota su secreto, NestJS fallaría silenciosamente. La introspección centralizada en PHP es la fuente de verdad correcta.

**¿Qué pasa si este endpoint está caído?**  
NestJS retornará `503 Service Unavailable` al cliente Angular, que deberá mostrar un error genérico. No se procesará ninguna acción administrativa hasta que el servicio se recupere.

**¿El endpoint puede recibir el token con el prefijo `Bearer `?**  
Preferiblemente no — NestJS enviará solo el token limpio. Sin embargo, si PHP decide soportar ambos formatos (con y sin prefijo `Bearer `), es bienvenido siempre que el comportamiento sea consistente.

**¿Necesitamos versionar este endpoint?**  
Por ahora no es necesario. Si en el futuro cambia el contrato de respuesta, coordinar con el equipo de NestJS con al menos 2 semanas de anticipación.

---

## 10. Contacto y coordinación

Para preguntas sobre este requerimiento o para coordinar la variable `SERVICE_API_KEY` que usarán ambos sistemas en desarrollo, contactar al equipo de backend eCommerce.

Antes de desplegar el endpoint en staging (pruebas), favor compartir la URL base del CRM API para configurar las variables de entorno en el ambiente de NestJS.
