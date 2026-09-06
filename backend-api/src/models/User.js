const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const User = sequelize.define(
    'User',
    {
      id:                { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:              { type: DataTypes.STRING(150), allowNull: false },
      // The handle a player is found and invited by. Nullable only because the
      // unique index had to be applied to a live table — every account gets one
      // at registration, and an older row is backfilled on its first profile
      // read. Always stored lowercase; see utils/username.js.
      username:          { type: DataTypes.STRING(30), unique: true },
      bio:               { type: DataTypes.STRING(160) },
      mobile:            { type: DataTypes.STRING(20), allowNull: false, unique: true },
      email:             { type: DataTypes.STRING(191), unique: true },
      password_hash:     { type: DataTypes.STRING(255) },
      profile_picture:   { type: DataTypes.TEXT('long') },
      current_latitude:  { type: DataTypes.DECIMAL(10, 7) },
      current_longitude: { type: DataTypes.DECIMAL(10, 7) },
      is_active:         { type: DataTypes.BOOLEAN, defaultValue: true },
      is_verified:       { type: DataTypes.BOOLEAN, defaultValue: false },
      deleted_at:        { type: DataTypes.DATE },
    },
    { tableName: 'users', underscored: true }
  );
  return User;
};
