const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const BankDetails = sequelize.define(
    'BankDetails',
    {
      id:                   { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      user_id:              { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      user_type:            {
        type: DataTypes.ENUM('ground_owner', 'user'),
        defaultValue: 'ground_owner',
      },
      account_holder_name:  { type: DataTypes.STRING(255), allowNull: false },
      account_number:       { type: DataTypes.STRING(50), allowNull: false },
      ifsc_code:            { type: DataTypes.STRING(20), allowNull: false },
      bank_name:            { type: DataTypes.STRING(255) },
      upi_id:               { type: DataTypes.STRING(100) },
    },
    { tableName: 'bank_details', underscored: true }
  );
  return BankDetails;
};
