const { Op } = require('sequelize');
const { sequelize, Ground, GroundOwner, GroundImage, Amenity, GroundAmenity, GroundSport, Sport, Slot } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta, haversineKm } = require('../utils/helpers');
const { appNow } = require('../utils/appTime');

// GET /grounds
/**
 * How many slots are still bookable today, per ground.
 *
 * One grouped query rather than a lookup per card. Slots are generated lazily,
 * so a ground with no rows for today is reported as unknown (absent from the
 * map) rather than as zero — "no slots left" and "nobody has opened this day
 * yet" are different answers and the second must not scare a player off.
 *
 * Past slots are excluded on both counts: a day that is three-quarters gone
 * should read "4 left" against the slots that remain, not against a morning
 * nobody can book.
 *
 * @returns {Promise<Map<number, {available: number, total: number}>>}
 */
async function todaysSlotCounts(groundIds) {
  if (groundIds.length === 0) return new Map();

  const now = appNow();
  const rows = await Slot.findAll({
    attributes: [
      [sequelize.col('groundSport.ground_id'), 'ground_id'],
      [sequelize.fn('COUNT', sequelize.col('Slot.id')), 'total'],
      [sequelize.fn('SUM', sequelize.literal('CASE WHEN Slot.is_available = 1 THEN 1 ELSE 0 END')), 'available'],
    ],
    include: [{
      model     : GroundSport,
      as        : 'groundSport',
      attributes: [],
      required  : true,
      where     : { ground_id: { [Op.in]: groundIds } },
    }],
    where: {
      slot_date      : now.date,
      slot_start_time: { [Op.gt]: minutesToTime(now.minutes) },
    },
    group: [sequelize.col('groundSport.ground_id')],
    raw  : true,
  });

  return new Map(rows.map((r) => [
    Number(r.ground_id),
    { available: Number(r.available) || 0, total: Number(r.total) || 0 },
  ]));
}

/** 930 -> '15:30:00', matching how slot_start_time is stored. */
function minutesToTime(minutes) {
  const h = String(Math.floor(minutes / 60)).padStart(2, '0');
  const m = String(minutes % 60).padStart(2, '0');
  return `${h}:${m}:00`;
}

