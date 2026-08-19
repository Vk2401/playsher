-- Payout details for ground owners. The model (src/models/BankDetails.js) exists
-- but the table was never in schema.sql.

CREATE TABLE IF NOT EXISTS `bank_details` (
  `id`                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`             INT UNSIGNED NOT NULL,
  `user_type`           ENUM('ground_owner','user') NOT NULL DEFAULT 'ground_owner',
  `account_holder_name` VARCHAR(255) NOT NULL,
  `account_number`      VARCHAR(50)  NOT NULL,
  `ifsc_code`           VARCHAR(20)  NOT NULL,
  `bank_name`           VARCHAR(255) DEFAULT NULL,
  `upi_id`              VARCHAR(100) DEFAULT NULL,
  `created_at`          DATETIME NOT NULL,
  `updated_at`          DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `bank_details_user_idx` (`user_id`, `user_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
