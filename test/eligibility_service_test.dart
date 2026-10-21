import 'package:flutter_test/flutter_test.dart';
import 'package:resq/services/eligibility_service.dart';

// The app re-classifies a donor from GET /api/donor/me on every profile
// fetch, so it has to agree with the backend after an admin's Mark Eligible
// (which clears both the hospital-recorded and the self-reported donation
// dates — see setDonorEligibility in the backend's donors.controller.js).
void main() {
  Map<String, dynamic> profile({String? lastDonationAt, String? selfReported, bool tattoo = false}) => {
        'age': 30,
        'weightKg': '68.00',
        'gender': 'male',
        'lastDonationAt': lastDonationAt,
        'healthScreening': {
          'isFirstTimeDonor': false,
          'lastDonationDate': selfReported,
          'hasTattsOrPierce': tattoo,
          'tattooDate': tattoo ? DateTime.now().subtract(const Duration(days: 10)).toIso8601String() : null,
          'hasAlcoholPast24hr': false,
          'hasActiveInfectOrMeds': false,
        },
      };
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

  test('a self-reported donation 30 days ago defers the donor', () {
    expect(classifyDonorFromProfile(profile(selfReported: thirtyDaysAgo))!.isEligible, isFalse);
  });

  test('after Mark Eligible clears both dates, the donor is eligible', () {
    expect(classifyDonorFromProfile(profile())!.isEligible, isTrue);
  });

  test('a hospital-recorded donation still defers even with no self-reported date', () {
    expect(classifyDonorFromProfile(profile(lastDonationAt: thirtyDaysAgo))!.isEligible, isFalse);
  });

  test('a recent tattoo still defers after the dates are cleared', () {
    expect(classifyDonorFromProfile(profile(tattoo: true))!.isEligible, isFalse);
  });
}
