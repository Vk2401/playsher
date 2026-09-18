/**
 * Self-check for the two payout rules that are dangerous when wrong:
 *
 *   node src/utils/payoutSafety.test.js
 *
 *   1. The webhook signature. This endpoint writes to the payout ledger with no
 *      bearer token, so a forged body must never be accepted.
 *   2. The refund reversal amount. Claw back too much and the owner is robbed;
 *      too little and the platform funds the difference.
 *
 * Runs without a database: the signature check is pure, and the reversal maths
 * takes a plain object.
 */
const assert = require('node:assert/strict');
const crypto = require('crypto');

const { _verifySignature } = require('../controllers/webhook.controller');
const { reversalAmount } = require('./refundBooking');

// ── webhook signature ─────────────────────────────────────────────────────
const SECRET = 'whsec_test_value';
const body = JSON.stringify({ event: 'transfer.processed', payload: { transfer: { entity: { id: 'trf_1' } } } });
const raw = Buffer.from(body, 'utf8');
const good = crypto.createHmac('sha256', SECRET).update(raw).digest('hex');

// `rawBody` is taken as given, with no default: passing undefined has to mean
// "the raw body was never captured", which is precisely one of the cases below.
const reqWith = (opts) => ({
  get: (h) => (h.toLowerCase() === 'x-razorpay-signature' ? opts.sig : undefined),
  rawBody: 'rawBody' in opts ? opts.rawBody : raw,
});

{
  const original = process.env.RAZORPAY_WEBHOOK_SECRET;

  // No secret configured: refuse. Never fall through to "verified" — that is
  // how an unconfigured deploy silently accepts anything.
  delete process.env.RAZORPAY_WEBHOOK_SECRET;
  assert.equal(_verifySignature(reqWith({ sig: good })).ok, false, 'must refuse without a secret');

  process.env.RAZORPAY_WEBHOOK_SECRET = SECRET;

  assert.equal(_verifySignature(reqWith({ sig: good })).ok, true, 'a real signature must pass');

  // Every way of getting it wrong.
  const bad = [
    undefined,                       // header absent
    '',                              // header empty
    good.slice(0, -1) + '0',         // one character changed
    good.slice(0, 32),               // truncated
    good + 'ff',                     // extended
    good.toUpperCase(),              // case differs
    'not-a-signature',
  ];
  for (const sig of bad) {
    assert.equal(_verifySignature(reqWith({ sig })).ok, false, `must reject signature ${JSON.stringify(sig)}`);
  }

  // Right signature, different body — the exact attack the raw buffer exists
  // to stop. A replayed signature over tampered content must not verify.
  const tampered = Buffer.from(body.replace('trf_1', 'trf_999'), 'utf8');
  assert.equal(_verifySignature(reqWith({ sig: good, rawBody: tampered })).ok, false,
    'a signature must not verify against a different body');

  // Missing raw body: refuse rather than hashing undefined.
  assert.equal(_verifySignature(reqWith({ sig: good, rawBody: undefined })).ok, false,
    'must refuse when the raw body was not captured');

  if (original === undefined) delete process.env.RAZORPAY_WEBHOOK_SECRET;
  else process.env.RAZORPAY_WEBHOOK_SECRET = original;
}

// ── refund reversal amount ────────────────────────────────────────────────
{
  // A ₹1,200 payment where ₹1,080 went to the owner and ₹120 was commission.
  const payment = { amount: 1200, vendor_payout_amount: 1080 };

  // Full refund pulls back the whole share, never more.
  assert.equal(reversalAmount(payment, 1200), 1080);
  assert.equal(reversalAmount(payment, 5000), 1080, 'over-refund must not over-reverse');

  // Half refund, half the share — the platform's fee is split the same way.
  assert.equal(reversalAmount(payment, 600), 540);
  assert.equal(reversalAmount(payment, 300), 270);

  // Never negative, never more than the share, for any refund in range.
  for (let refund = 0; refund <= 1200; refund += 37) {
    const back = reversalAmount(payment, refund);
    assert.ok(back >= 0, `negative reversal at ${refund}`);
    assert.ok(back <= 1080 + 1e-9, `reversal exceeds the share at ${refund}`);
  }

  // Nothing was transferred: nothing to pull back.
  assert.equal(reversalAmount({ amount: 1200, vendor_payout_amount: null }, 1200), 0);
  assert.equal(reversalAmount({ amount: 0, vendor_payout_amount: 0 }, 0), 0);
}

console.log('payoutSafety: all checks passed');
