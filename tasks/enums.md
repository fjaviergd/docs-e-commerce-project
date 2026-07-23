# Enums de condición eBay — aceptar el mapeo completo (HAN-16)

El `condition` de un listing debe aceptar los 16 valores del `CONDITION_MAPPING` de eBay (issue Linear `HAN-16`, equipo H&A Software), no solo un subconjunto.

> **Estado: Implementación ✅ MERGEADA a `develop`.**
>
> El `@IsIn([...])` de `condition` en `create-listing.dto.ts:184-200` ya incluye los 16 valores exactos del mapeo pedido en `HAN-16` — no requiere cambios adicionales.

---

## 1. Mapeo pedido (issue `HAN-16`)

```javascript
const CONDITION_MAPPING = [
  { conditionId: '1000', enumValue: 'NEW' },
  { conditionId: '1500', enumValue: 'NEW_OTHER' },
  { conditionId: '1750', enumValue: 'NEW_WITH_DEFECTS' },
  { conditionId: '2000', enumValue: 'CERTIFIED_REFURBISHED' },
  { conditionId: '2010', enumValue: 'EXCELLENT_REFURBISHED' },
  { conditionId: '2020', enumValue: 'VERY_GOOD_REFURBISHED' },
  { conditionId: '2030', enumValue: 'GOOD_REFURBISHED' },
  { conditionId: '2500', enumValue: 'SELLER_REFURBISHED' },
  { conditionId: '2750', enumValue: 'LIKE_NEW' },
  { conditionId: '2990', enumValue: 'PRE_OWNED_EXCELLENT' },
  { conditionId: '3000', enumValue: 'USED_EXCELLENT' },
  { conditionId: '3010', enumValue: 'PRE_OWNED_FAIR' },
  { conditionId: '4000', enumValue: 'USED_VERY_GOOD' },
  { conditionId: '5000', enumValue: 'USED_GOOD' },
  { conditionId: '6000', enumValue: 'USED_ACCEPTABLE' },
  { conditionId: '7000', enumValue: 'FOR_PARTS_OR_NOT_WORKING' },
];
```

## 2. Estado en código

`CreateListingChannelEbayDto.condition` (`create-listing.dto.ts:183-200`) valida contra los 16 `enumValue` de arriba, uno a uno, sin faltantes ni valores extra:

```typescript
@IsIn([
  'NEW', 'NEW_OTHER', 'NEW_WITH_DEFECTS', 'CERTIFIED_REFURBISHED',
  'EXCELLENT_REFURBISHED', 'VERY_GOOD_REFURBISHED', 'GOOD_REFURBISHED',
  'SELLER_REFURBISHED', 'LIKE_NEW', 'PRE_OWNED_EXCELLENT', 'USED_EXCELLENT',
  'PRE_OWNED_FAIR', 'USED_VERY_GOOD', 'USED_GOOD', 'USED_ACCEPTABLE',
  'FOR_PARTS_OR_NOT_WORKING',
])
@IsOptional()
condition?: string;
```

Solo valida el `enumValue` que envía el backend/frontend — el `conditionId` numérico (columna izquierda del mapeo) es responsabilidad de eBay al recibir el `enumValue` en el publish; este DTO no necesita guardar esa tabla de traducción.

## 3. Sin trabajo pendiente

No se identificó ningún otro punto del código (DTOs, entidades, servicios de eBay) que valide `condition` con una lista distinta o más corta. Sin acción adicional.
