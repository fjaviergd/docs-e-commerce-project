-- =============================================================================
-- Fix: migrar users, so_info y shipment de latin1_swedish_ci a utf8mb4
-- =============================================================================
-- Contexto: ver plan-customer-name-encoding.md en esta misma carpeta.
--
-- Verificado en gts_crm_db (host GTS_CRM_DB_HOST, db datalus_greentekcomcrm_dev) el 2026-07-08:
--   - La base de datos tiene charset/collation por defecto utf8mb4 / utf8mb4_0900_ai_ci.
--   - Las tablas `users`, `so_info` y `shipment` quedaron con collation latin1_swedish_ci
--     (legado), con 156 columnas de texto en latin1 sobre 165 totales.
--   - 9 columnas de `so_info` (contactcontact, contactphone, shiptoaddress1, shiptocontact,
--     shiptophone, client_PO_Number, invoices_description, invoices_extendeddescription,
--     invoices_billtocontactphone) ya fueron migradas a utf8mb4_0900_ai_ci en algún momento
--     anterior -> esto es una migración PARCIAL e inconsistente, no un fix completo.
--   - Se reprodujo el error real insertando un nombre en chino en una columna con la
--     definición real de `users.name` (latin1): ER_TRUNCATED_WRONG_VALUE_FOR_FIELD.
--
-- Alcance de este script: convierte las 3 tablas COMPLETAS (no columna por columna) a
-- utf8mb4_0900_ai_ci, para que cualquier campo de texto que reciba datos internacionales
-- libres (nombre, dirección, ciudad, comentarios) quede cubierto, no solo el campo que
-- causó el error original. Evita dejar una nueva mezcla de charsets dentro de la misma tabla.
--
-- Tamaño verificado (dev, 2026-07-08): shipment ~880 filas / 0.48 MB, so_info ~59,663 filas /
-- 88.38 MB, users ~14,245 filas / 13.75 MB. Volumen bajo; el ALTER debería completarse en
-- segundos/pocos minutos incluso en producción, pero de todas formas requiere backup previo
-- y ejecutarse en ventana de mantenimiento porque ALTER...CONVERT TO CHARACTER SET bloquea
-- escritura en la tabla mientras corre (MySQL reconstruye la tabla completa).
--
-- CONVERT TO CHARACTER SET reinterpreta los bytes existentes de latin1 a utf8mb4 sin
-- corromper el contenido actual (texto en español/inglés con acentos se preserva
-- correctamente); es la conversión estándar recomendada por MySQL para este escenario.
--
-- NO EJECUTAR TODAVÍA. Este script es un entregable de planeación, no una corrección aplicada.
-- Antes de correr en cualquier ambiente:
--   1. Confirmar en QUÉ base de datos se ejecuta (dev vs. producción) y correr primero en dev.
--   2. Tomar backup/snapshot de la base de datos.
--   3. Ejecutar en ventana de mantenimiento (bloquea escritura en cada tabla mientras corre).
--   4. Validar con la sección "Verificación" al final de este archivo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Backup lógico previo (ejecutar por separado, fuera de este script, ANTES de los ALTER)
-- -----------------------------------------------------------------------------
-- mysqldump -h <host> -u <user> -p <db> users so_info shipment > backup_pre_utf8mb4_YYYYMMDD.sql

-- -----------------------------------------------------------------------------
-- 2. Migración de charset (orden: tablas más chicas primero para validar antes de la grande)
-- -----------------------------------------------------------------------------

ALTER TABLE shipment
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE users
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE so_info
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- -----------------------------------------------------------------------------
-- 3. Verificación (correr después de cada ALTER o al final)
-- -----------------------------------------------------------------------------

-- 3.1 Confirmar que ya no queda ninguna columna de texto en latin1 en las 3 tablas
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, CHARACTER_SET_NAME, COLLATION_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('users', 'so_info', 'shipment')
  AND CHARACTER_SET_NAME IS NOT NULL
  AND CHARACTER_SET_NAME <> 'utf8mb4';
-- Debe devolver 0 filas.

-- 3.2 Confirmar collation de tabla
SELECT TABLE_NAME, TABLE_COLLATION
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('users', 'so_info', 'shipment');
-- Las 3 deben mostrar utf8mb4_0900_ai_ci.

-- 3.3 Prueba funcional: insertar y leer un nombre con caracteres chinos (el caso real que falló)
-- Ejecutar en una transacción y hacer ROLLBACK para no dejar datos de prueba:
START TRANSACTION;

INSERT INTO users (
  role, name, surname, email, password, company, birth_date, gender,
  estado_civil, ocupation, born_city, nationality, address, address2,
  colonia, city, zip_code, country, forgot_code, companies_id, activo
) VALUES (
  'customer', '测试', '姓名', 'charset-test@example.com',
  'f9dd628540cd4a5689406f258cc12fb1b9b80cb8401513b70ce0d3d731ee7474',
  'EBAY', '1779-01-01', 1, '', '', '', '', '', '', '', '', '', 1293, '1'
);

SELECT id, name, surname FROM users WHERE email = 'charset-test@example.com';
-- El SELECT debe devolver "测试" / "姓名" sin error y sin caracteres corruptos ("?" o "??").

ROLLBACK;
-- =============================================================================
