const { User, Sport, UserSportPreference } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

// Admin: GET /users
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { count, rows } = await User.findAndCountAll({
      where: { deleted_at: null },
      attributes: { exclude: ['password_hash'] },
      limit,
      offset,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Users retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// Admin: GET /users/:id
exports.show = async (req, res) => {
  try {
    const user = await User.findOne({
      where: { id: req.params.id, deleted_at: null },
      attributes: { exclude: ['password_hash'] },
      include: [{ model: UserSportPreference, as: 'sportPreferences', include: [{ model: Sport, as: 'sport' }] }],
    });
    if (!user) return error(res, 'User not found.', 404);
    return success(res, 'User retrieved.', user);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// Admin: PUT /users/:id
exports.update = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);
    const { password_hash, deleted_at, ...updateData } = req.body;
    await user.update(updateData);
    return success(res, 'User updated.', user);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// Admin: DELETE /users/:id (soft delete)
exports.destroy = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);
    await user.update({ deleted_at: new Date() });
    return success(res, 'User deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// Admin: PATCH /users/:id/toggle-status
exports.toggleStatus = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.params.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);
    await user.update({ is_active: !user.is_active });
    return success(res, `User ${user.is_active ? 'activated' : 'deactivated'}.`, user);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// User: GET /profile
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findOne({
      where: { id: req.user.id, deleted_at: null },
      attributes: { exclude: ['password_hash'] },
      include: [{ model: UserSportPreference, as: 'sportPreferences', include: [{ model: Sport, as: 'sport' }] }],
    });
    if (!user) return error(res, 'User not found.', 404);
    return success(res, 'Profile retrieved.', user);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// User: PUT /profile
exports.updateProfile = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.user.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);
    const { password_hash, deleted_at, ...updateData } = req.body;
    await user.update(updateData);
    return success(res, 'Profile updated.', user);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// User: POST /profile/sport-preferences
exports.addSportPreferences = async (req, res) => {
  try {
    const { sport_ids } = req.body;
    const records = sport_ids.map((sid) => ({ user_id: req.user.id, sport_id: sid }));
    await UserSportPreference.bulkCreate(records, { ignoreDuplicates: true });
    return success(res, 'Sport preferences added.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// User: DELETE /profile/sport-preferences/:sportId
exports.removeSportPreference = async (req, res) => {
  try {
    const deleted = await UserSportPreference.destroy({
      where: { user_id: req.user.id, sport_id: req.params.sportId },
    });
    if (!deleted) return error(res, 'Preference not found.', 404);
    return success(res, 'Sport preference removed.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
