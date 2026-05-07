# Soft Deletes — Revisión pendiente del equipo de backend

> Estado: **propuesta inicial** — requiere revisión y aprobación del equipo de backend antes de implementar.  
> Contexto: el sistema anterior usaba `deleted_at` en todas las tablas. Este documento propone un patrón diferenciado según el tipo de tabla.

---

## Propuesta por tabla

| Tabla | Patrón propuesto | Razón |
|-------|-----------------|-------|
| `listings` | `status = inactive` | Ya tiene ciclo de vida con estado propio — `inactive` es el equivalente al soft delete |
| `listing_variations` | `status = inactive` | Idem — ya tiene `status` con `active \| out_of_stock \| inactive` |
| `gts_categories` | `is_active = false` | Catálogo de referencia — no se puede hard delete porque hay FKs activas |
| `listing_channel_ebay` | `deleted_at` timestamp | Útil conservar historial de configuración del canal aunque se desvinculé |
| `listing_channel_gts_store` | `deleted_at` timestamp | Idem |
| `price_config` | `deleted_at` timestamp | Auditoría de cambios de configuración global de precios |
| `listing_images` | Hard delete | Borrar una imagen es una acción definitiva — no necesita recuperación |
| `listing_inventory_links` | Hard delete | Desvincular un ítem de inventario es definitivo |
| `listing_variation_axes` | Hard delete | Si se elimina un eje es porque se reestructuran las variaciones |
| `listing_pricing` | Hard delete | Va ligado al ciclo de vida del listing |
| `listing_stock` | Hard delete | Se recrea al relinkear inventario |
| `listing_stock_movements` | **Nunca borrar** | Es un ledger contable — borrar movimientos rompe la integridad del historial |
| `listing_channel_ebay_variations` | Hard delete | Datos operativos de eBay, se recrean al republicar |
| `gts_category_ebay_map` | Hard delete | Si existe esta tabla en el futuro — el mapeo se puede recrear |

---

## Preguntas abiertas para el equipo de backend

1. **`listing_images`** — ¿El equipo prefiere soft delete para poder recuperar imágenes borradas por error, o hard delete es suficiente dado que la imagen original siempre existe en el servidor privado?

2. **`listing_inventory_links`** — Si se desvincula un ítem de inventario de un listing por error, ¿hay necesidad de recuperarlo o simplemente se vuelve a vincular?

3. **`listing_channel_ebay` y `listing_channel_gts_store`** — ¿Se contempla el caso de querer "archivar" la configuración de un canal sin perderla (ej. despublicar de eBay temporalmente pero conservar todos los IDs y configuración)?

4. **Consistencia general** — ¿Prefieren `deleted_at` uniforme en todas las tablas aunque no sea estrictamente necesario en algunas (más fácil de razonar), o el patrón diferenciado propuesto arriba?

5. **Cascadas** — Para las tablas con hard delete, ¿el ORM maneja los deletes en cascada o se prefiere que la app los controle explícitamente?

---

## Nota sobre `listing_stock_movements`

Esta tabla es un ledger contable — registra todos los eventos de stock con su timestamp. Borrar filas de esta tabla haría que el `SUM(quantity_delta)` no coincida con `listing_stock.quantity_available`, rompiendo la integridad del sistema. **Esta tabla nunca debe tener delete de ningún tipo.**

Si se necesita "corregir" un movimiento incorrecto, la forma correcta es agregar un movimiento compensatorio (ej. si se registró `-5` por error, agregar `+5` con `movement_type = ADJUSTMENT` y una nota explicativa).
