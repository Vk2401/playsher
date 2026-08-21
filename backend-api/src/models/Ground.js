const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Ground = sequelize.define(
    'Ground',
    {
      id:          { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
      name:        { type: DataTypes.STRING(255), allowNull: false },
      about:       { type: DataTypes.TEXT },
      description: { type: DataTypes.TEXT },
      latitude:    { type: DataTypes.DECIMAL(10, 7) },
      longitude:   { type: DataTypes.DECIMAL(10, 7) },
      address:     { type: DataTypes.TEXT },
      // The locality players actually name — Adambakkam, Mylapore. Separate
      // from `address` so it can be searched and shown on a card.
      area:        { type: DataTypes.STRING(150) },
      city:        { type: DataTypes.STRING(100) },
      // What the venue *is*, not something it provides — hence a column here
      // rather than an amenity row.
      has_roof:    { type: DataTypes.BOOLEAN, defaultValue: false },
      venue_rules: { type: DataTypes.TEXT },
      is_approved: { type: DataTypes.BOOLEAN, defaultValue: false },
      is_active:   { type: DataTypes.BOOLEAN, defaultValue: true },
      owner_id:    { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
      deleted_at:  { type: DataTypes.DATE },
    },
    { tableName: 'grounds', underscored: true }
  );
  return Ground;
};
