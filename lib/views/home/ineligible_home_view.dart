import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/widgets/resq_ui.dart';

/// Which hero layout the deferred dashboard shows.
enum _DeferralKind {
  /// Cleared on reaching a measurable target (weight ≥ 50 kg).
  weight,

  /// Cleared after a fixed number of days (interval, tattoo, travel...).
  countdown,

  /// Short, condition-based hold with no day count (alcohol, not feeling
  /// well, fasting, menstrual timing, maternal protocol).
  condition,

  /// Needs clinical review, or can't be cleared by waiting (major medical
  /// history, clinical risk, age).
  review,
}

class IneligibleHomeView extends StatefulWidget {
  final ClassificationResult? classificationResult;
  final int daysRemaining;
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final String donorId;
  // These three were all missing before — the retake button below used to
  // open the wizard completely blank (no initialScreening) and its result
  // went nowhere at all (no onRetakeCompleted), not even updating this
  // screen's own local state.
  final ScreenNPTModel? screeningModel;
  final String token;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;
  // Hospital-verified donation count, shown as "Your impact so far" on the
  // medical-review layout. 0 hides that card.
  final int completedDonations;

  const IneligibleHomeView({
    super.key,
    this.classificationResult,
    this.daysRemaining = 45,
    this.isFirstTimeDonor = false,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.screeningModel,
    this.token = '',
    this.onRetakeCompleted,
    this.completedDonations = 0,
  });

  @override
  State<IneligibleHomeView> createState() => _IneligibleHomeViewState();
}

class _IneligibleHomeViewState extends State<IneligibleHomeView> {
  static const double _minWeightKg = 50.0;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  // Defensive, string-safe enum resolver to prevent enum-mismatch crashes
  String _getReasonTitle(EligibleStats? status) {
    if (status == null) return 'Temporary health deferral';
    final s = status.toString().toLowerCase();
    if (s.contains('weight')) return 'Weight below 50.0 kg (110 lbs)';
    if (s.contains('tatts') || s.contains('pierce')) return 'Recent tattoo or body piercing';
    if (s.contains('alcohol')) return 'Alcohol in the last 24 hours';
    if (s.contains('maternal') || s.contains('preg')) return 'Pregnancy or breastfeeding';
    if (s.contains('interval')) return 'Recovering from your last donation';
    if (s.contains('cycle') || s.contains('mens')) return 'Menstrual cycle timing';
    if (s.contains('notwell')) return 'Not feeling well today';
    if (s.contains('fasting')) return 'No recent meal or fluids';
    if (s.contains('age')) return 'Outside the donor age range';
    if (s.contains('recentprocedure')) return 'Recent medication or procedure';
    if (s.contains('majormedical')) return 'Medical history needs review';
    if (s.contains('transfusion')) return 'Recent transfusion or surgery';
    if (s.contains('travel')) return 'Recent travel or needle-stick';
    if (s.contains('clinicalrisk')) return 'Clinical risk needs review';
    if (s.contains('med')) return 'Medical or medication review';
    return 'Temporary health deferral';
  }

  String _getReasonDesc(EligibleStats? status) {
    if (status == null) return 'Your screening shows a temporary deferral.';
    final s = status.toString().toLowerCase();
    if (s.contains('weight')) {
      return 'Giving blood under 50 kg can cause fainting and sudden drops in blood pressure. This rule keeps you safe.';
    }
    if (s.contains('tatts') || s.contains('pierce')) {
      return 'A waiting window after a tattoo or piercing keeps transfusions safe from infections that tests may not catch yet.';
    }
    if (s.contains('alcohol')) {
      return 'Alcohol within 24 hours can cause dehydration and fainting while donating. Hydrate well and try again after 24 hours.';
    }
    if (s.contains('maternal') || s.contains('preg')) {
      return 'Deferred under maternal health protocols to protect the nutrient reserves of both mother and child.';
    }
    if (s.contains('interval')) {
      return 'Your body needs time to rebuild red blood cells and iron after a whole blood donation.';
    }
    if (s.contains('notwell') || s.contains('fasting')) {
      return 'You should feel well and have eaten a proper meal before donating. Try again once you do.';
    }
    if (s.contains('majormedical') || s.contains('clinicalrisk') || s.contains('med')) {
      return 'Your answers need a quick check by clinical staff before you can donate. This protects both you and the patient.';
    }
    return 'Based on clinical screening protocols, your donation is temporarily deferred to keep you safe.';
  }

