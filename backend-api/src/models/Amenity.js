const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Amenity = sequelize.define(
    'Amenity',
    {
      id:        { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:      { type: DataTypes.STRING(150), allowNull: false },
      icon:      { type: DataTypes.STRING(255) },
      type:      { type: DataTypes.ENUM('venue', 'sport'), defaultValue: 'venue' },
      is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'amenities', underscored: true }
  );
  return Amenity;
};
