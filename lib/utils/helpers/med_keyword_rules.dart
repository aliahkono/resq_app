/// Deterministic keyword-based classifier for the free-text descriptions a
/// donor gives for Major Medical History and Travel/Needle-Stick
/// disclosures (see medical_history_details_view.dart). Matches the
/// Philippine blood-donation eligibility guidance table: some conditions
/// always defer regardless of detail (heart disease, epilepsy/seizures,
/// blood/bleeding disorders, severe skin conditions, autoimmune disorders),
/// while others (asthma, diabetes) depend on whether the description
/// mentions specific controlling/uncontrolling details. Travel is similar:
/// malaria-endemic areas, needle-stick exposure, or a commercial
/// tattoo/piercing defer, but travel to a non-endemic city does not.
///
/// This is a heuristic keyword scan over free text, not a clinical
/// diagnosis tool — its only job is to (a) reach a deferred/eligible call
/// consistent with the guidance table, and (b) report exactly which words
/// drove that call so the reason can be highlighted for the donor or an
/// admin reviewer. No Flutter dependency on purpose — this stays a plain
/// Dart rules engine; the UI layer (donor_profile_view.dart) turns
/// [MedicalAssessment.matches] into highlighted text itself.
library;

enum KeywordVerdict { eligible, deferred }

class KeywordMatch {
  final String keyword;
  final int start;
  final int end;
  final KeywordVerdict verdict;
  final String conditionLabel;

  const KeywordMatch({
    required this.keyword,
    required this.start,
    required this.end,
    required this.verdict,
    required this.conditionLabel,
  });
}

class MedicalAssessment {
  final KeywordVerdict verdict;
  final String? note;
  final List<KeywordMatch> matches;

  const MedicalAssessment({required this.verdict, this.note, this.matches = const []});
}

class ConditionRule {
  final String label;
  final List<String> triggerKeywords;
  final List<String> deferralKeywords;
  final List<String> eligibleKeywords;
  final bool alwaysDeferred;

  const ConditionRule({
    required this.label,
    required this.triggerKeywords,
    this.deferralKeywords = const [],
    this.eligibleKeywords = const [],
    this.alwaysDeferred = false,
  });
}

class MedicalKeywordRules {
  MedicalKeywordRules._();

  static const List<ConditionRule> majorMedicalConditions = [
    ConditionRule(
      label: 'Asthma',
      triggerKeywords: ['asthma'],
      deferralKeywords: [
        'severe attack',
        'asthma attack',
        'oral steroid',
        'injected steroid',
        'steroid',
        'unmanaged',
        'difficult to manage',
        'uncontrolled asthma',
        'severe asthma',
      ],
      eligibleKeywords: ['controlled', 'mild', 'no symptoms', 'manageable'],
    ),
    ConditionRule(
      label: 'Heart Disease',
      triggerKeywords: ['heart disease', 'cardiac', 'heart attack', 'coronary'],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Diabetes',
      triggerKeywords: ['diabetes', 'diabetic'],
      deferralKeywords: ['insulin', 'uncontrolled', 'high blood sugar', 'beef insulin'],
      eligibleKeywords: ['metformin', 'oral medication', 'diet controlled', 'diet-controlled', 'controlled'],
    ),
    ConditionRule(
      label: 'Neurological Disorder',
      triggerKeywords: ['epilepsy', 'seizure', 'seizures', 'neurological disorder'],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Blood/Bleeding/Clotting Disorder',
      triggerKeywords: ['bleeding disorder', 'clotting disorder', 'hemophilia', 'blood disorder', 'thrombophilia'],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Severe Skin Condition',
      triggerKeywords: ['severe skin condition', 'severe psoriasis', 'severe eczema', 'skin infection'],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Autoimmune/Immunosuppressive Disorder',
      triggerKeywords: ['autoimmune', 'lupus', 'immunosuppressive', 'rheumatoid arthritis', 'immunocompromised'],
      alwaysDeferred: true,
    ),
  ];

  static const List<ConditionRule> travelConditions = [
    ConditionRule(
      label: 'Malaria-Endemic Travel',
      triggerKeywords: ['malaria', 'palawan', 'mindoro', 'romblon', 'endemic area', 'rural area'],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Needle Stick / Sharps Exposure',
      triggerKeywords: [
        'needle stick',
        'needlestick',
        'accidental needle',
        "someone else's blood",
        'exposure to blood',
        'sharps injury',
        'percutaneous',
      ],
      alwaysDeferred: true,
    ),
    ConditionRule(
      label: 'Tattoo / Piercing (Commercial Shop)',
      triggerKeywords: ['tattoo', 'piercing', 'ear piercing', 'body piercing'],
      alwaysDeferred: true,
    ),
  ];

