const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const RefreshToken = sequelize.define(
    'RefreshToken',
    {
      id:         { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      user_type:  { type: DataTypes.ENUM('admin', 'user', 'ground_owner', 'coach'), allowNull: false },
      token:      { type: DataTypes.STRING(512), allowNull: false, unique: true },
      expires_at: { type: DataTypes.DATE, allowNull: false },
      is_revoked: { type: DataTypes.BOOLEAN, defaultValue: false },
    },
    { tableName: 'refresh_tokens', underscored: true, updatedAt: false }
  );
  return RefreshToken;
};
