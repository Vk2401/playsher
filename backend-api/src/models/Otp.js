const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Otp = sequelize.define(
    'Otp',
    {
      id:          { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      mobile:      { type: DataTypes.STRING(20), allowNull: false, unique: true },
      otp:         { type: DataTypes.STRING(6), allowNull: false },
      expires_at:  { type: DataTypes.DATE, allowNull: false },
      is_verified: { type: DataTypes.BOOLEAN, defaultValue: false },
    },
    { tableName: 'otps', underscored: true }
  );
  return Otp;
};
