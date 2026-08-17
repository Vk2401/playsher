const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const BookedSlot = sequelize.define(
    'BookedSlot',
    {
      id:         { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      booking_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      slot_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'booked_slots', underscored: true, updatedAt: false }
  );
  return BookedSlot;
};
