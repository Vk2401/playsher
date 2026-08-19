const { Op } = require('sequelize');
const { Ground, GroundOwner, GroundImage, Amenity, GroundAmenity, GroundSport, Sport } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta, haversineKm } = require('../utils/helpers');

// GET /grounds
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { sport_id, lat, lng, radius_km } = req.query;

    const where = { is_approved: true, is_active: true, deleted_at: null };
    const include = [
      { model: GroundOwner, as: 'owner', attributes: ['id', 'name', 'email', 'mobile'] },
      { model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] },
      {
        model: Amenity,
        as: 'amenities',
        attributes: ['id', 'name', 'icon', 'type'],
        through: { attributes: [] },
      },
    ];

    if (sport_id) {
      include.push({
        model: GroundSport,
        as: 'groundSports',
        where: { sport_id, is_active: true },
        required: true,
        include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
      });
    }

    const { count, rows } = await Ground.findAndCountAll({ where, include, limit, offset, distinct: true });

    let data = rows;
    if (lat && lng && radius_km) {
      const rKm = parseFloat(radius_km);
      data = rows.filter((g) => {
        if (!g.latitude || !g.longitude) return true;
        return haversineKm(parseFloat(lat), parseFloat(lng), parseFloat(g.latitude), parseFloat(g.longitude)) <= rKm;
      });
    }

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
    const ground = await Ground.findByPk(req.params.id);
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
    const ground = await Ground.findByPk(req.params.id);
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
    const ground = await Ground.findByPk(req.params.id);
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
