import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/clinical_rec_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/profile/qr_pass_modal_view.dart';
import 'package:resq/views/settings/settings_view.dart';

class DonorProfileView extends StatelessWidget {
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final ClinicalVitalsRecord? clinicalVitals;
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onProfileUpdated;

  const DonorProfileView({
    super.key,
    this.screeningModel,
    this.classificationResult,
    this.clinicalVitals,
    required this.isFirstTimeDonor,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    this.onProfileUpdated,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get _vitalsSubtitle {
    if (clinicalVitals == null) {
      return 'No vitals logged yet by clinic';
    }
    return '${clinicalVitals!.hemoglobin.toStringAsFixed(1)} g/dL (${clinicalVitals!.hemoglobinStatus}) • ${_formatDate(clinicalVitals!.recordedDate)}';
  }

  // --- Deferral Resolution Helpers for Next Eligible Card ---
  _EligibilityInfo _resolveEligibilityInfo(bool isEligible) {
    if (isEligible) {
      return const _EligibilityInfo(
        mainText: 'TODAY',
        subText: 'Eligible',
        dotColor: Color(0xFF2E7D32),
        bgColor: Color(0xFFEFFBF3),
        borderColor: Color(0xFFC8E6C9),
        headerColor: Color(0xFF2E7D32),
        reasonDescription: 'You meet all physiological parameters and are ready to donate.',
      );
    }

    final status = classificationResult?.status;
    final int days = classificationResult?.daysRemaining ?? 0;
    final isFemale = screeningModel?.screensNPT.gender == BioSex.female;
    final double weight = screeningModel?.screensNPT.weight ?? 0.0;

    // 1. Weight Deferral (< 50 kg baseline)
    if (status == EligibleStats.deferredWeight || (weight > 0 && weight < 50.0)) {
      return _EligibilityInfo(
        mainText: '${weight > 0 ? weight.toStringAsFixed(0) : '< 50'} kg',
        subText: 'Weight Baseline',
        dotColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        headerColor: const Color(0xFFD97706),
        reasonDescription: 'Weight is below the 50 kg baseline. Retake screening once you reach 50 kg.',
      );
    }

    // 2. Tattoo / Piercing Window Deferral
    if (status == EligibleStats.deferredTattsPierce || status.toString().toLowerCase().contains('tattoo')) {
      final int remDays = days > 0 ? days : 180;
      return _EligibilityInfo(
        mainText: 'In $remDays Days',
        subText: 'Tattoo/Piercing',
        dotColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFFEDD5),
        headerColor: const Color(0xFFEA580C),
        reasonDescription: 'Standard 12-month deferral window for recent tattoos or piercings.',
      );
    }

    // 3. Biological Sex-Specific Screening (Female: Pregnancy / Lactation / Maternal)
    if (isFemale && (status == EligibleStats.deferredMaternal ||
        status.toString().toLowerCase().contains('pregnant') ||
        status.toString().toLowerCase().contains('female') ||
        status.toString().toLowerCase().contains('maternal'))) {
      final int remDays = days > 0 ? days : 180;
      return _EligibilityInfo(
        mainText: days > 0 ? 'In $remDays Days' : 'Postpartum',
        subText: 'Female Screening',
        dotColor: const Color(0xFFBE185D),
        bgColor: const Color(0xFFFDF2F8),
        borderColor: const Color(0xFFFCE7F3),
        headerColor: const Color(0xFFBE185D),
        reasonDescription: 'Deferred under maternal health protocols (pregnancy, lactation, or postpartum recovery).',
      );
    }

    // 4. Post-Donation Interval Deferral
    if (days > 0) {
      return _EligibilityInfo(
        mainText: 'In $days Days',
        subText: 'Recovering',
        dotColor: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF8E1),
        borderColor: const Color(0xFFFFE082),
        headerColor: const Color(0xFFE65100),
        reasonDescription: 'Standard whole blood donation recovery window in progress.',
      );
    }

    // 5. Default General Medical / Travel Deferral
    return const _EligibilityInfo(
      mainText: 'Deferred',
      subText: 'Medical Review',
      dotColor: Color(0xFFDC2626),
      bgColor: Color(0xFFFEF2F2),
      borderColor: Color(0xFFFEE2E2),
      headerColor: Color(0xFFDC2626),
      reasonDescription: 'Health screening indicator requires a temporary deferral period.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEligible = classificationResult?.isEligible ?? true;
    final String displayName = donorName.isNotEmpty ? donorName : 'John Doe';
    final String displayId = donorId.isNotEmpty ? donorId : '#BD-10942';
    final String displayBlood = bloodType.isNotEmpty ? bloodType : 'A+';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                child: Column(
                  children: [
                    _buildMainProfileCard(context, displayName, displayId, displayBlood, isEligible),
                    const SizedBox(height: 14),
                    _buildDonationScheduleRow(context, isEligible),
                    const SizedBox(height: 14),
                    _buildLifetimeImpactCard(context),
                    const SizedBox(height: 14),
                    _buildClinicalRecordsSection(context, isEligible),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Navigation Header ---
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 16, left: 18, right: 18),
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
                'Profile & Records',
                style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsView(
                    // --- FIXED HERE: Passed required dynamic data & placeholders ---
                    userName: donorName, // Use the existing donorName
                    userPhone: '09xxxxxxxxx', // TODO: Implement persistent storage retrieval here
                    userEmail: 'donor@example.com', // TODO: Implement persistent storage retrieval here
                    // --- Removed old parameters that caused errors ---
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Main Hero Profile Card ---
  Widget _buildMainProfileCard(
      BuildContext context,
      String name,
      String id,
      String bType,
      bool isEligible,
      ) {
    final int donations = (isFirstTimeDonor) ? 0 : (screeningModel?.screensNPT.totalDonations ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7D1B22), width: 2.2),
                ),
                child: const CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFFF3E5E6),
                  backgroundImage: AssetImage('assets/images/donor_sample.jpg'),
                  child: Icon(Icons.person_rounded, size: 44, color: Color(0xFF7D1B22)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF7D1B22),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEligible ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isEligible ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isEligible ? 'ELIGIBLE TO DONATE' : 'TEMPORARILY DEFERRED',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: isEligible ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEFE8E8)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Donor ID', style: TextStyle(fontSize: 12.5, color: Color(0xFF7A7A7A))),
                    const SizedBox(height: 3),
                    Text(
                      id.startsWith('#') ? id : '#$id',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFEFE8E8)),
              Expanded(
                child: Column(
                  children: [
                    const Text('Blood Type', style: TextStyle(fontSize: 12.5, color: Color(0xFF7A7A7A))),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$bType ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7D1B22),
                            ),
                          ),
                          TextSpan(
                            text: bType.endsWith('-') ? '(Negative)' : '(Positive)',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4A4A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEFE8E8)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology_outlined, color: Color(0xFF6B7280), size: 20),
              const SizedBox(width: 8),
              Text(
                isFirstTimeDonor || donations == 0
                    ? 'First-Time Hero (0 Donations Completed)'
                    : 'Lifesaving Hero ($donations Donation${donations == 1 ? '' : 's'} Completed)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                QrPassModalView.show(
                  context,
                  donorName: name,
                  bloodType: bType,
                  donorId: id,
                  isEligible: isEligible,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A1E26),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text(
                'Show Digital Donor QR Pass',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dynamic Next Eligible & Last Donation Row ---
  Widget _buildDonationScheduleRow(BuildContext context, bool isEligible) {
    final info = _resolveEligibilityInfo(isEligible);
    final lastDonation = screeningModel?.screensNPT.lastDonationDate ?? clinicalVitals?.recordedDate;

    return Row(
      children: [
        // Last Donation Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAST DONATION',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22), letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  lastDonation != null ? _formatDate(lastDonation).split(',')[0] : 'N/A',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF202020)),
                ),
                Text(
                  lastDonation != null ? lastDonation.year.toString() : 'No record',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A7A7A)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Context-Aware Next Eligible Card
        Expanded(
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(info.reasonDescription),
                  backgroundColor: isEligible ? const Color(0xFF2E7D32) : const Color(0xFF7D1B22),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: info.bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: info.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT ELIGIBLE',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: info.headerColor, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.mainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF202020)),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: info.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          info.subText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: info.dotColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Dynamic Lifetime Impact Card (Without Badges) ---
  Widget _buildLifetimeImpactCard(BuildContext context) {
    final int donations = (isFirstTimeDonor) ? 0 : (screeningModel?.screensNPT.totalDonations ?? 0);
    final double liters = donations * 0.45;
    final int lives = donations * 3;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 14, right: 14, bottom: 8),
            child: Row(
              children: const [
                Icon(Icons.favorite_border_rounded, color: Color(0xFF7D1B22), size: 18),
                SizedBox(width: 8),
                Text(
                  'Lifetime Impact Record',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF2C2C2C)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF7D1B22)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        liters > 0 ? liters.toStringAsFixed(1) : '0.0',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22)),
                      ),
                      const SizedBox(height: 2),
                      const Text('LITERS DONATED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: const Color(0xFFE5E7EB)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        lives.toString(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 2),
                      const Text('LIVES IMPACTED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Clinical & Donation Records Section ---
  Widget _buildClinicalRecordsSection(BuildContext context, bool isEligible) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Clinical & Donation Records',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF7D1B22)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF7D1B22)),
          _buildRecordTile(
            icon: Icons.local_hospital_outlined,
            title: 'Vitals & Hemoglobin History',
            subtitle: _vitalsSubtitle,
            onTap: () => _showVitalsModal(context),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          _buildRecordTile(
            icon: Icons.public_outlined,
            title: 'Travel & Medical Screening',
            subtitle: 'View past disclosures & deferral logs',
            onTap: () => _showScreeningHistoryModal(context),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          _buildRecordTile(
            icon: Icons.description_outlined,
            title: 'Donation Receipts & Certs',
            subtitle: 'Download verified records',
            isDownload: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading verified official donation certificate (PDF)...'),
                  backgroundColor: Color(0xFF2E7D32),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDownload = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFFDE8E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF7D1B22), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
      trailing: Icon(
        isDownload ? Icons.download_rounded : Icons.arrow_forward_ios_rounded,
        size: isDownload ? 18 : 14,
        color: isDownload ? const Color(0xFF7D1B22) : const Color(0xFF9CA3AF),
      ),
    );
  }

  // --- Modals for Clinical Records ---
  void _showVitalsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vitals & Hemoglobin History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (clinicalVitals != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Hospital Verified',
                      style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (clinicalVitals != null) ...[
              _buildModalRow(
                'Hemoglobin',
                '${clinicalVitals!.hemoglobin.toStringAsFixed(1)} g/dL (${clinicalVitals!.hemoglobinStatus} Range: 12.5 - 17.5)',
              ),
              _buildModalRow('Blood Pressure', '${clinicalVitals!.bloodPressure} mmHg'),
              _buildModalRow('Pulse Rate', '${clinicalVitals!.pulseRate} bpm'),
              _buildModalRow('Body Temperature', '${clinicalVitals!.bodyTemp.toStringAsFixed(1)} °C'),
              _buildModalRow('Evaluated By', clinicalVitals!.medTechName),
              _buildModalRow('Clinical Facility', clinicalVitals!.facility),
              _buildModalRow('Recorded Date', _formatDate(clinicalVitals!.recordedDate)),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'No vitals recorded by clinical staff yet.\nYour vitals will appear here after your first screening at the facility.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ),
            ],
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

  void _showScreeningHistoryModal(BuildContext context) {
    final double weight = screeningModel?.screensNPT.weight ?? 0.0;
    final int age = screeningModel?.screensNPT.age ?? 0;
    final String sex = (screeningModel?.screensNPT.gender == BioSex.female) ? 'Female' : 'Male';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medical & Screening Disclosures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildModalRow('Biological Sex', sex),
            _buildModalRow('Recorded Age', age > 0 ? '$age yrs' : 'N/A'),
            _buildModalRow('Recorded Weight', weight > 0 ? '$weight kg' : 'N/A'),
            _buildModalRow('Recent Travel Risk', 'Disclosed • None in 30 days'),
            _buildModalRow('Medication Disclosures', 'Disclosed • Clear'),
            _buildModalRow('Assessment Status', 'Evaluated via Real-time Logic'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RegistrationWizView(
                            isRetake: true,
                            initialScreening: screeningModel,
                            donorName: donorName,
                            bloodType: bloodType,
                            donorId: donorId,
                            onRetakeCompleted: onProfileUpdated,
                          ),
                        ),
                      );
                    },
                    child: const Text('RETAKE SCREENING', style: TextStyle(color: Color(0xFF7D1B22), fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                    child: const Text('CLOSE', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2C2C2C))),
        ],
      ),
    );
  }
}

// --- Eligibility Helper Value Object ---
class _EligibilityInfo {
  final String mainText;
  final String subText;
  final Color dotColor;
  final Color bgColor;
  final Color borderColor;
  final Color headerColor;
  final String reasonDescription;

  const _EligibilityInfo({
    required this.mainText,
    required this.subText,
    required this.dotColor,
    required this.bgColor,
    required this.borderColor,
    required this.headerColor,
    required this.reasonDescription,
  });
}