-- schema.sql predates the Razorpay integration and vendor payouts, so the
-- payments table is missing seven columns that src/models/Payment.js declares.
-- Without these, every payment endpoint fails with "Unknown column".

ALTER TABLE `payments`
  ADD COLUMN `razorpay_order_id`    VARCHAR(255) DEFAULT NULL AFTER `transaction_id`,
  ADD COLUMN `razorpay_payment_id`  VARCHAR(255) DEFAULT NULL AFTER `razorpay_order_id`,
  ADD COLUMN `razorpay_signature`   VARCHAR(255) DEFAULT NULL AFTER `razorpay_payment_id`,
  ADD COLUMN `vendor_payout_status` ENUM('pending','transferred','no_bank_details','no_vendor')
                                    DEFAULT 'pending' AFTER `razorpay_signature`,
  ADD COLUMN `vendor_payout_amount` DECIMAL(10,2) DEFAULT NULL AFTER `vendor_payout_status`,
  ADD COLUMN `platform_fee`         DECIMAL(10,2) DEFAULT NULL AFTER `vendor_payout_amount`,
  ADD COLUMN `transfer_id`          VARCHAR(255) DEFAULT NULL AFTER `platform_fee`;

CREATE INDEX `payments_razorpay_order_idx` ON `payments` (`razorpay_order_id`);
