# Backend Task: Resend Verification Email

**Fecha:** 2026-05-13  
**Solicitado por:** Frontend  
**Prioridad:** Media  
**Contexto:** Auth system — flujo de verificación de email

---

## Problema

Cuando un usuario se registra, recibe un email con un link de verificación válido por **24 horas**. Si el usuario no hace clic a tiempo, el token expira y queda en un estado bloqueado:

- La cuenta existe en la base de datos con `emailVerified: false`
- No puede iniciar sesión (el backend rechaza con 403)
- No puede registrarse de nuevo con el mismo email (el backend responde 409 conflict)
- No tiene forma de salir de este estado sin intervención manual

La solución es un endpoint que genere un nuevo token de verificación y reenvíe el email.

---

## Endpoint requerido

```
POST /v1/auth/resend-verification
```

### Request body

```json
{
  "email": "user@example.com"
}
```

**Validación:**
- `email`: requerido, formato email válido

### Respuesta exitosa

```
HTTP 202 Accepted
(sin body)
```

### Comportamiento de seguridad

**Siempre responder 202**, sin importar si el email existe o no en la base de datos. Esto evita enumerar usuarios (el atacante no puede saber qué emails están registrados).

---

## Cambio adicional requerido en POST /v1/auth/login

El endpoint de login actualmente devuelve un 403 genérico cuando el email no está verificado. Para que el frontend pueda mostrar el mensaje y botón correctos, se necesita distinguir entre dos situaciones:

| Situación | Código de error sugerido |
|-----------|--------------------------|
| Email registrado, token aún vigente (< 24h) | `EMAIL_NOT_VERIFIED` |
| Email registrado, token ya expirado (> 24h) | `VERIFICATION_TOKEN_EXPIRED` |

**Respuesta sugerida:**

```json
// Token aún válido
{
  "statusCode": 403,
  "code": "EMAIL_NOT_VERIFIED",
  "message": "Email not verified"
}

// Token expirado
{
  "statusCode": 403,
  "code": "VERIFICATION_TOKEN_EXPIRED",
  "message": "Verification token expired"
}
```

Esto permite al frontend mostrar mensajes precisos al usuario sin lógica extra del lado del cliente.

---

## Lógica de negocio

1. Buscar usuario por email
2. Si el usuario **no existe** → responder 202 (silencioso, sin acción)
3. Si el usuario **ya está verificado** → responder 202 (silencioso, sin acción)
4. Si el usuario **existe y no está verificado**:
   a. Invalidar tokens de verificación anteriores no usados (marcar `usedAt = now()` o eliminarlos)
   b. Generar nuevo token de verificación (32 bytes hex, guardar SHA256 en BD)
   c. Establecer nueva expiración: **24 horas** desde ahora
   d. Encolar job de email (BullMQ) con el nuevo token — reutilizar job `verify-email` existente
   e. Responder 202

### Rate limiting (recomendado)

Para evitar abuso (spam de emails), aplicar rate limit por dirección de email:
- Máximo **3 solicitudes por hora** por email
- Si se excede el límite, responder 202 igualmente (no revelar el límite al cliente)

---

## Email a enviar

Mismo template que el email de verificación inicial, con el mismo link:

```
${APP_URL}/verify-email?token=<nuevo_token_raw>
```

Se puede reutilizar el job existente de BullMQ (`verify-email`) y el método `sendVerificationEmail()` del MailerService.

---

## Casos de uso que resuelve

| Escenario | Comportamiento actual | Con este endpoint |
|-----------|----------------------|-------------------|
| Token expirado (24h) | Usuario bloqueado | Puede solicitar nuevo link |
| Email no llegó (spam / error de entrega) | Usuario bloqueado | Puede solicitar reenvío |
| Usuario real cuyo email fue registrado por error | Bloqueado indefinidamente | Puede reclamar la cuenta |

---

## Archivos de referencia en el backend

| Archivo | Relevancia |
|---------|-----------|
| `src/modules/auth/auth.service.ts` | Método `registerCustomer()` — misma lógica de generación de token |
| `src/modules/auth/auth.controller.ts` | Donde agregar el nuevo endpoint |
| `src/modules/mail/mailer.service.ts` | Método `sendVerificationEmail()` — reutilizar |
| `src/modules/auth/dto/v1/` | Crear `resend-verification.dto.ts` con campo `email` |
| `prisma/schema.prisma` | Modelo `AuthToken` — misma estructura, mismo tipo `verify_email` |

---

## Decisión de UX — Flujo elegido

Se evaluaron tres enfoques. Se eligió el **Flujo B: botón explícito con acción del usuario**.

### Flujo elegido (Opción B)

```
1. Usuario intenta hacer login
           ↓
2. Backend responde 403 con código EMAIL_NOT_VERIFIED o VERIFICATION_TOKEN_EXPIRED
           ↓
3. Frontend muestra la pantalla de login con el mensaje:
   "Your email isn't verified yet. We need to confirm it's really you before you can sign in."
   + botón: [Resend verification email]
           ↓
4. Usuario hace clic en el botón
           ↓
5. Frontend llama POST /v1/auth/resend-verification con el email
           ↓
6. Backend genera nuevo token y reenvía el email
           ↓
7. El botón cambia a: "We sent a new link to {email}. Check your inbox (and spam folder)."
           ↓
8. Usuario abre el email → hace clic en el link → /verify-email?token=X → cuenta activada
           ↓
9. Usuario regresa a /login → inicia sesión normalmente
```

### Por qué este flujo y no el automático

Se descartó la opción de reenviar el email automáticamente al detectar el token expirado por las siguientes razones:

1. **El usuario no sabe qué pasó.** Si el sistema actúa silenciosamente, el usuario ve un error de login sin contexto. No sabe que debe ir a revisar su correo en ese momento.

2. **El usuario que toma una acción consciente está listo para recibirla.** Al hacer clic en "Resend", el usuario está frente a su correo o va a abrirlo de inmediato. Un email automático puede llegar cuando el usuario ya cerró la sesión o está haciendo otra cosa.

3. **Riesgo de abuso.** El reenvío automático en cada intento de login permite que cualquier persona bombardee la bandeja de entrada de un email registrado simplemente intentando hacer login repetidamente.

4. **Principio de UX:** nunca ejecutar acciones importantes (como enviar un email) en nombre del usuario sin que él lo solicite explícitamente, aunque sea con un solo clic.

---

## Integración en el frontend (pendiente hasta que el endpoint esté listo)

Una vez implementado, el frontend agregará:

1. **Route Handler:** `POST /api/auth/resend-verification`
2. **UI en `/login`:** Cuando el backend devuelve 403 con código `EMAIL_NOT_VERIFIED` o `VERIFICATION_TOKEN_EXPIRED`, mostrar el mensaje explicativo y el botón de reenvío
3. **UI en `/verify-email`:** Cuando el token es inválido o expirado, incluir también el botón de reenvío como alternativa de recuperación
