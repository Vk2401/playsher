-- Move OTP storage out of process memory and into the database.
-- Required for any host that runs more than one process (serverless, PM2 cluster)
-- and so that a restart no longer drops pending logins.

CREATE TABLE IF NOT EXISTS `otps` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `mobile`      VARCHAR(20)  NOT NULL,
  `otp`         VARCHAR(6)   NOT NULL,
  `expires_at`  DATETIME     NOT NULL,
  `is_verified` TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at`  DATETIME     NOT NULL,
  `updated_at`  DATETIME     NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `otps_mobile_unique` (`mobile`),
  KEY `otps_expires_at_idx` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
