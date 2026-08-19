const { GroundOwner } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { count, rows } = await GroundOwner.findAndCountAll({
      attributes: { exclude: ['password_hash'] },
      limit,
      offset,
    });
    return success(res, 'Ground owners retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const owner = await GroundOwner.findByPk(req.params.id, {
      attributes: { exclude: ['password_hash'] },
    });
    if (!owner) return error(res, 'Ground owner not found.', 404);
    return success(res, 'Ground owner retrieved.', owner);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.approve = async (req, res) => {
  try {
    const owner = await GroundOwner.findByPk(req.params.id);
    if (!owner) return error(res, 'Ground owner not found.', 404);
    await owner.update({ is_approved: true });
    return success(res, 'Ground owner approved.', owner);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.toggleStatus = async (req, res) => {
  try {
    const owner = await GroundOwner.findByPk(req.params.id);
    if (!owner) return error(res, 'Ground owner not found.', 404);
    await owner.update({ is_active: !owner.is_active });
    return success(res, `Ground owner ${owner.is_active ? 'activated' : 'deactivated'}.`, owner);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const owner = await GroundOwner.findByPk(req.params.id);
    if (!owner) return error(res, 'Ground owner not found.', 404);
    await owner.destroy();
    return success(res, 'Ground owner deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