  String _getRecommendedAction(EligibleStats? status) {
    final s = (status ?? '').toString().toLowerCase();
    if (s.contains('weight')) return 'Eat protein- and iron-rich meals to safely reach 50 kg.';
    if (s.contains('alcohol')) return 'Skip alcohol for 24 hours and drink plenty of water.';
    if (s.contains('tatts') || s.contains('pierce')) return 'Wait for the healing window to finish.';
    if (s.contains('interval')) return 'Eat iron-rich food (malunggay, beans, leafy greens) while you recover.';
    if (s.contains('notwell') || s.contains('fasting')) return 'Rest, eat a full meal and drink fluids.';
    return 'Follow clinical guidance and update your assessment when things change.';
  }

  /// Full length of a day-based deferral window, used only to draw how far
  /// through it the donor is. Never shorter than what's left.
  int _windowLengthDays(EligibleStats status, int remaining) {
    int standard;
    switch (status) {
      case EligibleStats.deferredInterval:
        standard = DecisionTreeClassifier.minDonationIntervalDays;
        break;
      case EligibleStats.deferredTattsPierce:
        standard = DecisionTreeClassifier.tattooDeferralWindowDays;
        break;
      case EligibleStats.deferredRecentProcedure:
        standard = DecisionTreeClassifier.recentProcedureDefDays;
        break;
      case EligibleStats.deferredTransfusionSurgery:
        standard = DecisionTreeClassifier.transfusionSurgeryDefDays;
        break;
      case EligibleStats.deferredTravelNeedle:
        standard = remaining > DecisionTreeClassifier.malariaEndemicTravelDefDays
            ? DecisionTreeClassifier.travelNeedleDefDays
            : DecisionTreeClassifier.malariaEndemicTravelDefDays;
        break;
      default:
        standard = 30;
    }
    return math.max(standard, remaining);
  }

  _DeferralKind _kindFor(EligibleStats status, int days) {
    if (status == EligibleStats.deferredWeight) return _DeferralKind.weight;
    if (days > 0) return _DeferralKind.countdown;
    switch (status) {
      case EligibleStats.deferredMajorMedical:
      case EligibleStats.deferredClinicalRisk:
      case EligibleStats.deferredMedical:
      case EligibleStats.deferredAge:
      case EligibleStats.deferredTattsPierce:
      case EligibleStats.deferredTransfusionSurgery:
      case EligibleStats.deferredTravelNeedle:
      case EligibleStats.deferredRecentProcedure:
        return _DeferralKind.review;
      default:
        return _DeferralKind.condition;
    }
  }

  String get _firstName {
    final n = widget.donorName.trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.classificationResult?.status ?? EligibleStats.deferredWeight;
    final int days = widget.classificationResult?.daysRemaining ?? widget.daysRemaining;
    final kind = _kindFor(status, days);

    Widget hero;
    switch (kind) {
      case _DeferralKind.weight:
        hero = _buildWeightHero();
        break;
      case _DeferralKind.countdown:
        hero = _buildCountdownHero(status, days);
        break;
      case _DeferralKind.condition:
        hero = _buildConditionHero(status);
        break;
      case _DeferralKind.review:
        hero = _buildReviewHero(status);
        break;
    }

    return ColoredBox(
      color: RQColors.surface,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          // Red band continuing the app bar, with the hero card overlapping it.
          Stack(
            children: [
              Container(height: 84, color: RQColors.blood),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: hero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReasonCard(status, kind),
          if (kind == _DeferralKind.review && widget.completedDonations > 0) ...[
            const SizedBox(height: 16),
            _buildImpactCard(),
          ],
          const SizedBox(height: 22),
          _buildSectionTitle(kind == _DeferralKind.review ? 'What you can do' : 'Recommended actions'),
          const SizedBox(height: 10),
          _buildActionsCard(status, kind),
          const SizedBox(height: 16),
          _buildHelpCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero cards
  // ---------------------------------------------------------------------------

  BoxDecoration get _heroDecoration => BoxDecoration(
        color: RQColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B1416), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x1A1B1416), blurRadius: 28, offset: Offset(0, 10)),
        ],
      );

  Widget _deferredPill() => const RQPill(
        label: 'TEMPORARILY DEFERRED',
        background: RQColors.warningTint,
        color: RQColors.warning,
        dot: true,
        uppercase: true,
      );

