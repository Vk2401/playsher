/**
 * Writing to somebody's inbox.
 *
 * Every caller here is doing something else that matters more — taking a
 * booking, approving a coach — so a failure to record the notification is
 * swallowed and logged rather than thrown. A booking that succeeded must not
 * be rolled back because a row in `notifications` could not be written, and
 * the person still sees the booking itself in their list.
 *
 * The transaction argument exists for the opposite case: when a notification
 * is written inside a transaction that may still roll back, it has to roll
 * back with it, or the coach is told about a session that never existed.
 */
const { Notification, Admin } = require('../models');

const RECIPIENT_TYPES = ['user', 'ground_owner', 'coach', 'admin'];

/**
 * @param {object}  payload
 * @param {string}  payload.recipientType  one of RECIPIENT_TYPES
 * @param {number}  payload.recipientId
 * @param {string}  payload.type           machine-readable kind, e.g. 'coach_booking_created'
 * @param {string}  payload.title
 * @param {string} [payload.message]
 * @param {string} [payload.referenceType] what the row points at, e.g. 'coach_booking'
 * @param {number} [payload.referenceId]
 * @param {string} [payload.actionPath]    client-side route, not a URL
 * @param {import('sequelize').Transaction} [transaction]
 */
async function notify(payload, transaction) {
  const {
    recipientType, recipientId, type, title, message,
    referenceType, referenceId, actionPath,
  } = payload;

  if (!RECIPIENT_TYPES.includes(recipientType) || !recipientId || !title) {
    // eslint-disable-next-line no-console
    console.warn('[notify] ignored malformed notification', payload);
    return null;
  }

  try {
    return await Notification.create(
      {
        recipient_type: recipientType,
        recipient_id  : recipientId,
        type          : type || 'general',
        title,
        message       : message || null,
        reference_type: referenceType || null,
        reference_id  : referenceId || null,
        action_path   : actionPath || null,
      },
      transaction ? { transaction } : {},
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[notify] could not record notification:', err.message);
    return null;
  }
}

/** Same payload, delivered to every active admin. */
async function notifyAdmins(payload, transaction) {
  try {
    const admins = await Admin.findAll({
      where: { is_active: true },
      attributes: ['id'],
      ...(transaction ? { transaction } : {}),
    });
    return await Promise.all(
      admins.map((a) => notify({ ...payload, recipientType: 'admin', recipientId: a.id }, transaction)),
    );
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[notify] could not fan out to admins:', err.message);
    return [];
  }
}

module.exports = { notify, notifyAdmins, RECIPIENT_TYPES };
