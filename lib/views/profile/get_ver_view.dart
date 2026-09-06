import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/model/ver_stats_model.dart';

/// "Get Verified" — hands identity verification off to Didit (third-party
/// KYC: real ID authenticity checks, liveness, and face match), replacing
/// the on-device-only capture flow this screen used to run itself (still
/// in git history, and the backend route it posted to still exists — see
/// submitVerification's doc comment in donorPortal.controller.js — just no
/// longer called from here).
///
/// This screen never touches the donor's ID or face photos: it asks the
/// backend to open a Didit session (startDiditVerification), launches the
/// URL Didit returns in the device's own browser, and — since there's no
/// deep link back into the app — relies on the donor returning here
/// manually and tapping "I'm done — check my status" so the app can ask
/// the backend what Didit actually decided. The real decision always
/// arrives at the backend via Didit's webhook, independent of whether the
/// donor ever taps that button; it's just how this screen gets an update
/// without polling in the background.
class GetVerifiedView extends StatefulWidget {
  final String token;

  const GetVerifiedView({super.key, required this.token});

  @override
  State<GetVerifiedView> createState() => _GetVerifiedViewState();
}

class _GetVerifiedViewState extends State<GetVerifiedView> {
  bool _launching = false;
  bool _checking = false;
  bool _launched = false;
  String? _error;
  VerificationStatus? _status;

  Future<void> _startVerification() async {
    setState(() {
      _launching = true;
      _error = null;
    });
    try {
      final result = await ApiService.startDiditVerification(widget.token);
      final url = result['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ApiException(0, 'Verification could not be started. Please try again.');
      }
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _launching = false;
          _error = 'Could not open the verification page. Please try again.';
        });
        return;
      }
      setState(() {
        _launching = false;
        _launched = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final profile = await ApiService.getMyProfile(widget.token);
      final status = verificationStatusFromString(profile['verificationStatus'] as String?);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _status = status;
      });
      if (status == VerificationStatus.verified || status == VerificationStatus.rejected) {
        if (!mounted) return;
        Navigator.pop(context, true); // true = status changed, caller should refresh
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B1B20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Get Verified',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: Color(0xFFFDEBEC), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, size: 44, color: Color(0xFF9B1B20)),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Verify your identity',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You'll be taken to our verification partner, Didit, to scan a valid "
                "government ID and take a quick selfie. It only takes a couple of "
                "minutes, and your result is sent back to ResQ automatically once "
                "you finish.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: Color(0xFFE65100), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status!.label,
                          style: const TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _launching ? null : _startVerification,
                  icon: _launching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    _launched ? 'REOPEN VERIFICATION' : 'START VERIFICATION',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                ),
              ),
              if (_launched) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _checking ? null : _checkStatus,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF9B1B20)),
                          )
                        : const Icon(Icons.refresh_rounded, color: Color(0xFF9B1B20)),
                    label: const Text(
                      "I'M DONE — CHECK MY STATUS",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3, color: Color(0xFF9B1B20)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF9B1B20)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
