/**
 * Platform commission, computed in one place.
 *
 * Mirrors utils/pricing.js: every figure a ground owner is shown, and every
 * figure sent to Razorpay as a transfer, comes from here — so the Earnings
 * screen, the settlement row and the money that actually moves cannot disagree.
 *
 * The rate is read per call rather than cached at require time, so changing it
 * takes effect on restart without a rebuild. The rate that applied to a given
 * payment is stored on that payment (`platform_fee`), never recomputed: a rate
 * change next quarter must not silently restate what an owner already earned.
 */

/** Platform's cut, as a fraction. `0.10` is 10%. */
const DEFAULT_COMMISSION_RATE = 0.10;

function commissionRate() {
  const configured = process.env.PLATFORM_COMMISSION_RATE;

  // Empty or whitespace is "unset", not zero. `Number('')` is 0, which is a
  // finite number inside the valid range — so without this guard an env var
  // that exists but was never filled in would silently charge 0% commission
  // and nothing would look wrong until someone read the ledger.
  if (configured === undefined || String(configured).trim() === '') {
    return DEFAULT_COMMISSION_RATE;
  }

  const raw = Number(configured);
  // Non-numeric or out of range falls back rather than charging nothing (we
  // earn nothing) or everything (the owner earns nothing). 0 stays valid when
  // it is written deliberately: a promotional period charging no commission.
  if (!Number.isFinite(raw) || raw < 0 || raw >= 1) return DEFAULT_COMMISSION_RATE;
  return raw;
}

/** Round to whole paise. Money must never carry float dust into a gateway. */
function toRupees(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

/** Razorpay's Transfers API speaks paise, as integers. */
function toPaise(rupees) {
  return Math.round(toRupees(rupees) * 100);
}

/**
 * Split a captured amount into the platform's fee and the owner's share.
 *
 * Captured, not booked: for a pay-at-ground booking only the advance reaches
 * our account, so that is all there is to split. The cash the owner takes at
 * the gate never passes through us and is not commissionable here.
 *
 * The fee is rounded down to the paise so the owner is never short-changed by
 * rounding, and the owner's share is the remainder — the two always sum back to
 * the captured amount exactly, which is what makes reconciliation possible.
 *
 * @param {number} capturedAmount  what actually landed in the platform account
 * @param {number} [rate]          override, for a per-owner deal
 * @returns {{ captured:number, platformFee:number, ownerAmount:number, rate:number }}
 */
function splitCommission(capturedAmount, rate = commissionRate()) {
  const captured = toRupees(capturedAmount);

  if (!(captured > 0)) {
    return { captured: 0, platformFee: 0, ownerAmount: 0, rate };
  }

  const platformFee = Math.floor(captured * rate * 100) / 100;
  const ownerAmount = toRupees(captured - platformFee);

  return { captured, platformFee, ownerAmount, rate };
}

module.exports = {
  splitCommission,
  commissionRate,
  toRupees,
  toPaise,
  DEFAULT_COMMISSION_RATE,
};
