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

  // General Screening
  final bool hasTattsOrPierce;
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
    required this.hasTattsOrPierce,
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

    // Node 5: Tattoo / Piercing Window Check
    if (npt.hasTattsOrPierce) {
      return ClassificationResult(status: EligibleStats.deferredTattsPierce);
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