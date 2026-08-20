-- Migration: advance payment on pay-at-ground bookings
-- Run: mysql -u root -p playsher < database/migrations/add_booking_advance_payment.sql
--
-- A pay-at-ground booking now takes a non-refundable advance online (10% of the
-- total, floored at ₹10) and leaves the balance to be collected at the venue.
-- Both figures are stored so the ticket, the owner's list and any later
-- reconciliation all read the same numbers rather than recomputing a percentage
-- that may have changed since.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS advance_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER total_amount,
  ADD COLUMN IF NOT EXISTS balance_due    DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER advance_amount;
