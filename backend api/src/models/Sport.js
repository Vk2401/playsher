const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Sport = sequelize.define(
    'Sport',
    {
      id:                { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:              { type: DataTypes.STRING(150), allowNull: false },
      short_description: { type: DataTypes.STRING(500) },
      image:             { type: DataTypes.TEXT },
      place_type:        { type: DataTypes.ENUM('ground', 'court'), defaultValue: 'ground' },
      sports_type:       { type: DataTypes.ENUM('indoor', 'outdoor'), defaultValue: 'outdoor' },
      is_approved:       { type: DataTypes.BOOLEAN, defaultValue: false },
      is_active:         { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'sports', underscored: true }
  );
  return Sport;
};
