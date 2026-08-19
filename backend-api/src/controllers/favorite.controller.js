const { Favorite, Ground, GroundImage } = require('../models');
const { success, error } = require('../utils/response');

exports.list = async (req, res) => {
  try {
    const favorites = await Favorite.findAll({
      where: { user_id: req.user.id },
      include: [
        {
          model: Ground,
          as: 'ground',
          where: { deleted_at: null },
          include: [{ model: GroundImage, as: 'images', where: { is_primary: true }, required: false }],
        },
      ],
    });
    return success(res, 'Favorites retrieved.', favorites);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.add = async (req, res) => {
  try {
    const { ground_id } = req.body;
    const ground = await Ground.findOne({ where: { id: ground_id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    const [fav, created] = await Favorite.findOrCreate({
      where: { user_id: req.user.id, ground_id },
    });
    if (!created) return error(res, 'Already in favorites.');
    return success(res, 'Added to favorites.', fav, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.remove = async (req, res) => {
  try {
    const deleted = await Favorite.destroy({
      where: { user_id: req.user.id, ground_id: req.params.groundId },
    });
    if (!deleted) return error(res, 'Favorite not found.', 404);
    return success(res, 'Removed from favorites.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
