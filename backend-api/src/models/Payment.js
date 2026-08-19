const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Payment = sequelize.define(
    'Payment',
    {
      id:                     { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      booking_id:             { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      done_by_user_id:        { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      payment_done_by_mobile: { type: DataTypes.STRING(20) },
      payment_done_by_email:  { type: DataTypes.STRING(191) },
      payment_done_by_name:   { type: DataTypes.STRING(150) },
      payment_status:         {
        type: DataTypes.ENUM('pending', 'success', 'failed', 'refunded'),
        defaultValue: 'pending',
      },
      payment_method:         { type: DataTypes.STRING(50) },
      payment_mode:           { type: DataTypes.ENUM('online', 'offline'), defaultValue: 'online' },
      payment_timestamp:      { type: DataTypes.DATE },
      amount:                 { type: DataTypes.DECIMAL(10, 2), allowNull: false },
      currency:               { type: DataTypes.STRING(10), defaultValue: 'INR' },
      transaction_id:         { type: DataTypes.STRING(255) },
      razorpay_order_id:      { type: DataTypes.STRING(255), allowNull: true },
      razorpay_payment_id:    { type: DataTypes.STRING(255), allowNull: true },
      razorpay_signature:     { type: DataTypes.STRING(255), allowNull: true },
      vendor_payout_status:   {
        type: DataTypes.ENUM('pending', 'transferred', 'no_bank_details', 'no_vendor'),
        defaultValue: 'pending',
      },
      vendor_payout_amount:   { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      platform_fee:           { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      transfer_id:            { type: DataTypes.STRING(255), allowNull: true },
    },
    { tableName: 'payments', underscored: true }
  );
  return Payment;
};
