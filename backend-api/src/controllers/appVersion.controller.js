const { AppVersion } = require('../models');
const { success, error } = require('../utils/response');
const { isOlderThan, compareVersions } = require('../utils/version');

const PLATFORMS = ['android', 'ios'];

/**
 * Decide what the app should do about the version it reports.
 *
 * Two independent thresholds:
 *   latest_version        → an update exists; prompt, but let it be dismissed.
 *   min_supported_version → this build is retired; block until it updates.
 *
 * Fails open in every uncertain case — no row, checks disabled, or a version
 * string we cannot order. Locking users out of a working app because a gating
 * row is missing is far worse than missing one upgrade nag.
 */
function evaluate(record, installedVersion) {
  const idle = {
    update_available: false,
    update_required : false,
    latest_version  : null,
    min_supported_version: null,
    update_url      : null,
    release_notes   : null,
  };

  if (!record || !record.is_active) return idle;
  // An unorderable installed version means we cannot prove it is behind.
  if (compareVersions(installedVersion, record.latest_version) === null) return idle;

  return {
    update_available     : isOlderThan(installedVersion, record.latest_version),
    update_required      : isOlderThan(installedVersion, record.min_supported_version),
    latest_version       : record.latest_version,
    min_supported_version: record.min_supported_version,
    update_url           : record.update_url || null,
    release_notes        : record.release_notes || null,
  };
}

// GET /app-version?platform=android&version=1.2.3
// Public on purpose: the app must be able to check before anyone logs in, and
// a retired build has to be told so even if its stored token no longer works.
exports.check = async (req, res) => {
  try {
    const platform = String(req.query.platform).toLowerCase();
    const installed = req.query.version;

    const record = await AppVersion.findOne({ where: { platform } });
    return success(res, 'App version checked.', {
      platform,
      installed_version: installed,
      ...evaluate(record, installed),
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /admin/app-versions
exports.list = async (req, res) => {
  try {
    const rows = await AppVersion.findAll({ order: [['platform', 'ASC']] });

    // Always answer with both platforms so the admin screen can offer an "iOS"
    // row to fill in before anyone has ever saved one.
    const byPlatform = new Map(rows.map((row) => [row.platform, row]));
    const data = PLATFORMS.map((platform) => byPlatform.get(platform) || {
      id                   : null,
      platform,
      latest_version       : null,
      min_supported_version: null,
      update_url           : null,
      release_notes        : null,
      is_active            : false,
    });

    return success(res, 'App versions retrieved.', data);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PUT /admin/app-versions/:platform
exports.upsert = async (req, res) => {
  try {
    const platform = String(req.params.platform).toLowerCase();
    const {
      latest_version, min_supported_version, update_url, release_notes, is_active,
    } = req.body;

    // A minimum above the latest build would force every user — including those
    // already current — into an update that does not exist yet.
    if (compareVersions(min_supported_version, latest_version) === 1) {
      return error(res, 'Minimum supported version cannot be newer than the latest version.');
    }

    const [record] = await AppVersion.findOrCreate({
      where   : { platform },
      defaults: { platform, latest_version, min_supported_version },
    });

    await record.update({
      latest_version,
      min_supported_version,
      update_url   : update_url    === undefined ? record.update_url    : update_url,
      release_notes: release_notes === undefined ? record.release_notes : release_notes,
      is_active    : is_active     === undefined ? record.is_active     : is_active,
    });

    return success(res, 'App version updated.', record);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
