const { body, param } = require('express-validator');

const GAME_LEVELS = ['newbie', 'beginner', 'intermediate', 'advanced', 'professional', 'ultra_professional'];

const createGame = [
  body('game_name').trim().notEmpty().withMessage('game_name is required.'),
  body('booking_id').isInt({ min: 1 }).withMessage('booking_id is required.'),
  body('max_participants').optional().isInt({ min: 2 }),
  body('game_level').optional().isIn(GAME_LEVELS).withMessage('Invalid game_level.'),
  body('visibility').optional().isIn(['public', 'private']),
];

const updateGame = [
  param('id').isInt({ min: 1 }).withMessage('Invalid game ID.'),
  body('game_name').optional().trim().notEmpty(),
  body('max_participants').optional().isInt({ min: 2 }),
  body('game_level').optional().isIn(GAME_LEVELS),
  body('visibility').optional().isIn(['public', 'private']),
];

const inviteUsers = [
  param('id').isInt({ min: 1 }).withMessage('Invalid game ID.'),
  body('user_ids')
    .isArray({ min: 1 }).withMessage('user_ids must be a non-empty array.')
    .custom((arr) => arr.every((v) => Number.isInteger(v) && v > 0))
    .withMessage('Each user_id must be a positive integer.'),
];

const respondInvite = [
  param('id').isInt({ min: 1 }),
  param('userId').isInt({ min: 1 }),
  body('status').isIn(['accepted', 'declined']).withMessage('status must be accepted or declined.'),
];

module.exports = { createGame, updateGame, inviteUsers, respondInvite };
