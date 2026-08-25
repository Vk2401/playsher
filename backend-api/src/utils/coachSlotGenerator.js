/**
 * Concrete coach slots, generated from the coach's weekly availability.
 *
 * Deliberately the same shape and the same 30-minute grid as
 * utils/slotGenerator.js: a coaching session and a ground booking are quoted
 * per half hour, so a customer picking "07:00–08:00" gets two blocks either way.
 */
const { CoachSlot, CoachAvailability } = require('../models');
const { appToday, isPastSlot, dayOfWeek } = require('./appTime');
const { dropPastSlots } = require('./slotGenerator');

/**
 * Ensure CoachSlot rows exist for a coach on a date.
 * Existing rows are never regenerated — a booked block must keep its booking.
 *
 * @param {number} coachId
 * @param {string} slotDate  YYYY-MM-DD
 * @param {import('sequelize').Transaction} [transaction]
 * @returns {Promise<Array>} the coach's slots for that date, past ones dropped
 */
async function ensureCoachSlotsForDate(coachId, slotDate, transaction) {
  if (slotDate < appToday()) return [];

  const existing = await CoachSlot.findAll({
    where: { coach_id: coachId, slot_date: slotDate },
    order: [['slot_start_time', 'ASC']],
    ...(transaction ? { transaction } : {}),
  });
  if (existing.length > 0) return dropPastSlots(existing, slotDate);

  const template = await CoachAvailability.findOne({
    where: { coach_id: coachId, day_of_week: dayOfWeek(slotDate) },
    ...(transaction ? { transaction } : {}),
  });
  if (!template || template.is_closed) return [];

  const [startH, startM] = String(template.start_time).split(':').map(Number);
  const [endH, endM]     = String(template.end_time).split(':').map(Number);
  const startMinutes = startH * 60 + startM;
  const endMinutes   = endH * 60 + endM;

  const rows = [];
  for (let m = startMinutes; m + 30 <= endMinutes; m += 30) {
    rows.push({
      coach_id       : coachId,
      slot_date      : slotDate,
      slot_start_time: minutesToTime(m),
      slot_end_time  : minutesToTime(m + 30),
      is_available   : true,
    });
  }
  if (rows.length === 0) return [];

  await CoachSlot.bulkCreate(rows, {
    ignoreDuplicates: true,
    ...(transaction ? { transaction } : {}),
  });

  const created = await CoachSlot.findAll({
    where: { coach_id: coachId, slot_date: slotDate },
    order: [['slot_start_time', 'ASC']],
    ...(transaction ? { transaction } : {}),
  });
  return dropPastSlots(created, slotDate);
}

function minutesToTime(total) {
  const h = String(Math.floor(total / 60)).padStart(2, '0');
  const m = String(total % 60).padStart(2, '0');
  return `${h}:${m}:00`;
}

/**
 * Are these slots one unbroken run of half hours?
 *
 * A session is a single stretch of the coach's time. Letting a customer pick
 * 07:00 and 09:00 in one booking would produce a row reading "07:00–09:30"
 * that the coach reads as two and a half hours they never agreed to.
 */
function isContiguous(slots) {
  for (let i = 1; i < slots.length; i += 1) {
    if (slots[i].slot_start_time !== slots[i - 1].slot_end_time) return false;
  }
  return true;
}

module.exports = { ensureCoachSlotsForDate, isContiguous, isPastSlot, minutesToTime };
