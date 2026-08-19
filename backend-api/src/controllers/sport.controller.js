const { Sport } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true };
    const { count, rows } = await Sport.findAndCountAll({ where, limit, offset });
    return success(res, 'Sports retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    return success(res, 'Sport retrieved.', sport);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const sport = await Sport.create(req.body);
    return success(res, 'Sport created.', sport, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    await sport.update(req.body);
    return success(res, 'Sport updated.', sport);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    await sport.destroy();
    return success(res, 'Sport deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.approve = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    await sport.update({ is_approved: true });
    return success(res, 'Sport approved.', sport);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
