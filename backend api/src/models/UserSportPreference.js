const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const UserSportPreference = sequelize.define(
    'UserSportPreference',
    {
      id:       { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      sport_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'user_sport_preferences', underscored: true, updatedAt: false }
  );
  return UserSportPreference;
};
