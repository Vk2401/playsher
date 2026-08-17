-- Playsher Database Schema
-- MySQL 8.0+
-- Run: mysql -u root -p playsher_db < schema.sql

-- CREATE DATABASE IF NOT EXISTS playsher_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE playsher_db;
USE playsher_db;

-- 1. admins
CREATE TABLE IF NOT EXISTS admins (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(150) NOT NULL,
  email           VARCHAR(191) NOT NULL UNIQUE,
  mobile          VARCHAR(20)  NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  profile_picture LONGTEXT,
  is_active       TINYINT(1) NOT NULL DEFAULT 1,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. users
CREATE TABLE IF NOT EXISTS users (
  id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(150) NOT NULL,
  mobile              VARCHAR(20)  NOT NULL UNIQUE,
  email               VARCHAR(191) UNIQUE,
  password_hash       VARCHAR(255),
  profile_picture     LONGTEXT,
  current_latitude    DECIMAL(10, 7),
  current_longitude   DECIMAL(10, 7),
  is_active           TINYINT(1) NOT NULL DEFAULT 1,
  is_verified         TINYINT(1) NOT NULL DEFAULT 0,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at          DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. ground_owners
CREATE TABLE IF NOT EXISTS ground_owners (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(150) NOT NULL,
  email           VARCHAR(191) NOT NULL UNIQUE,
  mobile          VARCHAR(20)  NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  profile_picture LONGTEXT,
  is_active       TINYINT(1) NOT NULL DEFAULT 1,
  is_approved     TINYINT(1) NOT NULL DEFAULT 0,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. grounds
CREATE TABLE IF NOT EXISTS grounds (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  about       TEXT,
  description TEXT,
  latitude    DECIMAL(10, 7),
  longitude   DECIMAL(10, 7),
  address     TEXT,
  venue_rules TEXT,
  is_approved TINYINT(1) NOT NULL DEFAULT 0,
  is_active   TINYINT(1) NOT NULL DEFAULT 1,
  owner_id    INT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at  DATETIME,
  CONSTRAINT fk_ground_owner FOREIGN KEY (owner_id) REFERENCES ground_owners(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. ground_images
CREATE TABLE IF NOT EXISTS ground_images (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ground_id  INT UNSIGNED NOT NULL,
  image      LONGTEXT NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_gi_ground FOREIGN KEY (ground_id) REFERENCES grounds(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. amenities
CREATE TABLE IF NOT EXISTS amenities (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  icon       VARCHAR(255),
  type       ENUM('venue','sport') NOT NULL DEFAULT 'venue',
  is_active  TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. ground_amenities (pivot)
CREATE TABLE IF NOT EXISTS ground_amenities (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ground_id   INT UNSIGNED NOT NULL,
  amenity_id  INT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ground_amenity (ground_id, amenity_id),
  CONSTRAINT fk_ga_ground   FOREIGN KEY (ground_id)  REFERENCES grounds(id)   ON DELETE CASCADE,
  CONSTRAINT fk_ga_amenity  FOREIGN KEY (amenity_id) REFERENCES amenities(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. sports
CREATE TABLE IF NOT EXISTS sports (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name              VARCHAR(150) NOT NULL,
  short_description VARCHAR(500),
  image             TEXT,
  place_type        ENUM('ground','court') NOT NULL DEFAULT 'ground',
  sports_type       ENUM('indoor','outdoor') NOT NULL DEFAULT 'outdoor',
  is_approved       TINYINT(1) NOT NULL DEFAULT 0,
  is_active         TINYINT(1) NOT NULL DEFAULT 1,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. ground_sports
CREATE TABLE IF NOT EXISTS ground_sports (
  id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ground_id             INT UNSIGNED NOT NULL,
  sport_id              INT UNSIGNED NOT NULL,
  price_per_half_hour   DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  min_slots             INT NOT NULL DEFAULT 1,
  max_slots             INT NOT NULL DEFAULT 4,
  player_counts         VARCHAR(255),
  cancellation_policy   TEXT,
  is_active             TINYINT(1) NOT NULL DEFAULT 1,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ground_sport (ground_id, sport_id),
  CONSTRAINT fk_gs_ground FOREIGN KEY (ground_id) REFERENCES grounds(id) ON DELETE CASCADE,
  CONSTRAINT fk_gs_sport  FOREIGN KEY (sport_id)  REFERENCES sports(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. slots
CREATE TABLE IF NOT EXISTS slots (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ground_sport_id  INT UNSIGNED NOT NULL,
  slot_date        DATE NOT NULL,
  slot_start_time  TIME NOT NULL,
  slot_end_time    TIME NOT NULL,
  is_available     TINYINT(1) NOT NULL DEFAULT 1,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_slot_gs FOREIGN KEY (ground_sport_id) REFERENCES ground_sports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. bookings
CREATE TABLE IF NOT EXISTS bookings (
  id                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id              INT UNSIGNED NOT NULL,
  ground_sport_id      INT UNSIGNED NOT NULL,
  slot_date            DATE NOT NULL,
  slot_time_from       TIME NOT NULL,
  slot_time_to         TIME NOT NULL,
  total_amount         DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  is_game              TINYINT(1) NOT NULL DEFAULT 0,
  is_canceled          TINYINT(1) NOT NULL DEFAULT 0,
  cancellation_reason  TEXT,
  payment_id           INT UNSIGNED,
  status               ENUM('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending',
  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_booking_user FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE,
  CONSTRAINT fk_booking_gs   FOREIGN KEY (ground_sport_id) REFERENCES ground_sports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 12. booked_slots (pivot)
CREATE TABLE IF NOT EXISTS booked_slots (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id  INT UNSIGNED NOT NULL,
  slot_id     INT UNSIGNED NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_booked_slot (booking_id, slot_id),
  CONSTRAINT fk_bs_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
  CONSTRAINT fk_bs_slot    FOREIGN KEY (slot_id)    REFERENCES slots(id)    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 13. payments
CREATE TABLE IF NOT EXISTS payments (
  id                      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id              INT UNSIGNED NOT NULL,
  done_by_user_id         INT UNSIGNED NOT NULL,
  payment_done_by_mobile  VARCHAR(20),
  payment_done_by_email   VARCHAR(191),
  payment_done_by_name    VARCHAR(150),
  payment_status          ENUM('pending','success','failed','refunded') NOT NULL DEFAULT 'pending',
  payment_method          VARCHAR(50),
  payment_mode            ENUM('online','offline') NOT NULL DEFAULT 'online',
  payment_timestamp       DATETIME,
  amount                  DECIMAL(10, 2) NOT NULL,
  currency                VARCHAR(10) NOT NULL DEFAULT 'INR',
  transaction_id          VARCHAR(255),
  created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pay_booking FOREIGN KEY (booking_id)      REFERENCES bookings(id) ON DELETE CASCADE,
  CONSTRAINT fk_pay_user    FOREIGN KEY (done_by_user_id) REFERENCES users(id)    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add FK from bookings.payment_id → payments.id (after payments table exists)
ALTER TABLE bookings
  ADD CONSTRAINT fk_booking_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL;

-- 14. games
CREATE TABLE IF NOT EXISTS games (
  id                          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  game_name                   VARCHAR(255) NOT NULL,
  hosted_by_user_id           INT UNSIGNED,
  hosted_by_ground_owner_id   INT UNSIGNED,
  booking_id                  INT UNSIGNED NOT NULL,
  max_participants            INT NOT NULL DEFAULT 10,
  game_level                  ENUM('newbie','beginner','intermediate','advanced','professional','ultra_professional') NOT NULL DEFAULT 'beginner',
  description                 TEXT,
  image                       TEXT,
  visibility                  ENUM('public','private') NOT NULL DEFAULT 'public',
  is_active                   TINYINT(1) NOT NULL DEFAULT 1,
  created_at                  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at                  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_game_user    FOREIGN KEY (hosted_by_user_id)         REFERENCES users(id)         ON DELETE SET NULL,
  CONSTRAINT fk_game_owner   FOREIGN KEY (hosted_by_ground_owner_id) REFERENCES ground_owners(id) ON DELETE SET NULL,
  CONSTRAINT fk_game_booking FOREIGN KEY (booking_id)                REFERENCES bookings(id)      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 15. game_participants
CREATE TABLE IF NOT EXISTS game_participants (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  game_id    INT UNSIGNED NOT NULL,
  user_id    INT UNSIGNED NOT NULL,
  status     ENUM('invited','accepted','declined','joined') NOT NULL DEFAULT 'invited',
  joined_at  DATETIME,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_game_participant (game_id, user_id),
  CONSTRAINT fk_gp_game FOREIGN KEY (game_id) REFERENCES games(id) ON DELETE CASCADE,
  CONSTRAINT fk_gp_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 16. coaches
CREATE TABLE IF NOT EXISTS coaches (
  id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(150) NOT NULL,
  sport_name          VARCHAR(150),
  experience_years    INT,
  level               ENUM('beginner','intermediate','advanced','professional') NOT NULL DEFAULT 'beginner',
  mobile              VARCHAR(20),
  email               VARCHAR(191),
  about               TEXT,
  experience_details  TEXT,
  awards              TEXT,
  latitude            DECIMAL(10, 7),
  longitude           DECIMAL(10, 7),
  availability        VARCHAR(255),
  qualities           TEXT,
  profile_picture     TEXT,
  is_approved         TINYINT(1) NOT NULL DEFAULT 0,
  is_active           TINYINT(1) NOT NULL DEFAULT 1,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 17. reviews
CREATE TABLE IF NOT EXISTS reviews (
  id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reviewed_by_user_id   INT UNSIGNED NOT NULL,
  review_type           ENUM('ground','sport','coach','application') NOT NULL,
  ground_id             INT UNSIGNED,
  ground_sport_id       INT UNSIGNED,
  coach_id              INT UNSIGNED,
  booking_id            INT UNSIGNED,
  rating                TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment               TEXT,
  is_active             TINYINT(1) NOT NULL DEFAULT 1,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_rev_user    FOREIGN KEY (reviewed_by_user_id) REFERENCES users(id)         ON DELETE CASCADE,
  CONSTRAINT fk_rev_ground  FOREIGN KEY (ground_id)           REFERENCES grounds(id)       ON DELETE SET NULL,
  CONSTRAINT fk_rev_gs      FOREIGN KEY (ground_sport_id)     REFERENCES ground_sports(id) ON DELETE SET NULL,
  CONSTRAINT fk_rev_coach   FOREIGN KEY (coach_id)            REFERENCES coaches(id)       ON DELETE SET NULL,
  CONSTRAINT fk_rev_booking FOREIGN KEY (booking_id)          REFERENCES bookings(id)      ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 18. favorites
CREATE TABLE IF NOT EXISTS favorites (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  ground_id  INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_favorite (user_id, ground_id),
  CONSTRAINT fk_fav_user   FOREIGN KEY (user_id)   REFERENCES users(id)   ON DELETE CASCADE,
  CONSTRAINT fk_fav_ground FOREIGN KEY (ground_id) REFERENCES grounds(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 19. user_sport_preferences (pivot)
CREATE TABLE IF NOT EXISTS user_sport_preferences (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  sport_id   INT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_sport (user_id, sport_id),
  CONSTRAINT fk_usp_user  FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
  CONSTRAINT fk_usp_sport FOREIGN KEY (sport_id) REFERENCES sports(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 20. refresh_tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  user_type  ENUM('admin','user','ground_owner') NOT NULL,
  token      VARCHAR(512) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  is_revoked TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
