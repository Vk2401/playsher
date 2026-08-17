const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Favorite = sequelize.define(
    'Favorite',
    {
      id:        { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:   { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      ground_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'favorites', underscored: true, updatedAt: false }
  );
  return Favorite;
};
