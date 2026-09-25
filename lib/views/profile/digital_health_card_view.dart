import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/widgets/donor_id_card.dart';

/// Digital Health Card — opened from the "Digitalized Health Card" tile on
/// the Profile screen. Shows the donor's ID card (flip between Front and
/// Back), their donation stamps toward the next tier, and the priority
/// blood access level that tier unlocks.
///
/// Figma: ResQKineme › DHC-Screen (1625:1069, front) and DHC2-Screen
/// (1646:1109, back).
///
/// Everything the Profile screen already knows is passed in; the extra
/// card-only fields (donor code, birth date, issue date, emergency
/// contact, donation history) are fetched here from GET /api/donor/me and
/// GET /api/donor/appointments. Fields the backend doesn't return yet show
/// "—" rather than made-up values.
class DigitalHealthCardView extends StatefulWidget {
  final String token;
  final String donorName;
  final String bloodType;
  final String donorId;
  final int completedDonations;
  final String? photoUrl;
  final DateTime? lastDonationAt;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;

  const DigitalHealthCardView({
    super.key,
    required this.token,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    required this.completedDonations,
    this.photoUrl,
    this.lastDonationAt,
    this.screeningModel,
    this.classificationResult,
  });

  @override
  State<DigitalHealthCardView> createState() => _DigitalHealthCardViewState();
}

// Screen tokens from the Figma frames.
const _headerMaroon = Color(0xFF8B1526);
const _screenBg = Color(0xFFEBEBEB);
const _crimson = Color(0xFFB11921);
const _heading = Color(0xFF251F20);
const _body = Color(0xFF766D6C);
const _pinkTint = Color(0xFFF8E5E5);
const _stampBorder = Color(0xFFE6E1E1);
const _priorityBlue = Color(0xFF2450A4);
const _activeGreen = Color(0xFF2D9B4B);

/// Donation tiers — also decide the priority blood access level.
class _Tier {
  final String name;
  final String range;
  final int level;
  final int minDonations;

  const _Tier(this.name, this.range, this.level, this.minDonations);
}

const _tiers = [
  _Tier('Life Starter', '1–4 · Level 1', 1, 1),
  _Tier('Lifesaving Hero', '5–9 · Level 2', 2, 5),
  _Tier('Guardian of Life', '10+ · Level 3', 3, 10),
];

