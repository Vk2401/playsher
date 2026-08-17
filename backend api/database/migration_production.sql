-- ============================================================================
-- Playsher Production DB Migration
-- Adds missing columns expected by Node.js Sequelize models
-- Run this ONCE on the production database
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1. USERS TABLE
--    Model expects: mobile, password_hash, profile_picture, current_latitude,
--                   current_longitude, is_active, is_verified
--    Production has: phone, password, profile_photo, latitude, longitude, status
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `users` ADD COLUMN `mobile` VARCHAR(20) DEFAULT NULL AFTER `phone`;
ALTER TABLE `users` ADD COLUMN `password_hash` VARCHAR(255) DEFAULT NULL AFTER `password`;
ALTER TABLE `users` ADD COLUMN `profile_picture` LONGTEXT DEFAULT NULL AFTER `profile_photo`;
ALTER TABLE `users` ADD COLUMN `current_latitude` DECIMAL(10,7) DEFAULT NULL AFTER `latitude`;
ALTER TABLE `users` ADD COLUMN `current_longitude` DECIMAL(10,7) DEFAULT NULL AFTER `longitude`;
ALTER TABLE `users` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `status`;
ALTER TABLE `users` ADD COLUMN `is_verified` TINYINT(1) DEFAULT 0 AFTER `is_active`;

-- Copy existing data into new columns
UPDATE `users` SET `mobile` = `phone` WHERE `mobile` IS NULL AND `phone` IS NOT NULL;
UPDATE `users` SET `password_hash` = `password` WHERE `password_hash` IS NULL AND `password` IS NOT NULL;
UPDATE `users` SET `profile_picture` = `profile_photo` WHERE `profile_picture` IS NULL AND `profile_photo` IS NOT NULL;
UPDATE `users` SET `current_latitude` = CAST(`latitude` AS DECIMAL(10,7)) WHERE `current_latitude` IS NULL AND `latitude` IS NOT NULL;
UPDATE `users` SET `current_longitude` = CAST(`longitude` AS DECIMAL(10,7)) WHERE `current_longitude` IS NULL AND `longitude` IS NOT NULL;
UPDATE `users` SET `is_active` = CASE WHEN `status` = 'Active' THEN 1 ELSE 0 END;
UPDATE `users` SET `is_verified` = CASE WHEN `phone_verified_at` IS NOT NULL THEN 1 ELSE 0 END;

-- ────────────────────────────────────────────────────────────────────────────
-- 2. GROUNDS TABLE
--    Model expects: about, venue_rules, is_approved, is_active, owner_id, deleted_at
--    Production has: vendor_id, status (no about/venue_rules/deleted_at)
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `grounds` ADD COLUMN `owner_id` INT UNSIGNED DEFAULT NULL AFTER `vendor_id`;
ALTER TABLE `grounds` ADD COLUMN `about` TEXT DEFAULT NULL AFTER `name`;
ALTER TABLE `grounds` ADD COLUMN `venue_rules` TEXT DEFAULT NULL AFTER `address`;
ALTER TABLE `grounds` ADD COLUMN `is_approved` TINYINT(1) DEFAULT 0 AFTER `status`;
ALTER TABLE `grounds` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `is_approved`;
ALTER TABLE `grounds` ADD COLUMN `deleted_at` DATETIME DEFAULT NULL AFTER `updated_at`;

-- Copy vendor_id -> owner_id, map status
UPDATE `grounds` SET `owner_id` = `vendor_id` WHERE `owner_id` IS NULL AND `vendor_id` IS NOT NULL;
UPDATE `grounds` SET `is_approved` = 1, `is_active` = CASE WHEN `status` = 'Active' THEN 1 ELSE 0 END;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. BOOKINGS TABLE
--    Model expects: ground_sport_id, slot_date, slot_time_from, slot_time_to,
--                   total_amount, is_game, is_canceled, cancellation_reason, status
--    Production has: ground_id, booking_date, start_time, end_time,
--                    booking_status_id, cancel_reason
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `bookings` ADD COLUMN `ground_sport_id` INT UNSIGNED DEFAULT NULL AFTER `ground_id`;
ALTER TABLE `bookings` ADD COLUMN `slot_date` DATE DEFAULT NULL AFTER `booking_date`;
ALTER TABLE `bookings` ADD COLUMN `slot_time_from` TIME DEFAULT NULL AFTER `start_time`;
ALTER TABLE `bookings` ADD COLUMN `slot_time_to` TIME DEFAULT NULL AFTER `end_time`;
ALTER TABLE `bookings` ADD COLUMN `total_amount` DECIMAL(10,2) DEFAULT 0.00 AFTER `booking_type`;
ALTER TABLE `bookings` ADD COLUMN `is_game` TINYINT(1) DEFAULT 0 AFTER `total_amount`;
ALTER TABLE `bookings` ADD COLUMN `is_canceled` TINYINT(1) DEFAULT 0 AFTER `is_game`;
ALTER TABLE `bookings` ADD COLUMN `cancellation_reason` TEXT DEFAULT NULL AFTER `cancel_reason`;
ALTER TABLE `bookings` ADD COLUMN `status` ENUM('pending','confirmed','cancelled','completed') DEFAULT 'pending' AFTER `is_canceled`;

