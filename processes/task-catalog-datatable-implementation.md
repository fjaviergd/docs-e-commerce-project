# Task: Implementación del sistema de catálogos con data table reutilizable

## Contexto

El frontend de `ebay-listings` contiene un data table completo (filtros, vistas guardadas, paginación, sorting, acciones por fila, selección masiva, exportación) que sirvió como piloto. El diseño fue aprobado. Ahora hay que crear los componentes reutilizables basados en ese piloto y aplicarlos en los nuevos catálogos.

**Documentos de referencia:**
- [`table-views-setup-guide.md`](./table-views-setup-guide.md) — Cómo registrar cualquier tabla nueva en el sistema de vistas
- [`ecommerce-categories-table-views-setup.md`](./ecommerce-categories-table-views-setup.md) — Registros de BD ya realizados para `ecommerce_categories`

---

## Estado al momento de dejar pausada esta tarea

- [x] Registros de BD creados para `ecommerce_categories` (table_metadata, table_column_metadata, role_table_column_permission, vista DEFAULT)
- [ ] Frontend: componentes reutilizables no creados aún
- [ ] Backend: endpoint GET de categorías no alineado al patrón V2 de filtros dinámicos

---

## Trabajo pendiente

### 1. Crear los componentes reutilizables en el frontend

Ubicación propuesta: `gtsdashboard/src/app/e-commerce/shared/catalog-table/`

Basarse en `ebay-listings` como referencia. **No modificar el componente de listings** — está en producción.

#### Componentes a extraer

**`filter-chip/`** — El sistema de filtros (prioridad alta)
- `filter-chip.component` — El chip/botón que muestra el filtro activo y lo limpia
- `filter-popover-text.component` — Popover para filtros tipo texto y número
- `filter-popover-select.component` — Popover para filtros tipo select/enum
- `filter-popover-daterange.component` — Popover para rango de fechas
- `filter-popover-boolean.component` — Popover para filtros booleanos
- `filter-chip.types.ts` — Interfaces: `FilterChipConfig`, `FilterValue`
- `filters-to-api.util.ts` — Función `mapFiltersToApi()` (UI → API)

**`catalog-toolbar/`** — Toolbar + barra de selección masiva
- `catalog-toolbar.component` — Acepta acciones como `@Input()`, emite eventos

**`catalog-table.styles.css`** — CSS compartido (variables, toolbar, filter bar, scroll container, badges)

#### Lo que cada catálogo nuevo maneja por su cuenta
- Su propia `mat-table` con las columnas específicas de la entidad
- La lógica de carga de datos (llamada al API)
- Definición de sus `FilterChipConfig[]` y `ColumnConfig[]`
- Su propio servicio de API
- Su propio modal de crear/editar

---

### 2. Crear la página de categorías

Ruta: `gtsdashboard/src/app/e-commerce/pages/categories/`

**Campos de la entidad** (ver `backend/src/modules/categories`):

| column_key | Tipo | Notas |
|---|---|---|
| `id` | string (UUID) | No mostrar por defecto |
| `name` | string | Columna principal |
| `isActive` | boolean | Badge activo/inactivo |
| `sortOrder` | number | Orden de visualización |
| `createdAt` | date | — |
| `updatedAt` | date | — |

**Filter chips sugeridos:**

| Chip | Tipo | Condiciones |
|---|---|---|
| Name | `text` | Contains, Equals, Starts with |
| Status | `boolean` | Active / Inactive |
| Sort Order | `number` | Equals, Greater than, Less than, Between |
| Created At | `daterange` | Between |
| Updated At | `daterange` | Between |

**tableKey para vistas:** `ecommerce_categories`

**Sort por defecto:** `sortOrder ASC`

**Modal crear/editar — campos del formulario:**

| Campo | Input | Validación |
|---|---|---|
| Name | Text | Requerido, max 100 chars |
| Sort Order | Number | Opcional, min 0, default 0 |
| Status | Toggle (isActive) | Default activo |
| Icon | Text | Opcional, nombre del icono (ej: `laptop`) |
| Image | Text (URL) | Opcional, URL de la imagen de la categoría |

> `icon` e `image` son los campos que los administradores usarán para que el ecommerce renderice visualmente cada categoría en el storefront. El backend ya los soporta en `POST /v1/categories` y `PATCH /v1/categories/:id`.

---

### 3. Ajustar el endpoint GET de categorías en el backend

Archivo: `backend/src/modules/categories/`

El endpoint actual (`GET /v1/categories`) solo acepta `page` y `limit`. Necesita ser actualizado para aceptar el patrón V2:

**Query params requeridos:**
- `filters` — JSON stringificado con array de `ApiFilter`
- `sortBy` — nombre del campo (ej: `sortOrder`, `name`)
- `order` — `ASC` | `DESC`
- `page` — número de página (1-indexed)
- `limit` — items por página

**Response esperada:**
```json
{
  "categories": [],
  "total": 0,
  "page": 1,
  "limit": 20,
  "totalPages": 0
}
```

Referencia de implementación: `backend/src/modules/ecommerce-products`, endpoint `GET /simple-detailedV2`.

---

### 4. Registrar nuevas tablas en el sistema de vistas (proceso para devs/admins)

Cada vez que se agregue un catálogo nuevo al sistema, seguir los pasos de [`table-views-setup-guide.md`](./table-views-setup-guide.md):

1. Insertar en `table_metadata` con el `table_key` de la nueva tabla
2. Insertar las columnas en `table_column_metadata`
3. Insertar permisos en `role_table_column_permission` para todos los roles que apliquen
4. Crear la vista DEFAULT vía API o inserción directa
5. Verificar con `GET /api/table-views?tableKey=<table_key>`

Crear un archivo `.md` específico en esta carpeta (`processes/`) por cada tabla nueva, siguiendo el modelo de `ecommerce-categories-table-views-setup.md`.

---

## Catálogos pendientes además de categorías

Agregar aquí los otros catálogos que se van a implementar con este mismo patrón:

- [ ] `ecommerce_categories` — Registros de BD listos, frontend y backend pendientes
- [ ] _(agregar catálogo)_
- [ ] _(agregar catálogo)_
