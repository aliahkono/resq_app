enum BioSex { male, female }

/// Details captured for one recent medication/minor procedure chip, or for
/// a "yes" answer on Major Medical History / Transfusion-Surgery / Travel-
/// Needle Stick — when it happened and why, collected right after the
/// donor flags it so the decision tree has enough to judge whether the
/// deferral window has actually elapsed instead of deferring forever.
class MedProcedureDetail {
  final DateTime? date;
  final String? dosageOrReason;

  const MedProcedureDetail({this.date, this.dosageOrReason});
}

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
  // "Aspirin", "Vaccines", "Dental Work"
  final Set<String> recentMedProcedures;
  // Date + dosage/reason collected per chip in recentMedProcedures, keyed
  // by the same option name — used to judge whether the 4-week window has
  // actually elapsed instead of deferring forever just because a chip was
  // ever checked.
  final Map<String, MedProcedureDetail> medProcedureDetails;
  final bool hasMajorMedicalHistory; // heart disease, asthma, diabetes, etc.
  // Free-text description collected when hasMajorMedicalHistory is true —
  // no deferral window applies (clinical review required regardless of
  // when it happened), so only the description is kept, no date.
  final String? majorMedicalHistoryDesc;

  // Risk Factor Parameters (NEW)
  final bool hasTransfusionOrSurgery; // last 12 months
  final DateTime? transfusionOrSurgeryDate;
  final String? transfusionOrSurgeryDesc;
  final bool hasTravelOrNeedleStick; // international travel or accidental stick, last 12 months
  final DateTime? travelOrNeedleDate;
  final String? travelOrNeedleDesc;

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
    this.medProcedureDetails = const {},
    this.hasMajorMedicalHistory = false,
    this.majorMedicalHistoryDesc,
    this.hasTransfusionOrSurgery = false,
    this.transfusionOrSurgeryDate,
    this.transfusionOrSurgeryDesc,
    this.hasTravelOrNeedleStick = false,
    this.travelOrNeedleDate,
    this.travelOrNeedleDesc,
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

  /// 4-week window for recent minor medications/procedures (antibiotics,
  /// aspirin, vaccines, dental work) — matches EligibilityRules.recentProcedureDefDays.
  static const int recentProcedureDefDays = 28;

  /// 12-month window for a reported transfusion or surgery — matches
  /// EligibilityRules.transfusionSurgeryDefDays.
  static const int transfusionSurgeryDefDays = 365;

  /// 12-month window for reported travel or an accidental needle stick —
  /// matches EligibilityRules.travelNeedleDefDays.
  static const int travelNeedleDefDays = 365;

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

    // Node 6b: Recent Minor Medications/Procedures Check (4-week window per
    // chip — uses whichever selected procedure's date is most recent so a
    // donor who, say, took antibiotics 3 weeks ago and had dental work 2
    // months ago is judged against the antibiotics date, not cleared early).
    if (npt.recentMedProcedures.isNotEmpty) {
      DateTime? mostRecentDate;
      bool anyMissingDate = false;
      for (final option in npt.recentMedProcedures) {
        final date = npt.medProcedureDetails[option]?.date;
        if (date == null) {
          anyMissingDate = true;
          continue;
        }
        if (mostRecentDate == null || date.isAfter(mostRecentDate)) {
          mostRecentDate = date;
        }
      }
      if (anyMissingDate || mostRecentDate == null) {
        // No date on file for at least one selected procedure — can't verify
        // the window has elapsed, so defer.
        return ClassificationResult(status: EligibleStats.deferredRecentProcedure);
      }
      final daysSinceProcedure = DateTime.now().difference(mostRecentDate).inDays;
      if (daysSinceProcedure < recentProcedureDefDays) {
        return ClassificationResult(
          status: EligibleStats.deferredRecentProcedure,
          daysRemaining: recentProcedureDefDays - daysSinceProcedure,
        );
      }
      // Window has passed for every selected procedure — fall through.
    }

    // Node 6c: Major Medical History Check — no deferral window; a reported
    // major condition (heart disease, asthma, diabetes, etc.) always
    // requires clinical review regardless of when it was disclosed.
    if (npt.hasMajorMedicalHistory) {
      return ClassificationResult(status: EligibleStats.deferredMajorMedical);
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

    // Node 10: Transfusion or Surgery Check (12-month window, using the
    // actual event date collected in the follow-up screen — same pattern
    // as the tattoo check above, rather than deferring forever just
    // because the toggle was once set to "yes").
    if (npt.hasTransfusionOrSurgery) {
      if (npt.transfusionOrSurgeryDate != null) {
        final daysSince = DateTime.now().difference(npt.transfusionOrSurgeryDate!).inDays;
        if (daysSince >= transfusionSurgeryDefDays) {
          // Window has passed — fall through, no longer deferred for this.
        } else {
          return ClassificationResult(
            status: EligibleStats.deferredTransfusionSurgery,
            daysRemaining: transfusionSurgeryDefDays - daysSince,
          );
        }
      } else {
        return ClassificationResult(status: EligibleStats.deferredTransfusionSurgery);
      }
    }

    // Node 11: Travel or Needle Stick Check (12-month window, same pattern).
    if (npt.hasTravelOrNeedleStick) {
      if (npt.travelOrNeedleDate != null) {
        final daysSince = DateTime.now().difference(npt.travelOrNeedleDate!).inDays;
        if (daysSince >= travelNeedleDefDays) {
          // Window has passed — fall through, no longer deferred for this.
        } else {
          return ClassificationResult(
            status: EligibleStats.deferredTravelNeedle,
            daysRemaining: travelNeedleDefDays - daysSince,
          );
        }
      } else {
        return ClassificationResult(status: EligibleStats.deferredTravelNeedle);
      }
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