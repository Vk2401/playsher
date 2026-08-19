const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const GroundSport = sequelize.define(
    'GroundSport',
    {
      id:                   { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      ground_id:            { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      sport_id:             { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      price_per_half_hour:  { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      min_slots:            { type: DataTypes.INTEGER, defaultValue: 1 },
      max_slots:            { type: DataTypes.INTEGER, defaultValue: 4 },
      player_counts:        { type: DataTypes.STRING(255) },
      cancellation_policy:  { type: DataTypes.TEXT },
      is_active:            { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'ground_sports', underscored: true }
  );
  return GroundSport;
};
