import 'package:resq/utils/helpers/med_keyword_rules.dart';

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

  // Malaria symptom check (POST /api/donor/me/malaria-check), not asked by
  // the screening wizard: when the donor last answered it, the latest date
  // reported symptoms ended, and whether they're still unwell.
  final DateTime? malariaCheckedAt;
  final DateTime? malariaSymptomsEndDate;
  final bool malariaSymptomsOngoing;

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
    this.malariaCheckedAt,
    this.malariaSymptomsEndDate,
    this.malariaSymptomsOngoing = false,
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
  deferredMalariaCheck, // Malaria wait over; symptom check not answered yet
  deferredMaternal,
  deferredMensCycle,
  deferredMedical,
  deferredClinicalRisk,
}

/// Result payload containing status and days remaining for deferral tracking.
/// [status] and [daysRemaining] are the strictest finding (see
/// DecisionTreeClassifier.strictest); [otherReasons] are the rest of the
/// rules the donor also failed, in tree order.
class ClassificationResult {
  final EligibleStats status;
  final int daysRemaining;
  final List<ClassificationResult> otherReasons;

  bool get isEligible => status == EligibleStats.eligible;

  ClassificationResult({
    required this.status,
    this.daysRemaining = 0,
    this.otherReasons = const [],
  });
}

/// A malaria exposure's wait (see DecisionTreeClassifier.malariaWait).
/// [endsAt] is null when there's no date to count from or symptoms are
/// ongoing; [checkDone] means the donor answered the symptom check after
/// the wait ended.
class MalariaWait {
  final MalariaExposure exposure;
  final DateTime? endsAt;
  final bool checkDone;

  const MalariaWait({required this.exposure, this.endsAt, this.checkDone = false});
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

  /// Malaria waiting periods, counted from the date the donor gives:
  /// 1 year after visiting a malaria area (e.g. rural Palawan, Mindoro,
  /// Romblon), 3 years after leaving one they lived in, and 3 years after
  /// finishing malaria treatment. Fever, chills or flu-like illness after
  /// the exposure restarts the wait: 3 years after the symptoms end.
  static const int malariaVisitDefDays = 365;
  static const int malariaResidentDefDays = 1095;
  static const int malariaTreatedDefDays = 1095;
  static const int malariaSymptomDefDays = 1095;

  static int malariaWindowDays(MalariaExposure exposure) {
    switch (exposure) {
      case MalariaExposure.visited:
        return malariaVisitDefDays;
      case MalariaExposure.lived:
        return malariaResidentDefDays;
      case MalariaExposure.treated:
        return malariaTreatedDefDays;
    }
  }

  /// The malaria wait for a travel/needle-stick answer, or null when it
  /// isn't a malaria exposure. Same rule as malariaWait() in the backend's
  /// eligibilityClassifier.js.
  static MalariaWait? malariaWait(DonorScreensNPT npt) {
    if (!npt.hasTravelOrNeedleStick) return null;
    final assessment = MedicalKeywordRules.assessTravelOrNeedleStick(npt.travelOrNeedleDesc);
    final isMalaria = assessment.verdict == KeywordVerdict.deferred &&
        assessment.matches.any((m) => m.conditionLabel == 'Malaria-Endemic Travel');
    if (!isMalaria) return null;
    final exposure = MedicalKeywordRules.malariaExposureOf(npt.travelOrNeedleDesc);
    if (npt.travelOrNeedleDate == null || npt.malariaSymptomsOngoing) {
      return MalariaWait(exposure: exposure);
    }
    var endsAt = npt.travelOrNeedleDate!.add(Duration(days: malariaWindowDays(exposure)));
    final symptomsEnd = npt.malariaSymptomsEndDate;
    if (symptomsEnd != null) {
      final afterSymptoms = symptomsEnd.add(const Duration(days: malariaSymptomDefDays));
      if (afterSymptoms.isAfter(endsAt)) endsAt = afterSymptoms;
    }
    final checkedAt = npt.malariaCheckedAt;
    return MalariaWait(
      exposure: exposure,
      endsAt: endsAt,
      checkDone: checkedAt != null && !checkedAt.isBefore(endsAt),
    );
  }

