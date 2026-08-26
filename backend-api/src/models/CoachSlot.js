const { DataTypes } = require('sequelize');

/** One concrete 30-minute block of a coach's day. */
module.exports = (sequelize) => {
  const CoachSlot = sequelize.define(
    'CoachSlot',
    {
      id:              { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      coach_id:        { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      slot_date:       { type: DataTypes.DATEONLY, allowNull: false },
      slot_start_time: { type: DataTypes.TIME, allowNull: false },
      slot_end_time:   { type: DataTypes.TIME, allowNull: false },
      is_available:    { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'coach_slots', underscored: true }
  );
  return CoachSlot;
};
