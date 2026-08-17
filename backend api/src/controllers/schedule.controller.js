const { ScheduleTemplate, GroundSport, Ground, Sport } = require('../models');
const { success, error } = require('../utils/response');

/** GET /ground-owner/grounds/:groundId/schedule */
exports.list = async (req, res) => {
  try {
    const ground = await Ground.findOne({
      where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null },
    });
    if (!ground) return error(res, 'Ground not found.', 404);

    const groundSports = await GroundSport.findAll({
      where: { ground_id: ground.id },
      include: [
        { model: Sport, as: 'sport', attributes: ['id', 'name'] },
        { model: ScheduleTemplate, as: 'schedules' },
      ],
    });

    return success(res, 'Schedule retrieved.', { ground_sports: groundSports });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** PUT /ground-owner/grounds/:groundId/schedule */
exports.upsert = async (req, res) => {
  try {
    const ground = await Ground.findOne({
      where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null },
    });
    if (!ground) return error(res, 'Ground not found.', 404);

    const { ground_sport_id, schedules } = req.body;
    if (!ground_sport_id || !Array.isArray(schedules)) {
      return error(res, 'ground_sport_id and schedules array are required.');
    }

    // Verify ground_sport belongs to this ground
    const gs = await GroundSport.findOne({
      where: { id: ground_sport_id, ground_id: ground.id },
    });
    if (!gs) return error(res, 'Ground sport not found for this ground.', 404);

    // Upsert each day
    const results = [];
    for (const s of schedules) {
      if (s.day_of_week === undefined || s.day_of_week === null) continue;
      const [template] = await ScheduleTemplate.upsert({
        ground_sport_id,
        day_of_week: s.day_of_week,
        start_time: s.start_time || '06:00:00',
        end_time: s.end_time || '22:00:00',
        is_closed: s.is_closed || false,
      });
      results.push(template);
    }

    return success(res, 'Schedule saved.', results);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
