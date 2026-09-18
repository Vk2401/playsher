/**
 * Self-check for the SMS transport:
 *
 *   node src/utils/sms.test.js
 *
 * Two things, both silent when wrong:
 *
 *   1. Mobile normalisation. MSG91 wants 919876543210. Send it the wrong shape
 *      and it accepts the request and delivers nothing.
 *   2. MSG91 answering HTTP 200 on failure. If that is read as success, every
 *      undelivered OTP looks fine in the logs and the only symptom is a user
 *      who never got their code.
 *
 * `fetch` is stubbed, so nothing here contacts MSG91 or costs a message.
 */
const assert = require('node:assert/strict');

process.env.MSG91_AUTH_KEY = 'test-key';
process.env.MSG91_OTP_TEMPLATE_ID = 'test-template';

const { toMsg91Mobile, _sendOtpViaMsg91 } = require('./sms.utils');

// ── mobile normalisation ──────────────────────────────────────────────────
assert.equal(toMsg91Mobile('9876543210'), '919876543210', 'bare 10-digit gets 91');
assert.equal(toMsg91Mobile('+919876543210'), '919876543210', 'E.164 loses the plus');
assert.equal(toMsg91Mobile('919876543210'), '919876543210', 'already correct stays');
assert.equal(toMsg91Mobile('09876543210'), '919876543210', 'leading zero is dropped');
assert.equal(toMsg91Mobile('+91 98765 43210'), '919876543210', 'spaces from a form');
assert.equal(toMsg91Mobile('+91-98765-43210'), '919876543210', 'dashes from a form');
assert.equal(toMsg91Mobile(''), null);
assert.equal(toMsg91Mobile(null), null);
assert.equal(toMsg91Mobile(undefined), null);
// Not Indian: passed through rather than mangled into a wrong Indian number.
assert.equal(toMsg91Mobile('+14155550123'), '14155550123');

// ── the 200-on-failure trap ───────────────────────────────────────────────
const realFetch = global.fetch;
const stub = (status, payload) => {
  global.fetch = async () => ({
    ok: status >= 200 && status < 300,
    status,
    text: async () => (typeof payload === 'string' ? payload : JSON.stringify(payload)),
  });
};

(async () => {
  // The whole point: HTTP 200 carrying an error body must NOT read as sent.
  stub(200, { type: 'error', message: 'Invalid template id' });
  let r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(r.ok, false, 'a 200 with type:error must be a failure');
  assert.match(r.error, /Invalid template id/);

  // A real success.
  stub(200, { type: 'success', request_id: 'req_abc123' });
  r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(r.ok, true);
  assert.equal(r.id, 'req_abc123');

  // Ordinary HTTP failures.
  stub(401, { message: 'authkey is invalid' });
  r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(r.ok, false);
  assert.match(r.error, /authkey/);

  stub(500, 'upstream exploded');
  r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(r.ok, false, 'a 500 is a failure even with an unparseable body');

  // Non-JSON body on a 200 — must not throw, must not claim success blindly.
  stub(200, '<html>maintenance</html>');
  r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(typeof r.ok, 'boolean', 'an unparseable 200 must still resolve');

  // A number we cannot address is refused before any request is made.
  let called = false;
  global.fetch = async () => { called = true; throw new Error('should not be reached'); };
  r = await _sendOtpViaMsg91('', '123456');
  assert.equal(r.ok, false);
  assert.equal(called, false, 'an invalid number must not hit the network');

  // A network error is a failure, not an exception escaping to the caller.
  global.fetch = async () => { throw new Error('ECONNREFUSED'); };
  r = await _sendOtpViaMsg91('9876543210', '123456');
  assert.equal(r.ok, false);
  assert.match(r.error, /ECONNREFUSED/);

  global.fetch = realFetch;
  console.log('sms: all checks passed');
})().catch((err) => { global.fetch = realFetch; console.error(err); process.exit(1); });
