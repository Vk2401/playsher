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
const { Notification, Admin, GroundSport, Ground, User } = require('../models');

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


/**
 * Tell a ground owner that someone booked or cancelled at their venue.
 *
 * Wrapped rather than left to each caller because a booking confirms in four
 * different places — a free booking on create, a recorded payment, a verified
 * Razorpay payment, and cash taken at the gate — and every one of them needs
 * the same three lookups to write one sentence. Four copies is how three of
 * them end up missing the notification.
 *
 * **Only call this once the booking is actually confirmed.** A `pending`
 * booking holds its slots for five minutes waiting on the advance and is swept
 * away if that payment never lands, so notifying on create would fill the
 * owner's inbox with bookings that mostly never happened.
 *
 * `action_path` is the bookings *list*, not a detail route: the panel has no
 * `/owner/bookings/:id` page, and the notifications screen navigates to
 * whatever this says.
 *
 * @param {object} booking                    a Booking instance
 * @param {'booked'|'cancelled'} event        which sentence to write
 * @param {import('sequelize').Transaction} [transaction]
 */
const OWNER_BOOKING_EVENTS = {
  booked: {
    type : 'booking_created',
    title: 'New booking',
    verb : 'booked',
  },
  cancelled: {
    type : 'booking_cancelled_by_customer',
    title: 'Booking cancelled',
    verb : 'cancelled their booking for',
  },
};

async function notifyGroundOwnerOfBooking(booking, event, transaction) {
  const spec = OWNER_BOOKING_EVENTS[event];
  if (!spec || !booking) return null;

  try {
    const opts = transaction ? { transaction } : {};

    const groundSport = await GroundSport.findByPk(booking.ground_sport_id, {
      include: [{ model: Ground, as: 'ground', attributes: ['id', 'name', 'owner_id'] }],
      ...opts,
    });
    const ground = groundSport?.ground;
    if (!ground?.owner_id) return null;

    const customer = await User.findByPk(booking.user_id, { attributes: ['name'], ...opts });
    const who  = customer?.name || 'A customer';
    const when = `${booking.slot_date} at ${String(booking.slot_time_from || '').slice(0, 5)}`;

    return await notify({
      recipientType: 'ground_owner',
      recipientId  : ground.owner_id,
      type         : spec.type,
      title        : `${spec.title} — ${ground.name}`,
      message      : `${who} ${spec.verb} ${when}.`,
      referenceType: 'booking',
      referenceId  : booking.id,
      actionPath   : '/owner/bookings',
    }, transaction);
  } catch (err) {
    // Same contract as notify(): an inbox row must never fail the booking.
    // eslint-disable-next-line no-console
    console.error('[notify] could not notify ground owner:', err.message);
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

module.exports = { notify, notifyAdmins, notifyGroundOwnerOfBooking, RECIPIENT_TYPES };
