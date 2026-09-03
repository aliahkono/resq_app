import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';

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
  });

  @override
  State<IneligibleHomeView> createState() => _IneligibleHomeViewState();
}

class _IneligibleHomeViewState extends State<IneligibleHomeView> {
  // Defensive, string-safe enum resolver to prevent enum-mismatch crashes
  String _getReasonTitle(EligibleStats? status) {
    if (status == null) return 'Temporary Health Deferral';
    final s = status.toString().toLowerCase();
    if (s.contains('weight')) return 'Weight Below 50.0 kg Baseline';
    if (s.contains('tatts') || s.contains('pierce')) return 'Recent Tattoo or Body Piercing';
    if (s.contains('alcohol')) return 'Recent Alcohol Intake (< 24 hrs)';
    if (s.contains('maternal') || s.contains('preg')) return 'Maternal & Lactation Protocol';
    if (s.contains('interval')) return 'Whole Blood Recovery Window';
    if (s.contains('cycle') || s.contains('mens')) return 'Menstrual Cycle Timing';
    if (s.contains('med')) return 'Medical / Medication Review';
    return 'Temporary Health Deferral';
  }

  String _getReasonDesc(EligibleStats? status) {
    if (status == null) return 'Screening indicates temporary deferral.';
    final s = status.toString().toLowerCase();
    if (s.contains('weight')) {
      return 'The minimum weight requirement for whole blood donation is 50.0 kg (110 lbs). This standard protects donors from hypovolemia, sudden blood pressure drops, and fainting.';
    }
    if (s.contains('tatts') || s.contains('pierce')) {
      return 'A standard 6 to 12-month deferral window is required following recent tattoos or piercings to guarantee blood transfusion safety.';
    }
    if (s.contains('alcohol')) {
      return 'Alcohol consumption within 24 hours can cause dehydration and vasovagal reactions during collection. Please hydrate and retest after 24 hours.';
    }
    if (s.contains('maternal') || s.contains('preg')) {
      return 'Deferred under maternal health protocols (pregnancy or lactation) to protect mother and child nutrient reserves.';
    }
    if (s.contains('interval')) {
      return 'Your body requires at least 56 days to replenish red blood cells and iron stores after a whole blood donation.';
    }
    return 'Based on clinical screening protocols, your donation is temporarily deferred to prioritize your safety.';
  }

  String _getClearanceDate(EligibleStats? status, int days) {
    final s = (status ?? '').toString().toLowerCase();
    if (s.contains('weight')) return 'Upon reaching ≥ 50.0 kg';
    if (s.contains('alcohol')) return 'Tomorrow (24-Hour Clearance)';

    final target = DateTime.now().add(Duration(days: days > 0 ? days : 30));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[target.month - 1]} ${target.day}, ${target.year}';
  }

  String _resolveStandardWindow(EligibleStats? status, int days) {
    final s = (status ?? '').toString().toLowerCase();
    if (s.contains('tatts') || s.contains('pierce')) return '6 Months Window';
    if (s.contains('alcohol')) return '24 Hours Window';
    if (s.contains('weight')) return 'Until >= 50.0 kg baseline';
    if (s.contains('maternal')) return '6 Months Postpartum';
    return '$days Days Window';
  }

  String _getRecommendedAction(EligibleStats? status) {
    final s = (status ?? '').toString().toLowerCase();
    if (s.contains('weight')) {
      return 'Focus on a balanced diet rich in proteins and iron to safely reach the 50.0 kg weight requirement.';
    }
    if (s.contains('alcohol')) {
      return 'Refrain from alcohol intake for at least 24 hours and hydrate well before retaking your screening.';
    }
    if (s.contains('tatts') || s.contains('pierce')) {
      return 'Wait for the 6-month healing window to conclude to eliminate infection risk.';
    }
    if (s.contains('interval')) {
      return 'Allow your body sufficient time to replenish iron stores before booking your next appointment.';
    }
    return 'Follow clinical guidance and retake your health assessment once the temporary deferral window passes.';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.classificationResult?.status ?? EligibleStats.deferredWeight;
    final int effectiveDays =
        widget.classificationResult?.daysRemaining ?? widget.daysRemaining;

    final String reasonTitle = _getReasonTitle(status);
    final String reasonDesc = _getReasonDesc(status);
    final String clearanceDateStr = _getClearanceDate(status, effectiveDays);

    return ColoredBox(
      color: const Color(0xFFF3F3F5),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        children: [
          _buildIneligibilityBanner(reasonTitle),
          const SizedBox(height: 14),
          _buildCompactDeferralSummary(context, status, effectiveDays, reasonTitle, reasonDesc, clearanceDateStr),
          const SizedBox(height: 16),
          _buildActionCard(context, status),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCompactDeferralSummary(
      BuildContext context,
      EligibleStats status,
      int effectiveDays,
      String reasonTitle,
      String reasonDesc,
      String clearanceDateStr,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ineligible Home Active',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20)),
          ),
          const SizedBox(height: 10),
          _buildDetailInfoCard('REASON', reasonTitle),
          const SizedBox(height: 10),
          _buildDetailInfoCard('CLEARANCE DATE', clearanceDateStr),
          const SizedBox(height: 10),
          _buildDetailInfoCard('STANDARD WINDOW', _resolveStandardWindow(status, effectiveDays)),
          const SizedBox(height: 12),
          Text(
            reasonDesc,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _showScreeningDetailsModal(context, reasonTitle, reasonDesc, clearanceDateStr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1B20),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View Screening Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
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

  Widget _buildActionCard(BuildContext context, EligibleStats status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1B20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Update Health Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
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
            color: Colors.black.withValues(alpha: 0.02),
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
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20), letterSpacing: 0.6),
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

  void _showScreeningDetailsModal(BuildContext context, String title, String desc, String clearDate) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35)),
              const SizedBox(height: 12),
              Text('Projected Clearance: $clearDate', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
                  child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}