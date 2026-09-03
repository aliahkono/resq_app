import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class QrPassModalView extends StatelessWidget {
  final String donorName;
  final String bloodType;
  final String donorId;
  final bool isEligible;

  const QrPassModalView({
    super.key,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    required this.isEligible,
  });

  static void show(
      BuildContext context, {
        required String donorName,
        required String bloodType,
        required String donorId,
        required bool isEligible,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrPassModalView(
        donorName: donorName,
        bloodType: bloodType,
        donorId: donorId,
        isEligible: isEligible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Donor QR Pass',
                      overflow: TextOverflow.ellipsis,
                      style: ResQTheme.heading2.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ResQTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Present at Red Cross or Hospital triage',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: ResQTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: ResQTheme.textMuted,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ResQTheme.bgOffWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ResQTheme.lightBorder),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            donorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ResQTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: $donorId',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: ResQTheme.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ResQTheme.primaryCrimson,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bloodType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 28),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ResQTheme.lightBorder),
                  ),
                  child: Column(
                    children: [
                      // Encodes the donor's real donor_code (e.g. "D-4321") —
                      // the same value Donor Management's search bar already
                      // matches on server-side (donor_code ILIKE, see
                      // donors.controller.js), so any generic QR scanner (or
                      // a triage staffer just reading it off-screen) can look
                      // this donor up immediately without a dedicated
                      // in-app scanner having to exist yet.
                      Opacity(
                        opacity: isEligible ? 1 : 0.5,
                        child: donorId.trim().isEmpty
                            ? const SizedBox(
                                width: 190,
                                height: 190,
                                child: Center(
                                  child: Icon(Icons.qr_code_2_rounded, size: 96, color: ResQTheme.textMuted),
                                ),
                              )
                            : QrImageView(
                                data: donorId,
                                version: QrVersions.auto,
                                size: 190,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E1E1E)),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SCAN FOR PRIORITY TRIAGE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: ResQTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isEligible
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEligible
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFFFCC80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEligible
                            ? Icons.verified_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: isEligible
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEligible ? 'VERIFIED ACTIVE PASS' : 'RECOVERY RESTRICTION ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isEligible
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ResQTheme.primaryCrimson,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'DONE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}