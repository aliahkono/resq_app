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

  // Immediate Readiness Parameters (NEW)
  final bool feelsWellToday;
  final bool hasEatenRecently; // full meal & fluids within last 4-6 hrs

  // General Screening
  final bool hasTattsOrPierce;
  final DateTime? tattooDate;
  final bool hasAlcoholPast24hr;
  final bool hasActiveInfectOrMeds;

  // Medical History Parameters (NEW)
  // Recent meds/minor procedures in the last 4 weeks, e.g. "Antibiotics",
  // "Aspirin", "Vaccines", "Dental Work", "Minor Surgery"
  final Set<String> recentMedProcedures;
  final bool hasMajorMedicalHistory; // heart disease, asthma, diabetes, etc.

  // Risk Factor Parameters (NEW)
  final bool hasTransfusionOrSurgery; // last 12 months
  final bool hasTravelOrNeedleStick; // international travel or accidental stick, last 12 months

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
    this.feelsWellToday = true,
    this.hasEatenRecently = true,
    required this.hasTattsOrPierce,
    this.tattooDate,
    required this.hasAlcoholPast24hr,
    required this.hasActiveInfectOrMeds,
    this.recentMedProcedures = const {},
    this.hasMajorMedicalHistory = false,
    this.hasTransfusionOrSurgery = false,
    this.hasTravelOrNeedleStick = false,
    this.isPregOrNursing,
    this.lastMensPeriodDate,
    this.hasHighRiskExpo,
  });
}

/// Output classification results from the decision tree
enum EligibleStats {
  eligible,
  deferredNotWell, // Not feeling well / healthy today
  deferredFasting, // No recent meal / fluid intake
  deferredWeight,
  deferredAge,
  deferredInterval, // Deferral due to mandatory 90-day recovery gap
  deferredTattsPierce,
  deferredAlcohol,
  deferredRecentProcedure, // Recent meds/minor procedures within last 4 weeks
  deferredMajorMedical, // Heart disease, asthma, diabetes, etc.
  deferredTransfusionSurgery, // Transfusion or surgery within last 12 months
  deferredTravelNeedle, // Travel or accidental needle stick within last 12 months
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
    // Node 1: Immediate Wellness Check
    if (!npt.feelsWellToday) {
      return ClassificationResult(status: EligibleStats.deferredNotWell);
    }

    // Node 2: Meal / Fluid Intake Check (last 4-6 hrs)
    if (!npt.hasEatenRecently) {
      return ClassificationResult(status: EligibleStats.deferredFasting);
    }

    // Node 3: Weight Threshold Check (DOH Standard >= 50kg)
    if (npt.weight < 50.0) {
      return ClassificationResult(status: EligibleStats.deferredWeight);
    }

    // Node 4: Age Bracket Check (Standard 18-65)
    if (npt.age < 18 || npt.age > 65) {
      return ClassificationResult(status: EligibleStats.deferredAge);
    }

    // Node 5: Last Donation Interval Check (90-Day Deferral Window for returning donors)
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

    // Node 6: Medical / Active Infection Check
    if (npt.hasActiveInfectOrMeds) {
      return ClassificationResult(status: EligibleStats.deferredMedical);
    }

    // Node 5: Tattoo / Piercing Window Check
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

    // Node 10: Transfusion or Surgery Check (last 12 months)
    if (npt.hasTransfusionOrSurgery) {
      return ClassificationResult(status: EligibleStats.deferredTransfusionSurgery);
    }

    // Node 11: Travel or Needle Stick Check (last 12 months)
    if (npt.hasTravelOrNeedleStick) {
      return ClassificationResult(status: EligibleStats.deferredTravelNeedle);
    }

    // Node 12: Alcohol Intake Check (< 24 hrs)
    if (npt.hasAlcoholPast24hr) {
      return ClassificationResult(status: EligibleStats.deferredAlcohol);
    }

    // Node 13: Gender-Specific Branching
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