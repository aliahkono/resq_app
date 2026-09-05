import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';

/// Re-runs the same on-device decision tree used at registration
/// (RegistrationWizView -> DecisionTreeClassifier), using the donor's saved
/// screening answers from GET /api/donor/me — instead of trusting the
/// backend's own `isEligible` flag.
///
/// That flag (see donorPortal.controller.js's getMyProfile) only checks
/// "has it been 90+ days since your last completed donation, or have you
/// never donated at all". It was never meant to capture the full medical
/// screening (weight, age, tattoos/piercings, recent alcohol, active
/// infection, pregnancy, high-risk exposure) — so a donor correctly
/// deferred at registration would otherwise show as "Eligible" on every
/// later login, simply because they haven't donated yet and last_donation_at
/// is still NULL.
///
/// Returns null if there isn't enough saved screening data to evaluate —
/// e.g. an admin-created walk-in donor who never went through the app's
/// registration wizard, so `healthScreening`/age/weight/gender were never
/// collected. Callers should fall back to the backend's own `isEligible`
/// flag in that case, since there's nothing else to go on.
ClassificationResult? classifyDonorFromProfile(Map<String, dynamic> profile) {
  final npt = screensFromProfile(profile);
  if (npt == null) return null;
  return DecisionTreeClassifier().classify(npt);
}

/// Reconstructs a full ScreenNPTModel (the donor's actual current answers,
/// not just the pass/fail classification) from a GET /api/donor/me
/// response. Used to pre-fill RegistrationWizView's retake flow with real
/// data — without this, RegistrationWizView.initialScreening stayed null
/// for any donor who hadn't just come from a same-session registration
/// (i.e. anyone who logged in normally), and the wizard would silently
/// fall back to its Step 1 "create your account" UI instead of jumping to
/// the retake screening steps (see registration_wiz_view.dart's initState:
/// `if (widget.isRetake && widget.initialScreening != null)`).
///
/// Same null-if-incomplete contract as classifyDonorFromProfile.
ScreenNPTModel? buildScreeningModelFromProfile(Map<String, dynamic> profile) {
  final npt = screensFromProfile(profile);
  if (npt == null) return null;
  return ScreenNPTModel(
    donorProfId: (profile['id'] as String?) ?? '',
    // The backend doesn't track a separate "screening last submitted"
    // timestamp (health_screening is just a JSON blob on the donor row,
    // no timestamp inside it) — this is only used for display bookkeeping
    // in ScreenNPTModel, never read by the classifier itself, so "now" is
    // an honest-enough stand-in rather than a real submission date.
    submissionDate: DateTime.now(),
    screensNPT: npt,
  );
}

