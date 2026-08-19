const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Coach = sequelize.define(
    'Coach',
    {
      id:                 { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:               { type: DataTypes.STRING(150), allowNull: false },
      sport_name:         { type: DataTypes.STRING(150) },
      experience_years:   { type: DataTypes.INTEGER },
      level:              {
        type: DataTypes.ENUM('beginner', 'intermediate', 'advanced', 'professional'),
        defaultValue: 'beginner',
      },
      mobile:             { type: DataTypes.STRING(20) },
      email:              { type: DataTypes.STRING(191) },
      about:              { type: DataTypes.TEXT },
      experience_details: { type: DataTypes.TEXT },
      awards:             { type: DataTypes.TEXT },
      latitude:           { type: DataTypes.DECIMAL(10, 7) },
      longitude:          { type: DataTypes.DECIMAL(10, 7) },
      availability:       { type: DataTypes.STRING(255) },
      qualities:          { type: DataTypes.TEXT },
      profile_picture:    { type: DataTypes.TEXT },
      is_approved:        { type: DataTypes.BOOLEAN, defaultValue: false },
      is_active:          { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'coaches', underscored: true }
  );
  return Coach;
};
