const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Coach = sequelize.define(
    'Coach',
    {
      id:                 { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:               { type: DataTypes.STRING(150), allowNull: false },
      sport_id:           { type: DataTypes.INTEGER.UNSIGNED },
      sport_name:         { type: DataTypes.STRING(150) },
      experience_years:   { type: DataTypes.INTEGER },
      level:              {
        type: DataTypes.ENUM('beginner', 'intermediate', 'advanced', 'professional'),
        defaultValue: 'beginner',
      },
      mobile:             { type: DataTypes.STRING(20) },
      email:              { type: DataTypes.STRING(191) },
      city:               { type: DataTypes.STRING(100) },
      // A coach signs in with this panel, so the row is an account and not
      // only a directory entry. Nullable because an admin may create the
      // profile first and issue credentials afterwards.
      password_hash:      { type: DataTypes.STRING(255) },
      // One 30-minute block, exactly like grounds.price_per_slot. A coach
      // priced at 0 cannot be booked — see coachBooking.controller.
      price_per_slot:     { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
      about:              { type: DataTypes.TEXT },
      experience_details: { type: DataTypes.TEXT },
      awards:             { type: DataTypes.TEXT },
      latitude:           { type: DataTypes.DECIMAL(10, 7) },
      longitude:          { type: DataTypes.DECIMAL(10, 7) },
      availability:       { type: DataTypes.STRING(255) },
      qualities:          { type: DataTypes.TEXT },
      profile_picture:    { type: DataTypes.TEXT },
      rejection_reason:   { type: DataTypes.TEXT },
      last_login_at:      { type: DataTypes.DATE },
      is_approved:        { type: DataTypes.BOOLEAN, defaultValue: false },
      is_active:          { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    {
      tableName: 'coaches',
      underscored: true,
      // Nothing that reads a coach should hand its hash back over the wire.
      // Login and password change read through `Coach.unscoped()`, which is
      // the one place the column is wanted.
      defaultScope: { attributes: { exclude: ['password_hash'] } },
    }
  );
  return Coach;
};
