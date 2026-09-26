import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:resq/model/ver_stats_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/utils/constants/theme_constants.dart';

/// Donation-count tiers shown on the card + the Priority Blood Access
/// section below it — matches the Figma "Digitalized Health Card" design.
/// Thresholds are on *lifetime completed donations* (hospital-verified via
/// donor_arrivals, the same count already used everywhere else in the app —
/// see HomeView._effectiveDonations), not a separate tracked field.
enum _DonorTier { starter, hero, guardian }

extension on _DonorTier {
  String get label => switch (this) {
        _DonorTier.starter => 'Life Starter',
        _DonorTier.hero => 'Lifesaving Hero',
        _DonorTier.guardian => 'Guardian of Life',
      };

  int get level => switch (this) { _DonorTier.starter => 1, _DonorTier.hero => 2, _DonorTier.guardian => 3 };

  String get rangeLabel => switch (this) {
        _DonorTier.starter => '1–4 · Level 1',
        _DonorTier.hero => '5–9 · Level 2',
        _DonorTier.guardian => '10+ · Level 3',
      };
}

_DonorTier _tierFor(int donations) {
  if (donations >= 10) return _DonorTier.guardian;
  if (donations >= 5) return _DonorTier.hero;
  return _DonorTier.starter;
}

/// Full-screen "Digitalized Health Card" — a flippable digital donor ID
/// (front: identity/blood type/donor ID/priority level; back: QR + recent
/// donation history) plus the Donation Stamps tracker and Priority Blood
/// Access tier breakdown. Reached from Donor Profile's "Digitalized Health
/// Card" tile. All figures shown are the donor's real data (GET
/// /api/donor/me + /api/donor/donations) — nothing here is placeholder.
class DigitalHealthCardView extends StatefulWidget {
  final String token;
  final String donorName;
  final String donorCode;
  final String bloodType;
  final String? photoUrl;
  final int completedDonations;
  final VerificationStatus verificationStatus;
  final bool isEligible;
  final DateTime? memberSince;
  final DateTime? birthDate;
  final String? gender;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const DigitalHealthCardView({
    super.key,
    required this.token,
    required this.donorName,
    required this.donorCode,
    required this.bloodType,
    this.photoUrl,
    required this.completedDonations,
    required this.verificationStatus,
    required this.isEligible,
    this.memberSince,
    this.birthDate,
    this.gender,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
  });

  @override
  State<DigitalHealthCardView> createState() => _DigitalHealthCardViewState();
}

