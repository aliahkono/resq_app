/**
 * REFERENCE IMPLEMENTATION — not part of the Flutter app.
 *
 * Backend half of the Forgot Password flow (lib/views/auth/
 * forgot_password_view.dart). Belongs in the hospital-web-dashboard repo
 * alongside the other /api/donor-auth/* handlers. Like
 * backend_delete_acc_reference.js, table/helper names are illustrative —
 * adjust to your actual schema and existing donorAuth controller
 * conventions (bcrypt cost, OTP store, session store) before using this.
 *
 * Expected requests from the app (see ApiService.requestPasswordReset /
 * ApiService.resetPassword):
 *
 *   POST /api/donor-auth/forgot-password
 *   Body: { "identifier": "juan@example.com" | "09171234567" }
 *   -> 200 { ok: true, channel: "email" | "sms", destination: "j•••@example.com" }
 *
 *   POST /api/donor-auth/reset-password
 *   Body: { "identifier": "...", "code": "123456", "newPassword": "..." }
 *   -> 200 { ok: true }
 *
 * Errors use the usual { error: "..." } body — the app shows that string
 * to the donor as-is (see ApiException in api_service.dart).
 */

// In your donor-auth routes file (next to request-otp / verify-otp / login):
//
//   router.post('/forgot-password', otpRateLimiter, asyncHandler(forgotPassword));
//   router.post('/reset-password', otpRateLimiter, asyncHandler(resetPassword));
//
// Reuse whatever rate limiter request-otp already has, so this can't be
// used to spam SMS/email or brute-force the 6-digit code.

// Same "@" rule the login endpoint uses to tell email from phone.
async function findDonorByIdentifier(identifier) {
  const value = String(identifier || '').trim().toLowerCase();
  if (!value) return null;
  const result = value.includes('@')
    ? await db.query('SELECT id, phone, email FROM donors WHERE LOWER(email) = $1', [value])
    : await db.query('SELECT id, phone, email FROM donors WHERE phone = $1', [normalizePhone(value)]); // <- your existing helper
  return result.rows[0] || null;
}

function maskPhone(phone) {
  return phone.length <= 4 ? phone : '•'.repeat(phone.length - 4) + phone.slice(-4);
}

function maskEmail(email) {
  const [user, domain] = email.split('@');
  return `${user[0]}${'•'.repeat(Math.max(user.length - 1, 2))}@${domain}`;
}

async function forgotPassword(req, res) {
  const { identifier } = req.body;
  if (!identifier) {
    return res.status(400).json({ error: 'Please enter your email or phone number.' });
  }

  const donor = await findDonorByIdentifier(identifier);
  if (!donor) {
    // Matches the login endpoint's existing "Account does not exist"
    // wording. If you'd rather not reveal which emails/phones are
    // registered, return the same 200 response as below instead.
    return res.status(404).json({ error: 'Account does not exist. Please register first.' });
  }

  const byEmail = String(identifier).includes('@');

  // The code is always bound to the donor's phone, same as request-otp —
  // only the delivery channel changes. Reuse request-otp's own helper so
  // expiry, attempt limits and storage stay in one place.
  await sendOtpCode(donor.phone, { channel: byEmail ? 'email' : 'sms', email: donor.email }); // <- your existing helper

  return res.json({
    ok: true,
    channel: byEmail ? 'email' : 'sms',
    destination: byEmail ? maskEmail(donor.email) : maskPhone(donor.phone),
  });
}

async function resetPassword(req, res) {
  const { identifier, code, newPassword } = req.body;

  if (!identifier || !code) {
    return res.status(400).json({ error: 'Verification code is required.' });
  }
  if (!newPassword || newPassword.length < 8) {
    return res.status(400).json({ error: 'Password must be at least 8 characters.' });
  }

  const donor = await findDonorByIdentifier(identifier);
  if (!donor) {
    return res.status(400).json({ error: 'Invalid or expired verification code.' });
  }

  // Same check verify-otp uses — and it should consume the code so it
  // can't be replayed for a second reset.
  const isValid = await verifyOtpCode(donor.phone, code); // <- your existing helper
  if (!isValid) {
    return res.status(400).json({ error: 'Invalid or expired verification code.' });
  }

  const passwordHash = await bcrypt.hash(newPassword, 12); // match complete-profile's cost factor
  await db.query('UPDATE donors SET password_hash = $1 WHERE id = $2', [passwordHash, donor.id]);

  // End every existing session for this donor (same store /logout uses),
  // so a token saved on a lost or stolen phone stops working too. The app
  // already clears its saved token when it gets a 401 back.
  await invalidateAllSessionsForDonor(donor.id); // <- your existing session-store helper

  // Also clear any failed-login lockout (the login endpoint's 429), so the
  // donor can sign in right away with the new password.
  await clearLoginLockout(donor.id); // <- if your login lockout is stored per donor

  return res.json({ ok: true });
}
