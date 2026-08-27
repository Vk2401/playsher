const { body, param, query } = require('express-validator');

const GAME_LEVELS = ['newbie', 'beginner', 'intermediate', 'advanced', 'professional', 'ultra_professional'];
const SORTS = ['soonest', 'latest', 'newest'];
const WHENS = ['today', 'tomorrow', 'weekend', 'week'];

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * The discovery feed's filters.
 *
 * Everything is optional — a bare `GET /games` is the default feed — but a
 * malformed value is rejected rather than silently ignored, so a client that
 * sends `when=saturday` learns that the chip it built does not exist instead of
 * quietly getting an unfiltered list back.
 */
const listGames = [
  query('sport_id').optional().isInt({ min: 1 }).withMessage('sport_id must be a positive integer.'),
  query('ground_id').optional().isInt({ min: 1 }).withMessage('ground_id must be a positive integer.'),
  query('city').optional().trim().isLength({ max: 100 }),
  query('search').optional().trim().isLength({ max: 150 }),
  query('level').optional().isIn(GAME_LEVELS).withMessage('Invalid level.'),
  query('game_level').optional().isIn(GAME_LEVELS).withMessage('Invalid game_level.'),
  query('when').optional().isIn(WHENS).withMessage(`when must be one of: ${WHENS.join(', ')}.`),
  query('date').optional().matches(ISO_DATE).withMessage('date must be YYYY-MM-DD.'),
  query('date_from').optional().matches(ISO_DATE).withMessage('date_from must be YYYY-MM-DD.'),
  query('date_to').optional().matches(ISO_DATE).withMessage('date_to must be YYYY-MM-DD.'),
  query('sort').optional().isIn(SORTS).withMessage(`sort must be one of: ${SORTS.join(', ')}.`),
  query('visibility').optional().isIn(['public', 'private']),
  query('scope').optional().isIn(['upcoming', 'past', 'all'])
    .withMessage('scope must be one of: upcoming, past, all.'),
];

const createGame = [
  body('game_name').trim().notEmpty().withMessage('Give your game a name.')
    .isLength({ max: 255 }).withMessage('That name is too long.'),
  body('booking_id').isInt({ min: 1 }).withMessage('Pick the booking this game runs on.'),
  body('max_participants').optional().isInt({ min: 2, max: 50 })
    .withMessage('A game holds between 2 and 50 players.'),
  body('game_level').optional().isIn(GAME_LEVELS).withMessage('Invalid game_level.'),
  body('visibility').optional().isIn(['public', 'private']),
  body('description').optional({ nullable: true }).trim().isLength({ max: 2000 })
    .withMessage('Keep the description under 2000 characters.'),
];

const updateGame = [
  param('id').isInt({ min: 1 }).withMessage('Invalid game ID.'),
  body('game_name').optional().trim().notEmpty().isLength({ max: 255 }),
  body('max_participants').optional().isInt({ min: 2, max: 50 })
    .withMessage('A game holds between 2 and 50 players.'),
  body('game_level').optional().isIn(GAME_LEVELS),
  body('visibility').optional().isIn(['public', 'private']),
  body('description').optional({ nullable: true }).trim().isLength({ max: 2000 }),
];

const gameId = [param('id').isInt({ min: 1 }).withMessage('Invalid game ID.')];

const inviteUsers = [
  param('id').isInt({ min: 1 }).withMessage('Invalid game ID.'),
  body('user_ids')
    .isArray({ min: 1, max: 50 }).withMessage('user_ids must be a non-empty array.')
    .custom((arr) => arr.every((v) => Number.isInteger(v) && v > 0))
    .withMessage('Each user_id must be a positive integer.'),
];

const respondInvite = [
  param('id').isInt({ min: 1 }),
  param('userId').isInt({ min: 1 }),
  body('status').isIn(['accepted', 'declined']).withMessage('status must be accepted or declined.'),
];

module.exports = {
  listGames, createGame, updateGame, gameId, inviteUsers, respondInvite, GAME_LEVELS,
};
