# Guía: Registrar una nueva tabla en el sistema de Table Views

Esta guía explica el proceso completo para incorporar cualquier nueva entidad/catálogo al sistema de vistas guardadas (`table-views`) del API NestJS.

---

## Modelo de datos involucrado

El sistema usa **5 tablas** relacionadas entre sí:

```
table_metadata
    └── table_column_metadata
            └── role_table_column_permission

table_view (referencia a table_metadata)
user_last_table_view (referencia a table_view y table_metadata)
```

### `table_metadata`
Registro central de cada tabla/catálogo que usa el sistema.

| Columna | Tipo | Descripción |
|---|---|---|
| `id_table_metadata` | int PK | Auto-incremental |
| `table_key` | varchar(100) UNIQUE | Identificador lógico (ej: `ecommerce_listings`) |
| `description` | varchar(255) | Descripción legible |
| `created_at` | datetime | Auto |
| `updated_at` | datetime | Auto |

### `table_column_metadata`
Define qué columnas existen para cada tabla registrada.

| Columna | Tipo | Descripción |
|---|---|---|
| `id_table_column_metadata` | int PK | Auto-incremental |
| `id_table_metadata` | int FK | Referencia a `table_metadata` |
| `column_key` | varchar(100) | Nombre de la columna (ej: `name`, `createdAt`) |
| `data_type` | varchar(50) | `string` \| `number` \| `date` \| `enum` \| `boolean` |
| `description` | varchar(255) | Descripción legible |

> Constraint UNIQUE en `(id_table_metadata, column_key)`.

### `role_table_column_permission`
Whitelist de columnas visibles por rol. ADMINISTRATOR tiene acceso wildcard y no necesita registros aquí.

| Columna | Tipo | Descripción |
|---|---|---|
| `id_role_table_column_permission` | int PK | Auto-incremental |
| `id_table_column_metadata` | int FK | Columna a la que se da acceso |
| `id_role` | varchar(50) | Nombre del rol (ej: `SALES`, `WAREHOUSE`) |

> Constraint UNIQUE en `(id_table_column_metadata, id_role)`.

### `table_view`
Almacena cada vista guardada (DEFAULT, ROLE o USER).

| Columna | Tipo | Descripción |
|---|---|---|
| `id_table_view` | int PK | Auto-incremental |
| `uuid` | char(36) UNIQUE | Identificador público expuesto al frontend |
| `master_company_id` | int | ID de la compañía (aislamiento multi-tenant) |
| `user_id` | int nullable | Solo para vistas tipo USER |
| `created_by` | int | ID del usuario que creó la vista |
| `id_table_metadata` | int FK | Tabla a la que pertenece la vista |
| `view_type` | enum | `USER` \| `ROLE` \| `DEFAULT` |
| `role` | varchar(50) nullable | Solo para vistas tipo ROLE |
| `name` | varchar(100) | Nombre visible al usuario |
| `config_columns` | json | Array de column_keys a mostrar, en orden |
| `config_filters` | json nullable | Array de filtros activos por defecto |
| `sort_by` | varchar(100) nullable | Columna de ordenamiento |
| `sort_order` | enum nullable | `ASC` \| `DESC` |
| `pagination_limit` | int nullable | Máx. 100 |

### `user_last_table_view`
Recuerda la última vista que cada usuario seleccionó por tabla.

| Columna | Tipo | Descripción |
|---|---|---|
| `user_id` | int PK | ID del usuario |
| `id_table_view` | int PK | Vista seleccionada |
| `id_table_metadata` | int PK | Tabla correspondiente |
| `updated_at` | timestamp | Última actualización |

---

## Tipos de vistas y sus reglas

| Tipo | Quién la crea | Quién la ve | Editable por | Límite |
|---|---|---|---|---|
| `DEFAULT` | Solo ADMINISTRATOR | Todos (fallback) | Solo ADMINISTRATOR | 1 por tabla/compañía |
| `ROLE` | Solo ADMINISTRATOR | Usuarios del rol | Solo ADMINISTRATOR | 1 por rol/tabla/compañía |
| `USER` | Cualquier usuario autenticado | Solo el creador | Solo el creador | 10 por usuario/tabla |

**Orden de prioridad al cargar vistas:**
1. Vistas USER del usuario (hasta 10, newest first)
2. Vista ROLE del rol del usuario (si existe)
3. Vista DEFAULT (si existe)

Si el usuario tiene una vista en `user_last_table_view`, esa se mueve al frente.

---

## Proceso de registro paso a paso

### Paso 1 — Registrar la tabla en `table_metadata`

```sql
INSERT INTO table_metadata (table_key, description, created_at, updated_at)
VALUES ('<table_key>', '<descripción>', NOW(), NOW());

-- Guardar el ID generado para usarlo en los siguientes pasos
-- Ejemplo: SET @table_id = LAST_INSERT_ID();
```

**Naming convention para `table_key`:** `<dominio>_<entidad_en_plural>` en snake_case.
Ejemplos: `ecommerce_listings`, `ecommerce_categories`, `inventory_products`.