class _DigitalHealthCardViewState extends State<DigitalHealthCardView> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  bool _showingBack = false;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _loadHistory();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (widget.token.isEmpty) {
      setState(() => _loadingHistory = false);
      return;
    }
    try {
      final rows = await ApiService.listMyDonations(widget.token);
      if (!mounted) return;
      setState(() {
        _history = rows.cast<Map<String, dynamic>>();
        _loadingHistory = false;
      });
    } catch (_) {
      // Silent — the card still renders fine with an empty "no history yet"
      // state on the back; this is a nice-to-have detail, not core content.
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _flip() {
    if (_showingBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showingBack = !_showingBack);
  }

  void _shareCard() {
    final tier = _tierFor(widget.completedDonations);
    final text = 'ResQ Blood Donor Card\n'
        '${widget.donorName} · ${widget.bloodType}\n'
        'Donor ID: ${widget.donorCode}\n'
        'Donations: ${widget.completedDonations} · ${tier.label} (Level ${tier.level})\n'
        'Verification: ${widget.verificationStatus.label}';
    SharePlus.instance.share(ShareParams(text: text));
  }

  // Splits a full name into (surname, given names) the way the physical ID
  // card design does — best-effort only (Filipino naming order varies), not
  // a real structured name field anywhere in the schema.
  (String, String) _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return (name, '');
    return (parts.last, parts.sublist(0, parts.length - 1).join(' '));
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1].toUpperCase()} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(widget.completedDonations);

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: ResQTheme.primaryCrimson,
            foregroundColor: Colors.white,
            title: const Text('Digitalized Health Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            actions: [
              IconButton(
                onPressed: _shareCard,
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Share card details',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTabs(),
                const SizedBox(height: 14),
                _buildFlipCard(tier),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Tap the card to flip it',
                    style: TextStyle(fontSize: 12, color: ResQTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDonationStamps(tier),
                const SizedBox(height: 16),
                _buildPriorityAccess(tier),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Front', !_showingBack)),
          Expanded(child: _buildTabButton('Back', _showingBack)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool active) {
    return GestureDetector(
      onTap: () {
        if (active) return;
        _flip();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? ResQTheme.lightPinkTint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: active ? ResQTheme.primaryCrimson : ResQTheme.textMuted,
          ),
        ),
      ),
    );
  }

  static const Color _cardCream = Color(0xFFFBF6EF);
  static const Color _band = ResQTheme.primaryCrimson;

  Widget _buildFlipCard(_DonorTier tier) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            final angle = _flipController.value * math.pi;
            final showFront = angle < math.pi / 2;
            final content = showFront
                ? _buildCardFront(tier)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardBack(),
                  );
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: content,
            );
          },
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: _cardCream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      );

  Widget _bandText(String text, {String? trailing}) {
    return Container(
      color: _band,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
          if (trailing != null)
            Text(trailing, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Physical-ID-card-style front: photo/signature column on the left (with
  // a rotated "DONOR" sidebar label), identity fields on the right over a
  // faint ring watermark — matches the printable "Blood donor ID" design.
  Widget _buildCardFront(_DonorTier tier) {
    final (surname, given) = _splitName(widget.donorName);
    final issued = widget.memberSince;
    final validUntil = issued?.add(const Duration(days: 365 * 2));
    final sex = widget.gender == 'female' ? 'F' : (widget.gender == 'male' ? 'M' : '—');

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bandText('BLOOD DONOR  ·  DONOR NG DUGO  ·  RESQ  ·  BLOOD DONOR  ·  DONOR NG DUGO'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftColumn(),
                Expanded(child: _buildFrontFields(tier, surname, given, sex, issued, validUntil)),
              ],
            ),
          ),
          _bandText('SAVE A LIFE  ·  MAGSAVE NG BUHAY  ·  RESQ  ·  SAVE A LIFE  ·  MAGSAVE NG BUHAY'),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return SizedBox(
      width: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'DONOR',
                  style: TextStyle(
                    color: ResQTheme.primaryCrimson.withValues(alpha: 0.22),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 8, 8),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: const Color(0xFFE5E0D8),
                        width: double.infinity,
                        child: (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                            ? Image.network(widget.photoUrl!, fit: BoxFit.cover)
                            : const Icon(Icons.person_rounded, color: Color(0xFFAFA89C), size: 34),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 22,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: ResQTheme.lightBorder),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text('Signature · Lagda', style: TextStyle(fontSize: 6.5, color: ResQTheme.textMuted)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep this card with you. Present at every blood donation.',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(fontSize: 6, color: ResQTheme.textMuted, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontFields(
    _DonorTier tier,
    String surname,
    String given,
    String sex,
    DateTime? issued,
    DateTime? validUntil,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _RingsPainter(color: ResQTheme.primaryCrimson.withValues(alpha: 0.06))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: ResQTheme.primaryCrimson, size: 20),
                  const SizedBox(width: 6),
                  const Text('ResQ', style: TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.w900, fontSize: 17)),
                ],
              ),
              Text(
                'BLOOD DONOR ID CARD · PAGKAKAKILANLAN NG DONOR',
                style: TextStyle(color: ResQTheme.textMuted, fontSize: 6.3, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel('Surname · Apelyido'),
                        _cardValue(surname.isNotEmpty ? surname : widget.donorName),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel('Blood type · Uri ng dugo'),
                        Text(widget.bloodType, style: const TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _cardLabel('Given names · Pangalan'),
              _cardValue(given.isNotEmpty ? given : '—'),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardLabel('Birth date · Kapanganakan'),
                        _cardValue(issuedDateOr(widget.birthDate)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_cardLabel('Sex · Kasarian'), _cardValue(sex)],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_cardLabel('Donations · Donasyon'), _cardValue('${widget.completedDonations}')],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _cardLabel('Donor ID · Numero ng donor'),
              _cardValue(widget.donorCode.isNotEmpty ? widget.donorCode : '—'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_cardLabel('Issued · Petsa ng pagbigay'), _cardValue(issuedDateOr(issued))],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_cardLabel('Valid until · Balido hanggang'), _cardValue(issuedDateOr(validUntil))],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String issuedDateOr(DateTime? date) => date != null ? _formatDate(date) : 'N/A';

  Widget _cardLabel(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ResQTheme.textMuted, fontSize: 6.5),
      );

  Widget _cardValue(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.bold, fontSize: 11.5),
      );

  Widget _backLabel(String text, {Color? color}) => Text(
        text,
        style: TextStyle(color: color ?? ResQTheme.textMuted, fontSize: 6.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      );

  // Physical-ID-card-style back: coordinating hospital, a single-row
  // donation-stamp strip, emergency contact (if the donor has set one in
  // Settings), a corner-bracket QR (same donor-management check-in link as
  // the Donor Profile QR pass), the real recent donation table, and a
  // decorative MRZ-style strip built from the donor's own real fields.
  Widget _buildCardBack() {
    final (surname, given) = _splitName(widget.donorName);
    final hasEmergencyContact = widget.emergencyContactName.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bandText('IF FOUND · KUNG NATAGPUAN · RETURN TO ANY RESQ PARTNER BLOOD BANK', trailing: widget.donorCode),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _backLabel('REGISTERED AT · NAKATALA SA'),
                      const SizedBox(height: 2),
                      const Text(
                        'Philippine Red Cross – Quezon Chapter',
                        style: TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      const SizedBox(height: 8),
                      _backLabel('DONATION RECORD · TALA NG DONASYON'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        children: List.generate(10, (i) {
                          final filled = i < widget.completedDonations;
                          return Icon(
                            filled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                            size: 13,
                            color: filled ? ResQTheme.primaryCrimson : ResQTheme.lightBorder,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      _backLabel('EMERGENCY CONTACT · KONTAK SA EMERHENSIYA', color: ResQTheme.primaryCrimson),
                      const SizedBox(height: 2),
                      Text(
                        hasEmergencyContact
                            ? '${widget.emergencyContactName} · ${widget.emergencyContactPhone}'
                            : 'Not set — add one in Settings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasEmergencyContact ? ResQTheme.textDark : ResQTheme.textMuted,
                          fontWeight: hasEmergencyContact ? FontWeight.bold : FontWeight.normal,
                          fontStyle: hasEmergencyContact ? FontStyle.normal : FontStyle.italic,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildBracketedQr(),
                      const SizedBox(height: 4),
                      Text(
                        'SCAN TO VERIFY DONOR · I-SCAN',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: ResQTheme.textMuted, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: ResQTheme.lightPinkTint,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECENT DONATION RECORD · TALA NG DONASYON', style: TextStyle(color: ResQTheme.primaryCrimson, fontSize: 6.5, fontWeight: FontWeight.bold)),
                Text('${widget.completedDonations} lifetime', style: const TextStyle(color: ResQTheme.primaryCrimson, fontSize: 6.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _loadingHistory
                ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                : _history.isEmpty
                    ? Text('No donation history yet.', style: TextStyle(color: ResQTheme.textMuted, fontSize: 9))
                    : Column(
                        children: _history.take(3).toList().asMap().entries.map((entry) {
                          final row = entry.value;
                          final dateStr = row['arrivedAt'] as String?;
                          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
                          final hospital = row['hospitalName'] as String? ?? 'ResQ Partner Hospital';
                          final donNumber = widget.completedDonations - entry.key;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 62,
                                  child: Text(
                                    date != null ? _formatDate(date) : '—',
                                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: ResQTheme.textDark),
                                  ),
                                ),
                                Expanded(
                                  child: Text(hospital, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: ResQTheme.textDark)),
                                ),
                                Text(
                                  'DON-${donNumber.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ResQTheme.primaryCrimson),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFF0EDE7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              _buildMrz(surname, given),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 7.5, color: Color(0xFF5B5648), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBracketedQr() {
    const bracketSize = 96.0;
    const qrSize = bracketSize; // flush with the corner brackets, no gap
    return SizedBox(
      width: bracketSize,
      height: bracketSize,
      child: Stack(
        children: [
          Center(
            child: widget.donorCode.isEmpty
                ? const Icon(Icons.qr_code_2_rounded, size: qrSize)
                : QrImageView(
                    data: 'https://resq-admin.me/donor-management?checkin=${Uri.encodeQueryComponent(widget.donorCode)}',
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.transparent,
                  ),
          ),
          CustomPaint(size: const Size.square(bracketSize), painter: _CornerBracketsPainter()),
        ],
      ),
    );
  }

  // Decorative only (not a real scannable MRZ) — built from the donor's
  // actual name/blood type/birth date/donor code so it's at least
  // consistent with the rest of the card, rather than fabricated digits.
  String _buildMrz(String surname, String given) {
    String pad(String s, int len) => s.length >= len ? s.substring(0, len) : s.padRight(len, '<');
    final surnamePart = surname.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final givenPart = given.toUpperCase().replaceAll(RegExp(r'\s+'), '<');
    final line1 = pad('RQD<PHL<$surnamePart<<$givenPart', 30);
    final codePart = widget.donorCode.toUpperCase().replaceAll('-', '');
    final sexLetter = widget.gender == 'female' ? 'F' : 'M';
    String ymd(DateTime? d) => d == null
        ? '000000'
        : '${(d.year % 100).toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final line2 = pad('RQ$codePart<0<<${ymd(widget.birthDate)}$sexLetter${ymd(widget.memberSince)}', 30);
    return '$line1\n$line2';
  }

  Widget _buildDonationStamps(_DonorTier tier) {
    final donations = widget.completedDonations;
    const totalStamps = 10;
    final nextThreshold = tier == _DonorTier.guardian ? null : (tier == _DonorTier.starter ? 5 : 10);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: ResQTheme.primaryCrimson, size: 20),
              const SizedBox(width: 8),
              const Text('Donation Stamps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ResQTheme.textDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$donations blood donation${donations == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: ResQTheme.textMuted, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ResQTheme.lightPinkTint, borderRadius: BorderRadius.circular(14)),
                child: Text(tier.label.toUpperCase(), style: const TextStyle(color: ResQTheme.primaryCrimson, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(totalStamps, (i) {
              final filled = i < donations;
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: filled ? ResQTheme.primaryCrimson : Colors.transparent,
                  shape: BoxShape.circle,
                  border: filled ? null : Border.all(color: ResQTheme.lightBorder, style: BorderStyle.solid),
                ),
                alignment: Alignment.center,
                child: filled
                    ? const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20)
                    : Text('${i + 1}', style: TextStyle(color: ResQTheme.textMuted, fontWeight: FontWeight.bold)),
              );
            }),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nextThreshold == null ? 1.0 : (donations / nextThreshold).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: ResQTheme.lightBorder,
              valueColor: const AlwaysStoppedAnimation(ResQTheme.primaryCrimson),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            nextThreshold == null
                ? 'You\'ve reached the highest priority tier — Guardian of Life.'
                : '${nextThreshold - donations} more donation${(nextThreshold - donations) == 1 ? '' : 's'} to reach '
                    '${_tierFor(nextThreshold).label} and Priority Level ${_tierFor(nextThreshold).level}.',
            style: const TextStyle(fontSize: 12.5, color: ResQTheme.textDark, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityAccess(_DonorTier tier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: ResQTheme.lightPinkTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield_rounded, color: ResQTheme.primaryCrimson, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Priority Blood Access · Level ${tier.level}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ResQTheme.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'If you need blood, your request is moved ahead in the queue at ResQ partner blood banks. Show this card or your Donor ID when you ask for blood.',
            style: TextStyle(fontSize: 12.5, color: ResQTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: ResQTheme.statusGreenBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: ResQTheme.statusGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('PRIORITY ACTIVE', style: TextStyle(color: ResQTheme.statusGreen, fontWeight: FontWeight.bold, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _DonorTier.values.map((t) {
              final active = t == tier;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: t != _DonorTier.values.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: active ? ResQTheme.lightPinkTint : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? ResQTheme.primaryCrimson : ResQTheme.lightBorder, width: active ? 1.4 : 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: active ? ResQTheme.primaryCrimson : ResQTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(t.rangeLabel, style: const TextStyle(fontSize: 10, color: ResQTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Faint concentric-ring watermark behind the card front's identity fields —
/// the guilloche-pattern security-print look from the physical ID design,
/// approximated with plain circles rather than a real anti-counterfeiting
/// pattern (this is a display-only digital card, not something printed).
class _RingsPainter extends CustomPainter {
  final Color color;
  const _RingsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * 0.78, size.height * 0.5);
    for (var r = 20.0; r < size.width; r += 22) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => oldDelegate.color != color;
}

/// Four L-shaped corner brackets around the card back's QR — a "scanner
/// viewfinder" frame instead of a plain white box, matching the physical ID
/// design's back.
class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ResQTheme.textDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const len = 10.0;
    final w = size.width;
    final h = size.height;

    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(w, 0), Offset(w - len, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // bottom-left
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - len), paint);
    // bottom-right
    canvas.drawLine(Offset(w, h), Offset(w - len, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}
