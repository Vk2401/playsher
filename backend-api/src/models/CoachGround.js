const { DataTypes } = require('sequelize');

/**
 * A coach's registration at a ground.
 *
 * The coach asks; the ground's owner answers. Only an `approved` row makes the
 * ground selectable when a customer books that coach, which is what stops a
 * coach from advertising sessions at a venue that has never agreed to host them.
 */
module.exports = (sequelize) => {
  const CoachGround = sequelize.define(
    'CoachGround',
    {
      id:            { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      coach_id:      { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      ground_id:     { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      status:        {
        type: DataTypes.ENUM('pending', 'approved', 'rejected'),
        defaultValue: 'pending',
      },
      request_note:  { type: DataTypes.TEXT },
      response_note: { type: DataTypes.TEXT },
      requested_at:  { type: DataTypes.DATE },
      responded_at:  { type: DataTypes.DATE },
    },
    {
      tableName: 'coach_grounds',
      underscored: true,
      indexes: [
        { unique: true, fields: ['coach_id', 'ground_id'], name: 'uq_coach_ground' },
      ],
    }
  );
  return CoachGround;
};