// GET /grounds
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { sport_id, lat, lng, radius_km, search, has_roof } = req.query;

    const where = { is_approved: true, is_active: true, deleted_at: null };

    // Players search by whatever they remember: the venue, the locality, the
    // road it is on, or just the sport. Match all of them rather than making
    // them guess which field the box wants.
    const term = (search || '').trim();
    if (term) {
      const like = { [Op.like]: `%${term}%` };
      where[Op.or] = [
        { name: like },
        { area: like },
        { city: like },
        { address: like },
        // The sport lives on a joined table, so it is matched with a subquery
        // rather than a join — a join here would multiply the rows and break
        // the pagination count.
        {
          id: {
            [Op.in]: sequelize.literal(`(
              SELECT gs.ground_id FROM ground_sports gs
              JOIN sports s ON s.id = gs.sport_id
              WHERE gs.is_active = 1 AND s.name LIKE ${sequelize.escape(`%${term}%`)}
            )`),
          },
        },
      ];
    }

    if (has_roof !== undefined) where.has_roof = has_roof === 'true' || has_roof === '1';

    // groundSports was previously included ONLY when sport_id was passed, so
    // browsing "All sports" returned grounds with no pricing at all and every
    // card read "Price on request".
    const include = [
      { model: GroundOwner, as: 'owner', attributes: ['id', 'name', 'email', 'mobile'] },
      { model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] },
      {
        model: Amenity,
        as: 'amenities',
        attributes: ['id', 'name', 'icon', 'type'],
        through: { attributes: [] },
      },
      {
        model   : GroundSport,
        as      : 'groundSports',
        required: Boolean(sport_id),
        where   : sport_id ? { sport_id, is_active: true } : { is_active: true },
        include : [{ model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] }],
      },
    ];

    const { count, rows } = await Ground.findAndCountAll({ where, include, limit, offset, distinct: true });

    let data = rows.map((g) => g.toJSON());

    // Distance: filter when a radius is given, and sort nearest-first whenever
    // a location is known. Known scale limit — this only orders the current
    // page (see the note in CLAUDE.md).
    if (lat && lng) {
      const from = { lat: parseFloat(lat), lng: parseFloat(lng) };
      data = data.map((g) => ({
        ...g,
        distance_km: (g.latitude && g.longitude)
          ? Number(haversineKm(from.lat, from.lng, parseFloat(g.latitude), parseFloat(g.longitude)).toFixed(2))
          : null,
      }));

      if (radius_km) {
        const rKm = parseFloat(radius_km);
        data = data.filter((g) => g.distance_km === null || g.distance_km <= rKm);
      }

      // Grounds without coordinates sort last rather than to the top.
      data.sort((a, b) => (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity));
    }

    // What is left to book today, so a card can say "4 of 14 left" instead of
    // making the player open it to find out.
    const counts = await todaysSlotCounts(data.map((g) => g.id));
    data = data.map((g) => {
      const c = counts.get(g.id);
      return {
        ...g,
        slots_available_today: c ? c.available : null,
        slots_total_today    : c ? c.total     : null,
      };
    });

    return success(res, 'Grounds retrieved.', data, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /grounds/:id
exports.show = async (req, res) => {
  try {
    const ground = await Ground.findOne({
      where: { id: req.params.id, deleted_at: null },
      include: [
        { model: GroundOwner, as: 'owner', attributes: ['id', 'name', 'email', 'mobile'] },
        { model: GroundImage, as: 'images' },
        { model: Amenity, as: 'amenities', through: { attributes: [] } },
        {
          model: GroundSport,
          as: 'groundSports',
          include: [{ model: Sport, as: 'sport' }],
        },
      ],
    });
    if (!ground) return error(res, 'Ground not found.', 404);
    return success(res, 'Ground retrieved.', ground);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /grounds
exports.create = async (req, res) => {
  try {
    const ownerId = req.user.role === 'ground_owner' ? req.user.id : req.body.owner_id;
    const ground = await Ground.create({ ...req.body, owner_id: ownerId });
    return success(res, 'Ground created.', ground, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PUT /grounds/:id
exports.update = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    if (req.user.role === 'ground_owner' && ground.owner_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    await ground.update(req.body);
    return success(res, 'Ground updated.', ground);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// DELETE /grounds/:id
exports.destroy = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    if (req.user.role === 'ground_owner' && ground.owner_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    await ground.update({ deleted_at: new Date() });
    return success(res, 'Ground deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PATCH /grounds/:id/approve
exports.approve = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    await ground.update({ is_approved: true });
    return success(res, 'Ground approved.', ground);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PATCH /grounds/:id/toggle-status
exports.toggleStatus = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    await ground.update({ is_active: !ground.is_active });
    return success(res, `Ground ${ground.is_active ? 'activated' : 'deactivated'}.`, ground);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /grounds/:id/images
exports.addImages = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    if (req.user.role === 'ground_owner' && ground.owner_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    const { images } = req.body; // array of { image, is_primary }
    if (!Array.isArray(images) || images.length === 0) return error(res, 'images array required.');
    const records = await GroundImage.bulkCreate(images.map((img) => ({ ground_id: ground.id, ...img })));
    return success(res, 'Images added.', records, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// DELETE /grounds/:id/images/:imgId
exports.removeImage = async (req, res) => {
  try {
    const img = await GroundImage.findOne({ where: { id: req.params.imgId, ground_id: req.params.id } });
    if (!img) return error(res, 'Image not found.', 404);
    await img.destroy();
    return success(res, 'Image deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /grounds/:id/amenities
exports.addAmenities = async (req, res) => {
  try {
    const { amenity_ids } = req.body;
    const ground = await Ground.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    const records = amenity_ids.map((aid) => ({ ground_id: ground.id, amenity_id: aid }));
    await GroundAmenity.bulkCreate(records, { ignoreDuplicates: true });
    return success(res, 'Amenities added.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// DELETE /grounds/:id/amenities/:aId
exports.removeAmenity = async (req, res) => {
  try {
    const deleted = await GroundAmenity.destroy({
      where: { ground_id: req.params.id, amenity_id: req.params.aId },
    });
    if (!deleted) return error(res, 'Association not found.', 404);
    return success(res, 'Amenity removed.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
