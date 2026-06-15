# Backend Task: Expand R2V3 enum validation in POST /v1/listings

## Context

The `POST /v1/listings` DTO currently validates the three R2V3 fields with a restricted
subset of values. The frontend uses the full R2V3 standard (C0–C9, F1–F6, and two
data sanitization states), so the current validation will reject valid listings.

## Problem

### `r2v3DataSanitization`

| Frontend value | Backend accepts | Action needed |
|----------------|-----------------|---------------|
| `Non-Data` | `NON_DATA` ✓ (format only) | Frontend will send `NON_DATA` |
| `Pre-Sanitization` | ❌ Not in DTO | Add `PRE_SANITIZATION` |

### `r2v3Cosmetic`

| Frontend value | Backend accepts |
|----------------|-----------------|
| `C0` | ❌ |
| `C1` | ✓ |
| `C2` | ✓ |
| `C3` | ✓ |
| `C4` | ❌ |
| `C5` | ❌ |
| `C6` | ❌ |
| `C7` | ❌ |
| `C8` | ❌ |
| `C9` | ❌ |

### `r2v3Functionality`

| Frontend value | Backend accepts |
|----------------|-----------------|
| `F1` | ✓ |
| `F2` | ✓ |
| `F3` | ✓ |
| `F4` | ❌ |
| `F5` | ❌ |
| `F6` | ❌ |

## Required changes in `create-listing.dto.ts`

```typescript
// Before
@IsIn(['NON_DATA'])
r2v3DataSanitization?: string;

@IsIn(['C1', 'C2', 'C3'])
r2v3Cosmetic?: string;

@IsIn(['F1', 'F2', 'F3'])
r2v3Functionality?: string;

// After
@IsIn(['NON_DATA', 'PRE_SANITIZATION'])
r2v3DataSanitization?: string;

@IsIn(['C0', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9'])
r2v3Cosmetic?: string;

@IsIn(['F1', 'F2', 'F3', 'F4', 'F5', 'F6'])
r2v3Functionality?: string;
```

## Notes

- The C and F values sent by the frontend already use the correct format — no
  conversion needed on the frontend side.
- For `r2v3DataSanitization` the frontend will normalize the string to
  `UPPER_SNAKE_CASE` before sending (`Non-Data` → `NON_DATA`,
  `Pre-Sanitization` → `PRE_SANITIZATION`).
- If the database or downstream services also store these values, their schemas
  and validations should be updated accordingly.
