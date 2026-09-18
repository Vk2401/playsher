/**
 * Self-check for the commission split. No framework:
 *
 *   node src/utils/commission.test.js
 *
 * This is a money path, so the invariant that matters most is the one asserted
 * on every case below: fee + owner must equal captured, exactly, always.
 */
const assert = require('node:assert/strict');
const { splitCommission, commissionRate, toPaise, DEFAULT_COMMISSION_RATE } = require('./commission');

const R = 0.10;

// ── the invariant ─────────────────────────────────────────────────────────
// Anything that does not sum back is money that exists in one ledger and not
// the other, which is how a platform ends up transferring more than it holds.
for (const amount of [0, 1, 9.99, 10, 100, 120, 333.33, 599.55, 1200, 99999.99]) {
  const { captured, platformFee, ownerAmount } = splitCommission(amount, R);
  assert.equal(
    Math.round((platformFee + ownerAmount) * 100),
    Math.round(captured * 100),
    `fee + owner != captured for ${amount}`,
  );
  assert.ok(platformFee >= 0, `negative fee for ${amount}`);
  assert.ok(ownerAmount >= 0, `negative owner share for ${amount}`);
  assert.ok(platformFee <= captured, `fee exceeds captured for ${amount}`);
}

// ── rounding favours the owner ────────────────────────────────────────────
// 333.33 * 10% = 33.333, which must floor to 33.33 rather than round to 33.34.
// A half-paise taken from every booking is still money taken.
{
  const { platformFee, ownerAmount } = splitCommission(333.33, R);
  assert.equal(platformFee, 33.33);
  assert.equal(ownerAmount, 300.00);
}

// ── zero and nonsense ─────────────────────────────────────────────────────
for (const bad of [0, -5, null, undefined, NaN, '']) {
  const s = splitCommission(bad, R);
  assert.deepEqual(
    { captured: s.captured, platformFee: s.platformFee, ownerAmount: s.ownerAmount },
    { captured: 0, platformFee: 0, ownerAmount: 0 },
    `non-positive input ${bad} should split to zeros`,
  );
}

// ── the rate itself ───────────────────────────────────────────────────────
{
  const original = process.env.PLATFORM_COMMISSION_RATE;

  delete process.env.PLATFORM_COMMISSION_RATE;
  assert.equal(commissionRate(), DEFAULT_COMMISSION_RATE);

  process.env.PLATFORM_COMMISSION_RATE = '0.15';
  assert.equal(commissionRate(), 0.15);

  // A typo must not hand the whole booking to either side.
  for (const bad of ['', 'ten percent', '-0.2', '1', '1.5', 'NaN']) {
    process.env.PLATFORM_COMMISSION_RATE = bad;
    assert.equal(commissionRate(), DEFAULT_COMMISSION_RATE, `bad rate "${bad}" should fall back`);
  }

  // 0 is a real, valid choice: a promotional period charging nothing.
  process.env.PLATFORM_COMMISSION_RATE = '0';
  assert.equal(commissionRate(), 0);
  assert.deepEqual(splitCommission(500), { captured: 500, platformFee: 0, ownerAmount: 500, rate: 0 });

  if (original === undefined) delete process.env.PLATFORM_COMMISSION_RATE;
  else process.env.PLATFORM_COMMISSION_RATE = original;
}

// ── paise conversion ──────────────────────────────────────────────────────
// Razorpay rejects a non-integer amount, and 19.99 * 100 is 1998.9999... in
// float arithmetic — the exact case that silently under-transfers by a paise.
assert.equal(toPaise(19.99), 1999);
assert.equal(toPaise(1200), 120000);
assert.equal(toPaise(0.1 + 0.2), 30);
assert.ok(Number.isInteger(toPaise(333.33)));

console.log('commission: all checks passed');
