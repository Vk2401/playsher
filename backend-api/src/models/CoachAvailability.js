const { DataTypes } = require('sequelize');

/**
 * A coach's working hours for one weekday — the same shape as a ground's
 * ScheduleTemplate, so both sides of a session are described the same way.
 */
module.exports = (sequelize) => {
  const CoachAvailability = sequelize.define(
    'CoachAvailability',
    {
      id:          { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      coach_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      day_of_week: { type: DataTypes.TINYINT.UNSIGNED, allowNull: false }, // 0=Sun … 6=Sat
      start_time:  { type: DataTypes.TIME, allowNull: false },
      end_time:    { type: DataTypes.TIME, allowNull: false },
      is_closed:   { type: DataTypes.BOOLEAN, defaultValue: false },
    },
    {
      tableName: 'coach_availabilities',
      underscored: true,
      indexes: [
        { unique: true, fields: ['coach_id', 'day_of_week'], name: 'uq_coach_day' },
      ],
    }
  );
  return CoachAvailability;
};
