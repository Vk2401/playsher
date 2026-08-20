-- Migration: 5-minute slot holds for unpaid online bookings
-- Run: mysql -u root -p playsher < database/migrations/add_booking_slot_holds.sql
--
-- Creating a booking marks its slots unavailable inside the transaction. For an
-- online payment the booking stays `pending` until Razorpay confirms — and
-- nothing ever released it. A user who opened the checkout sheet and closed it
-- blocked those slots permanently. hold_expires_at gives the hold a deadline so
-- abandoned attempts return to the pool.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS hold_expires_at DATETIME NULL AFTER status;

-- The sweep looks up pending bookings whose hold has lapsed.
CREATE INDEX idx_booking_hold ON bookings (status, hold_expires_at);
