import 'package:resq/utils/algo/decision_tree_class.dart';

/// Clinical standards and rule parameters based on Department of Health (DOH)
/// and Philippine Red Cross (PRC) Voluntary Blood Donation guidelines.
class EligibilityRules {
  EligibilityRules._();

  //============================================================================
  // Clinical Parameter Thresholds & Deferral Windows
  //============================================================================

  static const double minWeight = 50.0;
  static const int minAge = 18;
  static const int maxAge = 65;

  // Deferral & Rest Windows (in Days/Hours)
  static const int wholeBloodRestPeriodDays = 90; // Mandatory 90-day NVBSP recovery gap
  static const int tattsPierceDefDays = 180;      // Mandatory 6-month deferral window
  static const int alcoholDefHours = 24;          // Minimum 24-hour sobriety period
  static const int mensRestDays = 7;              // Days deferred after recent heavy cycle
  static const int recentProcedureDefDays = 28;   // 4-week window for minor meds/procedures
  static const int transfusionSurgeryDefDays = 365; // 12-month window post transfusion/surgery
  static const int travelNeedleDefDays = 365;     // 12-month window for travel/needle-stick exposure

  //============================================================================
  // User-Facing Titles
  //============================================================================

  /// Returns user-friendly titles for each classification result.
  static String getStatsTitle(EligibleStats stats) {
    switch (stats) {
      case EligibleStats.eligible:
        return "Eligible to Donate";
      case EligibleStats.deferredNotWell:
        return "Not Feeling Well Today";
      case EligibleStats.deferredFasting:
        return "Meal & Fluids Needed";
      case EligibleStats.deferredWeight:
        return "Weight Requirement Not Met";
      case EligibleStats.deferredAge:
        return "Age Requirement Not Met";
      case EligibleStats.deferredInterval:
        return "Recovery Period Active";
      case EligibleStats.deferredTattsPierce:
        return "Recent Tattoo or Piercing";
      case EligibleStats.deferredAlcohol:
        return "Recent Alcohol Intake";
      case EligibleStats.deferredRecentProcedure:
        return "Recent Medication or Procedure";
      case EligibleStats.deferredMajorMedical:
        return "Medical History Review Required";
      case EligibleStats.deferredTransfusionSurgery:
        return "Recent Transfusion or Surgery";
      case EligibleStats.deferredTravelNeedle:
        return "Recent Travel or Needle Exposure";
      case EligibleStats.deferredMaternal:
        return "Maternal Health Deferral";
      case EligibleStats.deferredMensCycle:
        return "Active Menstrual Cycle";
      case EligibleStats.deferredMedical:
        return "Medical Clearance Required";
      case EligibleStats.deferredClinicalRisk:
        return "Temporary Clinical Deferral";
    }
  }

  //============================================================================
  // Detailed Explanations
  //============================================================================

  /// Detailed description for cards, alerts, countdowns, and modal notices.
  static String getStatsDesc(ClassificationResult result) {
    switch (result.status) {
      case EligibleStats.eligible:
        return "You meet all physical and health screening standards. You are ready to save lives!";
      case EligibleStats.deferredNotWell:
        return "You've indicated you're not feeling well today. Please donate once you're feeling healthy and back to normal.";
      case EligibleStats.deferredFasting:
        return "A full meal and fluids within 4-6 hours before donating helps prevent dizziness or fainting. Please eat, hydrate, and try again.";
      case EligibleStats.deferredWeight:
        return "DOH standards require a minimum weight of $minWeight kg to ensure donor safety during standard volume donation.";
      case EligibleStats.deferredAge:
        return "Donors must be between $minAge and $maxAge years old according to clinical safety protocols.";
      case EligibleStats.deferredInterval:
        return "NVBSP guidelines require a mandatory $wholeBloodRestPeriodDays-day recovery interval between whole blood donations. ${result.daysRemaining} days remaining.";
      case EligibleStats.deferredTattsPierce:
        return "Tattoos, body piercings, or permanent makeup require a mandatory 6-month ($tattsPierceDefDays days) waiting period from the date performed.";
      case EligibleStats.deferredAlcohol:
        return "Alcohol intake within $alcoholDefHours hours affects blood volume and donor recovery. Please rest and re-evaluate tomorrow.";
      case EligibleStats.deferredRecentProcedure:
        return "Recent medications or minor procedures (antibiotics, vaccines, dental work, minor surgery) within the last $recentProcedureDefDays days require a brief waiting period before donating.";
      case EligibleStats.deferredMajorMedical:
        return "A reported major medical history (e.g. heart disease, asthma, diabetes) requires clinical review before you can be cleared to donate.";
      case EligibleStats.deferredTransfusionSurgery:
        return "Blood transfusions or surgeries within the last 12 months ($transfusionSurgeryDefDays days) require a waiting period to ensure donor and recipient safety.";
      case EligibleStats.deferredTravelNeedle:
        return "International travel or accidental needle-stick exposure within the last 12 months ($travelNeedleDefDays days) requires a waiting period per blood safety protocols.";
      case EligibleStats.deferredMaternal:
        return "Pregnancy and breastfeeding temporarily defer donation to protect both mother and child iron levels.";
      case EligibleStats.deferredMensCycle:
        return "Donations during active or recent heavy menstrual flow (< $mensRestDays days) are deferred to prevent acute temporary anemia.";
      case EligibleStats.deferredMedical:
        return "Active infections, recent antibiotic use, or symptoms require complete recovery before donating.";
      case EligibleStats.deferredClinicalRisk:
        return "Specific clinical risk factors require a temporary waiting period in accordance with blood safety protocols.";
    }
  }

  //============================================================================
  // Date Calculators for Clearance & Recovery Roadmaps
  //============================================================================

  /// Calculates the next eligible donation date following a successful donation.
  static DateTime calcuNextEligibleDateAfterDonation(DateTime donationDate) {
    return donationDate.add(const Duration(days: wholeBloodRestPeriodDays));
  }

  /// Calculates the target clearance date for a tattoo/piercing deferral.
  static DateTime calcuTattsPierceClearanceDate(DateTime tattsPierceDate) {
    return tattsPierceDate.add(const Duration(days: tattsPierceDefDays));
  }

  /// Calculates the target clearance date for a transfusion/surgery deferral.
  static DateTime calcuTransfusionSurgeryClearanceDate(DateTime eventDate) {
    return eventDate.add(const Duration(days: transfusionSurgeryDefDays));
  }

  /// Calculates the target clearance date for a travel/needle-stick deferral.
  static DateTime calcuTravelNeedleClearanceDate(DateTime eventDate) {
    return eventDate.add(const Duration(days: travelNeedleDefDays));
  }

  /// Calculates the target clearance date for a recent medication/minor
  /// procedure deferral.
  static DateTime calcuRecentProcedureClearanceDate(DateTime procedureDate) {
    return procedureDate.add(const Duration(days: recentProcedureDefDays));
  }

  /// Returns remaining days until target clearance date.
  static int calcuRemainingDays(DateTime targetClearanceDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetClearanceDate.year, targetClearanceDate.month, targetClearanceDate.day);
    final diff = target.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }
}