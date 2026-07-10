-- =============================================================================
-- Migración: tabla ebay_tracking_outbox + trigger en shipment
-- =============================================================================
-- Objetivo : Mecanismo de sincronización del tracking hacia eBay (camino ShipEngine).
--            - El frontend, al imprimir la etiqueta, inserta la "intención" en
--              ebay_tracking_outbox (vía endpoint NestJS) con status PENDING_TRACKING.
--            - Symfony/ShipEngine escribe shipment.tracking_number (asíncrono).
--            - El TRIGGER de abajo copia ese tracking a la fila del outbox y la
--              pasa a status READY.
--            - Un consumer NestJS (@Cron) lee las filas READY y llama a la eBay
--              Fulfillment API (createShippingFulfillment).
--
-- Base de datos : CRM (la configurada en GTS_CRM_DB_NAME del api-nestjs).
--                 Ejecutar CONECTADO a esa base (mismo esquema que so_info / shipment).
-- Depende de    : migration-so_info-ebay_account_id.sql (guard "SO es de eBay").
--
-- Notas para el DBA:
--   * El trigger requiere privilegio TRIGGER (por eso va a DBA).
--   * El trigger va sobre la tabla `shipment` del CRM (la que Symfony actualiza
--     con tracking_number). Confirmar que esa es la tabla y columna correctas
--     antes de crearlo (columna esperada: shipment.tracking_number).
--   * InnoDB + utf8mb4 para alinear con el resto del esquema.
--   * synchronize=false en la app → este script es la única fuente del cambio.
--
-- Fecha : 2026-07-10
-- =============================================================================

-- --- 1) Tabla outbox --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ebay_tracking_outbox` (
  `id`              BIGINT       NOT NULL AUTO_INCREMENT,
  `shipment_id`     INT          NOT NULL COMMENT 'FK lógica a shipment.id',
  `so_id`           INT          NOT NULL COMMENT 'FK lógica a so_info.id (para agrupar por orden)',
  `order_id`        VARCHAR(120) NULL     COMMENT 'so_info.client_PO_Number = orderId de eBay',
  `line_item_id`    VARCHAR(64)  NULL     COMMENT 'so_info.reference = orderLineItemId de eBay',
  `ebay_account_id` INT          NOT NULL COMMENT 'Cuenta eBay (gobig_ebay_linked_accounts.id) que define el token',
  `tracking_number` VARCHAR(64)  NULL     COMMENT 'Lo llena el trigger cuando Symfony escribe shipment.tracking_number',
  `status`          ENUM('PENDING_TRACKING','READY','SYNCED','SKIPPED','ERROR')
                                 NOT NULL DEFAULT 'PENDING_TRACKING',
  `attempts`        INT          NOT NULL DEFAULT 0 COMMENT 'Reintentos del consumer',
  `last_error`      TEXT         NULL     COMMENT 'Diagnóstico del último error de sync',
  `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `synced_at`       DATETIME     NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ebay_tracking_outbox_shipment` (`shipment_id`),
  KEY `idx_ebay_tracking_outbox_status`   (`status`),
  KEY `idx_ebay_tracking_outbox_order`    (`order_id`),
  KEY `idx_ebay_tracking_outbox_account`  (`ebay_account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Cola de sincronización de tracking hacia la eBay Fulfillment API (camino ShipEngine).';

-- UNIQUE(shipment_id): garantiza una sola fila por shipment y permite inserciones
-- idempotentes desde el endpoint (INSERT ... ON DUPLICATE KEY UPDATE / INSERT IGNORE),
-- evitando duplicados si el operador presiona "Imprimir" más de una vez.

-- --- 2) Trigger: al escribirse el tracking en shipment, marcar READY ---------
--     Se dispara en cada UPDATE de shipment, pero solo actúa cuando tracking_number
--     pasa de NULL a un valor Y existe una fila de outbox pendiente para ese
--     shipment (las compras directas no tienen fila → no hace nada).
DROP TRIGGER IF EXISTS `trg_shipment_fill_tracking_outbox`;

DELIMITER $$

CREATE TRIGGER `trg_shipment_fill_tracking_outbox`
AFTER UPDATE ON `shipment`
FOR EACH ROW
BEGIN
  IF NEW.`tracking_number` IS NOT NULL
     AND NEW.`tracking_number` <> ''
     AND (OLD.`tracking_number` IS NULL OR OLD.`tracking_number` = '')
  THEN
    UPDATE `ebay_tracking_outbox`
       SET `tracking_number` = NEW.`tracking_number`,
           `status`          = 'READY'
     WHERE `shipment_id`     = NEW.`id`
       AND `tracking_number` IS NULL;
  END IF;
END$$

DELIMITER ;

-- --- 3) Verificación ---------------------------------------------------------
-- SHOW CREATE TABLE `ebay_tracking_outbox`;
-- SHOW TRIGGERS LIKE 'shipment';

-- =============================================================================
-- ROLLBACK (solo si hay que revertir)
-- =============================================================================
-- DROP TRIGGER IF EXISTS `trg_shipment_fill_tracking_outbox`;
-- DROP TABLE IF EXISTS `ebay_tracking_outbox`;
