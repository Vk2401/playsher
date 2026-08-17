const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const GroundImage = sequelize.define(
    'GroundImage',
    {
      id:         { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      ground_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      image:      { type: DataTypes.TEXT('long'), allowNull: false },
      is_primary: { type: DataTypes.BOOLEAN, defaultValue: false },
    },
    { tableName: 'ground_images', underscored: true }
  );
  return GroundImage;
};
