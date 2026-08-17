const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const GameParticipant = sequelize.define(
    'GameParticipant',
    {
      id:        { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      game_id:   { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      user_id:   { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      status:    {
        type: DataTypes.ENUM('invited', 'accepted', 'declined', 'joined'),
        defaultValue: 'invited',
      },
      joined_at: { type: DataTypes.DATE },
    },
    { tableName: 'game_participants', underscored: true }
  );
  return GameParticipant;
};
