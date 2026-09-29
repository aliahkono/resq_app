/**
 * REFERENCE IMPLEMENTATION — not part of the Flutter app.
 *
 * This is what's missing on the backend (the hospital-web-dashboard repo,
 * separate codebase from this Flutter app). The mobile app has been
 * calling `DELETE /api/donor/me` correctly since it was built — the error
 * "No route for DELETE /api/donor/me" is Express's own message for an
 * unmatched route, meaning this handler was never registered.
 *
 * Field/table names below are illustrative, guessed from patterns already
 * visible elsewhere in this conversation (donorPortal.controller.js,
 * healthScreening JSON blob, etc.) — adjust to match your actual schema
 * and existing donorPortal.controller.js conventions before using this.
 *
 * Expected request from the app (see ApiService.deleteMyAccount):
 *   DELETE /api/donor/me
 *   Authorization: Bearer <session token>
 *   Body: { "otpCode": "123456" }
 *
 * Expected response: 204 No Content on success, or a JSON error body
 * shaped like your other error responses ({ error: "..." }) with an
 * appropriate status code (400 for a wrong/expired code, 401 for a bad
 * token, etc.) — see ApiException in api_service.dart for how the app
 * surfaces whatever "error" string comes back.
 */

// In your donor routes file (wherever GET/PATCH /donor/me are registered):
//
//   router.delete('/me', requireDonorAuth, asyncHandler(deleteMyAccount));

async function deleteMyAccount(req, res) {
  const donorId = req.donor.id; // set by your requireDonorAuth middleware
  const { otpCode } = req.body;

  if (!otpCode) {
    return res.status(400).json({ error: 'Verification code is required.' });
  }

  // 1. Look up the donor's phone number (needed to check the OTP against
  //    the same store request-otp/verify-otp already use).
  const donor = await db.query('SELECT phone FROM donors WHERE id = $1', [donorId]);
  if (!donor.rows.length) {
    return res.status(404).json({ error: 'Donor not found.' });
  }
  const phone = donor.rows[0].phone;

  // 2. Verify the code the same way verify-otp already does — reuse
  //    whatever function/lookup that endpoint uses (Redis key, otp_codes
  //    table, etc.) rather than duplicating the logic here.
  const isValid = await verifyOtpCode(phone, otpCode); // <- your existing helper
  if (!isValid) {
    return res.status(400).json({ error: 'Invalid or expired verification code.' });
  }

  // 3. Delete the donor and everything that depends on them. Order matters
  //    if you don't have ON DELETE CASCADE set up on the foreign keys —
  //    delete child rows first, or add the cascade at the schema level
  //    instead of doing it here every time.
  await db.query('BEGIN');
  try {
    await db.query('DELETE FROM appointments WHERE donor_id = $1', [donorId]);
    await db.query('DELETE FROM donor_notifications WHERE donor_id = $1', [donorId]);
    // ... any other donor-scoped tables (verification documents, sessions, etc.)
    await db.query('DELETE FROM donors WHERE id = $1', [donorId]);
    await db.query('COMMIT');
  } catch (err) {
    await db.query('ROLLBACK');
    throw err;
  }

  // 4. Invalidate the session token itself, same as /donor-auth/logout does,
  //    so it can't be reused after the account is gone.
  await invalidateSession(req.token); // <- your existing session-store helper

  return res.status(204).send();
}
