import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resq/services/api_service.dart';

enum _CaptureKind { idFront, idBack, faceFront, faceLeft, faceRight, faceUp, faceDown }

class _CaptureStep {
  final _CaptureKind kind;
  final String title;
  final String instruction;
  final IconData icon;

  const _CaptureStep({required this.kind, required this.title, required this.instruction, required this.icon});
}

/// "Get Verified" flow — a separate step from the Profile screen (not part
/// of registration): scans the donor's valid ID front and back, then
/// guides them through five face captures (front, left, right, up, down).
///
/// Each face capture is run through on-device face detection (ML Kit) to
/// reject an obviously bad take — no face found, or the head isn't turned
/// roughly the way the step asked for — before letting the donor move on.
/// This is a capture-quality check only, not a security/identity check:
/// it can't detect a spoofed photo or confirm the ID actually belongs to
/// this person. Actually verifying identity happens after upload, either
/// by an admin reviewing these on the Web Dashboard or (later) a 3rd-party
/// KYC provider — this screen's job ends at getting good-quality images
/// into that review queue.
class GetVerifiedView extends StatefulWidget {
  final String token;

  const GetVerifiedView({super.key, required this.token});

  @override
  State<GetVerifiedView> createState() => _GetVerifiedViewState();
}

// Philippine government/KYC ID categories a donor can present — mirrors the
// same primary/secondary split banks and other KYC flows in the Philippines
// use, so staff reviewing a submission on the Web Dashboard know exactly
// what kind of document they're looking at instead of guessing from the
// photo alone.
const List<String> kPrimaryIdTypes = [
  "Philippine Identification (PhilID / National ID) or ePhilID",
  "Philippine Passport issued by the Department of Foreign Affairs (DFA)",
  "Land Transportation Office (LTO) Driver's License",
  "Unified Multi-Purpose ID (UMID) from SSS or GSIS",
  "Professional Regulation Commission (PRC) ID",
  "Postal ID (PVC card)",
  "Voter's ID or Voter's Certification from COMELEC",
  "Senior Citizen ID, PWD ID, or Solo Parent ID",
];

const List<String> kSecondaryIdTypes = [
  "Taxpayer Identification Number (TIN) ID",
  "PhilHealth Insurance Card",
  "Pag-IBIG Loyalty Card / Loyalty Card Plus",
  "Company ID or School ID",
  "NBI Clearance or Police Clearance",
  "Barangay Clearance or Barangay ID",
  "PSA Birth Certificate or Marriage Contract",
];

// These document types either have nothing printed on the back (a
// passport's data is all on the photo page) or are effectively single-
// sided documents (a clearance/certificate is one printed page, not a
// two-sided card) — asking for a "back" photo for these would just get a
// blank/irrelevant capture, so the Scan ID — Back step is skipped entirely
// for them (see the _steps getter below).
const Set<String> kNoIdBackTypes = {
  "Philippine Passport issued by the Department of Foreign Affairs (DFA)",
  "NBI Clearance or Police Clearance",
  "Barangay Clearance or Barangay ID",
  "PSA Birth Certificate or Marriage Contract",
};

