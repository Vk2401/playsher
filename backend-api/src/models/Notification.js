const { DataTypes } = require('sequelize');

/**
 * One inbox row, for any role.
 *
 * `recipient_type` + `recipient_id` is deliberately polymorphic rather than
 * four nullable foreign keys: a customer, an owner, a coach and an admin all
 * need the same three questions answered — what happened, when, and have I
 * read it — and every one of them reads through the same endpoint.
 */
module.exports = (sequelize) => {
  const Notification = sequelize.define(
    'Notification',
    {
      id:             { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      recipient_type: {
        type: DataTypes.ENUM('user', 'ground_owner', 'coach', 'admin'),
        allowNull: false,
      },
      recipient_id:   { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      type:           { type: DataTypes.STRING(60), defaultValue: 'general' },
      title:          { type: DataTypes.STRING(200), allowNull: false },
      message:        { type: DataTypes.TEXT },
      reference_type: { type: DataTypes.STRING(50) },
      reference_id:   { type: DataTypes.INTEGER.UNSIGNED },
      // Where the panel or app should go when the row is tapped, as a route
      // path rather than a URL — each client prefixes its own base.
      action_path:    { type: DataTypes.STRING(255) },
      is_read:        { type: DataTypes.BOOLEAN, defaultValue: false },
      read_at:        { type: DataTypes.DATE },
    },
    { tableName: 'notifications', underscored: true }
  );
  return Notification;
};
