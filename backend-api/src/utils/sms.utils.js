/**
 * SMS transport.
 *
 * MSG91 first, Twilio second, console last. The OTP itself is still generated,
 * stored and verified by us (`otps` table, otp.controller) — this file only
 * carries the message. That stays deliberately true: Playsher's client is
 * Flutter, and MSG91's browser OTP widget, which sends *and verifies* in a web
 * page, has nowhere to run there. Keeping verification server-side also means
 * the OTP survives a restart and works across processes.
 *
 * ── Two things about MSG91 that will bite ────────────────────────────────────
 *
 * 1. **It answers 200 on failure — and worse, "success" on a bad key.**
 *    A rejected request comes back as HTTP 200 with
 *    `{"type":"error","message":"..."}`, so `res.ok` alone is never enough and
 *    the body is inspected here, always.
 *
 *    But verified against the live API: sending with a *completely invalid*
 *    authkey still answers `{"type":"success","message":"<request id>"}`. The
 *    send is queued and dies silently downstream. **Nothing in the response to
 *    a send can tell you the message will arrive.** A wrong key in production
 *    looks perfectly healthy in the logs while every OTP vanishes.
 *
 *    That is why checkMsg91Health() runs at boot: a zero balance is the one
 *    cheap signal that catches both a bad key and an exhausted account, which
 *    are the two ways this fails invisibly. Real delivery confirmation needs
 *    MSG91's delivery-report webhook, which is a separate piece of work.
 *
 * 2. **DLT does not allow free text.** Transactional SMS to an Indian number
 *    must match a template registered with the operator, with the variable
 *    parts filled in. So the OTP goes through the Flow API against
 *    MSG91_OTP_TEMPLATE_ID; there is no path here that sends an arbitrary
 *    sentence to an Indian handset and expects it to arrive.
 */

const {
  MSG91_AUTH_KEY,
  MSG91_OTP_TEMPLATE_ID,
  MSG91_SENDER_ID,
  TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN,
  TWILIO_FROM_NUMBER,
} = process.env;

const MSG91_FLOW_URL = 'https://control.msg91.com/api/v5/flow/';

const msg91Ready = Boolean(MSG91_AUTH_KEY && MSG91_OTP_TEMPLATE_ID);

let twilioClient = null;
if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_FROM_NUMBER) {
  const twilio = require('twilio');
  twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
}

if (msg91Ready) {
  console.log('[SMS] MSG91 configured.');
} else if (twilioClient) {
  console.log('[SMS] MSG91 not configured; falling back to Twilio.');
} else {
  console.warn('[SMS] No SMS provider configured — OTP will only be logged to console.');
}

/**
 * MSG91 wants a bare country-code-prefixed number: 919876543210.
 * Our numbers arrive as +919876543210, 9876543210, or with spaces from a form.
 */
function toMsg91Mobile(raw) {
  const digits = String(raw || '').replace(/\D/g, '');
  if (!digits) return null;
  if (digits.length === 10) return `91${digits}`;          // bare Indian number
  if (digits.length === 12 && digits.startsWith('91')) return digits;
  if (digits.length === 11 && digits.startsWith('0')) return `91${digits.slice(1)}`;
  return digits; // already international, or not Indian — pass it through
}

/**
 * Send an OTP through MSG91's Flow API.
 *
 * The template decides the wording; we supply the variable. `var` is the
 * conventional name for the code in MSG91's OTP templates, and `otp` is sent
 * alongside it so a template registered with either name works — a mismatched
 * variable name delivers a message with an empty gap where the code should be,
 * which is indistinguishable from a delivery failure to the person waiting.
 *
 * @returns {Promise<{ ok: boolean, id?: string, error?: string }>}
 */