class _GetVerifiedViewState extends State<GetVerifiedView> {
  // Depends on _selectedIdType (Scan ID — Back is omitted for the document
  // types in kNoIdBackTypes) — a getter rather than a fixed const list, so
  // it always reflects whichever ID was actually chosen on the selection
  // screen. Recomputed on every access, which is fine at 6-7 tiny value
  // objects.
  List<_CaptureStep> get _steps {
    final skipBack = _selectedIdType != null && kNoIdBackTypes.contains(_selectedIdType);
    return [
      const _CaptureStep(
        kind: _CaptureKind.idFront,
        title: 'Scan ID — Front',
        instruction: 'Place the front of your valid government ID inside the frame. Make sure all text is readable.',
        icon: Icons.badge_outlined,
      ),
      if (!skipBack)
        const _CaptureStep(
          kind: _CaptureKind.idBack,
          title: 'Scan ID — Back',
          instruction: 'Now flip it over and capture the back of the same ID.',
          icon: Icons.badge_outlined,
        ),
      const _CaptureStep(
        kind: _CaptureKind.faceFront,
        title: 'Face — Straight Ahead',
        instruction: 'Look directly at the camera with a neutral expression.',
        icon: Icons.face_retouching_natural_rounded,
      ),
      const _CaptureStep(
        kind: _CaptureKind.faceLeft,
        title: 'Face — Turn Left',
        instruction: 'Slowly turn your head to your left, about 45°.',
        icon: Icons.face_retouching_natural_rounded,
      ),
      const _CaptureStep(
        kind: _CaptureKind.faceRight,
        title: 'Face — Turn Right',
        instruction: 'Now turn your head to your right, about 45°.',
        icon: Icons.face_retouching_natural_rounded,
      ),
      const _CaptureStep(
        kind: _CaptureKind.faceUp,
        title: 'Face — Tilt Up',
        instruction: 'Tilt your chin up slightly, keeping your face in frame.',
        icon: Icons.face_retouching_natural_rounded,
      ),
      const _CaptureStep(
        kind: _CaptureKind.faceDown,
        title: 'Face — Tilt Down',
        instruction: 'Tilt your chin down slightly, keeping your face in frame.',
        icon: Icons.face_retouching_natural_rounded,
      ),
    ];
  }

  // Which ID the donor said they'll present, chosen on a selection screen
  // shown before any capture starts. _selectedIdType null means that screen
  // hasn't been confirmed yet — it gates entry into the rest of the flow the
  // same way _isLastStep gates submission below. _pendingIdType is just the
  // radio selection in progress on that screen, kept separate so tapping an
  // option doesn't immediately jump into capturing before the donor taps
  // Continue (these are long labels on a scrollable list — an accidental
  // tap shouldn't fast-forward the whole flow).
  String? _selectedIdType;
  String? _pendingIdType;

  int _currentIndex = 0;
  final Map<_CaptureKind, String> _capturedPaths = {};
  bool _processing = false;
  String? _error;
  bool _submitting = false;

  // Ground truth for the ID Front OCR cross-check below — fetched once on
  // open so it's ready by the time the donor actually gets to that step.
  // Null just means "couldn't fetch" (or a field genuinely isn't on file);
  // every place that reads these treats null as "skip this specific check"
  // rather than blocking the whole flow over an unrelated network hiccup.
  String? _donorName;
  int? _donorAge;

  // Best-effort OCR results from the ID Front capture, carried through to
  // submission as extra context for whoever/whatever reviews it later —
  // not re-validated here, since the blocking checks already ran at
  // capture time (see _capture's idFront branch).
  DateTime? _extractedBirthdate;
  String? _extractedAddress;

