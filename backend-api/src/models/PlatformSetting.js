const { DataTypes } = require('sequelize');

/**
 * Operator-tunable values that must outlive a deploy.
 *
 * A key/value table rather than a column per setting: these are read rarely,
 * written by hand, and adding one should not mean a schema change and a model
 * edit. Values are stored as text and parsed by whoever reads them, so a bad
 * value is caught by that reader's own validation rather than by the column.
 *
 * This is configuration, not history. A setting says what applies *now* — what
 * applied to a past payment is stored on that payment.
 */
module.exports = (sequelize) => {
  const PlatformSetting = sequelize.define(
    'PlatformSetting',
    {
      id:          { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      setting_key: { type: DataTypes.STRING(64), allowNull: false, unique: true },
      value:       { type: DataTypes.STRING(255), allowNull: false },
      updated_by:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: true },
    },
    { tableName: 'platform_settings', underscored: true }
  );
  return PlatformSetting;
};
