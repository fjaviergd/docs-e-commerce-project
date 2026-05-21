# Backend Task: Auto-asignar sortOrder en FAQs y FAQ Groups

**Fecha:** 2026-05-20
**Solicitado por:** Frontend
**Prioridad:** Media
**Contexto:** Paridad con el comportamiento implementado en `categories`

---

## Contexto

En el módulo de categorías se implementó auto-asignación de `sortOrder` al crear nuevos registros (`MAX(sortOrder) + 1`), eliminando el campo del `CreateCategoryDto`. El mismo patrón debe aplicarse a **FAQs** y **FAQ Groups** para evitar que nuevos registros queden con `sortOrder: 0` y colisionen con registros existentes.

El frontend ya **no envía `sortOrder`** al crear FAQs ni FAQ Groups — el campo fue removido del formulario de creación. El reorder se gestiona exclusivamente vía los endpoints `PATCH /reorder` de cada módulo.

---

## Tarea

### 1. `FaqsService.create()`

Reemplazar el valor fijo `sortOrder: 0` por auto-asignación `MAX + 1`, limitado al mismo `groupId`:

```typescript
async create(dto: CreateFaqDto, user: JwtPayload): Promise<Faq> {
  const { _max } = await this.prisma.faq.aggregate({
    _max: { sortOrder: true },
    where: { groupId: dto.groupId },
  });
  const nextOrder = (_max.sortOrder ?? -1) + 1;

  return this.prisma.faq.create({
    data: {
      ...dto,
      sortOrder: nextOrder,
      createdBy: user.sub,
    },
  });
}
```

> **Nota:** el `sortOrder` en FAQs es **dentro del grupo**, no global. Por eso el `aggregate` filtra por `groupId`.

### 2. `CreateFaqDto` — remover `sortOrder`

```typescript
// Eliminar este bloque completo:
@ApiPropertyOptional({ ... })
@IsInt()
@Min(0)
@IsOptional()
sortOrder?: number;
```

### 3. `FaqGroupsService.create()`

Mismo patrón, pero el `sortOrder` en groups **sí es global** (no hay sub-agrupación):

```typescript
async create(dto: CreateFaqGroupDto, user: JwtPayload): Promise<FaqGroup> {
  const { _max } = await this.prisma.faqGroup.aggregate({
    _max: { sortOrder: true },
  });
  const nextOrder = (_max.sortOrder ?? -1) + 1;

  return this.prisma.faqGroup.create({
    data: {
      ...dto,
      sortOrder: nextOrder,
      createdBy: user.sub,
    },
  });
}
```

### 4. `CreateFaqGroupDto` — remover `sortOrder`

```typescript
// Eliminar este bloque completo:
@ApiPropertyOptional({ ... })
@IsInt()
@Min(0)
@IsOptional()
sortOrder?: number;
```

---

## Referencia

- Implementación equivalente en categories: `src/modules/categories/categories.service.ts` → método `create()`
- Endpoint de reorder FAQs: `PATCH /v1/faqs/reorder`
- Endpoint de reorder FAQ Groups: `PATCH /v1/faq-groups/reorder`
