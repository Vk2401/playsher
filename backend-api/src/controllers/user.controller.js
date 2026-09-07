const { Op } = require('sequelize');
const { User, Sport, UserSportPreference, UserFollow, Game, GameParticipant } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const {
  normalise, validationError, isTaken, generateUniqueUsername, isUsernameConflict,
} = require('../utils/username');

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

/**
 * Give an account a handle if it does not have one yet.
 *
 * Registration assigns one, so this only ever fires for an account that
 * predates handles existing. Doing it on the profile read rather than in a
 * migration means an account is backfilled the first time it is actually used,
 * which is also the first moment the handle could matter to anybody.
 *
 * Failures are swallowed: reading your profile must not break because a name
 * could not be minted, and the next read will try again.
 */
async function ensureUsername(user) {
  if (user.username) return user;
  try {
    await user.update({ username: await generateUniqueUsername(User) });
  } catch (err) {
    if (!isUsernameConflict(err)) {
      // eslint-disable-next-line no-console
      console.error('[username] could not backfill a handle:', err.message);
      return user;
    }
    try {
      await user.update({ username: await generateUniqueUsername(User) });
    } catch {
      // eslint-disable-next-line no-console
      console.error('[username] backfill lost a second race; leaving it for next time');
    }
  }
  return user;
}

// User: GET /profile
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findOne({
      where: { id: req.user.id, deleted_at: null },
      attributes: { exclude: ['password_hash'] },
      include: [{ model: UserSportPreference, as: 'sportPreferences', include: [{ model: Sport, as: 'sport' }] }],
    });
    if (!user) return error(res, 'User not found.', 404);

    await ensureUsername(user);

    // The counts the profile screen shows. Cheap, and fetching them here saves
    // the app three round trips to render one header.
    const [followers, following, gamesHosted, gamesPlayed] = await Promise.all([
      UserFollow.count({ where: { following_id: user.id } }),
      UserFollow.count({ where: { follower_id: user.id } }),
      Game.count({ where: { hosted_by_user_id: user.id } }),
      GameParticipant.count({
        where: { user_id: user.id, status: { [Op.in]: ['joined', 'accepted'] } },
      }),
    ]);

    const json = user.toJSON();
    delete json.password_hash;
    json.followers_count = followers;
    json.following_count = following;
    json.games_hosted    = gamesHosted;
    json.games_played    = gamesPlayed;

    return success(res, 'Profile retrieved.', json);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * GET /profile/username-available?username=
 *
 * What the field under the input reads while somebody types. Advisory only:
 * two people can pass this in the same second, so the unique index is what
 * actually decides — see the conflict handling in `setUsername`.
 */
exports.checkUsername = async (req, res) => {
  try {
    const candidate = normalise(req.query.username);
    const invalid = validationError(candidate);
    if (invalid) {
      return success(res, invalid, { username: candidate, available: false, reason: invalid });
    }

    const taken = await isTaken(User, candidate, req.user.id);
    return success(
      res,
      taken ? 'That username is taken.' : 'That username is available.',
      {
        username : candidate,
        available: !taken,
        reason   : taken ? 'That username is taken.' : null,
      },
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * PATCH /profile/username
 *
 * Its own endpoint rather than a field on the profile PUT, because it is the
 * one profile change that can fail for a reason the person has to act on, and
 * the answer needs to say which reason.
 */
exports.setUsername = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.user.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);

    const candidate = normalise(req.body.username);
    const invalid = validationError(candidate);
    if (invalid) return error(res, invalid);

    if (user.username === candidate) {
      return success(res, 'That is already your username.', { username: candidate });
    }

    if (await isTaken(User, candidate, user.id)) {
      return error(res, 'That username is taken.', 409);
    }

    try {
      await user.update({ username: candidate });
    } catch (err) {
      // Somebody claimed it between the check and the write.
      if (isUsernameConflict(err)) return error(res, 'That username was just taken.', 409);
      throw err;
    }

    return success(res, 'Username updated.', { username: user.username });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// User: PUT /profile
exports.updateProfile = async (req, res) => {
  try {
    const user = await User.findOne({ where: { id: req.user.id, deleted_at: null } });
    if (!user) return error(res, 'User not found.', 404);
    // Whitelist rather than blocklist. The previous version stripped only
    // password_hash and deleted_at, so a customer could set is_verified on
    // themselves — or change `mobile`, which is the login identifier: taking
    // over another account's number must go through OTP re-verification, not a
    // plain profile PUT.
    // `username` is deliberately absent: it has its own endpoint, because it is
    // the one field whose rejection the person has to act on.
    const EDITABLE = ['name', 'email', 'profile_picture', 'bio'];
    const patch = {};
    for (const key of EDITABLE) {
      if (req.body[key] !== undefined) patch[key] = req.body[key];
    }
    if (Object.keys(patch).length === 0) {
      return error(res, 'No updatable fields supplied.');
    }

    if (patch.email) {
      const clash = await User.findOne({
        where: { email: patch.email, id: { [Op.ne]: user.id }, deleted_at: null },
      });
      if (clash) return error(res, 'That email already belongs to another account.');
    }

    await user.update(patch);
    const json = user.toJSON();
    delete json.password_hash;
    return success(res, 'Profile updated.', json);
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
