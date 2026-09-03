import 'package:flutter/material.dart';
import 'package:resq/model/donor_profile_model.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/user_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/otp_ver_view.dart';

class RegistrationSummaryView extends StatelessWidget {
  final UserModel userModel;
  final DonorProfModel profileModel;
  final ScreenNPTModel screeningModel;
  final ClassificationResult classificationResult;
  final String rawPassword;
  final bool isFirstTimeDonor;

  const RegistrationSummaryView({
    super.key,
    required this.userModel,
    required this.profileModel,
    required this.screeningModel,
    required this.classificationResult,
    required this.rawPassword,
    required this.isFirstTimeDonor,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screens = screeningModel.screensNPT;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7D1B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Review Registration Summary',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fact_check_outlined, color: Color(0xFF1D4ED8), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please verify your personal and clinical details before submitting. An SMS OTP will be dispatched to your registered phone number.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 1: ACCOUNT CREDENTIALS
              _buildSectionHeader('Account & Contact Information'),
              const SizedBox(height: 8),
              _buildSummaryCard([
                _buildDataRow('Full Name', userModel.fullName),
                const Divider(height: 1),
                _buildDataRow('Email Address', userModel.email),
                const Divider(height: 1),
                _buildDataRow('Mobile Number', userModel.phoneNum),
                const Divider(height: 1),
                _buildDataRow('Password', '•••••••• (Securely Hashed)'),
              ]),

              const SizedBox(height: 18),

              // SECTION 2: PHYSICAL & CLINICAL METRICS
              _buildSectionHeader('Physical & Vital Metrics'),
              const SizedBox(height: 8),
              _buildSummaryCard([
                _buildDataRow('Blood Type', profileModel.bloodType),
                const Divider(height: 1),
                _buildDataRow('Biological Sex', screens.gender == BioSex.male ? 'Male' : 'Female'),
                const Divider(height: 1),
                _buildDataRow('Recorded Age', '${screens.age} yrs'),
                const Divider(height: 1),
                _buildDataRow('Weight', '${screens.weight.toStringAsFixed(1)} kg'),
              ]),

              const SizedBox(height: 18),

              // SECTION 3: DONATION & MEDICAL HISTORY
              _buildSectionHeader('Donation & Procedure History'),
              const SizedBox(height: 8),
              _buildSummaryCard([
                _buildDataRow('Donor Category', isFirstTimeDonor ? 'First-Time Donor' : 'Repeat Donor'),
                const Divider(height: 1),
                _buildDataRow('Last Donation Date', isFirstTimeDonor ? 'None (First Time)' : _formatDate(screens.lastDonationDate)),
                const Divider(height: 1),
                _buildDataRow('Total Lifetime Donations', isFirstTimeDonor ? '0' : '${screens.totalDonations}'),
                const Divider(height: 1),
                _buildDataRow('Tattoos / Piercings (< 12 mos)', screens.hasTattsOrPierce ? 'Yes (Deferred window)' : 'No'),
              ]),

              const SizedBox(height: 18),

              // SECTION 4: SEX-SPECIFIC & HEALTH SCREENING DISCLOSURES
              _buildSectionHeader('Health & Screening Disclosures'),
              const SizedBox(height: 8),
              _buildSummaryCard([
                if (screens.gender == BioSex.female) ...[
                  _buildDataRow('Last Menstrual Period', _formatDate(screens.lastMensPeriodDate)),
                  const Divider(height: 1),
                  _buildDataRow('Pregnant / Nursing Status', screens.isPregOrNursing == true ? 'Yes' : 'No / Clear'),
                  const Divider(height: 1),
                ],
                if (screens.gender == BioSex.male) ...[
                  _buildDataRow('High Risk Exposure (12 mos)', screens.hasHighRiskExpo == true ? 'Reported' : 'None'),
                  const Divider(height: 1),
                ],
                _buildDataRow('Alcohol Intake (Past 24h)', screens.hasAlcoholPast24hr ? 'Yes' : 'None'),
                const Divider(height: 1),
                _buildDataRow('Active Infection / Meds', screens.hasActiveInfectOrMeds ? 'Reported' : 'Clear'),
              ]),

              const SizedBox(height: 18),

              // SECTION 5: INITIAL VERIFICATION STATUS BADGE
              _buildSectionHeader('Preliminary Evaluation'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: classificationResult.isEligible ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: classificationResult.isEligible ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      classificationResult.isEligible ? Icons.check_circle_rounded : Icons.info_rounded,
                      color: classificationResult.isEligible ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classificationResult.isEligible ? 'Verified Eligible to Donate' : 'Temporary Deferral Pending',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: classificationResult.isEligible ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            classificationResult.isEligible
                                ? 'All baseline clinical parameters have been satisfied.'
                                : 'Status: ${classificationResult.status.name}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SUBMIT & EDIT BUTTONS
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => OtpVerView(
                          donorName: userModel.fullName,
                          email: userModel.email,
                          phoneNumber: userModel.phoneNum,
                          bloodType: profileModel.bloodType,
                          donorId: profileModel.profId,
                          password: rawPassword,
                          screeningModel: screeningModel,
                          classificationResult: classificationResult,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D1B22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'PROCEED TO OTP VERIFICATION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7D1B22), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: const Color(0xFF7D1B22),
                  ),
                  child: const Text(
                    'EDIT INFORMATION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B7280),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
            ),
          ),
        ],
      ),
    );
  }
}