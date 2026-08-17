const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const ScheduleTemplate = sequelize.define(
    'ScheduleTemplate',
    {
      id:               { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      ground_sport_id:  { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      day_of_week:      { type: DataTypes.TINYINT.UNSIGNED, allowNull: false }, // 0=Sun … 6=Sat
      start_time:       { type: DataTypes.TIME, allowNull: false },
      end_time:         { type: DataTypes.TIME, allowNull: false },
      is_closed:        { type: DataTypes.BOOLEAN, defaultValue: false },
    },
    {
      tableName: 'schedule_templates',
      underscored: true,
      indexes: [
        { unique: true, fields: ['ground_sport_id', 'day_of_week'], name: 'uq_gs_day' },
      ],
    }
  );
  return ScheduleTemplate;
};
