# Plan: Corrección de encoding para nombres con caracteres especiales en órdenes eBay

**Fecha:** 2026-07-08
**Estado:** Verificado contra base de datos — script listo, pendiente de ejecución
**Contexto:** Una orden internacional llegó con el nombre del comprador en caracteres chinos. Al intentar crear/actualizar el registro en el CRM, la inserción falló porque la columna del nombre del cliente no aceptó esos caracteres.

---

## Problema a resolver

El nombre del comprador (`shipTo.fullName`) se inserta **tal cual** en varias columnas, no solo en una:

| Tabla      | Columna                | Uso                                                                                      |
| ---------- | ---------------------- | ---------------------------------------------------------------------------------------- |
| `users`    | `name`, `surname`      | Registro del cliente (Nota 01, [`Mapeo de datos 1.md`](Mapeo%20de%20datos%201.md):11-41) |
| `so_info`  | `customer`             | Nombre del cliente en la SO ([`Mapeo de datos 1.md`](Mapeo%20de%20datos%201.md):610-613) |
| `shipment` | `to_name`, `from_name` | Nombre en la etiqueta de envío                                                           |

Arreglar solo la tabla `users` no habría resuelto el problema — la misma cadena con caracteres especiales llega a columnas de tres tablas.

---

## Verificación realizada contra la base de datos (2026-07-08)

Se conectó de forma **solo lectura** a `gts_crm_db` (host de `GTS_CRM_DB_HOST`, base `datalus_greentekcomcrm_dev`, credenciales de `api-nestjs/.env`) y se confirmó lo siguiente:

**1. La base de datos sí soporta estos caracteres — el problema es de tabla, no del motor.**

```
DEFAULT_CHARACTER_SET_NAME: utf8mb4
DEFAULT_COLLATION_NAME:     utf8mb4_0900_ai_ci
```

**2. Las tablas `users`, `so_info` y `shipment` están en `latin1_swedish_ci`, no en el charset por defecto de la base.** De 165 columnas de texto entre las tres tablas, **156 están en `latin1`**, incluidas las columnas del problema:

| Tabla | Columna | Charset actual |
|---|---|---|
| `users` | `name` | `latin1` |
| `users` | `surname` | `latin1` |
| `so_info` | `customer` | `latin1` |
| `shipment` | `to_name` | `latin1` |
| `shipment` | `from_name` | `latin1` |

**3. Migración previa parcial e inconsistente.** 9 columnas de `so_info` (`contactcontact`, `contactphone`, `shiptoaddress1`, `shiptocontact`, `shiptophone`, `client_PO_Number`, `invoices_description`, `invoices_extendeddescription`, `invoices_billtocontactphone`) **ya están en `utf8mb4_0900_ai_ci`** — alguien corrigió esto puntualmente antes, pero no se completó ni se documentó, por eso el problema reapareció en `customer` (columna hermana de `contactcontact`, ambas reciben el mismo valor de `shipTo.fullName`, pero solo una fue migrada).

**4. Se reprodujo el error exacto** insertando `测试中文姓名` en una tabla temporal con la definición real de `users.name` (`varchar(180)` en `latin1`):

```
ER_TRUNCATED_WRONG_VALUE_FOR_FIELD - Incorrect string value: '\xE6\xB5\x8B\xE8\xAF\x95...' for column 'name' at row 1
```

Este es el mismo error que debió producirse en la orden real.

**5. La conexión de la app ya negocia `utf8mb4` correctamente** (`character_set_client/connection/results/server = utf8mb4`) — no hay que tocar nada en la configuración de conexión de TypeORM. El único problema es el charset de las tablas.

**6. Tamaño de las tablas** (ambiente `dev`, bajo volumen — el `ALTER` debería tardar segundos):

| Tabla      | Filas  | Tamaño   |
| ---------- | ------ | -------- |
| `shipment` | 880    | 0.48 MB  |
| `users`    | 14,245 | 13.75 MB |
| `so_info`  | 59,663 | 88.38 MB |

---

## Solución: migrar `users`, `so_info` y `shipment` completas a `utf8mb4`

En vez de corregir columna por columna (habría que tocar más de 150 columnas y es fácil dejar otra migración parcial como la anterior), la corrección es convertir **las tres tablas completas** a `utf8mb4_0900_ai_ci` (mismo collation por defecto de la base) con `ALTER TABLE ... CONVERT TO CHARACTER SET`. Esto:

- Resuelve el error de fondo para `name`, `surname`, `customer`, `to_name`, `from_name` y de paso el resto de columnas de texto que hoy también están en `latin1` (direcciones, ciudades, comentarios) y que podrían fallar igual con otro dato internacional en el futuro.
- No requiere cambios en el código de la aplicación — es una migración de esquema.
- `CONVERT TO CHARACTER SET` reinterpreta los bytes existentes de `latin1` a `utf8mb4` sin corromper los datos actuales (nombres/direcciones en español con acentos se preservan).

**Script generado (no ejecutado):** [`fix-encoding-utf8mb4.sql`](fix-encoding-utf8mb4.sql) — incluye los 3 `ALTER TABLE`, queries de verificación posteriores, y una prueba funcional (insert + rollback) con un nombre en chino para confirmar el fix antes de darlo por cerrado.

---

## Consideraciones antes de ejecutar

1. **Este script se preparó y verificó contra el ambiente `dev`** (`datalus_greentekcomcrm_dev`). Falta correr la misma verificación de charset contra producción antes de ejecutar ahí — el volumen de datos y si ya tiene o no la misma migración parcial pueden diferir.
2. **`ALTER TABLE ... CONVERT TO CHARACTER SET` bloquea escritura en la tabla mientras corre** (reconstruye la tabla completa) — ejecutar en ventana de mantenimiento, aunque con los volúmenes vistos en dev el tiempo debería ser bajo.
3. **Backup previo obligatorio** (`mysqldump` de las 3 tablas) antes de correr en cualquier ambiente con datos reales.
4. Ningún cambio de código es necesario para este fix — es exclusivamente a nivel de esquema de base de datos.

---

## Próximos pasos

1. Correr la misma verificación de charset ([`fix-encoding-utf8mb4.sql`](fix-encoding-utf8mb4.sql), sección 3.1) contra producción para confirmar si tiene el mismo estado que dev.
2. Tomar backup de `users`, `so_info` y `shipment`.
3. Ejecutar el script en dev primero, validar con la prueba funcional incluida (nombre en chino).
4. Ejecutar en producción en ventana de mantenimiento.
5. Confirmar cerrando este documento con el resultado y actualizar el estado a "Implementado".
