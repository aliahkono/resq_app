import 'package:resq/utils/algo/decisionTree_class.dart';

/// This focus on the clinical standards and rule parameters based on Department of Health (DOH) and Philippine Red Cross (PRC) Voluntary Blood Donation guidelines.
class EligibilityRules {
  EligibilityRules._();

  //=====================
  //Clinical Parameters Thresholds
  //=====================

  static const double minWeight = 50.0;
  static const int minAge = 18;
  static const int maxAge = 65;

  //Deferral & Rest Windows (in Days/Hours)
  static const int wholeBloodRestPeriodDays = 56; //Standard Recovery period
  static const int tattsPierceDefDays = 100; //Mandatory 6mos deferral window
  static const int  alcoholDefHours = 24; //Minimum 24hr sobriety period
  static const int mensRestDays = 7; //Days to defer after heavy cycle onset

  //=====================
  //User-facing deferral reason messages
  //=====================

  /// This returns to user-friendly explanations for each classification result.
  static String getStatsTitle(EligibleStats stats) {
    switch (stats) {
      case EligibleStats.eligible:
        return "Eligible to Donate";
      case EligibleStats.defferedWeight:
        return "Weight Requirement Not Met";
      case EligibleStats.defferedAge:
        return "Age Requirement Not Met";
      case EligibleStats.defferedTattsPierce:
        return "Recent Tattoo or Piercing";
      case EligibleStats.defferedAlcohol:
        return "Recent Alcohol Intake";
      case EligibleStats.defferedMaternal:
        return "Maternal Health Deferral";
      case EligibleStats.defferedMensCycle:
        return "Active Menstrual Cycle";
      case EligibleStats.defferedMedical:
        return "Medical Clearance Required";
      case EligibleStats.defferedClinicalRisk:
        return "Temporary Clinical Deferral";
    }
  }

  /// Detailed description for cards, alerts, and modal notices.
  static String getStatsDesc(EligibleStats stats) {
    switch (stats) {
      case EligibleStats.eligible:
        return "You meet all physical and health screening standards. You are ready to save lives!";
      case EligibleStats.defferedWeight:
        return "DOH standards require a minimum weight of $minWeight kg to ensure donor safety during standard volume donation.";
      case EligibleStats.defferedAge:
        return "Donors must be between $minAge and $maxAge years old according to clinical safety protocols.";
      case EligibleStats.defferedTattsPierce:
        return "Tattoos, body piercings, or permanent makeup require a mandatory 6-month waiting period from the date performed.";
      case EligibleStats.defferedAlcohol:
        return "Alcohol intake within $alcoholDefHours hours affects blood volume and donor recovery. Please rest and re-evaluate tomorrow.";
      case EligibleStats.defferedMaternal:
        return "Pregnancy and breastfeeding temporarily defer donation to protect both mother and child iron levels.";
      case EligibleStats.defferedMensCycle:
        return "Donations during active or recent heavy menstrual flow are deferred to prevent temporary acute anemia.";
      case EligibleStats.defferedMedical:
        return "Active infections, recent antibiotic use, or symptoms require complete recovery before donating.";
      case EligibleStats.defferedClinicalRisk:
        return "Specific clinical risk factors require a temporary waiting period in accordance with blood safety protocols.";
    }
  }

  //=======================
  //Date Calculators for Clearance Roadmaps
  //=======================

  /// Calculates the next eligible donation date following a success donation.
  static DateTime calcuNextEligibleDateAfterDonation(DateTime donationDate) {
    return donationDate.add(const Duration(days: wholeBloodRestPeriodDays));
  }

  /// Calculates the target clearance date for a tattoo/piercing deferral.
  static DateTime calcuTattsPierceClearanceDate(DateTime tattsPierceDate) {
    return tattsPierceDate.add(const Duration(days: tattsPierceDefDays));
  }

  /// Returns remaining days until target clearance date.
  static int calcuRemainingDays(DateTime targetClearanceDate) {
    final now = DateTime.now();
    final diff = targetClearanceDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff > 0 ? diff : 0;
  }
}