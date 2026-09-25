import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/clinical_rec_model.dart';
import 'package:resq/model/ver_stats_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/helpers/med_keyword_rules.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/profile/digital_health_card_view.dart';
import 'package:resq/views/profile/get_ver_view.dart';
import 'package:resq/views/profile/qr_pass_modal_view.dart';
import 'package:resq/widgets/editable_avatar.dart';
import 'package:resq/widgets/resq_ui.dart';

class DonorProfileView extends StatelessWidget {
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final ClinicalVitalsRecord? clinicalVitals;
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onProfileUpdated;
  final String token;
  // Hospital-verified count (GET /api/donor/me's completedDonations) — not
  // the donor's self-reported totalDonations from registration/retake
  // screening, which never changes just because a real donation happened.
  // Starts at 0 for a first-time donor and only grows when a hospital
  // admin actually marks an appointment completed.
  final int completedDonations;
  final String? photoUrl;
  final ValueChanged<String>? onPhotoUpdated;
  final VerificationStatus verificationStatus;
  final DateTime? lastDonationAt;

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
    this.token = '',
    this.completedDonations = 0,
    this.photoUrl,
    this.onPhotoUpdated,
    this.verificationStatus = VerificationStatus.notStarted,
    this.lastDonationAt,
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
      backgroundColor: const Color(0xFFF3F3F5),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        child: Column(
          children: [
            _buildMainProfileCard(
                context, displayName, displayId, displayBlood, isEligible),
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
    // Hospital-verified count, same source as the Lifetime Impact card below
    // — not isFirstTimeDonor/screensNPT.totalDonations, which are just the
    // donor's own self-report from registration/retake screening and never
    // change just because a real donation got recorded at a hospital.
    final int donations = completedDonations;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              EditableAvatar(
                photoUrl: photoUrl,
                radius: 38,
                token: token,
                onUploaded: (url) => onPhotoUpdated?.call(url),
              ),
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF9B1B20),
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
          _buildVerificationBadge(context),
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
                              color: Color(0xFF9B1B20),
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
                donations == 0
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
              // The QR needs the donor's donor_code ("D-1234") — the thing
              // Donor Management's own search actually matches on — not the
              // raw internal id shown as `id` here. GET /api/donor/me is the
              // only place this app has fetched donorCode from so far, so
              // it's fetched fresh right before showing the pass rather
              // than threading a new field through login/Home/here.
              onPressed: () async {
                String qrValue = id;
                try {
                  final profile = await ApiService.getMyProfile(token);
                  final code = profile['donorCode'] as String?;
                  if (code != null && code.isNotEmpty) qrValue = code;
                } catch (_) {
                  // Falls back to `id` below — still shows a pass, just one
                  // that won't resolve via the scan-to-lookup link if the
                  // fetch failed.
                }
                if (!context.mounted) return;
                QrPassModalView.show(
                  context,
                  donorName: name,
                  bloodType: bType,
                  donorId: qrValue,
                  isEligible: isEligible,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1B20),
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
    // Hospital-verified date (GET /api/donor/me's lastDonationAt, set when
    // an admin actually records a completed donation) takes priority over
    // the donor's self-reported lastDonationDate from registration/retake
    // screening — that self-report never updates from a real donation
    // event, which is exactly why this used to go stale/inaccurate right
    // after a donation was recorded.
    final lastDonation = lastDonationAt ?? screeningModel?.screensNPT.lastDonationDate ?? clinicalVitals?.recordedDate;

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
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20), letterSpacing: 0.5),
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
                  backgroundColor: isEligible ? const Color(0xFF2E7D32) : const Color(0xFF9B1B20),
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
    final int donations = completedDonations;
    final double liters = donations * 0.45;
    final int lives = donations * 3;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, left: 14, right: 14, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.favorite_border_rounded, color: Color(0xFF9B1B20), size: 18),
                SizedBox(width: 8),
                Text(
                  'Lifetime Impact Record',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF2C2C2C)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF9B1B20)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        liters > 0 ? liters.toStringAsFixed(1) : '0.0',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20)),
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
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Clinical & Donation Records',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF9B1B20)),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF9B1B20)),
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
            icon: Icons.badge_outlined,
            title: 'Digitalized Health Card',
            subtitle: 'View your donor records',
            onTap: () => _openHealthCard(context),
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
        child: Icon(icon, color: const Color(0xFF9B1B20), size: 20),
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
        color: isDownload ? const Color(0xFF9B1B20) : const Color(0xFF9CA3AF),
      ),
    );
  }

  // --- Modals for Clinical Records ---
  void _showVitalsModal(BuildContext context) {
    final v = clinicalVitals;
    showResQSheet(
      context: context,
      builder: (ctx) => ResQSheet(
        icon: Icons.monitor_heart_outlined,
        title: 'Vitals & Hemoglobin',
        subtitle: v != null ? 'Recorded ${_formatDate(v.recordedDate)}' : 'No screenings recorded yet',
        footer: RQButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        child: v == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: const [
                    RQIconBox(icon: Icons.monitor_heart_outlined, size: 64),
                    SizedBox(height: 14),
                    Text('No vitals yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.ink)),
                    SizedBox(height: 4),
                    Text(
                      'Your hemoglobin, blood pressure, pulse and temperature will show here after your first screening at the facility.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: RQColors.muted),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHemoglobinSummary(v),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _vitalTile('BLOOD PRESSURE', v.bloodPressure, 'mmHg')),
                      const SizedBox(width: 10),
                      Expanded(child: _vitalTile('PULSE', '${v.pulseRate}', 'bpm')),
                      const SizedBox(width: 10),
                      Expanded(child: _vitalTile('TEMP', v.bodyTemp.toStringAsFixed(1), '°C')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Screening record',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.bloodText)),
                      ),
                      const RQPill(label: 'Hospital verified', background: RQColors.successTint, color: RQColors.success),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RQColors.hairline),
                    ),
                    child: Column(
                      children: [
                        _sheetRow('Date', _formatDate(v.recordedDate)),
                        _sheetRow('Facility', v.facility),
                        _sheetRow('Evaluated by', v.medTechName, last: true),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Latest hemoglobin with a range bar showing where it sits against the
  /// 12.5–17.5 g/dL donor range.
  Widget _buildHemoglobinSummary(ClinicalVitalsRecord v) {
    const double minG = 10, maxG = 20, lowG = 12.5, highG = 17.5;
    final bool normal = v.hemoglobinStatus == 'Normal';
    final String statusLabel = v.hemoglobinStatus == 'Low'
        ? 'Below 12.5 minimum'
        : v.hemoglobinStatus == 'High'
            ? 'Above 17.5 maximum'
            : 'Within donor range';
    final double pos = ((v.hemoglobin - minG) / (maxG - minG)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RQSectionLabel('Latest hemoglobin'),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: v.hemoglobin.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: normal ? RQColors.ink : RQColors.warning,
                            ),
                          ),
                          const TextSpan(
                            text: ' g/dL',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RQColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RQPill(
                  label: statusLabel,
                  background: normal ? RQColors.successTint : RQColors.warningTint,
                  color: normal ? RQColors.success : RQColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final lowX = w * (lowG - minG) / (maxG - minG);
              final highX = w * (highG - minG) / (maxG - minG);
              return SizedBox(
                height: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 7,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(color: RQColors.hairline, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    Positioned(
                      left: lowX,
                      width: highX - lowX,
                      top: 7,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(color: const Color(0xFFBFE3C3), borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    Positioned(
                      left: (w * pos - 11).clamp(0.0, w - 22),
                      top: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: normal ? RQColors.blood : RQColors.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Text('10', style: TextStyle(fontSize: 11, color: RQColors.muted)),
              Spacer(),
              Text('Donor range 12.5 – 17.5', style: TextStyle(fontSize: 11, color: RQColors.success)),
              Spacer(),
              Text('20', style: TextStyle(fontSize: 11, color: RQColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalTile(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RQColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: RQColors.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: RQColors.ink)),
          ),
          Text(unit, style: const TextStyle(fontSize: 11, color: RQColors.muted)),
        ],
      ),
    );
  }

  Widget _sheetRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: RQColors.hairline)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: RQColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RQColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  void _showScreeningHistoryModal(BuildContext context) {
    final s = screeningModel?.screensNPT;
    final bool hasTravelFlag = s?.hasTravelOrNeedleStick ?? false;
    final bool hasMedicalFlag = s?.hasMajorMedicalHistory ?? false;
    final String? travelDesc = s?.travelOrNeedleDesc;
    final String? medicalDesc = s?.majorMedicalHistoryDesc;
    final travelAssessment = MedicalKeywordRules.assessTravelOrNeedleStick(travelDesc);
    final medicalAssessment = MedicalKeywordRules.assessMajorMedicalHistory(medicalDesc);

    final bool travelDeferred = hasTravelFlag && travelAssessment.verdict == KeywordVerdict.deferred;
    final bool medicalDeferred = hasMedicalFlag && medicalAssessment.verdict == KeywordVerdict.deferred;
    final bool surgery = s?.hasTransfusionOrSurgery ?? false;
    final bool tattoo = s?.hasTattsOrPierce ?? false;
    final bool recentMeds = s?.recentMedProcedures.isNotEmpty ?? false;
    final bool alcohol = s?.hasAlcoholPast24hr ?? false;
    final int flagged = [travelDeferred, medicalDeferred, surgery, tattoo, recentMeds, alcohol].where((f) => f).length;

    showResQSheet(
      context: context,
      builder: (ctx) => ResQSheet(
        icon: Icons.fact_check_outlined,
        title: 'Travel & Medical Screening',
        subtitle: screeningModel != null ? 'Answered ${_formatDate(screeningModel!.submissionDate)}' : 'No screening on file',
        bodyColor: RQColors.surface,
        bodyPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        footer: Row(
          children: [
            Expanded(
              child: RQButton.secondary(
                label: 'Retake screening',
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RegistrationWizView(
                        isRetake: true,
                        initialScreening: screeningModel,
                        donorName: donorName,
                        bloodType: bloodType,
                        donorId: donorId,
                        token: token,
                        onRetakeCompleted: onProfileUpdated,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: RQButton(label: 'Done', onPressed: () => Navigator.pop(ctx))),
          ],
        ),
        child: s == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Complete your health screening to see your answers here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: RQColors.muted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _screeningBanner(flagged),
                  const SizedBox(height: 14),
                  _screeningCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Basics',
                    children: [
                      _answerRow('Sex', valueText: s.gender == BioSex.female ? 'Female' : 'Male'),
                      _answerRow('Age', valueText: s.age > 0 ? '${s.age} yrs' : 'N/A'),
                      _answerRow('Weight',
                          valueText: s.weight > 0 ? '${s.weight.toStringAsFixed(1)} kg' : 'N/A',
                          valueColor: s.weight > 0 && s.weight < 50 ? RQColors.warning : RQColors.ink,
                          last: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _screeningCard(
                    icon: Icons.public_rounded,
                    title: 'Travel · last 12 months',
                    children: [
                      _answerRow(
                        'Traveled abroad or had a needle-stick?',
                        yes: hasTravelFlag,
                        flagged: travelDeferred,
                        last: true,
                        detail: hasTravelFlag ? _buildReasonBlock(travelDesc, travelAssessment) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _screeningCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Medical history',
                    children: [
                      _answerRow(
                        'Heart disease, asthma, diabetes or other major condition?',
                        yes: hasMedicalFlag,
                        flagged: medicalDeferred,
                        detail: hasMedicalFlag ? _buildReasonBlock(medicalDesc, medicalAssessment) : null,
                      ),
                      _answerRow(
                        'Medication or minor procedure in the last 4 weeks?',
                        yes: recentMeds,
                        flagged: recentMeds,
                        detail: recentMeds ? _chipList(s.recentMedProcedures) : null,
                      ),
                      _answerRow('Transfusion or surgery in the last 12 months?', yes: surgery, flagged: surgery),
                      _answerRow('Tattoo or piercing?', yes: tattoo, flagged: tattoo),
                      _answerRow('Alcohol in the last 24 hours?', yes: alcohol, flagged: alcohol, last: true),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _screeningBanner(int flagged) {
    final bool ok = flagged == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? RQColors.successTint : RQColors.caution,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ok ? const Color(0xFFBFE3C3) : RQColors.cautionBorder),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.verified_outlined : Icons.warning_amber_rounded,
              color: ok ? RQColors.success : RQColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'No answers flagged' : '$flagged ${flagged == 1 ? 'answer needs' : 'answers need'} attention',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RQColors.ink),
                ),
                Text(
                  ok ? 'Nothing here is stopping you from donating.' : 'These can defer you for a while. Staff may check them before you donate.',
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _screeningCard({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: RQColors.bloodText),
                const SizedBox(width: 8),
                RQSectionLabel(title, color: RQColors.bloodText),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: RQColors.hairline),
          ...children,
        ],
      ),
    );
  }

  /// One question → answer row. Pass [valueText] for a plain value, or
  /// [yes] for a Yes/No chip ([flagged] colours a "Yes" orange).
  Widget _answerRow(
    String question, {
    String? valueText,
    Color valueColor = RQColors.ink,
    bool yes = false,
    bool flagged = false,
    bool last = false,
    Widget? detail,
  }) {
    Widget trailing;
    if (valueText != null) {
      trailing = Text(valueText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor));
    } else {
      final bool warn = yes && flagged;
      trailing = Container(
        constraints: const BoxConstraints(minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: warn ? RQColors.warningTint : RQColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          yes ? 'Yes' : 'No',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warn ? RQColors.warning : const Color(0xFF555555)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: RQColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(question, style: const TextStyle(fontSize: 14, height: 1.4, color: RQColors.ink)),
              ),
              const SizedBox(width: 16),
              trailing,
            ],
          ),
          if (detail != null) ...[const SizedBox(height: 8), detail],
        ],
      ),
    );
  }

  Widget _chipList(Iterable<String> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Text(e, style: const TextStyle(fontSize: 12, color: RQColors.body)),
              ))
          .toList(),
    );
  }

  /// "Digitalized Health Card" tile — opens the full Digital Health Card
  /// screen (ID card front/back, donation stamps, priority access).
  void _openHealthCard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DigitalHealthCardView(
          token: token,
          donorName: donorName,
          bloodType: bloodType,
          donorId: donorId,
          completedDonations: completedDonations,
          photoUrl: photoUrl,
          lastDonationAt: lastDonationAt,
          screeningModel: screeningModel,
          classificationResult: classificationResult,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (verificationStatus) {
      case VerificationStatus.verified:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.verified_rounded;
        break;
      case VerificationStatus.pending:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_top_rounded;
        break;
      case VerificationStatus.inReview:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.visibility_outlined;
        break;
      case VerificationStatus.rejected:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.error_outline_rounded;
        break;
      case VerificationStatus.notStarted:
        bg = const Color(0xFFF3F3F5);
        fg = const Color(0xFF6B7280);
        icon = Icons.shield_outlined;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 5),
              Text(
                verificationStatus.label.toUpperCase(),
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: fg),
              ),
            ],
          ),
        ),
        if (verificationStatus != VerificationStatus.verified &&
            verificationStatus != VerificationStatus.pending &&
            verificationStatus != VerificationStatus.inReview) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => GetVerifiedView(token: token)),
            ),
            child: const Text(
              'Get Verified',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20), decoration: TextDecoration.underline),
            ),
          ),
        ],
      ],
    );
  }

  /// "Reason" block shown under Recent Travel Risk / Medication
  /// Disclosures in the screening history modal — the free-text
  /// description the donor gave, with the specific words that drove the
  /// eligible/deferred call highlighted (see medical_keyword_rules.dart),
  /// so a donor or admin can see *why* without needing to look anything up.
  Widget _buildReasonBlock(String? description, MedicalAssessment assessment) {
    final bool hasDesc = description != null && description.trim().isNotEmpty;
    final bool isDeferred = assessment.verdict == KeywordVerdict.deferred;
    final Color accent = isDeferred ? const Color(0xFFB91C1C) : const Color(0xFF15803D);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 10.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDeferred ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REASON',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: accent),
            ),
            const SizedBox(height: 4),
            if (hasDesc)
              RichText(text: TextSpan(children: _buildHighlightedSpans(description, assessment)))
            else
              Text(
                assessment.note ?? 'No additional details provided.',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563)),
              ),
            if (hasDesc && assessment.note != null) ...[
              const SizedBox(height: 4),
              Text(
                assessment.note!,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Turns a free-text reason into spans with each matched keyword
  /// bolded/colored — red for a word that drove a deferral, green for one
  /// that supported eligibility (e.g. "controlled" for a diabetes note).
  List<InlineSpan> _buildHighlightedSpans(String description, MedicalAssessment assessment) {
    const baseStyle = TextStyle(fontSize: 11.5, color: Color(0xFF1E1E1E), height: 1.35);
    if (assessment.matches.isEmpty) {
      return [TextSpan(text: description, style: baseStyle)];
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in assessment.matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: description.substring(cursor, m.start), style: baseStyle));
      }
      final color = m.verdict == KeywordVerdict.deferred ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
      spans.add(TextSpan(
        text: description.substring(m.start, m.end),
        style: baseStyle.copyWith(color: color, fontWeight: FontWeight.bold, backgroundColor: color.withValues(alpha: 0.12)),
      ));
      cursor = m.end;
    }
    if (cursor < description.length) {
      spans.add(TextSpan(text: description.substring(cursor), style: baseStyle));
    }
    return spans;
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