---

### Paso 2 — Registrar las columnas en `table_column_metadata`

Un registro por cada columna que el frontend puede mostrar, filtrar u ordenar.

```sql
INSERT INTO table_column_metadata
  (id_table_metadata, column_key, data_type, description, created_at, updated_at)
VALUES
  (@table_id, 'id',        'number',  'ID único',           NOW(), NOW()),
  (@table_id, 'name',      'string',  'Nombre',             NOW(), NOW()),
  (@table_id, 'isActive',  'boolean', 'Estado activo',      NOW(), NOW()),
  (@table_id, 'createdAt', 'date',    'Fecha de creación',  NOW(), NOW()),
  (@table_id, 'updatedAt', 'date',    'Última modificación',NOW(), NOW());
  -- ...agregar todas las columnas de la entidad
```

**Valores válidos para `data_type`:**

| Valor | Filtros compatibles |
|---|---|
| `string` | `equals`, `like` (contains), `in` |
| `number` | `equals`, `gt`, `gte`, `lt`, `lte`, `between` |
| `boolean` | `is` |
| `date` | `equals`, `before`, `after`, `between` |
| `enum` | `equals`, `in` |

---

### Paso 3 — Otorgar permisos de columna por rol

ADMINISTRATOR tiene acceso wildcard: **no necesita registros aquí**.

Para cualquier otro rol, insertar los permisos de las columnas que debe ver:

```sql
-- Otorgar acceso a todas las columnas para un rol específico
INSERT INTO role_table_column_permission
  (id_table_column_metadata, id_role, created_at, updated_at)
SELECT
  id_table_column_metadata,
  '<NOMBRE_ROL>',
  NOW(),
  NOW()
FROM table_column_metadata
WHERE id_table_metadata = @table_id;

-- O solo para columnas seleccionadas
INSERT INTO role_table_column_permission
  (id_table_column_metadata, id_role, created_at, updated_at)
SELECT
  id_table_column_metadata,
  '<NOMBRE_ROL>',
  NOW(),
  NOW()
FROM table_column_metadata
WHERE id_table_metadata = @table_id
  AND column_key IN ('id', 'name', 'isActive');
```

---

### Paso 4 — Crear la vista DEFAULT

#### Opción A: Vía API (recomendado, requiere token de ADMINISTRATOR)

```http
POST /api/table-views
Authorization: Bearer <token_admin>
Content-Type: application/json

{
  "tableKey": "<table_key>",
  "type": "DEFAULT",
  "name": "Vista por defecto",
  "config": {
    "columns": ["id", "name", "isActive", "createdAt", "updatedAt"],
    "filters": [],
    "sort": {
      "column": "createdAt",
      "order": "DESC"
    },
    "paginationLimit": 20
  }
}
```

#### Opción B: Inserción directa en base de datos

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
  UUID(),                     -- uuid auto-generado
  <master_company_id>,        -- ID de la compañía
  NULL,                       -- NULL para DEFAULT
  <admin_user_id>,            -- ID del usuario administrador
  @table_id,                  -- ID obtenido en el Paso 1
  'DEFAULT',
  NULL,                       -- NULL para DEFAULT
  'Vista por defecto',
  '["id", "name", "isActive", "createdAt", "updatedAt"]',
  '[]',                       -- sin filtros por defecto, o un array de filtros
  'createdAt',
  'DESC',
  20,
  NOW(),
  NOW()
);
```

---

### Paso 5 — Verificar

Usando el API con un token de ADMINISTRATOR:

```http
GET /api/table-views?tableKey=<table_key>
Authorization: Bearer <token_admin>
```

La respuesta debe incluir la vista DEFAULT con `readOnly: true`:

```json
{
  "views": [
    {
      "id": "<uuid>",
      "type": "DEFAULT",
      "name": "Vista por defecto",
      "readOnly": true,
      "config": {
        "columns": ["id", "name", "isActive", "createdAt", "updatedAt"],
        "filters": [],
        "sort": { "column": "createdAt", "order": "DESC" },
        "paginationLimit": 20
      }
    }
  ]
}
```

---

## Notas importantes

- **`master_company_id`** — Todas las inserciones directas requieren el ID correcto de la compañía. Confirmar el valor antes de insertar.
- **`created_by`** — Debe ser el ID de un usuario ADMINISTRATOR válido en el sistema.
- **Columnas en `config_columns`** — Deben existir exactamente en `table_column_metadata` con el mismo `column_key`. El API valida esto y rechazará la vista si hay discrepancias.
- **Filtros en `config_filters`** — El formato es el mismo que usa el frontend: `{ "column": "...", "type": "...", "condition": "...", "value": ... }`. Las columnas de los filtros también son validadas contra el whitelist de permisos.
- **No se necesita tocar `user_last_table_view`** — Esta tabla se gestiona automáticamente cuando los usuarios interactúan con el selector de vistas.
