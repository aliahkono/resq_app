/// Status of a donor's ID + facial verification (see GetVerifiedView).
/// Mirrors GET /api/donor/me's verificationStatus field.
enum VerificationStatus { notStarted, pending, verified, rejected }

VerificationStatus verificationStatusFromString(String? raw) {
  switch (raw) {
    case 'pending':
      return VerificationStatus.pending;
    case 'verified':
      return VerificationStatus.verified;
    case 'rejected':
      return VerificationStatus.rejected;
    default:
      return VerificationStatus.notStarted;
  }
}

extension VerificationStatusX on VerificationStatus {
  bool get isVerified => this == VerificationStatus.verified;

  String get label {
    switch (this) {
      case VerificationStatus.notStarted:
        return 'Not Verified';
      case VerificationStatus.pending:
        return 'Verification Pending';
      case VerificationStatus.verified:
        return 'Verified Donor';
      case VerificationStatus.rejected:
        return 'Verification Rejected';
    }
  }
}