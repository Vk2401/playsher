-- Migration: app version gating
-- Run: mysql -u root -p playsher < database/migrations/add_app_versions.sql
--
-- Lets an admin declare, per platform, the newest published build and the
-- oldest one still allowed to run. The app checks on launch and prompts — or,
-- below min_supported_version, blocks — so a build with a broken payment or an
-- outdated API contract can be retired without waiting for users to update on
-- their own.
--
-- Only admins may write these rows; the read is public because the app must
-- check before anyone has logged in.

CREATE TABLE IF NOT EXISTS app_versions (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  platform              ENUM('android','ios') NOT NULL,
  latest_version        VARCHAR(20)  NOT NULL,
  min_supported_version VARCHAR(20)  NOT NULL,
  update_url            VARCHAR(255) DEFAULT NULL,
  release_notes         TEXT         DEFAULT NULL,
  is_active             TINYINT(1)   NOT NULL DEFAULT 1,
  created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_app_versions_platform (platform)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed both platforms at the version currently in the stores, with the minimum
-- equal to it so nothing is forced until an admin deliberately raises the bar.
INSERT INTO app_versions (platform, latest_version, min_supported_version, update_url, release_notes)
VALUES
  ('android', '1.0.0', '1.0.0', NULL, NULL),
  ('ios',     '1.0.0', '1.0.0', NULL, NULL)
ON DUPLICATE KEY UPDATE platform = platform;
