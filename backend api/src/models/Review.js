const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Review = sequelize.define(
    'Review',
    {
      id:                   { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      reviewed_by_user_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      review_type:          {
        type: DataTypes.ENUM('ground', 'sport', 'coach', 'application'),
        allowNull: false,
      },
      ground_id:            { type: DataTypes.INTEGER.UNSIGNED },
      ground_sport_id:      { type: DataTypes.INTEGER.UNSIGNED },
      coach_id:             { type: DataTypes.INTEGER.UNSIGNED },
      booking_id:           { type: DataTypes.INTEGER.UNSIGNED },
      rating:               { type: DataTypes.TINYINT.UNSIGNED, allowNull: false },
      comment:              { type: DataTypes.TEXT },
      is_active:            { type: DataTypes.BOOLEAN, defaultValue: true },
    },
    { tableName: 'reviews', underscored: true }
  );
  return Review;
};
