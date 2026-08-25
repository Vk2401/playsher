/**
 * One inbox endpoint for every role.
 *
 * The recipient is always the token holder — there is no path here that reads
 * or writes someone else's notifications, which is what keeps a polymorphic
 * recipient column safe.
 */
const { Notification } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

/** The inbox a token addresses. Role strings and recipient types are the same set. */
function inboxOf(req) {
  return { recipient_type: req.user.role, recipient_id: req.user.id };
}

/** GET /notifications */
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = inboxOf(req);
    if (req.query.unread === 'true') where.is_read = false;

    const { count, rows } = await Notification.findAndCountAll({
      where,
      order: [['created_at', 'DESC'], ['id', 'DESC']],
      limit,
      offset,
    });
    return success(res, 'Notifications retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /notifications/unread-count */
exports.unreadCount = async (req, res) => {
  try {
    const count = await Notification.count({ where: { ...inboxOf(req), is_read: false } });
    return success(res, 'Unread count retrieved.', { unread: count });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** PATCH /notifications/:id/read */
exports.markRead = async (req, res) => {
  try {
    const row = await Notification.findOne({ where: { id: req.params.id, ...inboxOf(req) } });
    if (!row) return error(res, 'Notification not found.', 404);
    if (!row.is_read) await row.update({ is_read: true, read_at: new Date() });
    return success(res, 'Notification marked as read.', row);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** PATCH /notifications/read-all */
exports.markAllRead = async (req, res) => {
  try {
    const [updated] = await Notification.update(
      { is_read: true, read_at: new Date() },
      { where: { ...inboxOf(req), is_read: false } },
    );
    return success(res, 'All notifications marked as read.', { updated });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** DELETE /notifications/:id */
exports.destroy = async (req, res) => {
  try {
    const row = await Notification.findOne({ where: { id: req.params.id, ...inboxOf(req) } });
    if (!row) return error(res, 'Notification not found.', 404);
    await row.destroy();
    return success(res, 'Notification deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
