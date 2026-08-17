/**
 * SMS utility — sends messages via Twilio.
 * Falls back to console.log when Twilio credentials are not configured.
 */

const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER } = process.env;

let twilioClient = null;

if (TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_FROM_NUMBER) {
  const twilio = require('twilio');
  twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
  console.log('[SMS] Twilio client initialized.');
} else {
  console.warn('[SMS] Twilio credentials missing — OTP will only be logged to console.');
}

/**
 * Send an SMS message.
 * @param {string} to   — recipient phone number (E.164 format)
 * @param {string} body — message text
 * @returns {Promise<string|null>} Twilio message SID or null if fallback
 */
async function sendSms(to, body) {
  if (twilioClient) {
    const message = await twilioClient.messages.create({
      body,
      from: TWILIO_FROM_NUMBER,
      to,
    });
    console.log(`[SMS] Sent to ${to} — SID: ${message.sid}`);
    return message.sid;
  }

  // Fallback: log to console (dev mode)
  console.log(`[SMS-FALLBACK] to=${to} body="${body}"`);
  return null;
}

module.exports = { sendSms };
