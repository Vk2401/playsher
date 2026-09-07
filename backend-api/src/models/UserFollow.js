const { DataTypes } = require('sequelize');

/**
 * One player following another.
 *
 * Directed, not mutual: (a follows b) and (b follows a) are two separate rows,
 * and either can exist without the other. That is what makes "invite the people
 * you play with" work without asking both sides to agree first — the whole
 * point is to lower the cost of getting a game together.
 */
module.exports = (sequelize) => {
  const UserFollow = sequelize.define(
    'UserFollow',
    {
      id:           { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      follower_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      following_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
    },
    { tableName: 'user_follows', underscored: true }
  );
  return UserFollow;
};
