const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Booking = sequelize.define(
    'Booking',
    {
      id:                   { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:              { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      ground_sport_id:      { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      slot_date:            { type: DataTypes.DATEONLY, allowNull: false },
      slot_time_from:       { type: DataTypes.TIME, allowNull: false },
      slot_time_to:         { type: DataTypes.TIME, allowNull: false },
      total_amount:         { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      is_game:              { type: DataTypes.BOOLEAN, defaultValue: false },
      is_canceled:          { type: DataTypes.BOOLEAN, defaultValue: false },
      cancellation_reason:  { type: DataTypes.TEXT },
      payment_id:           { type: DataTypes.INTEGER.UNSIGNED },
      booking_reference:    { type: DataTypes.STRING(50), unique: true },
      payment_method:       { type: DataTypes.STRING(20), defaultValue: 'pay_at_ground' },
      // When an unpaid online booking's slot hold lapses. Null once the
      // booking is settled, or for pay-at-ground bookings, which never hold.
      hold_expires_at:      { type: DataTypes.DATE, allowNull: true },
      status:               {
        type: DataTypes.ENUM('pending', 'confirmed', 'cancelled', 'completed'),
        defaultValue: 'pending',
      },
    },
    { tableName: 'bookings', underscored: true }
  );
  return Booking;
};
