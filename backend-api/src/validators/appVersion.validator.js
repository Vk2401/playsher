const { body, param, query } = require('express-validator');
const { isValidVersion } = require('../utils/version');

const versionString = (value) => isValidVersion(value);

const checkVersion = [
  query('platform')
    .exists().withMessage('platform is required.')
    .isIn(['android', 'ios']).withMessage('platform must be android or ios.'),
  query('version')
    .exists().withMessage('version is required.')
    .custom(versionString).withMessage('version must be dotted numbers, e.g. 1.2.3.'),
];

const upsertVersion = [
  param('platform')
    .isIn(['android', 'ios']).withMessage('platform must be android or ios.'),
  body('latest_version')
    .exists().withMessage('latest_version is required.')
    .custom(versionString).withMessage('latest_version must be dotted numbers, e.g. 1.2.3.'),
  body('min_supported_version')
    .exists().withMessage('min_supported_version is required.')
    .custom(versionString).withMessage('min_supported_version must be dotted numbers, e.g. 1.2.3.'),
  // Where the store link points is the difference between an update prompt that
  // works and one that dead-ends, so it must be a real URL if given at all.
  body('update_url')
    .optional({ nullable: true, checkFalsy: true })
    .isURL().withMessage('update_url must be a valid URL.'),
  body('release_notes').optional({ nullable: true }).trim(),
  body('is_active').optional().isBoolean().withMessage('is_active must be true or false.'),
];

module.exports = { checkVersion, upsertVersion };
