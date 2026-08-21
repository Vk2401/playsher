const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Admin = sequelize.define(
    'Admin',
    {
      id:              { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:            { type: DataTypes.STRING(150), allowNull: false },
      email:           { type: DataTypes.STRING(191), allowNull: false, unique: true },
      mobile:          { type: DataTypes.STRING(20), allowNull: false, unique: true },
      password_hash:   { type: DataTypes.STRING(255), allowNull: false },
      // Tier within the admin role, not a fourth role. Every row here still
      // authenticates as `admin` in the JWT — that string is the contract with
      // the mobile app and the panel — and only the management endpoints in
      // admin.controller care about the distinction.
      role:            { type: DataTypes.ENUM('super_admin', 'admin'), allowNull: false, defaultValue: 'admin' },
      profile_picture: { type: DataTypes.TEXT('long') },
      is_active:       { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'admins', underscored: true }
  );
  return Admin;
};
