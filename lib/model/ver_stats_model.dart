/// Status of a donor's ID + facial verification (see GetVerifiedView).
/// Mirrors GET /api/donor/me's verificationStatus field — 'in_review' is
/// only ever produced by the Didit-backed flow (a session Didit itself
/// flagged for manual review, e.g. a borderline age case), never by the
/// legacy local flow.
enum VerificationStatus { notStarted, pending, inReview, verified, rejected }

VerificationStatus verificationStatusFromString(String? raw) {
  switch (raw) {
    case 'pending':
      return VerificationStatus.pending;
    case 'in_review':
      return VerificationStatus.inReview;
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
      case VerificationStatus.inReview:
        return 'Under Review';
      case VerificationStatus.verified:
        return 'Verified Donor';
      case VerificationStatus.rejected:
        return 'Verification Rejected';
    }
  }
}