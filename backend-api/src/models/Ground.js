const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Ground = sequelize.define(
    'Ground',
    {
      id:          { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:        { type: DataTypes.STRING(255), allowNull: false },
      about:       { type: DataTypes.TEXT },
      description: { type: DataTypes.TEXT },
      latitude:    { type: DataTypes.DECIMAL(10, 7) },
      longitude:   { type: DataTypes.DECIMAL(10, 7) },
      address:     { type: DataTypes.TEXT },
      venue_rules: { type: DataTypes.TEXT },
      is_approved: { type: DataTypes.BOOLEAN, defaultValue: false },
      is_active:   { type: DataTypes.BOOLEAN, defaultValue: true },
      owner_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      deleted_at:  { type: DataTypes.DATE },
    },
    { tableName: 'grounds', underscored: true }
  );
  return Ground;
};