  Widget _buildWeightHero() {
    final double weight = widget.screeningModel?.screensNPT.weight ?? 0;
    final bool known = weight > 0 && weight < _minWeightKg;
    final double toGo = known ? (_minWeightKg - weight) : 0;
    final double progress = known ? (weight / _minWeightKg).clamp(0.0, 1.0) : 0.0;
    final DateTime? since = widget.screeningModel?.submissionDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _deferredPill(),
              if (since != null)
                Text('Since ${_months[since.month - 1]} ${since.day}',
                    style: const TextStyle(fontSize: 12, color: RQColors.muted)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            known ? "You're almost there, $_firstName" : 'Reach 50 kg to donate',
            style: const TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.w600, color: RQColors.ink),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ProgressRing(
                progress: progress,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      known ? '${toGo.toStringAsFixed(1)} kg' : '50 kg',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: RQColors.ink),
                    ),
                    Text(known ? 'to go' : 'target',
                        style: const TextStyle(fontSize: 11, color: RQColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statBlock('CURRENT WEIGHT', weight > 0 ? '${weight.toStringAsFixed(1)} kg' : '—',
                        valueColor: RQColors.warning),
                    const SizedBox(height: 12),
                    _statBlock('NEEDED TO DONATE', '${_minWeightKg.toStringAsFixed(1)} kg'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _cautionNote(
            icon: Icons.schedule_rounded,
            text: 'No waiting period. You can donate as soon as you reach 50.0 kg.',
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownHero(EligibleStats status, int days) {
    final int total = _windowLengthDays(status, days);
    final double progress = total > 0 ? (1 - days / total).clamp(0.0, 1.0) : 0.0;
    final DateTime eligibleOn = DateTime.now().add(Duration(days: days));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _deferredPill(),
              Text('$total-day window', style: const TextStyle(fontSize: 12, color: RQColors.muted)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ProgressRing(
                progress: progress,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$days',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: RQColors.ink)),
                    Text(days == 1 ? 'day to go' : 'days to go',
                        style: const TextStyle(fontSize: 11, color: RQColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statBlock('NEXT ELIGIBLE', _fmtDate(eligibleOn)),
                    const SizedBox(height: 12),
                    _statBlock('REASON', _getReasonTitle(status), small: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildConditionHero(EligibleStats status) {
    final s = status.toString().toLowerCase();
    String when;
    if (s.contains('alcohol')) {
      when = 'After 24 hours';
    } else if (s.contains('maternal')) {
      when = 'After the postpartum window';
    } else if (s.contains('mens')) {
      when = 'After your cycle ends';
    } else {
      when = 'When you feel ready';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _heroDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _deferredPill(),
          const SizedBox(height: 16),
          Row(
            children: [
              const RQIconBox(
                icon: Icons.hourglass_bottom_rounded,
                size: 56,
                background: RQColors.warningTint,
                color: RQColors.warning,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOU CAN DONATE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: RQColors.muted)),
                    Text(when,
                        style: const TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w600, color: RQColors.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _cautionNote(
            icon: Icons.info_outline_rounded,
            text: 'This is a short hold. Update your health assessment once it no longer applies.',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewHero(EligibleStats status) {
    final bool isAge = status == EligibleStats.deferredAge;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: _heroDecoration,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: RQColors.bloodTint, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border_rounded, color: RQColors.blood, size: 34),
          ),
          const SizedBox(height: 12),
          RQPill(
            label: isAge ? 'NOT ELIGIBLE TO DONATE' : 'MEDICAL REVIEW NEEDED',
            background: RQColors.navyTint,
            color: RQColors.navy,
            uppercase: true,
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you for stepping up, $_firstName',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w600, color: RQColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            isAge
                ? "You're outside the age range for donating blood. You can still save lives with ResQ in other ways."
                : 'Some of your answers need a check by clinical staff first. You can still help save lives in the meantime.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Supporting cards
  // ---------------------------------------------------------------------------

  Widget _buildReasonCard(EligibleStats status, _DeferralKind kind) {
    final bool review = kind == _DeferralKind.review;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RQIconBox(
                icon: review ? Icons.info_outline_rounded : Icons.monitor_weight_outlined,
                size: 44,
                background: review ? RQColors.navyTint : RQColors.warningTint,
                color: review ? RQColors.navy : RQColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review ? 'Reason on file' : "Why you're deferred",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                    Text(_getReasonTitle(status),
                        style: const TextStyle(fontSize: 13, height: 1.4, color: RQColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_getReasonDesc(status), style: const TextStyle(fontSize: 13, height: 1.55, color: RQColors.body)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showScreeningDetailsSheet(status),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('View screening details',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RQColors.navy)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: RQColors.navy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard() {
    final int n = widget.completedDonations;
    // 450 mL per whole-blood unit; each unit can help up to 3 patients.
    final String liters = (n * 0.45).toStringAsFixed(2);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RQSectionLabel('Your impact so far'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _impactStat('$n', n == 1 ? 'donation' : 'donations', RQColors.bloodText)),
              Expanded(child: _impactStat('$liters L', 'given', RQColors.bloodText)),
              Expanded(child: _impactStat('${n * 3}', 'lives helped', RQColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
      ],
    );
  }

  Widget _buildActionsCard(EligibleStats status, _DeferralKind kind) {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          _actionRow(
            icon: Icons.favorite_border_rounded,
            title: _getRecommendedAction(status),
            subtitle: kind == _DeferralKind.weight
                ? 'Eggs, fish, beans, malunggay, rice'
                : 'Take care of yourself first',
            showDivider: true,
          ),
          _actionRow(
            icon: Icons.fact_check_outlined,
            title: 'Update your health assessment',
            subtitle: kind == _DeferralKind.weight
                ? 'Once you reach 50 kg'
                : 'When your situation changes',
            showDivider: false,
          ),
          const SizedBox(height: 10),
          RQButton(
            label: 'Update Health Assessment',
            onPressed: _openRetake,
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: RQColors.hairline)) : null,
      ),
      child: Row(
        children: [
          RQIconBox(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: RQColors.ink)),
                Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: RQColors.navy, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You can still help today',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                SizedBox(height: 2),
                Text('Invite friends and family to become donors',
                    style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xE6FFFFFF))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Builder(
            builder: (btnContext) => SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _shareInvite(btnContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: RQColors.navy,
                  elevation: 0,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    Widget dot({required bool done, required bool current}) {
      if (done) {
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: RQColors.warning, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        );
      }
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: current ? RQColors.warning : RQColors.hairline, width: 3),
        ),
        child: current
            ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: RQColors.warning, shape: BoxShape.circle),
                ),
              )
            : null,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            dot(done: true, current: false),
            Expanded(child: Container(height: 4, color: RQColors.warning)),
            dot(done: false, current: true),
            Expanded(child: Container(height: 4, color: RQColors.hairline)),
            dot(done: false, current: false),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Deferred', style: TextStyle(fontSize: 12, color: RQColors.muted)),
            Text('Recovering', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RQColors.warning)),
            Text('Eligible', style: TextStyle(fontSize: 12, color: RQColors.muted)),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.bloodText)),
    );
  }

  Widget _statBlock(String label, String value, {Color valueColor = RQColors.ink, bool small = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: RQColors.muted)),
        Text(
          value,
          style: TextStyle(
            fontSize: small ? 13 : 19,
            height: 1.35,
            fontWeight: small ? FontWeight.w500 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _cautionNote({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RQColors.caution,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RQColors.cautionBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: RQColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: RQColors.ink))),
        ],
      ),
    );
  }

  void _openRetake() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrationWizView(
          isRetake: true,
          initialScreening: widget.screeningModel,
          donorName: widget.donorName,
          bloodType: widget.bloodType,
          donorId: widget.donorId,
          token: widget.token,
          onRetakeCompleted: widget.onRetakeCompleted,
        ),
      ),
    );
  }

  void _shareInvite(BuildContext btnContext) {
    const text = 'I use ResQ to answer urgent blood requests from hospitals near me. '
        'Join as a donor. One donation can help save up to three lives.';
    final box = btnContext.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
    SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  }

  void _showScreeningDetailsSheet(EligibleStats status) {
    final int days = widget.classificationResult?.daysRemaining ?? widget.daysRemaining;
    final screening = widget.screeningModel;
    final double weight = screening?.screensNPT.weight ?? 0;

    String clearance;
    if (status == EligibleStats.deferredWeight) {
      clearance = 'On reaching 50.0 kg';
    } else if (days > 0) {
      clearance = _fmtDate(DateTime.now().add(Duration(days: days)));
    } else if (status == EligibleStats.deferredAlcohol) {
      clearance = 'After 24 hours';
    } else {
      clearance = 'After review';
    }

    showResQSheet(
      context: context,
      builder: (ctx) => ResQSheet(
        icon: Icons.fact_check_outlined,
        title: 'Screening details',
        subtitle: screening != null ? 'Answered ${_fmtDate(screening.submissionDate)}' : null,
        footer: RQButton(label: 'Got it', onPressed: () => Navigator.pop(ctx)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getReasonTitle(status),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.ink)),
            const SizedBox(height: 6),
            Text(_getReasonDesc(status), style: const TextStyle(fontSize: 13, height: 1.55, color: RQColors.body)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _detailRow('Cleared', clearance),
                  if (weight > 0) _detailRow('Recorded weight', '${weight.toStringAsFixed(1)} kg'),
                  if (screening != null) _detailRow('Recorded age', '${screening.screensNPT.age} yrs', last: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: RQColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: RQColors.muted))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RQColors.ink)),
        ],
      ),
    );
  }
}

/// Circular progress ring with content in the middle.
class _ProgressRing extends StatelessWidget {
  final double progress;
  final Widget child;
  const _ProgressRing({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = RQColors.warningTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..color = RQColors.warning
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}