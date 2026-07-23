# Expansión de validación de enums R2V3 en POST /v1/listings

El DTO de creación de listing validaba los 3 campos R2V3 con un subconjunto restringido de valores. El frontend usa el estándar R2V3 completo (C0–C9, F1–F6, y 2 estados de sanitización) — con la validación anterior, listings válidos se rechazaban con 400.

> **Estado: Diseño ✅ CERRADO · Implementación ✅ COMPLETA.**
>
> **Hecho (2026-07-23):** `create-listing.dto.ts` (los 3 `@IsIn([...])`) y el comentario de documentación en `schema.prisma` actualizados — commit `162af13` en rama `feature/r2v3`, pendiente de mergear a `develop`. **Sin migración de BD:** las columnas (`r2v3_data_sanitization`, `r2v3_cosmetic`, `r2v3_functionality`) son `VARCHAR` libres en Postgres — no hay `enum` a nivel de motor que ensanchar.

---

## 1. Problema

### `r2v3DataSanitization`

| Valor del frontend | Backend aceptaba (antes) |
|---|---|
| `NON_DATA` | ✓ |
| `PRE_SANITIZATION` | ❌ |

### `r2v3Cosmetic`

| Valor | Backend aceptaba (antes) |
|---|---|
| `C0` | ❌ |
| `C1`–`C3` | ✓ |
| `C4`–`C9` | ❌ |

### `r2v3Functionality`

| Valor | Backend aceptaba (antes) |
|---|---|
| `F1`–`F3` | ✓ |
| `F4`–`F6` | ❌ |

## 2. Cambio aplicado

```typescript
// Antes
@IsIn(['NON_DATA'])
r2v3DataSanitization?: string;

@IsIn(['C1', 'C2', 'C3'])
r2v3Cosmetic?: string;

@IsIn(['F1', 'F2', 'F3'])
r2v3Functionality?: string;

// Después (create-listing.dto.ts:322-342)
@IsIn(['NON_DATA', 'PRE_SANITIZATION'])
r2v3DataSanitization?: string;

@IsIn(['C0', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9'])
r2v3Cosmetic?: string;

@IsIn(['F1', 'F2', 'F3', 'F4', 'F5', 'F6'])
r2v3Functionality?: string;
```

## 3. Decisiones cerradas

1. **Sin conversión del lado del frontend** — los valores C/F ya llegan en el formato correcto; el frontend normaliza `r2v3DataSanitization` a `UPPER_SNAKE_CASE` antes de enviarlo (`Non-Data` → `NON_DATA`, `Pre-Sanitization` → `PRE_SANITIZATION`).
2. **Sin migración de esquema** — se confirmó que las 3 columnas en `schema.prisma` son `VARCHAR` sin `CHECK`/`enum` de Postgres; solo se actualizó el comentario de documentación (`schema.prisma:70-72`) para que no quede desactualizado.
3. **`backend-update-inventory-r2v3.md` depende de este cambio** — sin esta expansión, el DTO rechazaría antes de llegar a la lógica de update los mismos payloads que usan `C4`–`C9`/`F4`–`F6`/`PRE_SANITIZATION`. Se implementó primero por esto.

## 4. Pendiente

- Mergear `feature/r2v3` a `develop`.
- Confirmar si algún servicio downstream (CRM, dashboard) valida estos mismos valores con una lista más corta y necesita el mismo ajuste.