class _DigitalHealthCardViewState extends State<DigitalHealthCardView> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  final _frontKey = GlobalKey();
  final _backKey = GlobalKey();

  bool _showBack = false;
  bool _sharing = false;
  TickerFuture? _flipDone;

  // Extra fields from GET /api/donor/me + /api/donor/appointments.
  Map<String, dynamic> _profile = const {};
  List<Map<String, dynamic>> _appointments = const [];

  @override
  void initState() {
    super.initState();
    _loadCardDetails();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  Future<void> _loadCardDetails() async {
    if (widget.token.isEmpty) return;
    // Both are background enrichment — the card still renders from what
    // the Profile screen passed in if either request fails.
    try {
      final profile = await ApiService.getMyProfile(widget.token);
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('DigitalHealthCardView: getMyProfile failed: $e');
    }
    try {
      final list = await ApiService.listMyAppointments(widget.token);
      if (mounted) {
        setState(() => _appointments = list.whereType<Map<String, dynamic>>().toList());
      }
    } catch (e) {
      debugPrint('DigitalHealthCardView: listMyAppointments failed: $e');
    }
  }

  void _setSide(bool back) {
    if (back == _showBack) return;
    setState(() => _showBack = back);
    _flipDone = back ? _flip.forward() : _flip.reverse();
  }

  // ---------------------------------------------------------------------
  // Data shaping
  // ---------------------------------------------------------------------

  String? _str(List<String> keys) {
    for (final k in keys) {
      final v = _profile[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  DateTime? _date(List<String> keys) {
    final s = _str(keys);
    return s == null ? null : DateTime.tryParse(s)?.toLocal();
  }

  String get _donorCode {
    final code = _str(['donorCode']);
    if (code != null) return code;
    final id = widget.donorId.replaceFirst('#', '');
    return id.isNotEmpty ? id : '—';
  }

  /// Splits "Juan Miguel Dela Cruz" into surname "Dela Cruz" and given
  /// names "Juan Miguel", keeping common Filipino/Spanish surname
  /// particles (dela, de los, san, sta., …) with the surname. A name
  /// written "Dela Cruz, Juan Miguel" is split on the comma instead.
  (String, String) _splitName(String full) {
    final name = full.trim().isEmpty ? 'Donor' : full.trim();
    if (name.contains(',')) {
      final parts = name.split(',');
      return (parts.first.trim(), parts.sublist(1).join(' ').trim());
    }
    final words = name.split(RegExp(r'\s+'));
    if (words.length == 1) return (words.first, '');
    const particles = {'de', 'del', 'dela', 'della', 'delos', 'los', 'las', 'la', 'san', 'sta', 'sta.', 'santa', 'santo', 'sto', 'sto.', 'van', 'von', 'da', 'di', 'mac', 'mc'};
    var start = words.length - 1;
    while (start > 1 && particles.contains(words[start - 1].toLowerCase())) {
      start--;
    }
    return (words.sublist(start).join(' '), words.sublist(0, start).join(' '));
  }

  String get _sex {
    final gender = widget.screeningModel?.screensNPT.gender;
    if (gender != null) return gender == BioSex.female ? 'F' : 'M';
    final g = _str(['gender'])?.toLowerCase();
    if (g == 'female') return 'F';
    if (g == 'male') return 'M';
    return '—';
  }

  List<Map<String, dynamic>> get _completedAppointments {
    final done = _appointments.where((a) => a['status'] == 'completed').toList();
    done.sort((a, b) => _apptDate(b).compareTo(_apptDate(a)));
    return done;
  }

  DateTime _apptDate(Map<String, dynamic> a) =>
      DateTime.tryParse((a['scheduledAt'] as String?) ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? get _lastDonation =>
      widget.lastDonationAt ??
      (_completedAppointments.isNotEmpty ? _apptDate(_completedAppointments.first) : null) ??
      widget.screeningModel?.screensNPT.lastDonationDate;

  DateTime get _nextEligible {
    final days = widget.classificationResult?.daysRemaining ?? 0;
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day).add(Duration(days: days > 0 ? days : 0));
  }

  DonorCardData _buildCardData() {
    final (surname, given) = _splitName(widget.donorName);
    final completed = _completedAppointments;

    // "Registered at" = where the donor most recently donated, else the
    // facility of their latest booking, else a generic partner label.
    final facilitySource = completed.isNotEmpty ? completed.first : (_appointments.isNotEmpty ? _appointments.first : null);
    final facility = (facilitySource?['hospitalName'] as String?)?.trim();
    final address = (facilitySource?['hospitalAddress'] as String?)?.trim();

    final contactName = _str(['emergencyContactName', 'emergency_contact_name']);
    final contactPhone = _str(['emergencyContactPhone', 'emergency_contact_phone']);
    final contact = [contactName, contactPhone].whereType<String>().join(' · ');

    final total = widget.completedDonations;
    final records = <DonationRecordEntry>[];
    for (var i = 0; i < completed.length && i < 3; i++) {
      final n = total - i;
      records.add(DonationRecordEntry(
        date: _apptDate(completed[i]),
        place: (completed[i]['hospitalName'] as String?) ?? 'ResQ Partner Facility',
        code: 'DON-${(n > 0 ? n : completed.length - i).toString().padLeft(2, '0')}',
      ));
    }

    return DonorCardData(
      surname: surname,
      givenNames: given.isEmpty ? '—' : given,
      bloodType: widget.bloodType.isNotEmpty ? widget.bloodType : '—',
      sex: _sex,
      birthDate: _date(['birthdate', 'birthDate', 'dateOfBirth', 'dob']),
      completedDonations: total,
      donorCode: _donorCode,
      issuedAt: _date(['createdAt', 'registeredAt', 'created_at']),
      photoUrl: widget.photoUrl ?? _str(['photoUrl']),
      registeredFacility: (facility != null && facility.isNotEmpty) ? facility : 'ResQ Partner Blood Bank',
      registeredAddress: (address != null && address.isNotEmpty) ? address : 'Any ResQ partner blood bank',
      emergencyContact: contact.isNotEmpty ? contact : 'Not provided',
      recentDonations: records,
      lastDonationAt: _lastDonation,
      nextEligibleAt: _nextEligible,
    );
  }

  // ---------------------------------------------------------------------
  // Download (share the visible side as a PNG)
  // ---------------------------------------------------------------------

  Future<void> _downloadCard(Rect? shareOrigin) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Only the side facing the user is in the tree, and it swaps halfway
      // through the flip — so finish any flip in progress before capturing.
      if (_flip.isAnimating && _flipDone != null) {
        try {
          await _flipDone!.orCancel;
        } on TickerCanceled {
          // Flipped again mid-animation; the latest flip is awaited below.
        }
        if (_flip.isAnimating && _flipDone != null) {
          try {
            await _flipDone!.orCancel;
          } on TickerCanceled {
            // Fall through and capture whichever side is showing.
          }
        }
      }
      final key = _showBack ? _backKey : _frontKey;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Card not ready');
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode card');
      final side = _showBack ? 'back' : 'front';
      final fileName = 'resq_health_card_$side.png';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes.buffer.asUint8List(), mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'ResQ Digital Health Card',
        // Required on iPad, where the share sheet is a popover anchored to
        // the button that opened it.
        sharePositionOrigin: shareOrigin,
      ));
    } catch (e) {
      debugPrint('DigitalHealthCardView: download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the card. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _buildCardData();
    final qrData = 'https://resq-admin.me/donor-management?checkin=${Uri.encodeQueryComponent(data.donorCode)}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _screenBg,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _FrontBackToggle(showBack: _showBack, onChanged: _setSide),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label: _showBack ? 'Donor card, back side' : 'Donor card, front side',
                    hint: 'Flips the card',
                    child: GestureDetector(
                      onTap: () => _setSide(!_showBack),
                      child: _buildFlipCard(data, qrData),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      'Tap the card to flip it',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF8B8B8B)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DonationStampsCard(donations: widget.completedDonations),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _PriorityAccessCard(donations: widget.completedDonations),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _headerMaroon,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text('Profile', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400)),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Digital Health Card',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
                  ),
                ),
              ),
            ),
            // Figma places a ~26px tray-download glyph 26px from the right edge.
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Download card',
                  onPressed: _sharing
                      ? null
                      : () {
                          final box = buttonContext.findRenderObject() as RenderBox?;
                          final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
                          _downloadCard(origin);
                        },
                  icon: _sharing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.save_alt_rounded, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlipCard(DonorCardData data, String qrData) {
    final front = RepaintBoundary(key: _frontKey, child: DonorIdCardFront(data: data));
    final back = RepaintBoundary(key: _backKey, child: DonorIdCardBack(data: data, qrData: qrData));

    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_flip.value);
        final angle = t * math.pi;
        final showingBack = angle > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Front / Back segmented toggle (Figma component "Front-Back Btn")
