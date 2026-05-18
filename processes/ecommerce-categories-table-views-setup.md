# Setup: Table Views para `ecommerce_categories`

Guía específica para registrar el catálogo de categorías en el sistema de vistas guardadas.

> Para entender el modelo de datos completo y las reglas del sistema, ver:
> [`table-views-setup-guide.md`](./table-views-setup-guide.md)

---

## Entidad de referencia

Campos actuales de `CategoryEntity` en `backend/src/modules/categories`:

| `column_key` | `data_type` | Notas |
|---|---|---|
| `id` | `string` | UUID, PK |
| `name` | `string` | Nombre de la categoría, max 100 chars |
| `isActive` | `boolean` | Estado. `true` = activa, `false` = desactivada/eliminada |
| `sortOrder` | `number` | Orden de visualización, default 0 |
| `createdAt` | `date` | Auto-generado |
| `updatedAt` | `date` | Auto-actualizado |

> **Nota sobre el endpoint GET actual:** El endpoint existente en el backend (`GET /v1/categories`) no sigue el patrón de filtros dinámicos que usa el data table (parámetros `filters`, `sortBy`, `order`, `page`, `limit`). Habrá que ajustarlo antes de conectar el frontend. Ver tarea pendiente al final de este documento.

---

## Paso 1 — Registrar en `table_metadata`

```sql
INSERT INTO table_metadata (table_key, description, created_at, updated_at)
VALUES ('ecommerce_categories', 'E-commerce categories catalog', NOW(), NOW());

SET @table_id = LAST_INSERT_ID();
-- Anotar el valor de @table_id para los siguientes pasos
```

---

## Paso 2 — Registrar columnas en `table_column_metadata`

```sql
INSERT INTO table_column_metadata
  (id_table_metadata, column_key, data_type, description, created_at, updated_at)
VALUES
  (@table_id, 'id',        'string',  'Unique ID (UUID)',          NOW(), NOW()),
  (@table_id, 'name',      'string',  'Category name',            NOW(), NOW()),
  (@table_id, 'isActive',  'boolean', 'Active/inactive status',   NOW(), NOW()),
  (@table_id, 'sortOrder', 'number',  'Display order',            NOW(), NOW()),
  (@table_id, 'createdAt', 'date',    'Creation timestamp',       NOW(), NOW()),
  (@table_id, 'updatedAt', 'date',    'Last update timestamp',    NOW(), NOW());
```

---

## Paso 3 — Permisos por rol

ADMINISTRATOR tiene acceso wildcard, no necesita registros.

Todos los demás roles tienen acceso a todas las columnas del catálogo:

```sql
INSERT INTO role_table_column_permission
  (id_table_column_metadata, id_role, created_at, updated_at)
SELECT
  tcm.id_table_column_metadata,
  r.role_name,
  NOW(),
  NOW()
FROM table_column_metadata tcm
CROSS JOIN (
  SELECT 'MANAGER'               AS role_name UNION ALL
  SELECT 'PURCHASINGREP'                       UNION ALL
  SELECT 'SALESREP'                            UNION ALL
  SELECT 'TECH SUPERVISOR'                     UNION ALL
  SELECT 'WAREHOUSE SUPERVISOR'                UNION ALL
  SELECT 'RECEIVINGDEPARTMENT'
) r
WHERE tcm.id_table_metadata = @table_id;
```

---

## Paso 4 — Crear la vista DEFAULT

### Opción A: Vía API (recomendado)

```http
POST /api/table-views
Authorization: Bearer <token_admin>
Content-Type: application/json

{
  "tableKey": "ecommerce_categories",
  "type": "DEFAULT",
  "name": "Default View",
  "config": {
    "columns": ["name", "isActive", "sortOrder", "createdAt", "updatedAt"],
    "filters": [
      {
        "column": "isActive",
        "type": "boolean",
        "condition": "is",
        "value": true
      }
    ],
    "sort": {
      "column": "sortOrder",
      "order": "ASC"
    },
    "paginationLimit": 20
  }
}
```

> La vista por defecto propone: ordenar por `sortOrder` ASC (respeta el orden intencional del catálogo), filtro inicial mostrando solo activas, sin columna `id` visible (se puede agregar si se prefiere).

### Opción B: Inserción directa en base de datos

Reemplazar `<master_company_id>` y `<admin_user_id>` con los valores reales del entorno.

```sql
INSERT INTO table_view (
  uuid,
  master_company_id,
  user_id,
  created_by,
  id_table_metadata,
  view_type,
  role,
  name,
  config_columns,
  config_filters,
  sort_by,
  sort_order,
  pagination_limit,
  created_at,
  updated_at
)
VALUES (
  UUID(),
  <master_company_id>,
  NULL,
  <admin_user_id>,
  @table_id,
  'DEFAULT',
  NULL,
  'Default View',
  '["name", "isActive", "sortOrder", "createdAt", "updatedAt"]',
  '[{"column": "isActive", "type": "boolean", "condition": "is", "value": true}]',
  'sortOrder',
  'ASC',
  20,
  NOW(),
  NOW()
);
```

---

## Paso 5 — Verificar

```http
GET /api/table-views?tableKey=ecommerce_categories
Authorization: Bearer <token_admin>
```

Respuesta esperada:

```json
{
  "views": [
    {
      "id": "<uuid-generado>",
      "type": "DEFAULT",
      "name": "Default View",
      "readOnly": true,
      "config": {
        "columns": ["name", "isActive", "sortOrder", "createdAt", "updatedAt"],
        "filters": [
          { "column": "isActive", "type": "boolean", "condition": "is", "value": true }
        ],
        "sort": { "column": "sortOrder", "order": "ASC" },
        "paginationLimit": 20
      }
    }
  ]
}
```

---

## Configuración propuesta para el Angular data table

### Columnas

| `column_key` | Label | Visible por defecto | Sortable | Filterable |
|---|---|---|---|---|
| `name` | Nombre | Sí | Sí | Sí (text) |
| `isActive` | Estado | Sí | Sí | Sí (boolean) |
| `sortOrder` | Orden | Sí | Sí | Sí (number) |
| `createdAt` | Creado | Sí | Sí | Sí (daterange) |
| `updatedAt` | Modificado | Sí | Sí | Sí (daterange) |
| `id` | ID | No | No | Sí (text) |

### Filter chips sugeridos

| Chip | Tipo | Condiciones disponibles |
|---|---|---|
| Nombre | `text` | Contains, Equals, Starts with |
| Estado | `boolean` | Activo / Inactivo |
| Orden | `number` | Equals, Greater than, Less than, Between |
| Fecha creación | `daterange` | Between |
| Fecha modificación | `daterange` | Between |

### Sort por defecto
- Campo: `sortOrder`
- Dirección: `ASC`

---

## Tarea pendiente: ajuste del endpoint GET en el backend

El endpoint actual (`GET /v1/categories`) usa paginación simple y no soporta filtros dinámicos ni sorting configurable. Antes de conectar el frontend necesita ser actualizado para aceptar:

- `filters` — JSON stringificado con array de `ApiFilter`
- `sortBy` — nombre del campo
- `order` — `ASC` | `DESC`
- `page` — número de página (1-indexed)
- `limit` — items por página

Y retornar:

```json
{
  "categories": [],
  "total": 0,
  "page": 1,
  "limit": 20,
  "totalPages": 0
}
```

Ver el patrón de implementación en `backend/src/modules/ecommerce-products` (endpoint `GET /simple-detailedV2`) como referencia.
