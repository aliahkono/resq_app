import 'package:flutter_test/flutter_test.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';

// Same cases as the backend's eligibilityClassifier.test.js for the malaria
// wait, the symptom check and the age rule, so the app and the dashboard
// never disagree.
void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  DonorScreensNPT donor({
    int age = 30,
    String? travelDesc,
    int? travelDaysAgo,
    DateTime? checkedAt,
    DateTime? symptomsEnd,
    bool ongoing = false,
  }) =>
      DonorScreensNPT(
        gender: BioSex.male,
        weight: 68,
        age: age,
        isFirstTimeDonor: true,
        hasTattsOrPierce: false,
        hasAlcoholPast24hr: false,
        hasActiveInfectOrMeds: false,
        hasHighRiskExpo: false,
        hasTravelOrNeedleStick: travelDesc != null,
        travelOrNeedleDesc: travelDesc,
        travelOrNeedleDate: travelDaysAgo == null ? null : daysAgo(travelDaysAgo),
        malariaCheckedAt: checkedAt,
        malariaSymptomsEndDate: symptomsEnd,
        malariaSymptomsOngoing: ongoing,
      );
  ClassificationResult classify(DonorScreensNPT npt) => DecisionTreeClassifier().classify(npt);

  test('a malaria-area visit defers 1 year (P14: 200 days ago)', () {
    final r = classify(donor(travelDesc: 'Trip to Palawan, stayed in El Nido', travelDaysAgo: 200));
    expect(r.status, EligibleStats.deferredTravelNeedle);
    expect(r.daysRemaining, 165);
    expect(classify(donor(travelDesc: 'Trip to Palawan', travelDaysAgo: 364)).daysRemaining, 1);
  });

  test('after the wait the symptom check is needed, and a check during the wait does not count', () {
    expect(classify(donor(travelDesc: 'Trip to Palawan', travelDaysAgo: 400)).status,
        EligibleStats.deferredMalariaCheck);
    expect(classify(donor(travelDesc: 'Trip to Palawan', travelDaysAgo: 400, checkedAt: daysAgo(100))).status,
        EligibleStats.deferredMalariaCheck);
    expect(classify(donor(travelDesc: 'Trip to Palawan', travelDaysAgo: 400, checkedAt: DateTime.now())).isEligible,
        isTrue);
  });

  test('symptoms defer 3 years after they end, or until they end', () {
    final r = classify(donor(
        travelDesc: 'Trip to Palawan', travelDaysAgo: 200, checkedAt: daysAgo(150), symptomsEnd: daysAgo(160)));
    expect(r.status, EligibleStats.deferredTravelNeedle);
    expect(r.daysRemaining, 935);
    final ongoing = classify(donor(travelDesc: 'Trip to Palawan', travelDaysAgo: 400, checkedAt: DateTime.now(), ongoing: true));
    expect(ongoing.status, EligibleStats.deferredTravelNeedle);
    expect(ongoing.daysRemaining, 0);
  });

  test('living in a malaria area and past malaria still defer 3 years', () {
    expect(classify(donor(travelDesc: 'Lived in rural Palawan for 5 years', travelDaysAgo: 400)).daysRemaining, 695);
    expect(classify(donor(travelDesc: 'Had malaria, treated in 2024', travelDaysAgo: 400)).daysRemaining, 695);
  });

  test('a needle-stick still defers 12 months with no symptom check', () {
    const needle = 'Accidental needle stick injury while working at a clinic';
    expect(classify(donor(travelDesc: needle, travelDaysAgo: 364)).daysRemaining, 1);
    expect(classify(donor(travelDesc: needle, travelDaysAgo: 365)).isEligible, isTrue);
  });

  test('no upper age limit (P19: 66), but under 18 still defers', () {
    expect(classify(donor(age: 66)).isEligible, isTrue);
    expect(classify(donor(age: 80)).isEligible, isTrue);
    expect(classify(donor(age: 17)).status, EligibleStats.deferredAge);
  });
}
