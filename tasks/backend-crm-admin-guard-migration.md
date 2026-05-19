# Backend Task: Migrar endpoints admin a CrmAdminGuard

**Fecha:** 2026-05-19
**Solicitado por:** Frontend
**Prioridad:** Alta
**Contexto:** Auth system — validación de token admin

---

## Contexto

El dashboard administrativo (Angular) autentica a sus usuarios a través del CRM (PHP/Symfony). El token que el angular guarda en `localStorage['token']` es emitido por el CRM y **no puede ser validado localmente** por el backend NestJS.

Para resolver esto se creó `CrmAdminGuard` (`src/core/crm/crm-admin.guard.ts`) en el backend, el cual:

1. Extrae el Bearer token del header `Authorization`
2. Llama a `POST ${CRM_API_URL}/auth/validate-token` con el token
3. El CRM PHP responde con los datos del usuario y su rol
4. Popula `request.user` con el formato que `RolesGuard` espera
5. Si el token es inválido → `401`. Si el CRM no responde → `503`

Este guard ya está implementado y funcionando. Actualmente solo se usa en `GET /v1/categories/admin/all-v2`.

---

## Tarea

### 1. Migrar todos los endpoints admin de `JwtAuthGuard` → `CrmAdminGuard`

El patrón es el mismo en todos los módulos:

**a) Importar `CrmModule` en el módulo del feature:**
```typescript
import { CrmModule } from 'core/crm/crm.module';

@Module({
  imports: [CrmModule],  // agregar
  ...
})
```

**b) Cambiar el guard en el controlador:**
```typescript
// Antes
import { JwtAuthGuard } from 'core/common/guards/jwt-auth.guard';
@UseGuards(JwtAuthGuard, RolesGuard)

// Después
import { CrmAdminGuard } from 'core/crm/crm-admin.guard';
@UseGuards(CrmAdminGuard, RolesGuard)
```

`RolesGuard` no cambia — `CrmAdminGuard` ya popula `request.user.roles` en el formato correcto.

---

### 2. Endpoints a migrar por módulo

#### `categories` — parcialmente migrado
| Endpoint | Estado |
|---|---|
| `GET /v1/categories/admin/all-v2` | ✅ Ya migrado |
| `GET /v1/categories/admin/all` | ⏳ Pendiente |
| `POST /v1/categories` | ⏳ Pendiente |
| `PATCH /v1/categories/:id` | ⏳ Pendiente |
| `PATCH /v1/categories/:id/toggle` | ⏳ Pendiente |
| `DELETE /v1/categories/:id` | ⏳ Pendiente |

#### `faqs`
| Endpoint | Estado |
|---|---|
| `POST /v1/faqs` | ⏳ Pendiente |
| `PATCH /v1/faqs/:id` | ⏳ Pendiente |
| `PATCH /v1/faqs/:id/toggle` | ⏳ Pendiente |
| `DELETE /v1/faqs/:id` | ⏳ Pendiente |

#### `price-config`
| Endpoint | Estado |
|---|---|
| `GET /v1/price-config` | ⏳ Pendiente |
| `GET /v1/price-config/channel/:channel` | ⏳ Pendiente |
| `GET /v1/price-config/history` | ⏳ Pendiente |
| `PATCH /v1/price-config/:id` | ⏳ Pendiente |

#### `notifications`
| Endpoint | Estado |
|---|---|
| `GET /v1/notifications/templates` | ⏳ Pendiente |
| `GET /v1/notifications/templates/:key` | ⏳ Pendiente |
| `PATCH /v1/notifications/templates/:key` | ⏳ Pendiente |
| `GET /v1/notifications/deliveries` | ⏳ Pendiente |

#### `system-config`
| Endpoint | Estado |
|---|---|
| `GET /v1/system-config` | ⏳ Pendiente |
| `GET /v1/system-config/:key` | ⏳ Pendiente |
| `PATCH /v1/system-config/:key` | ⏳ Pendiente |

---

### 3. Endpoints que NO deben modificarse

Los siguientes endpoints **ya están correctos** y no requieren cambios:

**Públicos (sin guard):**
- `GET /v1/categories`, `GET /v1/categories/:id`
- `GET /v1/faqs`, `GET /v1/faqs/groups/:group`, `GET /v1/faqs/:id`
- Todos los endpoints de auth (register, login, refresh, forgot/reset password, verify-email)

**Token de cliente — `JwtAuthGuard` correcto:**
- Todos los `GET|POST|PATCH|DELETE /v1/users/me/*`
- `POST /v1/auth/logout`
- `POST /v1/auth/crm/link/initiate`
- `POST /v1/auth/crm/link/confirm`

---

### 4. Endpoint obsoleto — evaluar eliminación

`POST /v1/auth/admin/login` fue diseñado para un flujo de doble token (el dashboard intercambiaba el token del CRM por un JWT propio del backend). Ese flujo **no se implementó** — el dashboard envía el token del CRM directamente a cada endpoint, donde `CrmAdminGuard` lo valida.

Este endpoint no tiene consumidores activos. Se recomienda marcarlo como deprecated o eliminarlo, previa confirmación de que ninguna otra app lo esté usando.

---

## Variables de entorno requeridas

Asegurarse de que los ambientes tengan configuradas:

```env
CRM_API_URL=https://www.greenteksolutions.com/web   # con www
SERVICE_API_KEY=14-ECOMMERCE-2026-DEV               # api key del CRM
```

La URL **debe incluir `www`** — sin él el CRM responde 405.

---

## Referencia

- Guard implementado: `src/core/crm/crm-admin.guard.ts`
- Módulo: `src/core/crm/crm.module.ts`
- Ejemplo completo de módulo con el guard: `src/modules/categories/categories.module.ts`
- Ejemplo completo de controlador con el guard: `src/modules/categories/controllers/v1/categories.controller.ts`