// ---------------------------------------------------------------------------

class _FrontBackToggle extends StatelessWidget {
  final bool showBack;
  final ValueChanged<bool> onChanged;

  const _FrontBackToggle({required this.showBack, required this.onChanged});

  // Figma (345 × 51 track): 170 × 42 pill, 7px in from the left for Front
  // and 6px in from the right for Back. Scaled to the actual track width.
  static const _designWidth = 345.0;
  static const _pillWidth = 170.0;
  static const _pillHeight = 42.0;
  static const _frontInset = 7.0;
  static const _backInset = 6.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 51,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final k = w / _designWidth;
          final pillW = _pillWidth * k;
          final frontLeft = _frontInset * k;
          final backLeft = w - _backInset * k - pillW;
          const top = (51 - _pillHeight) / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: showBack ? backLeft : frontLeft,
                top: top,
                width: pillW,
                height: _pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x54FF383C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Positioned(
                left: frontLeft,
                top: 0,
                bottom: 0,
                width: pillW,
                child: _segment('Front', selected: !showBack, onTap: () => onChanged(false)),
              ),
              Positioned(
                left: backLeft,
                top: 0,
                bottom: 0,
                width: pillW,
                child: _segment('Back', selected: showBack, onTap: () => onChanged(true)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(String label, {required bool selected, required VoidCallback onTap}) {
    return SizedBox.expand(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.poppins(
                fontSize: 16,
                height: 1.75,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? const Color(0xFFB80035) : Colors.black,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Donation Stamps card
// ---------------------------------------------------------------------------

class _DonationStampsCard extends StatelessWidget {
  final int donations;

  const _DonationStampsCard({required this.donations});

  _Tier? get _currentTier {
    _Tier? current;
    for (final t in _tiers) {
      if (donations >= t.minDonations) current = t;
    }
    return current;
  }

  _Tier? get _nextTier {
    for (final t in _tiers) {
      if (donations < t.minDonations) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentTier;
    final next = _nextTier;
    final target = next?.minDonations ?? donations;
    final slotCount = math.max(target, donations);
    final progress = target == 0 ? 0.0 : (donations / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: _crimson, size: 22),
              const SizedBox(width: 10),
              Text(
                'Donation Stamps',
                style: GoogleFonts.poppins(fontSize: 21, fontWeight: FontWeight.w600, color: _heading),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$donations',
                      style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w600, color: _crimson, height: 1.0),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        donations == 1 ? 'blood donation' : 'blood donations',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w500, color: _body),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _pinkTint, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  (current?.name ?? 'First-Time Hero').toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: _crimson, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (slotCount > 0) ...[
            Wrap(
              spacing: 26,
              runSpacing: 10,
              children: [
                for (var i = 1; i <= slotCount; i++)
                  i <= donations
                      ? const _FilledStamp()
                      : _EmptyStamp(number: i, isGoal: i == target && next != null),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Container(
            height: 6,
            decoration: BoxDecoration(color: _pinkTint, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: next == null ? 1.0 : progress,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(color: _crimson, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            _progressMessage(next),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: _body, height: 20 / 14),
          ),
        ],
      ),
    );
  }

  TextSpan _progressMessage(_Tier? next) {
    final bold = GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _heading);
    if (next == null) {
      return TextSpan(children: [
        const TextSpan(text: 'You\'ve reached '),
        TextSpan(text: 'Guardian of Life', style: bold),
        const TextSpan(text: ' — the highest Priority Level. Thank you!'),
      ]);
    }
    final remaining = next.minDonations - donations;
    return TextSpan(children: [
      TextSpan(text: '$remaining more donation${remaining == 1 ? '' : 's'}', style: bold),
      TextSpan(text: ' to reach ${next.name} and Priority Level ${next.level}.'),
    ]);
  }
}

class _FilledStamp extends StatelessWidget {
  const _FilledStamp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(color: _crimson, shape: BoxShape.circle),
      child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
    );
  }
}

class _EmptyStamp extends StatelessWidget {
  final int number;
  final bool isGoal;

  const _EmptyStamp({required this.number, required this.isGoal});

  @override
  Widget build(BuildContext context) {
    final color = isGoal ? _crimson : _stampBorder;
    return CustomPaint(
      painter: _DashedCirclePainter(color: color, strokeWidth: 1.5),
      child: SizedBox(
        width: 50,
        height: 50,
        child: Center(
          child: Text(
            '$number',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: isGoal ? _crimson : _body),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    const dashes = 24;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Priority Blood Access card
// ---------------------------------------------------------------------------

class _PriorityAccessCard extends StatelessWidget {
  final int donations;

  const _PriorityAccessCard({required this.donations});

  @override
  Widget build(BuildContext context) {
    int level = 0;
    for (final t in _tiers) {
      if (donations >= t.minDonations) level = t.level;
    }
    final active = level > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EEF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shield_rounded, color: _priorityBlue, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Priority Blood Access · Level $level' : 'Priority Blood Access',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _priorityBlue, height: 24 / 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active
                          ? 'If you need blood, your request is moved ahead in the queue at ResQ partner blood banks. Show this card or your Donor ID when you ask for blood.'
                          : 'Complete your first donation to unlock priority access at ResQ partner blood banks when you or your family need blood.',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: _body, height: 20 / 14),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFE7F5E9) : const Color(0xFFF1EFEF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? _activeGreen : _body,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            active ? 'PRIORITY ACTIVE' : 'NOT YET ACTIVE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? _activeGreen : _body,
                              letterSpacing: 0.7,
                            ),
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
          // Tiles are 79px tall in Figma; IntrinsicHeight keeps all three the
          // same height if a large system font makes one of them taller.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _tiers.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _tierTile(_tiers[i], _tiers[i].level == level)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierTile(_Tier tier, bool current) {
    return Container(
      constraints: const BoxConstraints(minHeight: 79),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: current ? const Color(0xFFFFF0F1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: current ? _crimson : _stampBorder, width: current ? 1.5 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tier.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: current ? _crimson : _heading,
              height: 16 / 13,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tier.range,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400, color: _body, height: 16 / 13),
            ),
          ),
        ],
      ),
    );
  }
}
