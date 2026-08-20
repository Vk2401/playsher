const { Slot, ScheduleTemplate } = require('../models');
const { appToday, isPastSlot, dayOfWeek } = require('./appTime');

/**
 * Slots whose start time has already passed are dropped.
 * They cannot be booked, and listing them made the day look full of options
 * that all failed on tap. "Passed" is judged in the app timezone, not the
 * server's — see utils/appTime.js.
 */
function dropPastSlots(slots, slotDate) {
  return slots.filter((slot) => !isPastSlot(slotDate, slot.slot_start_time));
}

/**
 * Ensure concrete Slot rows exist for a given GroundSport + date.
 * If slots already exist → returns them (never regenerates booked slots).
 * If no slots → looks up the ScheduleTemplate for that day_of_week,
 *   generates 30-min blocks from start_time to end_time, and bulk-creates.
 *
 * @param {number} groundSportId
 * @param {string} slotDate  YYYY-MM-DD
 * @param {import('sequelize').Transaction} [transaction]
 * @returns {Promise<Array>} slots for the date
 */
async function ensureSlotsForDate(groundSportId, slotDate, transaction) {
  // Guard: refuse past dates
  const today = appToday();
  if (slotDate < today) return [];

  // Check if slots already exist for this date
  const existing = await Slot.findAll({
    where: { ground_sport_id: groundSportId, slot_date: slotDate },
    order: [['slot_start_time', 'ASC']],
    ...(transaction ? { transaction } : {}),
  });
  if (existing.length > 0) return dropPastSlots(existing, slotDate);

  // Look up the schedule template for this day_of_week
  const day = dayOfWeek(slotDate); // 0=Sun … 6=Sat
  const template = await ScheduleTemplate.findOne({
    where: { ground_sport_id: groundSportId, day_of_week: day },
    ...(transaction ? { transaction } : {}),
  });

  if (!template || template.is_closed) return [];

  // Generate 30-min blocks from start_time to end_time
  const slots = [];
  const [startH, startM] = template.start_time.split(':').map(Number);
  const [endH, endM] = template.end_time.split(':').map(Number);
  const startMinutes = startH * 60 + startM;
  const endMinutes = endH * 60 + endM;

  for (let m = startMinutes; m + 30 <= endMinutes; m += 30) {
    const fromH = String(Math.floor(m / 60)).padStart(2, '0');
    const fromM = String(m % 60).padStart(2, '0');
    const toM_total = m + 30;
    const toH = String(Math.floor(toM_total / 60)).padStart(2, '0');
    const toM = String(toM_total % 60).padStart(2, '0');

    slots.push({
      ground_sport_id: groundSportId,
      slot_date: slotDate,
      slot_start_time: `${fromH}:${fromM}:00`,
      slot_end_time: `${toH}:${toM}:00`,
      is_available: true,
    });
  }

  if (slots.length === 0) return [];

  await Slot.bulkCreate(slots, {
    ignoreDuplicates: true,
    ...(transaction ? { transaction } : {}),
  });

  // Re-fetch to get IDs and actual state
  const created = await Slot.findAll({
    where: { ground_sport_id: groundSportId, slot_date: slotDate },
    order: [['slot_start_time', 'ASC']],
    ...(transaction ? { transaction } : {}),
  });
  return dropPastSlots(created, slotDate);
}

module.exports = { ensureSlotsForDate, dropPastSlots };