  /// Reasons that need a clinician's judgment, not a fixed wait.
  static const Set<EligibleStats> clinicalReviewReasons = {
    EligibleStats.deferredMedical,
    EligibleStats.deferredClinicalRisk,
    EligibleStats.deferredMajorMedical,
  };

  /// Reasons that clear the same day or with one quick action.
  static const Set<EligibleStats> sameDayReasons = {
    EligibleStats.deferredNotWell,
    EligibleStats.deferredFasting,
    EligibleStats.deferredAlcohol,
    EligibleStats.deferredMalariaCheck,
  };

  /// How strict a finding is (higher wins), same as strictness() in the
  /// backend's eligibilityClassifier.js:
  ///   3  needs clinical review
  ///   2  deferred with no date to count down to (under 50 kg, under 18,
  ///      pregnant/nursing, or a date the rules need is missing)
  ///   1  deferred with a countdown; the longest countdown wins
  ///   0  clears the same day or with one quick action
  static int strictness(ClassificationResult r) {
    if (clinicalReviewReasons.contains(r.status)) return 3;
    if (r.daysRemaining > 0) return 1;
    if (sameDayReasons.contains(r.status)) return 0;
    return 2;
  }

  /// The strictest of [findings] (ties keep tree order), or null when empty.
  static ClassificationResult? strictest(List<ClassificationResult> findings) {
    ClassificationResult? best;
    for (final f in findings) {
      if (best == null) {
        best = f;
        continue;
      }
      final a = strictness(f);
      final b = strictness(best);
      if (a > b || (a == 1 && b == 1 && f.daysRemaining > best.daysRemaining)) best = f;
    }
    return best;
  }

  /// Runs every decision-tree node and reports the strictest outcome, with
  /// the other matching reasons in [ClassificationResult.otherReasons]. The
  /// tree used to stop at the first match, so a donor with two risks was
  /// told about only one, and the countdown could be shorter than the real
  /// wait (e.g. a recent donation hiding a surgery deferral).
  ClassificationResult classify(DonorScreensNPT npt) {
    final findings = evaluateAll(npt);
    final best = strictest(findings);
    if (best == null) return ClassificationResult(status: EligibleStats.eligible);
    return ClassificationResult(
      status: best.status,
      daysRemaining: best.daysRemaining,
      otherReasons: [for (final f in findings) if (!identical(f, best)) f],
    );
  }