  late final FaceDetector _faceDetector;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(enableTracking: false, performanceMode: FaceDetectorMode.accurate),
    );
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _loadDonorProfile();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _loadDonorProfile() async {
    try {
      final profile = await ApiService.getMyProfile(widget.token);
      if (!mounted) return;
      setState(() {
        _donorName = profile['name'] as String?;
        _donorAge = (profile['age'] as num?)?.toInt();
      });
    } catch (_) {
      // Best-effort only — see the field comments above.
    }
  }

  // Requires most (rounded up) of the donor's own name tokens to appear
  // somewhere in the ID's recognized text. Not exact-match: OCR noise and
  // name-order differences (Last/First/Middle vs First Last on different ID
  // layouts) make a strict match too easy to false-positive-reject on a
  // real, correct ID.
  bool _nameLooksConsistent(String ocrText, String donorName) {
    final normalizedOcr = ocrText.toUpperCase().replaceAll(RegExp(r'[^A-Z\s]'), ' ');
    final tokens = donorName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return true; // nothing usable to compare — don't block on it
    final matched = tokens.where(normalizedOcr.contains).length;
    return matched >= (tokens.length / 2).ceil();
  }

  static const List<String> _monthAbbrevs = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  // Best-effort date-of-birth parse across a few common PH-ID date formats.
  // Genuinely heuristic: picks the first date it finds whose year falls in
  // a plausible birth-year range (16-100 years old), not the specific
  // field actually labeled "Date of Birth" — this app has no per-ID-type
  // template to know where that label even is.
  DateTime? _extractBirthdate(String ocrText) {
    final now = DateTime.now();
    bool plausibleBirthYear(int year) => year > now.year - 100 && year <= now.year - 16;

    final monthName = RegExp(
      r'(JAN(?:UARY)?|FEB(?:RUARY)?|MAR(?:CH)?|APR(?:IL)?|MAY|JUN(?:E)?|JUL(?:Y)?|AUG(?:UST)?|SEP(?:TEMBER)?|OCT(?:OBER)?|NOV(?:EMBER)?|DEC(?:EMBER)?)\.?\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    );
    for (final m in monthName.allMatches(ocrText)) {
      final monthIdx = _monthAbbrevs.indexWhere((abbr) => m.group(1)!.toUpperCase().startsWith(abbr));
      final day = int.tryParse(m.group(2)!);
      final year = int.tryParse(m.group(3)!);
      if (monthIdx >= 0 && day != null && year != null && plausibleBirthYear(year)) {
        try {
          return DateTime(year, monthIdx + 1, day);
        } catch (_) {}
      }
    }

    final numeric = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})');
    for (final m in numeric.allMatches(ocrText)) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      final year = int.tryParse(m.group(3)!);
      if (a == null || b == null || year == null || !plausibleBirthYear(year)) continue;
      int? month, day;
      if (a >= 1 && a <= 12) {
        month = a;
        day = b;
      } else if (b >= 1 && b <= 12) {
        month = b;
        day = a;
      }
      if (month == null || day == null) continue;
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }

    final isoLike = RegExp(r'(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})');
    for (final m in isoLike.allMatches(ocrText)) {
      final year = int.tryParse(m.group(1)!);
      final month = int.tryParse(m.group(2)!);
      final day = int.tryParse(m.group(3)!);
      if (year == null || month == null || day == null || !plausibleBirthYear(year)) continue;
      if (month < 1 || month > 12) continue;
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }
    return null;
  }

  // null = couldn't check either value, not a pass/fail. A ±2 year window
  // accommodates the donor's registered age being self-reported once at
  // registration rather than recalculated as time passes, not just OCR
  // error.
  bool? _ageConsistent(DateTime? birthdate, int? registeredAge) {
    if (birthdate == null || registeredAge == null) return null;
    final now = DateTime.now();
    int computedAge = now.year - birthdate.year;
    if (now.month < birthdate.month || (now.month == birthdate.month && now.day < birthdate.day)) {
      computedAge -= 1;
    }
    return (computedAge - registeredAge).abs() <= 2;
  }

  // Purely informational — there's nothing on the donor's record to check
  // an address against (donors aren't asked for one anywhere else in this
  // app), so this is captured for context only, never blocking.
  String? _extractAddress(String ocrText) {
    const keywords = [
      'BRGY', 'BARANGAY', 'STREET', 'ST.', 'AVE', 'AVENUE', 'CITY', 'PROVINCE', 'ROAD', 'RD.', 'PUROK', 'ZONE', 'MUNICIPALITY',
    ];
    for (final rawLine in ocrText.split('\n')) {
      final line = rawLine.trim();
      final upper = line.toUpperCase();
      if (line.length > 8 && keywords.any(upper.contains)) return line;
    }
    return null;
  }

  _CaptureStep get _current => _steps[_currentIndex];
  bool get _isIdStep => _current.kind == _CaptureKind.idFront || _current.kind == _CaptureKind.idBack;
  bool get _isLastStep => _currentIndex == _steps.length - 1;

  Future<void> _capture() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 90);
    if (picked == null) {
      setState(() => _processing = false);
      return;
    }

    if (_current.kind == _CaptureKind.idBack) {
      // Most PH IDs' backs have no photo on them at all (National ID,
      // driver's license, etc.) — nothing to detect a face against, so
      // just accept the capture and move on.
      setState(() {
        _capturedPaths[_current.kind] = picked.path;
        _processing = false;
      });
      _advanceOrFinish();
      return;
    }

    if (_current.kind == _CaptureKind.idFront) {
      // Automated check #1: the front of a valid ID should show a face —
      // catches an obviously wrong capture (a blank surface, a random
      // object, the wrong side of the ID) before it's ever uploaded. This
      // only confirms *a* face is present, not that it's this donor's
      // face — that would need real face-matching against the selfie
      // captures below, which this app doesn't do.
      try {
        final faces = await _faceDetector.processImage(InputImage.fromFilePath(picked.path));
        if (faces.isEmpty) {
          setState(() {
            _error = "We couldn't find a photo on that ID — please make sure the front (with your photo) is in frame and try again.";
            _processing = false;
          });
          return;
        }
      } catch (e) {
        setState(() {
          _error = 'Could not analyze that photo — please try again.';
          _processing = false;
        });
        return;
      }

      // Automated check #2: read the ID's printed text (on-device OCR) and
      // sanity-check it against the donor's own registered profile — still
      // not a database-verified identity check (see class doc comment),
      // just catching an ID that's clearly not this donor's (wrong name
      // entirely, wildly inconsistent birth year) before auto-approval.
      // OCR itself failing outright (blur, glare, an ID format it can't
      // read) doesn't block the donor — only an actual detected mismatch
      // below does; a tech hiccup shouldn't be treated the same as fraud.
      try {
        final recognized = await _textRecognizer.processImage(InputImage.fromFilePath(picked.path));
        final ocrText = recognized.text;
        if (_donorName != null && ocrText.trim().length > 15 && !_nameLooksConsistent(ocrText, _donorName!)) {
          setState(() {
            _error =
                "The name on this ID doesn't seem to match your registered profile ($_donorName). Make sure you're scanning your own ID, or update your profile name in Settings first.";
            _processing = false;
          });
          return;
        }
        final birthdate = _extractBirthdate(ocrText);
        if (_ageConsistent(birthdate, _donorAge) == false) {
          setState(() {
            _error = "The birthdate on this ID doesn't look consistent with your registered age. Please double check, or update your profile first.";
            _processing = false;
          });
          return;
        }
        _extractedBirthdate = birthdate;
        _extractedAddress = _extractAddress(ocrText);
      } catch (_) {
        // See comment above — OCR failing is not itself a rejection.
      }

      setState(() {
        _capturedPaths[_current.kind] = picked.path;
        _processing = false;
      });
      _advanceOrFinish();
      return;
    }

    // Face steps: run on-device detection to catch an obviously bad take
    // before it's uploaded. Thresholds here are a starting point — ML
    // Kit's exact angle sign/scale can vary a little by device/camera, so
    // treat these as needing a quick real-device calibration pass rather
    // than exact clinical figures.
    try {
      final faces = await _faceDetector.processImage(InputImage.fromFilePath(picked.path));
      if (faces.isEmpty) {
        setState(() {
          _error = 'No face detected — please make sure your face is clearly visible and try again.';
          _processing = false;
        });
        return;
      }
      final face = faces.first;
      final yaw = face.headEulerAngleY ?? 0; // left/right turn
      final pitch = face.headEulerAngleX ?? 0; // up/down tilt
      String? mismatch;
      switch (_current.kind) {
        case _CaptureKind.faceFront:
          if (yaw.abs() > 15 || pitch.abs() > 15) mismatch = 'Please face the camera directly.';
          break;
        case _CaptureKind.faceLeft:
          if (yaw < 15) mismatch = 'Please turn your head further to the left.';
          break;
        case _CaptureKind.faceRight:
          if (yaw > -15) mismatch = 'Please turn your head further to the right.';
          break;
        case _CaptureKind.faceUp:
          if (pitch < 10) mismatch = 'Please tilt your chin up a bit more.';
          break;
        case _CaptureKind.faceDown:
          if (pitch > -10) mismatch = 'Please tilt your chin down a bit more.';
          break;
        case _CaptureKind.idFront:
        case _CaptureKind.idBack:
          break;
      }

      if (mismatch != null) {
        setState(() {
          _error = mismatch;
          _processing = false;
        });
        return;
      }

      setState(() {
        _capturedPaths[_current.kind] = picked.path;
        _processing = false;
      });
      _advanceOrFinish();
    } catch (e) {
      setState(() {
        _error = 'Could not analyze that photo — please try again.';
        _processing = false;
      });
    }
  }

  void _advanceOrFinish() {
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _currentIndex++);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ApiService.submitVerification(
        widget.token,
        idType: _selectedIdType!,
        idFrontPath: _capturedPaths[_CaptureKind.idFront]!,
        // Absent (null) for ID types in kNoIdBackTypes — this step never
        // ran for those, so there's nothing captured under this key.
        idBackPath: _capturedPaths[_CaptureKind.idBack],
        extractedBirthdate: _extractedBirthdate?.toIso8601String(),
        extractedAddress: _extractedAddress,
        facePosePaths: {
          'front': _capturedPaths[_CaptureKind.faceFront]!,
          'left': _capturedPaths[_CaptureKind.faceLeft]!,
          'right': _capturedPaths[_CaptureKind.faceRight]!,
          'up': _capturedPaths[_CaptureKind.faceUp]!,
          'down': _capturedPaths[_CaptureKind.faceDown]!,
        },
      );
      if (!mounted) return;
      // Submission is checked automatically and (currently) approved right
      // away rather than queued for a human reviewer — reflect whatever the
      // backend actually reports instead of assuming, in case that changes
      // later without this screen being updated to match.
      final approved = result['verificationStatus'] == 'verified';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                color: const Color(0xFF9B1B20),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                approved ? 'You\'re Verified!' : 'Submitted for Review',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            approved
                ? 'Your ID and photos passed our automated checks — your account is verified.'
                : 'Your ID and photos have been submitted. This usually takes 1-2 business days to review — you\'ll be notified once your account is verified.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B1B20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true); // true = submitted, caller should refresh status
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit for review: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIdType == null) {
      return _buildIdTypeSelection(context);
    }
    return _buildCaptureFlow(context);
  }

  // First screen of the flow: pick which government ID will be presented,
  // grouped the way DFA/bank KYC forms usually do — one Primary ID is
  // normally enough on its own, while a Secondary one is meant to be
  // paired with either a Primary ID or another Secondary ID. Reviewers on
  // the Web Dashboard see whichever label is picked here alongside the
  // scanned photos.
  Widget _buildIdTypeSelection(BuildContext context) {
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
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which ID will you present?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Choose one government-issued ID — you'll scan it (and your face) in the next step.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                children: [
                  _buildIdSectionHeader('PRIMARY ID'),
                  const SizedBox(height: 8),
                  ...kPrimaryIdTypes.map(_buildIdOption),
                  const SizedBox(height: 20),
                  _buildIdSectionHeader('SECONDARY ID'),
                  const SizedBox(height: 4),
                  const Text(
                    'Only if you don\'t have a Primary ID — present two Secondary IDs together.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF), height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  ...kSecondaryIdTypes.map(_buildIdOption),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _pendingIdType == null
                      ? null
                      : () => setState(() => _selectedIdType = _pendingIdType),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B20),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdSectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF9B1B20),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildIdOption(String label) {
    final selected = _pendingIdType == label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _pendingIdType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF9B1B20) : const Color(0xFFE5E7EB), width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: label,
                groupValue: _pendingIdType,
                activeColor: const Color(0xFF9B1B20),
                onChanged: (value) => setState(() => _pendingIdType = value),
              ),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1E1E1E),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureFlow(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B1B20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: (_processing || _submitting)
              ? null
              : () {
                  // Stepping back from the very first capture returns to ID
                  // selection (still part of this same flow) instead of
                  // popping out of Get Verified entirely.
                  if (_currentIndex == 0) {
                    setState(() {
                      _selectedIdType = null;
                      _pendingIdType = null;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
        ),
        title: Text(
          'Get Verified (${_currentIndex + 1}/${_steps.length})',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex) / _steps.length,
                backgroundColor: const Color(0xFFE5E7EB),
                color: const Color(0xFF9B1B20),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: Color(0xFFFDEBEC), shape: BoxShape.circle),
                  child: Icon(_current.icon, size: 44, color: const Color(0xFF9B1B20)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _current.title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _current.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                ),
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_processing || _submitting) ? null : _capture,
                  icon: (_processing || _submitting)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    _submitting
                        ? 'SUBMITTING...'
                        : _processing
                            ? 'CHECKING...'
                            : (_isIdStep ? 'CAPTURE ID' : 'CAPTURE PHOTO'),
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
            ],
          ),
        ),
      ),
    );
  }
}