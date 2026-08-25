const { DataTypes } = require('sequelize');

/**
 * A customer's coaching session.
 *
 * Kept apart from `bookings` because that table is anchored to a
 * `ground_sport_id` that a coaching session may not have: a coach can be booked
 * at a ground they are approved at, or with no venue at all.
 */
module.exports = (sequelize) => {
  const CoachBooking = sequelize.define(
    'CoachBooking',
    {
      id:                  { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:             { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      coach_id:            { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      ground_id:           { type: DataTypes.INTEGER.UNSIGNED },
      session_date:        { type: DataTypes.DATEONLY, allowNull: false },
      time_from:           { type: DataTypes.TIME, allowNull: false },
      time_to:             { type: DataTypes.TIME, allowNull: false },
      total_amount:        { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      advance_amount:      { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      balance_due:         { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      status:              {
        type: DataTypes.ENUM('pending', 'confirmed', 'rejected', 'cancelled', 'completed'),
        defaultValue: 'pending',
      },
      payment_method:      { type: DataTypes.STRING(20), defaultValue: 'pay_at_ground' },
      payment_id:          { type: DataTypes.INTEGER.UNSIGNED },
      booking_reference:   { type: DataTypes.STRING(50) },
      customer_note:       { type: DataTypes.TEXT },
      coach_note:          { type: DataTypes.TEXT },
      cancellation_reason: { type: DataTypes.TEXT },
      hold_expires_at:     { type: DataTypes.DATE },
    },
    { tableName: 'coach_bookings', underscored: true }
  );
  return CoachBooking;
};
