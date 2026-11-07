import 'package:flutter_test/flutter_test.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';

// Every rule is checked and the strictest outcome is reported, with the rest
// in otherReasons. Same cases as the multi-risk tests in the backend's
// eligibilityClassifier.test.js.
void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  ClassificationResult classify(DonorScreensNPT npt) => DecisionTreeClassifier().classify(npt);
  List<EligibleStats> others(ClassificationResult r) => [for (final o in r.otherReasons) o.status];

  test('the longest countdown wins and the other reason is kept', () {
    final r = classify(DonorScreensNPT(
      gender: BioSex.male,
      weight: 68,
      age: 30,
      isFirstTimeDonor: false,
      lastDonationDate: daysAgo(30),
      hasTattsOrPierce: false,
      hasAlcoholPast24hr: false,
      hasActiveInfectOrMeds: false,
      hasHighRiskExpo: false,
      hasTransfusionOrSurgery: true,
      transfusionOrSurgeryDate: daysAgo(100),
    ));
    expect(r.status, EligibleStats.deferredTransfusionSurgery);
    expect(r.daysRemaining, 265);
    expect(others(r), [EligibleStats.deferredInterval]);
    expect(r.otherReasons.single.daysRemaining, 60);
  });

  test('a deferral with no end date beats a same-day one', () {
    final r = classify(DonorScreensNPT(
      gender: BioSex.female,
      weight: 55,
      age: 28,
      isFirstTimeDonor: true,
      hasTattsOrPierce: false,
      hasAlcoholPast24hr: true,
      hasActiveInfectOrMeds: false,
      isPregOrNursing: true,
      lastMensPeriodDate: daysAgo(3),
    ));
    expect(r.status, EligibleStats.deferredMaternal);
    expect(r.daysRemaining, 0);
    expect(others(r), [EligibleStats.deferredAlcohol, EligibleStats.deferredMensCycle]);
  });

  test('clinical review beats any fixed deferral', () {
    final r = classify(DonorScreensNPT(
      gender: BioSex.male,
      weight: 49,
      age: 40,
      isFirstTimeDonor: true,
      hasTattsOrPierce: false,
      hasAlcoholPast24hr: false,
      hasActiveInfectOrMeds: false,
      hasHighRiskExpo: false,
      hasMajorMedicalHistory: true,
      majorMedicalHistoryDesc: 'Type 1 diabetes, on insulin',
    ));
    expect(r.status, EligibleStats.deferredMajorMedical);
    expect(others(r), [EligibleStats.deferredWeight]);
  });

  test('a countdown beats a same-day deferral', () {
    final r = classify(DonorScreensNPT(
      gender: BioSex.male,
      weight: 68,
      age: 30,
      isFirstTimeDonor: true,
      hasTattsOrPierce: true,
      tattooDate: daysAgo(30),
      hasAlcoholPast24hr: true,
      hasActiveInfectOrMeds: false,
      hasHighRiskExpo: false,
    ));
    expect(r.status, EligibleStats.deferredTattsPierce);
    expect(r.daysRemaining, 335);
    expect(others(r), [EligibleStats.deferredAlcohol]);
  });

  test('one risk has no other reasons; eligible has none', () {
    DonorScreensNPT male({bool alcohol = false}) => DonorScreensNPT(
          gender: BioSex.male,
          weight: 68,
          age: 30,
          isFirstTimeDonor: true,
          hasTattsOrPierce: false,
          hasAlcoholPast24hr: alcohol,
          hasActiveInfectOrMeds: false,
          hasHighRiskExpo: false,
        );
    final r = classify(male(alcohol: true));
    expect(r.status, EligibleStats.deferredAlcohol);
    expect(r.otherReasons, isEmpty);
    expect(classify(male()).isEligible, isTrue);
    expect(classify(male()).otherReasons, isEmpty);
  });
}
