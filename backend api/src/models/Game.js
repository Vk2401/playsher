const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Game = sequelize.define(
    'Game',
    {
      id:                         { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      game_name:                  { type: DataTypes.STRING(255), allowNull: false },
      hosted_by_user_id:          { type: DataTypes.INTEGER.UNSIGNED },
      hosted_by_ground_owner_id:  { type: DataTypes.INTEGER.UNSIGNED },
      booking_id:                 { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      max_participants:           { type: DataTypes.INTEGER, defaultValue: 10 },
      game_level:                 {
        type: DataTypes.ENUM('newbie', 'beginner', 'intermediate', 'advanced', 'professional', 'ultra_professional'),
        defaultValue: 'beginner',
      },
      description: { type: DataTypes.TEXT },
      image:       { type: DataTypes.TEXT },
      visibility:  { type: DataTypes.ENUM('public', 'private'), defaultValue: 'public' },
      is_active:   { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'games', underscored: true }
  );
  return Game;
};