-- Copy existing data
UPDATE `bookings` SET `slot_date` = `booking_date` WHERE `slot_date` IS NULL;
UPDATE `bookings` SET `slot_time_from` = `start_time` WHERE `slot_time_from` IS NULL;
UPDATE `bookings` SET `slot_time_to` = `end_time` WHERE `slot_time_to` IS NULL;
UPDATE `bookings` SET `cancellation_reason` = `cancel_reason` WHERE `cancellation_reason` IS NULL AND `cancel_reason` IS NOT NULL;
-- Map booking_status_id to status enum (1=Pending, 2=Confirmed, 3=Completed, 4=Cancelled — adjust if different)
UPDATE `bookings` SET `status` = CASE
  WHEN `booking_status_id` = 1 THEN 'pending'
  WHEN `booking_status_id` = 2 THEN 'confirmed'
  WHEN `booking_status_id` = 3 THEN 'completed'
  WHEN `booking_status_id` = 4 THEN 'cancelled'
  ELSE 'pending'
END;
UPDATE `bookings` SET `is_canceled` = CASE WHEN `status` = 'cancelled' THEN 1 ELSE 0 END;

-- Populate ground_sport_id from ground_id (pick first ground_sport for each ground)
UPDATE `bookings` b
  JOIN `ground_sports` gs ON gs.ground_id = b.ground_id
  SET b.ground_sport_id = gs.id
  WHERE b.ground_sport_id IS NULL AND b.ground_id IS NOT NULL;

-- Populate total_amount from the linked payment
UPDATE `bookings` b
  JOIN `payments` p ON p.id = b.payment_id
  SET b.total_amount = p.total
  WHERE b.total_amount IS NULL OR b.total_amount = 0;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. PAYMENTS TABLE
--    Model expects: booking_id, done_by_user_id, payment_done_by_mobile/email/name,
--                   payment_status, payment_method, payment_mode, payment_timestamp,
--                   amount, currency, transaction_id, vendor_payout_amount, transfer_id
--    Production has: user_id, status, method, price, total,
--                   vendor_amount, vendor_transfer_id
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `payments` ADD COLUMN `booking_id` INT UNSIGNED DEFAULT NULL AFTER `id`;
ALTER TABLE `payments` ADD COLUMN `done_by_user_id` BIGINT UNSIGNED DEFAULT NULL AFTER `booking_id`;
ALTER TABLE `payments` ADD COLUMN `payment_done_by_mobile` VARCHAR(20) DEFAULT NULL AFTER `done_by_user_id`;
ALTER TABLE `payments` ADD COLUMN `payment_done_by_email` VARCHAR(191) DEFAULT NULL AFTER `payment_done_by_mobile`;
ALTER TABLE `payments` ADD COLUMN `payment_done_by_name` VARCHAR(150) DEFAULT NULL AFTER `payment_done_by_email`;
ALTER TABLE `payments` ADD COLUMN `payment_status` ENUM('pending','success','failed','refunded') DEFAULT 'pending' AFTER `status`;
ALTER TABLE `payments` ADD COLUMN `payment_method` VARCHAR(50) DEFAULT NULL AFTER `method`;
ALTER TABLE `payments` ADD COLUMN `payment_mode` ENUM('online','offline') DEFAULT 'online' AFTER `payment_method`;
ALTER TABLE `payments` ADD COLUMN `payment_timestamp` DATETIME DEFAULT NULL AFTER `payment_mode`;
ALTER TABLE `payments` ADD COLUMN `amount` DECIMAL(10,2) DEFAULT NULL AFTER `total`;
ALTER TABLE `payments` ADD COLUMN `currency` VARCHAR(10) DEFAULT 'INR' AFTER `amount`;
ALTER TABLE `payments` ADD COLUMN `transaction_id` VARCHAR(255) DEFAULT NULL AFTER `currency`;
ALTER TABLE `payments` ADD COLUMN `vendor_payout_amount` DECIMAL(10,2) DEFAULT NULL AFTER `vendor_amount`;
ALTER TABLE `payments` ADD COLUMN `transfer_id` VARCHAR(255) DEFAULT NULL AFTER `vendor_transfer_id`;