/// Shared parsing/validation for both functions above.
DonorScreensNPT? screensFromProfile(Map<String, dynamic> profile) {
  final screening = profile['healthScreening'];
  if (screening is! Map) return null;

  final age = profile['age'];
  // weight_kg is a Postgres NUMERIC column — the pg driver returns those as
  // strings (e.g. "62.50"), not JS/Dart numbers, to avoid float precision
  // loss. Has to be parsed explicitly, or this would silently bail out on
  // every real donor.
  final weightKgRaw = profile['weightKg'];
  final weightKg = weightKgRaw is num ? weightKgRaw : (weightKgRaw is String ? num.tryParse(weightKgRaw) : null);
  final genderStr = profile['gender'] as String?;
  final hasTatts = screening['hasTattsOrPierce'];
  final hasAlcohol = screening['hasAlcoholPast24hr'];
  final hasActiveInfect = screening['hasActiveInfectOrMeds'];

  // All required (non-nullable) by DonorScreensNPT — if any are missing,
  // the saved record is incomplete and there isn't enough to safely
  // classify.
  if (age is! num) return null;
  if (weightKg == null) return null;
  if (genderStr != 'male' && genderStr != 'female') return null;
  if (hasTatts is! bool || hasAlcohol is! bool || hasActiveInfect is! bool) return null;

  // The donor's *actual* completed-donation history (lastDonationAt, kept
  // current by hospital staff recording real donations — see
  // donors.controller.js completeAppointment) is more authoritative than
  // the self-reported "is this your first donation?" answer, since it's
  // hospital-verified. But it only ever gets set once an admin marks a
  // real appointment completed — a donor who self-reported as a *returning*
  // donor at registration (with their own last-donation date) but hasn't
  // had one recorded by a hospital yet still has a null lastDonationAt here.
  // Treating null as "definitely first-time" in that case would silently
  // discard their self-report on every login and could wrongly clear a
  // real post-donation-interval deferral — so null only means "no
  // hospital-verified donation on file", and falls back to what the donor
  // themselves reported (stored in healthScreening) rather than assuming
  // first-time outright.
  final lastDonationAtStr = profile['lastDonationAt'] as String?;
  final backendLastDonation = lastDonationAtStr != null ? DateTime.tryParse(lastDonationAtStr) : null;
  final selfReportedLastDonationStr = screening['lastDonationDate'] as String?;
  final selfReportedLastDonation =
      selfReportedLastDonationStr != null ? DateTime.tryParse(selfReportedLastDonationStr) : null;
  final lastDonationDate = backendLastDonation ?? selfReportedLastDonation;
  final isFirstTimeDonor = backendLastDonation != null
      ? false
      : ((screening['isFirstTimeDonor'] as bool?) ?? (selfReportedLastDonation == null));

  Map<String, MedProcedureDetail> parseMedProcedureDetails(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, MedProcedureDetail>{};
    raw.forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = MedProcedureDetail(
          date: value['date'] != null ? DateTime.tryParse(value['date'] as String) : null,
          dosageOrReason: value['dosageOrReason'] as String?,
        );
      }
    });
    return result;
  }

  final npt = DonorScreensNPT(
    gender: genderStr == 'female' ? BioSex.female : BioSex.male,
    weight: weightKg.toDouble(),
    age: age.toInt(),
    isFirstTimeDonor: isFirstTimeDonor,
    lastDonationDate: lastDonationDate,
    totalDonations: (screening['totalDonations'] as num?)?.toInt() ?? 0,
    feelsWellToday: (screening['feelsWellToday'] as bool?) ?? true,
    hasEatenRecently: (screening['hasEatenRecently'] as bool?) ?? true,
    hasTattsOrPierce: hasTatts,
    tattooDate: screening['tattooDate'] != null
        ? DateTime.tryParse(screening['tattooDate'] as String)
        : null,
    hasAlcoholPast24hr: hasAlcohol,
    hasActiveInfectOrMeds: hasActiveInfect,
    recentMedProcedures: (screening['recentMedProcedures'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        const {},
    medProcedureDetails: parseMedProcedureDetails(screening['medProcedureDetails']),
    hasMajorMedicalHistory: (screening['hasMajorMedicalHistory'] as bool?) ?? false,
    majorMedicalHistoryDesc: screening['majorMedicalHistoryDesc'] as String?,
    hasTransfusionOrSurgery: (screening['hasTransfusionOrSurgery'] as bool?) ?? false,
    transfusionOrSurgeryDate: screening['transfusionOrSurgeryDate'] != null
        ? DateTime.tryParse(screening['transfusionOrSurgeryDate'] as String)
        : null,
    transfusionOrSurgeryDesc: screening['transfusionOrSurgeryDesc'] as String?,
    hasTravelOrNeedleStick: (screening['hasTravelOrNeedleStick'] as bool?) ?? false,
    travelOrNeedleDate: screening['travelOrNeedleDate'] != null
        ? DateTime.tryParse(screening['travelOrNeedleDate'] as String)
        : null,
    travelOrNeedleDesc: screening['travelOrNeedleDesc'] as String?,
    isPregOrNursing: screening['isPregOrNursing'] as bool?,
    lastMensPeriodDate: screening['lastMensPeriodDate'] != null
        ? DateTime.tryParse(screening['lastMensPeriodDate'] as String)
        : null,
    hasHighRiskExpo: screening['hasHighRiskExpo'] as bool?,
  );

  return npt;
}