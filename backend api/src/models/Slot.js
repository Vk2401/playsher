const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Slot = sequelize.define(
    'Slot',
    {
      id:               { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      ground_sport_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      slot_date:        { type: DataTypes.DATEONLY, allowNull: false },
      slot_start_time:  { type: DataTypes.TIME, allowNull: false },
      slot_end_time:    { type: DataTypes.TIME, allowNull: false },
      is_available:     { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'slots', underscored: true }
  );
  return Slot;
};