-- Copy existing data
UPDATE `payments` SET `done_by_user_id` = `user_id` WHERE `done_by_user_id` IS NULL;
UPDATE `payments` SET `payment_status` = CASE
  WHEN LOWER(`status`) = 'pending' THEN 'pending'
  WHEN LOWER(`status`) = 'success' THEN 'success'
  WHEN LOWER(`status`) = 'failed' THEN 'failed'
  WHEN LOWER(`status`) = 'refunded' THEN 'refunded'
  ELSE 'pending'
END;
UPDATE `payments` SET `payment_method` = `method` WHERE `payment_method` IS NULL AND `method` IS NOT NULL;
UPDATE `payments` SET `amount` = `total` WHERE `amount` IS NULL AND `total` IS NOT NULL;
UPDATE `payments` SET `payment_timestamp` = `created_at` WHERE `payment_timestamp` IS NULL;
UPDATE `payments` SET `vendor_payout_amount` = CAST(`vendor_amount` AS DECIMAL(10,2)) WHERE `vendor_payout_amount` IS NULL AND `vendor_amount` IS NOT NULL;
UPDATE `payments` SET `transfer_id` = `vendor_transfer_id` WHERE `transfer_id` IS NULL AND `vendor_transfer_id` IS NOT NULL;

-- Link payments to bookings (bookings have payment_id -> payments.id)
UPDATE `payments` p
  JOIN `bookings` b ON b.payment_id = p.id
  SET p.booking_id = b.id
  WHERE p.booking_id IS NULL;

-- Fill payment_done_by fields from users
UPDATE `payments` p
  JOIN `users` u ON u.id = p.user_id
  SET p.payment_done_by_name = u.name,
      p.payment_done_by_mobile = COALESCE(u.phone, u.mobile),
      p.payment_done_by_email = u.email
  WHERE p.payment_done_by_name IS NULL;

-- ────────────────────────────────────────────────────────────────────────────
-- 5. GAMES TABLE
--    Model expects: game_name, hosted_by_user_id, hosted_by_ground_owner_id,
--                   booking_id, max_participants, game_level, image, visibility, is_active
--    Production has: title, host_id, ground_id, total_slots, skill_level,
--                    is_public, status
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `games` ADD COLUMN `game_name` VARCHAR(255) DEFAULT NULL AFTER `id`;
ALTER TABLE `games` ADD COLUMN `hosted_by_user_id` INT UNSIGNED DEFAULT NULL AFTER `host_id`;
ALTER TABLE `games` ADD COLUMN `hosted_by_ground_owner_id` INT UNSIGNED DEFAULT NULL AFTER `hosted_by_user_id`;
ALTER TABLE `games` ADD COLUMN `booking_id` INT UNSIGNED DEFAULT NULL AFTER `hosted_by_ground_owner_id`;
ALTER TABLE `games` ADD COLUMN `max_participants` INT DEFAULT 10 AFTER `total_slots`;
ALTER TABLE `games` ADD COLUMN `game_level` ENUM('newbie','beginner','intermediate','advanced','professional','ultra_professional') DEFAULT 'beginner' AFTER `skill_level`;
ALTER TABLE `games` ADD COLUMN `image` TEXT DEFAULT NULL AFTER `description`;
ALTER TABLE `games` ADD COLUMN `visibility` ENUM('public','private') DEFAULT 'public' AFTER `is_public`;
ALTER TABLE `games` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `status`;

-- Copy existing data
UPDATE `games` SET `game_name` = `title` WHERE `game_name` IS NULL AND `title` IS NOT NULL;
UPDATE `games` SET `hosted_by_user_id` = `host_id` WHERE `hosted_by_user_id` IS NULL AND `host_id` IS NOT NULL;
UPDATE `games` SET `max_participants` = `total_slots` WHERE `total_slots` IS NOT NULL;
UPDATE `games` SET `game_level` = CASE
  WHEN `skill_level` = 'Beginner' THEN 'beginner'
  WHEN `skill_level` = 'Intermediate' THEN 'intermediate'
  WHEN `skill_level` = 'Advanced' THEN 'advanced'
  ELSE 'beginner'