  /// Assesses a Major Medical History free-text description. No description
  /// on file (but the toggle was "yes") always defers pending review — the
  /// condition table has nothing safe to clear it against.
  static MedicalAssessment assessMajorMedicalHistory(String? description) {
    return _assess(
      description,
      majorMedicalConditions,
      noMentionVerdict: KeywordVerdict.deferred,
      noMentionNote: 'A condition was flagged but no description was given — deferred pending clinical review.',
    );
  }

  /// Assesses a Travel/Needle-Stick free-text description. Unlike major
  /// medical history, a description that mentions travel but none of the
  /// known risk keywords defaults to eligible — matches "travel to
  /// non-endemic, metropolitan cities abroad -> Eligible".
  static MedicalAssessment assessTravelOrNeedleStick(String? description) {
    return _assess(
      description,
      travelConditions,
      noMentionVerdict: KeywordVerdict.deferred,
      noMentionNote: 'A recent travel/exposure event was flagged but no description was given — deferred pending review.',
      defaultWhenNoTriggerMatches: KeywordVerdict.eligible,
      defaultNote: 'No malaria-endemic area, needle-stick, or tattoo/piercing exposure mentioned — treated as low-risk travel.',
    );
  }

  static MedicalAssessment _assess(
    String? description,
    List<ConditionRule> rules, {
    required KeywordVerdict noMentionVerdict,
    required String noMentionNote,
    KeywordVerdict defaultWhenNoTriggerMatches = KeywordVerdict.deferred,
    String? defaultNote,
  }) {
    if (description == null || description.trim().isEmpty) {
      return MedicalAssessment(verdict: noMentionVerdict, note: noMentionNote);
    }

    final lower = description.toLowerCase();
    final matches = <KeywordMatch>[];
    KeywordVerdict overallVerdict = defaultWhenNoTriggerMatches;
    String? note = defaultNote;
    bool anyTriggerFound = false;

    for (final rule in rules) {
      int? triggerIndex;
      String? triggerWord;
      for (final kw in rule.triggerKeywords) {
        final idx = lower.indexOf(kw);
        if (idx != -1) {
          triggerIndex = idx;
          triggerWord = kw;
          break;
        }
      }
      if (triggerIndex == null || triggerWord == null) continue;
      anyTriggerFound = true;

      final KeywordVerdict ruleVerdict;
      if (rule.alwaysDeferred) {
        ruleVerdict = KeywordVerdict.deferred;
      } else {
        final hasDeferralKw = rule.deferralKeywords.any((kw) => lower.contains(kw));
        final hasEligibleKw = rule.eligibleKeywords.any((kw) => lower.contains(kw));
        if (hasDeferralKw) {
          ruleVerdict = KeywordVerdict.deferred;
        } else if (hasEligibleKw) {
          ruleVerdict = KeywordVerdict.eligible;
        } else {
          // Mentioned but controllability is unclear from the text — err
          // conservative rather than assume it's fine.
          ruleVerdict = KeywordVerdict.deferred;
        }
      }

      matches.add(KeywordMatch(
        keyword: description.substring(triggerIndex, triggerIndex + triggerWord.length),
        start: triggerIndex,
        end: triggerIndex + triggerWord.length,
        verdict: ruleVerdict,
        conditionLabel: rule.label,
      ));

      // Also highlight whichever specific deferral/eligible sub-keyword
      // fired, so the reason shown makes clear *why* — not just *that*.
      final subKeywords = ruleVerdict == KeywordVerdict.deferred ? rule.deferralKeywords : rule.eligibleKeywords;
      for (final kw in subKeywords) {
        final idx = lower.indexOf(kw);
        if (idx != -1 && idx != triggerIndex) {
          matches.add(KeywordMatch(
            keyword: description.substring(idx, idx + kw.length),
            start: idx,
            end: idx + kw.length,
            verdict: ruleVerdict,
            conditionLabel: rule.label,
          ));
        }
      }

      if (ruleVerdict == KeywordVerdict.deferred) {
        overallVerdict = KeywordVerdict.deferred;
        note = '${rule.label} noted — deferred per donation eligibility guidelines.';
      } else if (overallVerdict != KeywordVerdict.deferred) {
        overallVerdict = KeywordVerdict.eligible;
        note ??= '${rule.label} noted, appears well-controlled — no deferral required for this item.';
      }
    }

    if (!anyTriggerFound) {
      overallVerdict = defaultWhenNoTriggerMatches;
    }

    // Sort by position and drop overlapping matches for clean highlighting.
    matches.sort((a, b) => a.start.compareTo(b.start));
    final deduped = <KeywordMatch>[];
    int lastEnd = -1;
    for (final m in matches) {
      if (m.start >= lastEnd) {
        deduped.add(m);
        lastEnd = m.end;
      }
    }

    return MedicalAssessment(verdict: overallVerdict, note: note, matches: deduped);
  }
}