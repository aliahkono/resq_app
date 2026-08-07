enum BioSex { male, female}
/// This represents the raw screening inputs passed into the Decision Tree
class DonorScreensNPT {
  //Baseline Parameters
  final BioSex gender;
  final double weight;
  final int age;

  //General Screening
  final bool hasTattsOrPierce;
  final bool hasAlcoholPast24hr;
  final bool hasActiveInfectOrMeds;

  //Female-Specific Screening Parameters
  final bool? isPregOrNursing;
  final DateTime? lastMensPeriodDate;

  //Male / Clinical Risk Parameters
  final bool? hasHighRiskExpo;

  DonorScreensNPT({
    required this.gender,
    required this.weight,
    required this.age,
    required this.hasTattsOrPierce,
    required this.hasAlcoholPast24hr,
    required this.hasActiveInfectOrMeds,
    this.isPregOrNursing,
    this.lastMensPeriodDate,
    this.hasHighRiskExpo,
  });
}

/// This base on the output classification result from the decision tree
enum EligibleStats {
  eligible,
  defferedWeight,
  defferedAge,
  defferedTattsPierce,
  defferedAlcohol,
  defferedMaternal,
  defferedMensCycle,
  defferedMedical,
  defferedClinicalRisk,
}

/// Engine of Decision Tree Classification for the donor screening
class DecisionTreeClassifier {
  /// This evaluates the donor parameters through rule-based decision nodes
  EligibleStats classify(DonorScreensNPT npt) {
    //Node 1: Weight Threshold Check (DOH Standard >= 50kg)
    if (npt.weight < 50.0) {
      return EligibleStats.defferedWeight;
    }

    //Node 2: Age Bracket Check (Standard 18-65)
    if (npt.age < 18 || npt.age > 65) {
      return EligibleStats.defferedAge;
    }

    //Node 3: Medical / Infect Check
    if (npt.hasActiveInfectOrMeds) {
      return EligibleStats.defferedMedical;
    }

    //Node 4: Tattoo / Pierce Deferral Window (< 6 Mos)
    if (npt.hasTattsOrPierce) {
      return EligibleStats.defferedTattsPierce;
    }

    //Node 5: Immediate Readiness Check
    if (npt.hasAlcoholPast24hr) {
      return EligibleStats.defferedAlcohol;
    }

    //Node 6: Gender-Specific Branching
    if (npt.gender == BioSex.female) {
      return _evalFemBranch(npt);
    } else {
      return _evaluateMaleBranch(npt);
    }
  }

  /// Evaluates Female-Specific Decision Nodes
  EligibleStats _evalFemBranch(DonorScreensNPT npt) {
    // Check Maternal Health (Pregnancy / Nursing)
    if (npt.isPregOrNursing == true) {
      return EligibleStats.defferedMaternal;
    }

    //Checks the Mens Cycle (Heavy flow or recent cycle window < 7 days)
    if (npt.lastMensPeriodDate != null) {
      final daysSinceLmp =
          DateTime.now().difference(npt.lastMensPeriodDate!).inDays;
      if (daysSinceLmp < 7) {
        return EligibleStats.defferedMensCycle;
      }
    }

    return EligibleStats.eligible;
  }

  /// Evaluates Male-Specific Decision Nodes
  EligibleStats _evaluateMaleBranch(DonorScreensNPT npt) {
    // Check Clinical High-Risk Exposure
    if (npt.hasHighRiskExpo == true) {
      return EligibleStats.defferedClinicalRisk;
    }
    return EligibleStats.eligible;
  }
}
