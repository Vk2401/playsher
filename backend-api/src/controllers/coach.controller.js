const { Coach } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true, is_approved: true };
    const { count, rows } = await Coach.findAndCountAll({ where, limit, offset });
    return success(res, 'Coaches retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    return success(res, 'Coach retrieved.', coach);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const coach = await Coach.create(req.body);
    return success(res, 'Coach created.', coach, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.update(req.body);
    return success(res, 'Coach updated.', coach);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.destroy();
    return success(res, 'Coach deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.approve = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.update({ is_approved: true });
    return success(res, 'Coach approved.', coach);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
