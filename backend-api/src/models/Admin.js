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
      profile_picture: { type: DataTypes.TEXT('long') },
      is_active:       { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'admins', underscored: true }
  );
  return Admin;
};
