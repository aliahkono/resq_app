enum BioSex { male, female }

/// Represents the raw donor screening inputs passed into the Decision Tree
class DonorScreensNPT {
  // Baseline Parameters
  final BioSex gender;
  final double weight;
  final int age;

  // Donation History Parameters
  final bool isFirstTimeDonor;
  final DateTime? lastDonationDate;
  final int totalDonations; // Lifetime donation count

  // General Screening
  final bool hasTattsOrPierce;
  final DateTime? tattooDate;
  final bool hasAlcoholPast24hr;
  final bool hasActiveInfectOrMeds;

  // Female-Specific Screening Parameters
  final bool? isPregOrNursing;
  final DateTime? lastMensPeriodDate;

  // Male / Clinical Risk Parameters
  final bool? hasHighRiskExpo;

  DonorScreensNPT({
    required this.gender,
    required this.weight,
    required this.age,
    required this.isFirstTimeDonor,
    this.lastDonationDate,
    this.totalDonations = 0,
    required this.hasTattsOrPierce,
    this.tattooDate,
    required this.hasAlcoholPast24hr,
    required this.hasActiveInfectOrMeds,
    this.isPregOrNursing,
    this.lastMensPeriodDate,
    this.hasHighRiskExpo,
  });
}

/// Output classification results from the decision tree
enum EligibleStats {
  eligible,
  deferredWeight,
  deferredAge,
  deferredInterval, // Deferral due to mandatory 90-day recovery gap
  deferredTattsPierce,
  deferredAlcohol,
  deferredMaternal,
  deferredMensCycle,
  deferredMedical,
  deferredClinicalRisk,
}

/// Result payload containing status and days remaining for deferral tracking
class ClassificationResult {
  final EligibleStats status;
  final int daysRemaining;

  bool get isEligible => status == EligibleStats.eligible;

  ClassificationResult({
    required this.status,
    this.daysRemaining = 0,
  });
}

/// Engine of Decision Tree Classification for donor screening
class DecisionTreeClassifier {
  /// Minimum mandatory deferral interval between whole blood donations (DOH / NVBSP standard)
  static const int minDonationIntervalDays = 90;

  /// Standard tattoo/piercing deferral window (matches the "Standard 12-month
  /// deferral window" messaging shown on the donor profile's eligibility
  /// explanation, and the upper bound of the "6 to 12 months" note shown on
  /// the screening wizard itself).
  static const int tattooDeferralWindowDays = 365;

  /// Evaluates donor parameters through rule-based decision tree nodes
  ClassificationResult classify(DonorScreensNPT npt) {
    // Node 1: Weight Threshold Check (DOH Standard >= 50kg)
    if (npt.weight < 50.0) {
      return ClassificationResult(status: EligibleStats.deferredWeight);
    }

    // Node 2: Age Bracket Check (Standard 18-65)
    if (npt.age < 18 || npt.age > 65) {
      return ClassificationResult(status: EligibleStats.deferredAge);
    }

    // Node 3: Last Donation Interval Check (90-Day Deferral Window for returning donors)
    if (!npt.isFirstTimeDonor && npt.lastDonationDate != null) {
      final daysSinceLastDonation =
          DateTime.now().difference(npt.lastDonationDate!).inDays;
      if (daysSinceLastDonation < minDonationIntervalDays) {
        final remainingDays = minDonationIntervalDays - daysSinceLastDonation;
        return ClassificationResult(
          status: EligibleStats.deferredInterval,
          daysRemaining: remainingDays,
        );
      }
    }

    // Node 4: Medical / Active Infection Check
    if (npt.hasActiveInfectOrMeds) {
      return ClassificationResult(status: EligibleStats.deferredMedical);
    }

    // Node 5: Tattoo / Piercing Window Check (12-month deferral from the
    // date of the procedure, same interval-check shape as Node 3's donation
    // recency check). Previously this was a permanent boolean-only defer
    // with no expiry, which conflicted with the UI's own "12-month deferral
    // window" messaging and left donors stuck deferred forever unless they
    // manually flipped the Yes/No toggle to No.
    if (npt.hasTattsOrPierce) {
      if (npt.tattooDate != null) {
        final daysSinceProcedure =
            DateTime.now().difference(npt.tattooDate!).inDays;
        if (daysSinceProcedure >= tattooDeferralWindowDays) {
          // Window has passed — fall through, no longer deferred for this.
        } else {
          return ClassificationResult(
            status: EligibleStats.deferredTattsPierce,
            daysRemaining: tattooDeferralWindowDays - daysSinceProcedure,
          );
        }
      } else {
        // No date on file to verify the window has elapsed — defer.
        return ClassificationResult(status: EligibleStats.deferredTattsPierce);
      }
    }

    // Node 6: Alcohol Intake Check (< 24 hrs)
    if (npt.hasAlcoholPast24hr) {
      return ClassificationResult(status: EligibleStats.deferredAlcohol);
    }

    // Node 7: Gender-Specific Branching
    if (npt.gender == BioSex.female) {
      return _evalFemBranch(npt);
    } else {
      return _evalMaleBranch(npt);
    }
  }

  /// Evaluates Female-Specific Decision Nodes
  ClassificationResult _evalFemBranch(DonorScreensNPT npt) {
    // Maternal Health Check
    if (npt.isPregOrNursing == true) {
      return ClassificationResult(status: EligibleStats.deferredMaternal);
    }

    // Menstrual Cycle Check (< 7 days window)
    if (npt.lastMensPeriodDate != null) {
      final daysSinceLmp =
          DateTime.now().difference(npt.lastMensPeriodDate!).inDays;
      if (daysSinceLmp < 7) {
        return ClassificationResult(status: EligibleStats.deferredMensCycle);
      }
    }

    return ClassificationResult(status: EligibleStats.eligible);
  }

  /// Evaluates Male-Specific Decision Nodes
  ClassificationResult _evalMaleBranch(DonorScreensNPT npt) {
    if (npt.hasHighRiskExpo == true) {
      return ClassificationResult(status: EligibleStats.deferredClinicalRisk);
    }
    return ClassificationResult(status: EligibleStats.eligible);
  }
}