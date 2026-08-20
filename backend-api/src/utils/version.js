/**
 * Comparing app version strings.
 *
 * Store versions are dotted numbers, and comparing them as strings is wrong in
 * the one case that matters: '1.10.0' < '1.9.0' lexically, so a user on the
 * newest build would be told to update. Compare component by component instead.
 *
 * Tolerates the shapes the clients actually send:
 *   '1.2.3'    plain semver
 *   '1.2'      short — missing components read as 0
 *   '1.2.3+45' Flutter's pubspec `version` with its build number
 *   'v1.2.3'   a leading v, as some CI pipelines emit
 * Pre-release suffixes ('1.2.3-beta.1') are ignored for ordering — a beta and
 * its release compare equal, which is the safe direction: we never force an
 * update on a tester who is effectively current.
 */

/** Split a version string into numeric components, or null if unparseable. */
function parseVersion(value) {
  if (value === null || value === undefined) return null;
  const cleaned = String(value).trim().replace(/^v/i, '').split('+')[0].split('-')[0];
  if (cleaned === '') return null;

  const parts = cleaned.split('.');
  const numbers = parts.map((part) => (/^\d+$/.test(part) ? Number(part) : NaN));
  if (numbers.some(Number.isNaN)) return null;
  return numbers;
}

/**
 * Compare two version strings.
 * @returns {number|null} -1 if a < b, 0 if equal, 1 if a > b; null if either
 *   side is unparseable — callers must treat null as "cannot tell" and fail
 *   open rather than locking a user out of the app on a malformed string.
 */
function compareVersions(a, b) {
  const left  = parseVersion(a);
  const right = parseVersion(b);
  if (!left || !right) return null;

  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i += 1) {
    const l = left[i] ?? 0;
    const r = right[i] ?? 0;
    if (l !== r) return l < r ? -1 : 1;
  }
  return 0;
}

/** True when `version` is strictly older than `target`. Unparseable → false. */
function isOlderThan(version, target) {
  return compareVersions(version, target) === -1;
}

/** True when the string is a version we can actually order. */
function isValidVersion(value) {
  return parseVersion(value) !== null;
}

module.exports = { parseVersion, compareVersions, isOlderThan, isValidVersion };
