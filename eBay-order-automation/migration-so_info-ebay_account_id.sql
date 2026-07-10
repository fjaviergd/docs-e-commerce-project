-- =============================================================================
-- Migración: so_info.ebay_account_id
-- =============================================================================
-- Objetivo : Vincular cada Sales Order con la cuenta de eBay que originó la orden.
--            Es el prerrequisito (Decisión #1) del plan de auto-sync de tracking
--            y, a la vez, el guard "¿esta SO es de eBay?" (ebay_account_id IS NOT NULL).
--
-- Base de datos : CRM (la configurada en GTS_CRM_DB_NAME del api-nestjs).
--                 Ejecutar CONECTADO a esa base; el script no hace USE por diseño.
-- Tabla         : so_info
-- Referencia    : gobig_ebay_linked_accounts.id  (INT, PK auto-increment)
--
-- Notas para el DBA:
--   * La columna es NULLABLE a propósito: las SOs históricas y las compras
--     directas (no-eBay) quedan en NULL. NO backfillear con un valor por defecto.
--   * Tipo INT (con signo) para calzar con gobig_ebay_linked_accounts.id.
--   * so_info es una tabla grande/legacy: el ALTER puede tomar bloqueo. Programar
--     en ventana de mantenimiento si aplica.
--   * synchronize=false en la app → este script es la única fuente del cambio.
--
-- Fecha : 2026-07-10
-- =============================================================================

-- --- 1) Agregar la columna --------------------------------------------------
ALTER TABLE `so_info`
  ADD COLUMN `ebay_account_id` INT NULL DEFAULT NULL
  COMMENT 'FK lógica a gobig_ebay_linked_accounts.id. NULL = SO no originada en eBay (compra directa / SO histórica).'
  AFTER `master_id`;

-- --- 2) Índice para el guard/consultas del job de sync ----------------------
--     El consumer filtra por `ebay_account_id IS NOT NULL` y hace JOIN por esta
--     columna; el índice evita full scans de so_info.
ALTER TABLE `so_info`
  ADD INDEX `idx_so_info_ebay_account_id` (`ebay_account_id`);

-- --- 3) (OPCIONAL) Foreign key ----------------------------------------------
--     Descomentar SOLO si ambas tablas son InnoDB y se desea integridad
--     referencial a nivel BD. ON DELETE SET NULL para no bloquear el borrado de
--     una cuenta vinculada (deja las SOs sin cuenta en lugar de impedir el DELETE).
--
-- ALTER TABLE `so_info`
--   ADD CONSTRAINT `fk_so_info_ebay_account`
--   FOREIGN KEY (`ebay_account_id`) REFERENCES `gobig_ebay_linked_accounts` (`id`)
--   ON DELETE SET NULL
--   ON UPDATE CASCADE;

-- --- 4) Verificación ---------------------------------------------------------
--     Debe listar la nueva columna y el índice.
-- SHOW COLUMNS FROM `so_info` LIKE 'ebay_account_id';
-- SHOW INDEX FROM `so_info` WHERE Key_name = 'idx_so_info_ebay_account_id';

-- =============================================================================
-- ROLLBACK (solo si hay que revertir)
-- =============================================================================
-- ALTER TABLE `so_info` DROP FOREIGN KEY `fk_so_info_ebay_account`;      -- si se creó el FK
-- ALTER TABLE `so_info` DROP INDEX `idx_so_info_ebay_account_id`;
-- ALTER TABLE `so_info` DROP COLUMN `ebay_account_id`;
