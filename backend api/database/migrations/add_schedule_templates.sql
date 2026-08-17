-- Migration: Weekly Schedule Templates & Booking Reference
-- Run: mysql -u root -p playsher < database/migrations/add_schedule_templates.sql

-- 1. Schedule templates table
CREATE TABLE IF NOT EXISTS schedule_templates (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ground_sport_id INT UNSIGNED NOT NULL,
  day_of_week TINYINT UNSIGNED NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_closed TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_gs_day (ground_sport_id, day_of_week),
  FOREIGN KEY (ground_sport_id) REFERENCES ground_sports(id) ON DELETE CASCADE
);

-- 2. Booking reference column
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS booking_reference VARCHAR(50) AFTER id;
CREATE UNIQUE INDEX uq_booking_ref ON bookings(booking_reference);

-- 3. Payment method column
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) DEFAULT 'pay_at_ground' AFTER status;

-- 4. Unique composite index on slots to prevent duplicate generation
CREATE UNIQUE INDEX uq_slot_unique ON slots(ground_sport_id, slot_date, slot_start_time, slot_end_time);