  /// Every rule the donor fails, in tree order (empty = eligible).
  List<ClassificationResult> evaluateAll(DonorScreensNPT npt) {
    final found = <ClassificationResult>[];
    void add(EligibleStats status, [int daysRemaining = 0]) =>
        found.add(ClassificationResult(status: status, daysRemaining: daysRemaining));
    final now = DateTime.now();

    // Node 1: Immediate Wellness Check
    if (!npt.feelsWellToday) add(EligibleStats.deferredNotWell);

    // Node 2: Meal / Fluid Intake Check (last 4-6 hrs)
    if (!npt.hasEatenRecently) add(EligibleStats.deferredFasting);

    // Node 3: Weight Threshold Check (DOH Standard >= 50kg)
    if (npt.weight < 50.0) add(EligibleStats.deferredWeight);

    // Node 4: Minimum Age Check. No upper limit: a donor over 65 is
    // eligible but evaluated by the hospital first (EligibleAppointView
    // tells them when they book).
    if (npt.age < 18) add(EligibleStats.deferredAge);

    // Node 5: Last Donation Interval Check (90-Day Deferral Window for returning donors)
    if (!npt.isFirstTimeDonor && npt.lastDonationDate != null) {
      final daysSince = now.difference(npt.lastDonationDate!).inDays;
      if (daysSince < minDonationIntervalDays) {
        add(EligibleStats.deferredInterval, minDonationIntervalDays - daysSince);
      }
    }

    // Node 6: Medical / Active Infection Check
    if (npt.hasActiveInfectOrMeds) add(EligibleStats.deferredMedical);

    // Node 6b: Recent Minor Medications/Procedures Check (4-week window,
    // judged against the most recent selected item; any item without a date
    // defers since the window can't be verified).
    if (npt.recentMedProcedures.isNotEmpty) {
      DateTime? mostRecentDate;
      bool anyMissingDate = false;
      for (final option in npt.recentMedProcedures) {
        final date = npt.medProcedureDetails[option]?.date;
        if (date == null) {
          anyMissingDate = true;
          continue;
        }
        if (mostRecentDate == null || date.isAfter(mostRecentDate)) mostRecentDate = date;
      }
      if (anyMissingDate || mostRecentDate == null) {
        add(EligibleStats.deferredRecentProcedure);
      } else {
        final daysSince = now.difference(mostRecentDate).inDays;
        if (daysSince < recentProcedureDefDays) {
          add(EligibleStats.deferredRecentProcedure, recentProcedureDefDays - daysSince);
        }
      }
    }

    // Node 6c: Major Medical History Check — assessed against the free-text
    // description (see medical_keyword_rules.dart): controlled asthma or
    // diabetes doesn't defer; heart disease, epilepsy, bleeding disorders,
    // severe skin conditions and autoimmune disorders always do.
    if (npt.hasMajorMedicalHistory &&
        MedicalKeywordRules.assessMajorMedicalHistory(npt.majorMedicalHistoryDesc).verdict ==
            KeywordVerdict.deferred) {
      add(EligibleStats.deferredMajorMedical);
    }

    // Node 7: Tattoo / Piercing Window Check (12 months; no date defers)
    if (npt.hasTattsOrPierce) {
      if (npt.tattooDate != null) {
        final daysSince = now.difference(npt.tattooDate!).inDays;
        if (daysSince < tattooDeferralWindowDays) {
          add(EligibleStats.deferredTattsPierce, tattooDeferralWindowDays - daysSince);
        }
      } else {
        add(EligibleStats.deferredTattsPierce);
      }
    }

    // Node 10: Transfusion or Surgery Check (12 months from the event date)
    if (npt.hasTransfusionOrSurgery) {
      if (npt.transfusionOrSurgeryDate != null) {
        final daysSince = now.difference(npt.transfusionOrSurgeryDate!).inDays;
        if (daysSince < transfusionSurgeryDefDays) {
          add(EligibleStats.deferredTransfusionSurgery, transfusionSurgeryDefDays - daysSince);
        }
      } else {
        add(EligibleStats.deferredTransfusionSurgery);
      }
    }

    // Node 11: Travel or Needle Stick Check — assessed against the free-text
    // description: non-endemic travel doesn't defer; malaria waits as in
    // malariaWait() and then needs the symptom check; needle-stick exposure
    // or a commercial tattoo/piercing disclosed here defers 12 months.
    final malaria = malariaWait(npt);
    if (malaria != null) {
      final endsAt = malaria.endsAt;
      if (endsAt == null) {
        add(EligibleStats.deferredTravelNeedle);
      } else if (now.isBefore(endsAt)) {
        add(EligibleStats.deferredTravelNeedle,
            (endsAt.difference(now).inMilliseconds / Duration.millisecondsPerDay).ceil());
      } else if (!malaria.checkDone) {
        add(EligibleStats.deferredMalariaCheck);
      }
    } else if (npt.hasTravelOrNeedleStick &&
        MedicalKeywordRules.assessTravelOrNeedleStick(npt.travelOrNeedleDesc).verdict ==
            KeywordVerdict.deferred) {
      if (npt.travelOrNeedleDate != null) {
        final daysSince = now.difference(npt.travelOrNeedleDate!).inDays;
        if (daysSince < travelNeedleDefDays) {
          add(EligibleStats.deferredTravelNeedle, travelNeedleDefDays - daysSince);
        }
      } else {
        add(EligibleStats.deferredTravelNeedle);
      }
    }

    // Node 12: Alcohol Intake Check (< 24 hrs)
    if (npt.hasAlcoholPast24hr) add(EligibleStats.deferredAlcohol);

    // High-risk exposure applies to every donor, so it runs before the
    // sex-specific checks.
    if (npt.hasHighRiskExpo == true) add(EligibleStats.deferredClinicalRisk);

    // Node 13: Female-specific checks
    if (npt.gender == BioSex.female) {
      if (npt.isPregOrNursing == true) add(EligibleStats.deferredMaternal);
      if (npt.lastMensPeriodDate != null) {
        final daysSinceLmp = now.difference(npt.lastMensPeriodDate!).inDays;
        if (daysSinceLmp < 7) add(EligibleStats.deferredMensCycle, 7 - daysSinceLmp);
      }
    }
    return found;
  }
}
