import 'package:flutter/material.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/profile/qr_pass_modal_view.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class IneligibleHomeView extends StatefulWidget {
  final ClassificationResult? classificationResult;
  final int daysRemaining;
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final String donorId;

  const IneligibleHomeView({
    super.key,
    this.classificationResult,
    this.daysRemaining = 45,
    this.isFirstTimeDonor = false,
    this.donorName = 'Donor',
    this.bloodType = '',
    this.donorId = '',
  });

  @override
  State<IneligibleHomeView> createState() => _IneligibleHomeViewState();
}

class _IneligibleHomeViewState extends State<IneligibleHomeView> {
  final List<Map<String, dynamic>> _checklistTasks = [
    {'title': 'Maintain a high-iron diet', 'completed': true},
    {'title': 'Maintain body weight > 50kg', 'completed': true},
    {'title': 'Routine wellness check', 'completed': false},
    {'title': 'Hydrate regularly (2.0L - 2.5L daily)', 'completed': false},
    {'title': 'Review deferral clearance guidelines', 'completed': false},
  ];

  String _formatClearanceDate(int days) {
    final target = DateTime.now().add(Duration(days: days > 0 ? days : 1));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[target.month - 1]} ${target.day}, ${target.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.classificationResult?.status ?? EligibleStats.deferredWeight;
    final effectiveDays = widget.classificationResult?.daysRemaining ?? widget.daysRemaining;

    final String reasonTitle = EligibilityRules.getStatsTitle(status);
    final String reasonDesc = widget.classificationResult != null
        ? EligibilityRules.getStatsDesc(widget.classificationResult!)
        : EligibilityRules.getStatsDesc(
      ClassificationResult(status: status, daysRemaining: effectiveDays),
    );

    final String clearanceDateStr = _formatClearanceDate(effectiveDays);
    final bool isPostDonationRecovery = status == EligibleStats.deferredInterval;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIneligibilityBanner(reasonTitle),
                    const SizedBox(height: 14),

                    if (isPostDonationRecovery)
                      _buildActiveDonorRecoveryLayout(context, status, effectiveDays, reasonTitle, clearanceDateStr)
                    else
                      _buildClinicalDeferralLayout(context, status, effectiveDays, reasonTitle, reasonDesc, clearanceDateStr),

                    const SizedBox(height: 16),
                    _buildActionCard(context, status),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 18, right: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF7D1B22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/rq_logo_white.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'RQ',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1.5, height: 22, color: Colors.white60),
              const SizedBox(width: 12),
              const Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          AppNotificationBell(
            isEligible: false,
            donorBloodType: widget.bloodType,
          ),
        ],
      ),
    );
  }

  Widget _buildIneligibilityBanner(String reason) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CURRENT STATUS: TEMPORARILY DEFERRED ($reason)',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalDeferralLayout(
      BuildContext context,
      EligibleStats status,
      int effectiveDays,
      String reasonTitle,
      String reasonDesc,
      String clearanceDateStr,
      ) {
    final completedCount = _checklistTasks.where((t) => t['completed'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF8A1E26),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D1B22).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 26),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      QrPassModalView.show(
                        context,
                        donorName: widget.donorName,
                        bloodType: widget.bloodType.isNotEmpty ? widget.bloodType : 'Pending',
                        donorId: widget.donorId.isNotEmpty ? widget.donorId : 'BD-PENDING',
                        isEligible: false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Show Digital Pass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Temporary Deferral Notice',
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your health comes first! Based on your health assessment, you are temporarily deferred from donating today.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ESTIMATED CLEARANCE DATE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clearanceDateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => _showScreeningDetailsModal(context, reasonTitle, reasonDesc, clearanceDateStr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF8A1E26),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'View Screening Details',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Why Am I Deferred?'),
        const SizedBox(height: 12),
        _buildDetailInfoCard('REASON', reasonTitle),
        const SizedBox(height: 10),
        _buildDetailInfoCard('STANDARD WINDOW', _resolveStandardWindow(status, effectiveDays)),
        const SizedBox(height: 10),
        _buildDetailInfoCard('SAFETY NOTE', _resolveSafetyNote(status)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Preparation Checklist'),
            Text(
              '$completedCount OF ${_checklistTasks.length} COMPLETED',
              style: const TextStyle(
                color: Color(0xFF8A1E26),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_checklistTasks.length.clamp(0, 3), (index) {
          final task = _checklistTasks[index];
          final bool isDone = task['completed'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  task['completed'] = !isDone;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFEBF3FE) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF8A1E26) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone ? const Color(0xFF8A1E26) : const Color(0xFFD4D4D4),
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDone ? const Color(0xFF1E1E1E) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveDonorRecoveryLayout(
      BuildContext context,
      EligibleStats status,
      int effectiveDays,
      String reasonTitle,
      String clearanceDateStr,
      ) {
    const int totalCycleDays = 56;
    final int daysPassed = (totalCycleDays - effectiveDays).clamp(0, totalCycleDays);
    final int percentComplete = ((daysPassed / totalCycleDays) * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3D6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE68A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.nightlight_round, color: Color(0xFFB45309), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REST & RECOVERY PERIOD',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Thank you for your recent donation! Your body is replenishing its red blood cell reserves.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT ELIGIBLE DATE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clearanceDateStr,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reminder set for $clearanceDateStr!'),
                          backgroundColor: const Color(0xFF2E7D32),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.alarm, size: 15),
                    label: const Text('Set Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$effectiveDays Days Left in Recovery',
                style: const TextStyle(color: Color(0xFF8A1E26), fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress: $daysPassed/$totalCycleDays Days', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
                  Text('$percentComplete% Complete', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (daysPassed / totalCycleDays).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFFFDDE0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8A1E26)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, EligibleStats status) {
    bool canRetake = status == EligibleStats.deferredAlcohol ||
        status == EligibleStats.deferredMensCycle ||
        status == EligibleStats.deferredMedical ||
        status == EligibleStats.deferredWeight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Action',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 8),
          Text(
            _getRecommendedAction(status),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.45),
          ),
          const SizedBox(height: 16),
          if (canRetake)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistrationWizView(isRetake: true),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7D1B22),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Update Health Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showInfoModal(context, 'Deferral Policy', 'This deferral is based on clinical safety guidelines set by DOH and NVBSP to protect donor and recipient health.');
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Understand Deferral Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7D1B22),
                  side: const BorderSide(color: Color(0xFF7D1B22), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getRecommendedAction(EligibleStats status) {
    switch (status) {
      case EligibleStats.deferredWeight:
        return "Focus on a balanced diet rich in proteins and iron to safely reach the 50.0 kg weight requirement.";
      case EligibleStats.deferredAlcohol:
        return "Refrain from alcohol intake for at least 24 hours and hydrate well before retaking your screening.";
      case EligibleStats.deferredTattsPierce:
        return "Wait for the 6-month healing window to conclude to eliminate infection risk.";
      case EligibleStats.deferredInterval:
        return "Allow your body sufficient time to replenish iron stores before booking your next appointment.";
      default:
        return "Follow clinical guidance and retake your health assessment once the temporary deferral window passes.";
    }
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF8A1E26),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  Widget _buildDetailInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8A1E26), letterSpacing: 0.6),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  String _resolveStandardWindow(EligibleStats status, int days) {
    switch (status) {
      case EligibleStats.deferredTattsPierce:
        return '6 Months Window';
      case EligibleStats.deferredAlcohol:
        return '24 Hours Window';
      case EligibleStats.deferredWeight:
        return 'Until >= 50.0 kg baseline';
      case EligibleStats.deferredMaternal:
        return '6 Months Postpartum';
      default:
        return '$days Days Window';
    }
  }

  String _resolveSafetyNote(EligibleStats status) {
    switch (status) {
      case EligibleStats.deferredTattsPierce:
        return 'DOH transfusion safety protocol for skin procedures.';
      case EligibleStats.deferredWeight:
        return 'Required by clinical standards to prevent donor fainting or hypotension.';
      case EligibleStats.deferredAlcohol:
        return 'Ensures plasma hydration and prevents adverse vasovagal reactions.';
      default:
        return 'Clinical protocol prioritizing donor recovery and safety.';
    }
  }

  void _showScreeningDetailsModal(BuildContext context, String title, String desc, String clearDate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35)),
            const SizedBox(height: 12),
            Text('Projected Clearance: $clearDate', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoModal(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}