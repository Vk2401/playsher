const { Amenity } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true };
    if (req.query.type) where.type = req.query.type;
    const { count, rows } = await Amenity.findAndCountAll({ where, limit, offset });
    return success(res, 'Amenities retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const amenity = await Amenity.findByPk(req.params.id);
    if (!amenity) return error(res, 'Amenity not found.', 404);
    return success(res, 'Amenity retrieved.', amenity);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const amenity = await Amenity.create(req.body);
    return success(res, 'Amenity created.', amenity, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const amenity = await Amenity.findByPk(req.params.id);
    if (!amenity) return error(res, 'Amenity not found.', 404);
    await amenity.update(req.body);
    return success(res, 'Amenity updated.', amenity);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const amenity = await Amenity.findByPk(req.params.id);
    if (!amenity) return error(res, 'Amenity not found.', 404);
    await amenity.destroy();
    return success(res, 'Amenity deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
