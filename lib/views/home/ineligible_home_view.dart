import 'package:flutter/material.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/profile/qr_pass_modal_view.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class IneligibleHomeView extends StatefulWidget {
  final ClassificationResult? classificationResult;
  final int daysRemaining;
  final bool isFirstTimeDonor;

  const IneligibleHomeView({
    super.key,
    this.classificationResult,
    this.daysRemaining = 45,
    this.isFirstTimeDonor = false,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            _buildIneligibilityBanner(reasonTitle),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  children: [
                    if (widget.isFirstTimeDonor)
                      _buildFirstTimeDonorLayout(context, status, effectiveDays, reasonTitle, reasonDesc, clearanceDateStr)
                    else
                      _buildActiveDonorRecoveryLayout(context, status, effectiveDays, reasonTitle, clearanceDateStr),
                    
                    const SizedBox(height: 20),
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

  Widget _buildIneligibilityBanner(String reason) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF2F2),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'CURRENT STATUS: TEMPORARILY DEFERRED ($reason)',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, EligibleStats status) {
    bool canRetake = status == EligibleStats.deferredAlcohol || 
                    status == EligibleStats.deferredMensCycle || 
                    status == EligibleStats.deferredMedical;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Action',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 12),
          Text(
            _getRecommendedAction(status),
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
          ),
          const SizedBox(height: 20),
          if (canRetake)
            SizedBox(
              width: double.infinity,
              height: 50,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Update My Health Status', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                   _showInfoModal(context, 'Deferral Policy', 'This deferral is based on clinical safety guidelines. Our team is here to help you return to eligibility safely.');
                },
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Understand Deferral Policy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7D1B22),
                  side: const BorderSide(color: Color(0xFF7D1B22), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        return "Focus on a balanced diet rich in proteins and iron. We recommend consulting a nutritionist to reach the 50kg threshold safely.";
      case EligibleStats.deferredAlcohol:
        return "Please refrain from alcohol for at least 24 hours. Hydrate well with water and fruit juices before your next attempt.";
      case EligibleStats.deferredTattsPierce:
        return "Wait for the mandatory 6-month healing period to conclude. This ensures zero risk of blood-borne transmissions.";
      case EligibleStats.deferredInterval:
        return "Your body needs time to replenish its iron stores. Use this period to maintain a healthy lifestyle for your next donation.";
      default:
        return "Follow the guidance provided in your screening details. You can update your status once the deferral period has passed.";
    }
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 16, right: 16),
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
          const AppNotificationBell(
            isEligible: false,
            donorBloodType: '',
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeDonorLayout(
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFB52934),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D1B22).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: Colors.white, size: 24),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      QrPassModalView.show(
                        context,
                        donorName: 'First-Time Volunteer',
                        bloodType: 'Pending',
                        donorId: 'BD-PENDING',
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
                    child: const Text('Show Digital Pass', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Temporary Deferral Notice',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your health comes first!\nBased on your screening, you are temporarily deferred from donating today.',
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CLEARANCE DATE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clearanceDateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () => _showScreeningDetailsModal(context, reasonTitle, reasonDesc, clearanceDateStr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF7D1B22),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'View Screening Details',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 10),
        _buildDetailInfoCard('REASON', reasonTitle),
        const SizedBox(height: 8),
        _buildDetailInfoCard('STANDARD WINDOW', _resolveStandardWindow(status, effectiveDays)),
        const SizedBox(height: 8),
        _buildDetailInfoCard('CLEAR DATE', clearanceDateStr),
        const SizedBox(height: 8),
        _buildDetailInfoCard('SAFETY NOTE', _resolveSafetyNote(status)),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('"Getting Ready"\nPlan'),
            Text(
              '$completedCount OF ${_checklistTasks.length} TASKS\nCOMPLETE',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF7D1B22),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_checklistTasks.length.clamp(0, 3), (index) {
          final task = _checklistTasks[index];
          final bool isDone = task['completed'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  task['completed'] = !isDone;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFFEBF1FA) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDone ? Colors.transparent : const Color(0xFFD4D4D4),
                    width: 1,
                  ),
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
                          color: isDone ? const Color(0xFF8A1E26) : const Color(0xFFBDBDBD),
                          width: 1.5,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDone ? const Color(0xFF1E1E1E) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        _buildSectionHeader('First - Time Donor Knowledge Hub'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildKnowledgeChip(Icons.help_outline_rounded, 'Deferral Rules', () {
              _showInfoModal(context, 'Deferral Rules & Protocols', 'Blood donation safety regulations set by the Department of Health (DOH) protect donor hemodynamics and transfusion safety.');
            }),
            _buildKnowledgeChip(Icons.water_drop_outlined, 'Hemoglobin Tests', () {
              _showInfoModal(context, 'Hemoglobin Standards', 'Healthy baseline: 12.5 g/dL to 17.5 g/dL ensures safe whole blood collection without triggering post-donation fatigue.');
            }),
            _buildKnowledgeChip(Icons.menu_book_outlined, 'First-Time Donor Guide', () {
              _showInfoModal(context, 'First-Time Donor Guide', 'Everything you need to know about preparing for your first blood drive: hydration, iron intake, and recovery.');
            }),
          ],
        ),
        const SizedBox(height: 24),
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE68A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.nightlight_round, color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'REST & RECOVERY\nPERIOD',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Thank you for your recent donation! Your body is replenishing its reserves.',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7D1B22),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              clearanceDateStr,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
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
                          icon: const Icon(Icons.alarm, size: 14),
                          label: const Text('Set Reminder', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEDF2FE),
                            foregroundColor: const Color(0xFF1E3A8A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$effectiveDays Days Left',
                      style: const TextStyle(color: Color(0xFF8A1E26), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress: $daysPassed/$totalCycleDays Days', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        Text('$percentComplete% Complete', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (daysPassed / totalCycleDays).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFFFDDE0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8A1E26)),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 10),
                    const Text(
                      'Last Donation: April 12, 2026 (@ Philippine Red Cross)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reason: Standard $totalCycleDays-day whole blood recovery',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
            children: [
              TextSpan(text: 'Staying Ready '),
              TextSpan(text: '| ', style: TextStyle(color: Color(0xFF7D1B22))),
              TextSpan(text: 'Recovery Tips'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRecoveryTipTile(
                icon: Icons.restaurant_rounded,
                title: 'Iron-Rich Foods',
                desc: 'Spinach, lentils, and red meats help recovery.',
                iconColor: const Color(0xFF8A1E26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRecoveryTipTile(
                icon: Icons.water_drop_rounded,
                title: 'Daily Hydration (2.5L)',
                desc: 'Current goal: 2.5L daily intake for replenishment.',
                iconColor: const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildRecoveryTipTile(
                icon: Icons.fitness_center_rounded,
                title: 'Light Exercise',
                desc: 'Avoid heavy lifting; stick to walking for now.',
                iconColor: const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRecoveryTipTile(
                icon: Icons.nightlight_round,
                title: 'Sleep & Recovery',
                desc: 'Target 7-8 hours of quality restorative rest.',
                iconColor: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A1E26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'URGENT NEED',
                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Quezon / Cavite Region', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Help Save Lives While You Rest',
                style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              RichText(
                text: const TextSpan(
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  children: [
                    TextSpan(text: 'Type '),
                    TextSpan(text: 'O+ ', style: TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.bold)),
                    TextSpan(text: 'supplies are critically low near your area. Since you\'re resting, can you share this with your circle?'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sharing urgent blood recruitment link to your social apps...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share Urgent Blood Need', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A1E26),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR LIFETIME IMPACT SUMMARY',
                style: TextStyle(color: Color(0xFF7D1B22), fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop_outlined, color: Color(0xFF8A1E26), size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('1.8', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
                            Text('Total Donated (L)', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, color: Color(0xFF1D4ED8), size: 28),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('12', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
                            Text('Lives Impacted', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF7D1B22),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  Widget _buildDetailInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22), letterSpacing: 0.5),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2C)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryTipTile({
    required IconData icon,
    required String title,
    required String desc,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280), height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDCE8FD),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveStandardWindow(EligibleStats status, int days) {
    switch (status) {
      case EligibleStats.deferredTattsPierce:
        return '6 to 12 Months';
      case EligibleStats.deferredAlcohol:
        return '24 Hours';
      case EligibleStats.deferredWeight:
        return 'Until >= 50.0 kg';
      case EligibleStats.deferredMaternal:
        return '6 Months Postpartum / Lactation';
      default:
        return '$days Days Window';
    }
  }

  String _resolveSafetyNote(EligibleStats status) {
    switch (status) {
      case EligibleStats.deferredTattsPierce:
        return 'Standard health safety protocol for skin healing.';
      case EligibleStats.deferredWeight:
        return 'Required by DOH safety standards to prevent donor hypotension.';
      case EligibleStats.deferredAlcohol:
        return 'Ensures proper plasma hydration and prevents vasovagal reactions.';
      default:
        return 'Medical protocol prioritizing donor recovery and safety.';
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