const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const GroundOwner = sequelize.define(
    'GroundOwner',
    {
      id:              { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:            { type: DataTypes.STRING(150), allowNull: false },
      email:           { type: DataTypes.STRING(191), allowNull: false, unique: true },
      mobile:          { type: DataTypes.STRING(20), allowNull: false, unique: true },
      password_hash:   { type: DataTypes.STRING(255), allowNull: false },
      profile_picture: { type: DataTypes.TEXT('long') },
      is_active:       { type: DataTypes.BOOLEAN, defaultValue: true },
      is_approved:     { type: DataTypes.BOOLEAN, defaultValue: false },
      // Razorpay Route linked account (`acc_...`). Null until the owner has
      // bank details and onboarding has succeeded; utils/razorpayRoute is the
      // only thing that writes it. Without one, their share of a payment stays
      // in the platform account and is reported as awaiting onboarding rather
      // than transferred.
      razorpay_linked_account_id: { type: DataTypes.STRING(40), allowNull: true },
      // Having an `acc_...` is not the same as being able to receive money.
      // Razorpay verifies a linked account after creation, and a transfer to
      // one that is not `activated` fails — so the state is tracked and checked
      // before we try, rather than discovered by a failed transfer.
      razorpay_account_status:    { type: DataTypes.STRING(32), allowNull: true },
    },
    { tableName: 'ground_owners', underscored: true }
  );
  return GroundOwner;
};