END WHERE `skill_level` IS NOT NULL;
UPDATE `games` SET `visibility` = CASE WHEN `is_public` = 1 THEN 'public' ELSE 'private' END;
UPDATE `games` SET `is_active` = CASE WHEN `status` IN ('open','full') THEN 1 ELSE 0 END;

-- ────────────────────────────────────────────────────────────────────────────
-- 6. COACHES TABLE
--    Model expects: name, sport_name, experience_years, level, mobile, email,
--                   about, experience_details, awards, qualities, profile_picture,
--                   is_approved, is_active
--    Production has: user_id, expertise, bio, experience, hourly_rate, is_verified, status
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `coaches` ADD COLUMN `name` VARCHAR(150) DEFAULT NULL AFTER `id`;
ALTER TABLE `coaches` ADD COLUMN `sport_name` VARCHAR(150) DEFAULT NULL AFTER `name`;
ALTER TABLE `coaches` ADD COLUMN `experience_years` INT DEFAULT NULL AFTER `sport_name`;
ALTER TABLE `coaches` ADD COLUMN `level` ENUM('beginner','intermediate','advanced','professional') DEFAULT 'beginner' AFTER `experience_years`;
ALTER TABLE `coaches` ADD COLUMN `mobile` VARCHAR(20) DEFAULT NULL AFTER `level`;
ALTER TABLE `coaches` ADD COLUMN `email` VARCHAR(191) DEFAULT NULL AFTER `mobile`;
ALTER TABLE `coaches` ADD COLUMN `about` TEXT DEFAULT NULL AFTER `email`;
ALTER TABLE `coaches` ADD COLUMN `experience_details` TEXT DEFAULT NULL AFTER `about`;
ALTER TABLE `coaches` ADD COLUMN `awards` TEXT DEFAULT NULL AFTER `experience_details`;
ALTER TABLE `coaches` ADD COLUMN `qualities` TEXT DEFAULT NULL AFTER `awards`;
ALTER TABLE `coaches` ADD COLUMN `profile_picture` TEXT DEFAULT NULL AFTER `qualities`;
ALTER TABLE `coaches` ADD COLUMN `is_approved` TINYINT(1) DEFAULT 0 AFTER `profile_picture`;
ALTER TABLE `coaches` ADD COLUMN `is_active` TINYINT(1) DEFAULT 1 AFTER `is_approved`;

-- Copy existing data from old columns
UPDATE `coaches` SET `about` = `bio` WHERE `about` IS NULL AND `bio` IS NOT NULL;
UPDATE `coaches` SET `is_approved` = `is_verified`;
UPDATE `coaches` SET `is_active` = CASE WHEN `status` = 'active' THEN 1 ELSE 0 END;
-- Copy name from linked user
UPDATE `coaches` c
  JOIN `users` u ON u.id = c.user_id
  SET c.name = u.name, c.mobile = COALESCE(u.phone, u.mobile), c.email = u.email
  WHERE c.name IS NULL;
-- Parse experience string to integer (e.g. '10 Years' -> 10)
UPDATE `coaches` SET `experience_years` = CAST(`experience` AS UNSIGNED) WHERE `experience` IS NOT NULL;

-- ────────────────────────────────────────────────────────────────────────────
-- 7. BOOKED_SLOTS TABLE
--    Model expects: id, booking_id, slot_id (simple pivot)
--    Production has: id, user_id, booking_id, ground_id, ground_slot_id, etc.
--    Need to add slot_id column
-- ────────────────────────────────────────────────────────────────────────────

ALTER TABLE `booked_slots` ADD COLUMN `slot_id` INT UNSIGNED DEFAULT NULL AFTER `ground_slot_id`;

-- If ground_slot_id maps to slots, copy it
UPDATE `booked_slots` SET `slot_id` = `ground_slot_id` WHERE `slot_id` IS NULL AND `ground_slot_id` IS NOT NULL;

-- ────────────────────────────────────────────────────────────────────────────
-- 8. FAVORITES TABLE
--    Model uses updatedAt: false, so no issue. But ensure created_at exists
--    (it does in production). No changes needed.
-- ────────────────────────────────────────────────────────────────────────────

-- No changes needed for favorites.

-- ────────────────────────────────────────────────────────────────────────────
-- DONE! Verify by running: SELECT COUNT(*) FROM users WHERE mobile IS NOT NULL;
-- ============================================================================
