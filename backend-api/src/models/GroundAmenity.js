const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const GroundAmenity = sequelize.define(
    'GroundAmenity',
    {
      id:         { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      ground_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      amenity_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'ground_amenities', underscored: true, updatedAt: false }
  );
  return GroundAmenity;
};