async function sendOtpViaMsg91(mobile, otp) {
  const recipient = toMsg91Mobile(mobile);
  if (!recipient) return { ok: false, error: 'Invalid mobile number.' };

  const body = {
    template_id: MSG91_OTP_TEMPLATE_ID,
    short_url: '0',
    recipients: [{ mobiles: recipient, var: String(otp), otp: String(otp) }],
  };
  if (MSG91_SENDER_ID) body.sender = MSG91_SENDER_ID;

  // 15s: long enough for a slow gateway, short enough that a hung request does
  // not hold the send-OTP endpoint open until the client gives up.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);

  try {
    const res = await fetch(MSG91_FLOW_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        accept: 'application/json',
        authkey: MSG91_AUTH_KEY,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    const text = await res.text();
    let payload;
    try { payload = JSON.parse(text); } catch { payload = { raw: text }; }

    // See the header: a 200 here does not mean it worked.
    if (!res.ok || payload?.type === 'error') {
      const message = payload?.message || payload?.raw || `HTTP ${res.status}`;
      return { ok: false, error: typeof message === 'string' ? message : JSON.stringify(message) };
    }

    return { ok: true, id: payload?.request_id || payload?.message || null };
  } catch (err) {
    const reason = err.name === 'AbortError' ? 'MSG91 timed out' : err.message;
    return { ok: false, error: reason };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Ask MSG91 what our balance is, purely to make silent failure loud.
 *
 * A bad authkey and an account with no credit both report 0, and both mean no
 * OTP will ever arrive — while every send still answers "success". Logged at
 * boot rather than thrown: the API must keep serving grounds and bookings even
 * when SMS is misconfigured.
 */
async function checkMsg91Health() {
  if (!msg91Ready) return { ok: false, reason: 'not_configured' };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const res = await fetch(
      `https://control.msg91.com/api/balance.php?authkey=${encodeURIComponent(MSG91_AUTH_KEY)}&type=4`,
      { signal: controller.signal },
    );
    const balance = Number((await res.text()).trim());

    if (!Number.isFinite(balance)) {
      console.warn('[SMS] MSG91 balance check returned something unreadable — key may be wrong.');
      return { ok: false, reason: 'unreadable' };
    }
    if (balance <= 0) {
      console.error(
        '[SMS] MSG91 balance is 0. Either the authkey is invalid or the account is out of '
        + 'credit. Sends will still answer "success" and no OTP will be delivered.',
      );
      return { ok: false, reason: 'no_balance', balance };
    }

    console.log('[SMS] MSG91 balance: %s', balance);
    return { ok: true, balance };
  } catch (err) {
    console.warn('[SMS] MSG91 balance check failed: %s', err.message);
    return { ok: false, reason: 'unreachable' };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Send a one-time code.
 *
 * Prefer this over sendSms for OTPs: it is the only path that satisfies DLT,
 * because the wording comes from the registered template rather than from here.
 *
 * Throws on failure so the caller can tell the user the code was not sent,
 * rather than leaving them waiting for a message that is never coming.
 *
 * @param {string} mobile
 * @param {string|number} otp
 */
async function sendOtpSms(mobile, otp) {
  if (msg91Ready) {
    const result = await sendOtpViaMsg91(mobile, otp);
    if (result.ok) {
      console.log('[SMS] OTP sent to %s via MSG91 (%s)', mobile, result.id ?? 'no id');
      return result.id;
    }
    console.error('[SMS] MSG91 failed for %s: %s', mobile, result.error);
    // Fall through to Twilio if it is configured; otherwise this is fatal.
    if (!twilioClient) throw new Error(`Could not send OTP: ${result.error}`);
  }

  return sendSms(mobile, `Your Playsher OTP is ${otp}. Valid for 5 minutes.`);
}

/**
 * Send a plain SMS.
 *
 * Kept for Twilio and for the console fallback. Note that free text will not
 * pass DLT for an Indian recipient — anything user-facing and Indian should go
 * through a template, as sendOtpSms does.
 *
 * @param {string} to    recipient, E.164 preferred
 * @param {string} body  message text
 */
async function sendSms(to, body) {
  if (twilioClient) {
    const message = await twilioClient.messages.create({ body, from: TWILIO_FROM_NUMBER, to });
    console.log(`[SMS] Sent to ${to} — SID: ${message.sid}`);
    return message.sid;
  }

  console.log(`[SMS-FALLBACK] to=${to} body="${body}"`);
  return null;
}

module.exports = {
  sendSms, sendOtpSms, checkMsg91Health, toMsg91Mobile,
  _sendOtpViaMsg91: sendOtpViaMsg91,
};
