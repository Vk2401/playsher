const { DataTypes } = require('sequelize');

/** Which of the coach's blocks a session consumed. */
module.exports = (sequelize) => {
  const CoachBookingSlot = sequelize.define(
    'CoachBookingSlot',
    {
      id:               { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      coach_booking_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      coach_slot_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'coach_booking_slots', underscored: true }
  );
  return CoachBookingSlot;
};
