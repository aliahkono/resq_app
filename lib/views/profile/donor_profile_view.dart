import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/profile/qr_pass_modal_view.dart';
import 'package:resq/views/settings/settings_view.dart';

class DonorProfileView extends StatelessWidget {
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onProfileUpdated;

  const DonorProfileView({
    super.key,
    this.screeningModel,
    this.classificationResult,
    required this.isFirstTimeDonor,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEligible = classificationResult?.isEligible ?? true;
    final status = classificationResult?.status ?? EligibleStats.eligible;
    final int daysRemaining = classificationResult?.daysRemaining ?? 45;

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Donor Profile',
                style: ResQTheme.heading1.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personal information & donation records',
                style: TextStyle(fontSize: 12.5, color: ResQTheme.textMuted),
              ),
              const SizedBox(height: 20),

              // 1. Digital Donor Card (With Overflow Protection)
              _buildDonorCard(context, isEligible, isFirstTimeDonor),

              const SizedBox(height: 20),

              // 2. Status & Metric Section (Figma branches)
              if (isEligible && !isFirstTimeDonor)
                _buildActiveEligibleStats()
              else if (isEligible && isFirstTimeDonor)
                _buildFirstTimeEligiblePrompt()
              else if (!isEligible && !isFirstTimeDonor)
                  _buildActiveIneligibleRecovery(daysRemaining)
                else
                  _buildFirstTimeIneligibleDeferral(status),

              const SizedBox(height: 24),

              // 3. Clinical & Bio Parameters Row
              _buildClinicalSummary(),

              const SizedBox(height: 24),

              // 4. Settings & Account Actions
              _buildProfileActionsList(context, isEligible),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonorCard(BuildContext context, bool isEligible, bool isFirstTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: ResQTheme.primaryCrimson.withValues(alpha: 0.1),
            child: Text(
              donorName.isNotEmpty ? donorName[0].toUpperCase() : 'D',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ResQTheme.primaryCrimson,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donorName.isNotEmpty ? donorName : 'Volunteer Donor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ResQTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFirstTime ? 'First-Time Volunteer Donor' : 'Active Regular Donor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: ResQTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isEligible
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEligible
                            ? Icons.verified_user_rounded
                            : Icons.schedule_rounded,
                        size: 13,
                        color: isEligible
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isEligible ? 'Verified Eligible' : 'Temporarily Deferred',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isEligible
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              QrPassModalView.show(
                context,
                donorName: donorName,
                bloodType: bloodType,
                donorId: donorId,
                isEligible: isEligible,
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ResQTheme.primaryCrimson,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BLOOD',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    bloodType.isNotEmpty ? bloodType : 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveEligibleStats() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile('Donations', '4', 'Lifetime completed', Icons.water_drop_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile('Lives Saved', '12', 'Est. 3 lives/unit', Icons.favorite_rounded),
        ),
      ],
    );
  }

  Widget _buildFirstTimeEligiblePrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFF2E7D32), size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'First Donation Milestone Awaiting!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1B5E20)),
                ),
                SizedBox(height: 2),
                Text(
                  'You meet all health parameters. Book your first session to receive your donor badge.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF388E3C), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveIneligibleRecovery(int daysRemaining) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFE65100), size: 18),
                  SizedBox(width: 6),
                  Text('90-Day Recovery Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100))),
                ],
              ),
              Text('$daysRemaining days left', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFE65100))),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ((90 - daysRemaining) / 90.0).clamp(0.0, 1.0),
            backgroundColor: ResQTheme.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE65100)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeIneligibleDeferral(EligibleStats status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  EligibilityRules.getStatsTitle(status),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status == EligibleStats.deferredWeight
                ? 'Your weight is currently below the 50 kg baseline. Follow the nutrition guidance on the home dashboard to qualify.'
                : 'Initial health screening indicators require a temporary observation period before your first booking.',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFF57C00), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String sub, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ResQTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ResQTheme.primaryCrimson, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ResQTheme.textDark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          Text(sub, style: TextStyle(fontSize: 10.5, color: ResQTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildClinicalSummary() {
    final double weight = screeningModel?.screensNPT.weight ?? 0.0;
    final int age = screeningModel?.screensNPT.age ?? 0;
    final String sex = (screeningModel?.screensNPT.gender == BioSex.female) ? 'Female' : 'Male';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ResQTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Profile Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildClinicalItem('Biological Sex', sex),
              _buildClinicalItem('Age', age > 0 ? '$age yrs' : 'N/A'),
              _buildClinicalItem('Weight', weight > 0 ? '$weight kg' : 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: ResQTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      ],
    );
  }

  Widget _buildProfileActionsList(BuildContext context, bool isEligible) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ResQTheme.lightBorder),
      ),
      child: Column(
        children: [
          _buildActionTile(
            Icons.qr_code_2_rounded,
            'View Digital Donor QR Pass',
                () {
              QrPassModalView.show(
                context,
                donorName: donorName,
                bloodType: bloodType,
                donorId: donorId,
                isEligible: isEligible,
              );
            },
          ),
          const Divider(height: 1),
          _buildActionTile(
            Icons.history_rounded,
            'Donation History & Certificates',
                () {},
          ),
          const Divider(height: 1),
          _buildActionTile(
            Icons.refresh_rounded,
            'Retake Health Assessment',
                () {
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
          ),
          const Divider(height: 1),
          _buildActionTile(
            Icons.settings_outlined,
            'Account Settings & Preferences',
                () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsView(
                    screeningModel: screeningModel,
                    donorName: donorName,
                    bloodType: bloodType,
                    donorId: donorId,
                    onRetakeCompleted: onProfileUpdated,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: ResQTheme.textDark, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}