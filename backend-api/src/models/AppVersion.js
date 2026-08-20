const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const AppVersion = sequelize.define(
    'AppVersion',
    {
      id:                    { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      platform:              { type: DataTypes.ENUM('android', 'ios'), allowNull: false, unique: true },
      latest_version:        { type: DataTypes.STRING(20), allowNull: false },
      min_supported_version: { type: DataTypes.STRING(20), allowNull: false },
      update_url:            { type: DataTypes.STRING(255) },
      release_notes:         { type: DataTypes.TEXT },
      // Off means the app is told nothing and never prompts — the kill switch
      // for a bad rollout, so a wrong version number can be walked back without
      // shipping a new build.
      is_active:             { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'app_versions', underscored: true }
  );
  return AppVersion;
};
