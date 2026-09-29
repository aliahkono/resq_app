import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:resq/model/ver_stats_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/profile/signature_pad_view.dart';

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
  final String? signatureUrl;
  // Null means the donor is free to (re)draw their signature right now.
  // A non-null value in the future means it's locked until that date — see
  // donorPortal.controller.js's SIGNATURE_COOLDOWN_DAYS comment for why a
  // signature isn't freely re-editable (RA 8792 wants it to be a stable,
  // sole-control identifier) but also isn't locked forever (RA 10173 gives
  // donors the right to correct their own data on a reasonable cadence).
  final DateTime? signatureEditableAt;
  // Bubbles a newly-saved signature's URL up to whoever constructed this
  // screen (HomeView) so ITS OWN state updates too — without this, saving a
  // signature only updated this screen instance's local state, so leaving
  // and re-opening the card (a fresh DigitalHealthCardView, built again
  // from HomeView's now-stale signatureUrl) looked like the signature was
  // never saved at all. Same pattern as DonorProfileView's onPhotoUpdated.
  final ValueChanged<String>? onSignatureUpdated;
  final int completedDonations;
  final VerificationStatus verificationStatus;
  final bool isEligible;
  final DateTime? memberSince;
  final DateTime? birthDate;
  final String? gender;
  final String emergencyContactName;
  final String emergencyContactPhone;
  // True for the "View Digitalized Health Card" button on the Profile
  // page's top card — shows just the flip card (still with the tap-to-flip
  // and "view fullscreen in landscape" actions), not the Donation Stamps /
  // Priority Blood Access sections below it. Those stay the default (false)
  // for the Clinical & Donation Records tile, which still opens the full
  // screen.
  final bool cardOnly;

  const DigitalHealthCardView({
    super.key,
    required this.token,
    required this.donorName,
    required this.donorCode,
    required this.bloodType,
    this.photoUrl,
    this.signatureUrl,
    this.signatureEditableAt,
    this.onSignatureUpdated,
    required this.completedDonations,
    required this.verificationStatus,
    required this.isEligible,
    this.memberSince,
    this.birthDate,
    this.gender,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.cardOnly = false,
  });

  @override
  State<DigitalHealthCardView> createState() => _DigitalHealthCardViewState();
}

class _DigitalHealthCardViewState extends State<DigitalHealthCardView> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  bool _showingBack = false;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;
  String? _signatureUrl;
  DateTime? _signatureEditableAt;

  // The card is drawn on a fixed design canvas with real ID-card
  // proportions (ISO/IEC 7810 ID-1 / CR80: 85.60 × 53.98 mm, ≈ 1.586:1) and
  // scaled uniformly to the screen width — so it's never "fat", both faces
  // are always the same size, and nothing can overflow on small phones or
  // with large system font sizes.
  static const double _cardAspect = 85.60 / 53.98;
  static const double _cardW = 340;
  static const double _cardH = _cardW / _cardAspect; // ≈ 214

  @override
  void initState() {
    super.initState();
    _signatureUrl = widget.signatureUrl;
    _signatureEditableAt = widget.signatureEditableAt;
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _loadHistory();
  }

  // Opens the signature pad (see signature_pad_view.dart); on a successful
  // save it returns the new hosted signature URL, which we show on the
  // card immediately without needing to reload the whole profile.
  //
  // Gated by _signatureEditableAt (mirrors donorPortal.controller.js's
  // SIGNATURE_COOLDOWN_DAYS): a signature is a stable, sole-control
  // identifier once set (RA 8792), not something redrawn on a whim, so a
  // donor who already has one can't just tap through to redo it — they see
  // the date it unlocks instead. The server enforces this for real; this
  // check just avoids sending them to draw a signature it'll reject.
  Future<void> _openSignaturePad() async {
    final lockedUntil = _signatureEditableAt;
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Signature Locked'),
          content: Text(
            'Your signature is already on file and can\'t be redrawn yet — '
            'it can be updated again on ${_formatDate(lockedUntil)}. This '
            'keeps your Digital Health Card signature stable and trustworthy '
            'between updates.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
          ],
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => SignaturePadView(token: widget.token)),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _signatureUrl = result;
        _signatureEditableAt = DateTime.now().add(const Duration(days: 180));
      });
      widget.onSignatureUpdated?.call(result);
    }
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

  // Keys on the front/back faces (see _buildFlipCard) so the visible side
  // can be captured as an image for "Download".
  final GlobalKey _frontFaceKey = GlobalKey();
  final GlobalKey _backFaceKey = GlobalKey();
  bool _saving = false;

  /// Download: saves the side of the card that's showing as a PNG straight
  /// into the phone's gallery / Photos (not the share sheet).
  Future<void> _downloadCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Let a flip in progress finish so the right face is captured.
      while (_flipController.isAnimating) {
        await Future.delayed(const Duration(milliseconds: 60));
      }
      final key = _showingBack ? _backFaceKey : _frontFaceKey;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Card not ready');
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode card');

      // Photos permission (iOS, and Android 9 and below).
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) {
          _showSnack('Allow ResQ to access your photos to save the card.');
          return;
        }
      }

      final side = _showingBack ? 'back' : 'front';
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'resq_health_card_${side}_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showSnack('Health card saved to your gallery.');
    } on GalException catch (e) {
      debugPrint('DigitalHealthCardView: save to gallery failed: ${e.type}');
      _showSnack(e.type == GalExceptionType.accessDenied
          ? 'Allow ResQ to access your photos to save the card.'
          : e.type == GalExceptionType.notEnoughSpace
              ? 'Not enough storage to save the card.'
              : 'Could not save the card. Please try again.');
    } catch (e) {
      debugPrint('DigitalHealthCardView: download failed: $e');
      _showSnack('Could not save the card. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // "View card enlarged" — for handing the phone to hospital staff or a
  // scanner: just the card, rotated to fill the screen edge-to-edge the way
  // a landscape card would, but WITHOUT actually rotating the device/app —
  // the status bar, nav bar, and everything else stay upright and in
  // portrait, matching how the Philippine national ID app's own "enlarge"
  // view behaves (plain white background, card rotated in place, plain
  // buttons below it — not a full black fullscreen takeover).
  // Reuses _buildFlipCard's own widget (tap-to-flip animation included),
  // but with FRESH GlobalKeys: the on-screen DigitalHealthCardView stays
  // mounted underneath this pushed route (MaterialPageRoute doesn't
  // dispose the route below it), so its own _buildFlipCard call is still
  // using _frontFaceKey/_backFaceKey at the same time — reusing those same
  // keys here would mean two simultaneously-mounted widgets sharing one
  // GlobalKey, which Flutter disallows and previously rendered as a black
  // screen.
  void _openFullscreenCard(_DonorTier tier) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CardFullscreenView(
          card: _buildFlipCard(tier, frontKey: GlobalKey(), backKey: GlobalKey()),
          cardAspect: _cardAspect,
          onFlip: _flip,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
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

    // cardOnly (the Profile page's "View Digitalized Health Card" button)
    // is meant to be handed over at checkin as-is — already in landscape,
    // no extra tap on a separate fullscreen icon required. So this whole
    // screen IS the landscape presentation from the moment it opens,
    // rather than the normal portrait Scaffold below (which still needs
    // its own manual "open in full" step for the other, stamps-inclusive
    // entry point). Only one _buildFlipCard call exists in the tree here,
    // so it's safe to use the default (singleton) front/back keys.
    if (widget.cardOnly) {
      return _CardFullscreenView(card: _buildFlipCard(tier), cardAspect: _cardAspect, onFlip: _flip);
    }

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
                onPressed: () => _openFullscreenCard(tier),
                tooltip: 'Enlarge card',
                icon: const Icon(Icons.open_in_full_rounded),
              ),
              IconButton(
                onPressed: _saving ? null : _downloadCard,
                tooltip: 'Download card',
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt_rounded),
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
                // cardOnly (the Profile page's "View Digitalized Health
                // Card" button) stops here — just the card someone can show
                // at checkin, not the Donation Stamps / Priority Blood
                // Access sections, which are their own separate concept
                // (progress toward donation tiers) unrelated to what a
                // donor is actually handing over to be scanned.
                if (!widget.cardOnly) ...[
                  const SizedBox(height: 20),
                  _buildDonationStamps(tier),
                  const SizedBox(height: 16),
                  _buildPriorityAccess(tier),
                ],
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

  // frontKey/backKey default to the instance-level _frontFaceKey/
  // _backFaceKey (used by the on-screen copy that "Download" captures from).
  // The fullscreen route below builds a *second*, simultaneously-mounted
  // copy of this same widget tree while the on-screen one stays mounted
  // underneath it in the Navigator stack — reusing the same GlobalKeys for
  // both would violate Flutter's one-GlobalKey-per-tree rule and crash to a
  // black screen, so that call site passes fresh keys instead.
  Widget _buildFlipCard(_DonorTier tier, {GlobalKey? frontKey, GlobalKey? backKey}) {
    final effectiveFrontKey = frontKey ?? _frontFaceKey;
    final effectiveBackKey = backKey ?? _backFaceKey;
    return GestureDetector(
      onTap: _flip,
      child: AspectRatio(
        aspectRatio: _cardAspect,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _cardW,
            height: _cardH,
            // The card is a fixed-layout graphic that's already scaled to
            // fit by the FittedBox above, so the phone's font-size setting
            // shouldn't also enlarge (and overflow) its text.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  final angle = _flipController.value * math.pi;
                  final showFront = angle < math.pi / 2;
                  final content = showFront
                      ? RepaintBoundary(key: effectiveFrontKey, child: _buildCardFront(tier))
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: RepaintBoundary(key: effectiveBackKey, child: _buildCardBack()),
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
          ),
        ),
      ),
    );
  }

  // A flat fill read as a printout; real government/bank-style ID cards are
  // laminated card stock, so this is a soft diagonal sheen (light catching
  // the surface) plus a slightly deeper edge, instead of one flat color.
  BoxDecoration get _cardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF9), _cardCream, Color(0xFFF3ECE0)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      );

  // Two decorative layers sandwiched around the card's real content
  // (unchanged) to read as security-printed card stock instead of a flat
  // background: a faint engraved wave-line texture (like the fine guilloché
  // printing on IDs/banknotes), and a soft diagonal glass-like highlight
  // sweeping across the laminate, as if catching light. Both are
  // IgnorePointer'd and low-opacity so they never compete with the actual
  // fields, photo, or text.
  Widget _cardBackdrop() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SecurityWeavePainter(color: _band.withValues(alpha: 0.05))),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment(-1.0, -1.0),
                  end: Alignment(1.0, 1.0),
                  colors: [Colors.transparent, Colors.white, Colors.transparent],
                  stops: [0.30, 0.46, 0.62],
                ).createShader(rect),
                blendMode: BlendMode.srcIn,
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandText(String text, {String? trailing}) {
    return Container(
      color: _band,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            // FittedBox scales the whole line down to fit rather than
            // hard-clipping mid-word — the band was previously cutting text
            // off abruptly (e.g. ending on a dangling "·") whenever the
            // phrase was a hair too wide for the available space.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            // Capped to its own small box (not left to grow with the
            // content) — a donor whose code happens to be a long UUID
            // rather than the usual short "D-1234" form was otherwise
            // dwarfing the actual "if found" instructions next to it.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 78),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  trailing,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Short, unique-per-donor label for the back band's badge — the donor's
  // real code (hyphens stripped), capped to 10 characters. Full code is
  // still shown in full on the front ("Donor ID") and in the MRZ strip
  // below; this is just a compact tag, not a separate identifier.
  String get _shortDonorCode {
    final stripped = widget.donorCode.toUpperCase().replaceAll('-', '');
    return stripped.length > 10 ? stripped.substring(0, 10) : stripped;
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
      width: _cardW,
      height: _cardH,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Stack(
        children: [
          Positioned.fill(child: _cardBackdrop()),
          Column(
            children: [
              _bandText('BLOOD DONOR  ·  DONOR NG DUGO  ·  RESQ', trailing: widget.bloodType),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftColumn(),
                    Expanded(child: _buildFrontFields(tier, surname, given, sex, issued, validUntil)),
                  ],
                ),
              ),
              _bandText('OFFICIAL BLOOD DONOR IDENTIFICATION  ·  NON-TRANSFERABLE  ·  RESQ NETWORK'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return SizedBox(
      width: 90,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 6, 6),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: const Color(0xFFE5E0D8),
                        width: double.infinity,
                        child: (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                            ? Image.network(
                                widget.photoUrl!,
                                fit: BoxFit.cover,
                                // A transient load failure (e.g. slow
                                // network on first open) shouldn't show
                                // Flutter's default red error glyph — fall
                                // back to the same placeholder as "no photo
                                // set" instead.
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person_rounded, color: Color(0xFFAFA89C), size: 34),
                              )
                            : const Icon(Icons.person_rounded, color: Color(0xFFAFA89C), size: 34),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Fixed height; the photo above takes whatever is left of
                  // the card's fixed height.
                  GestureDetector(
                    onTap: _openSignaturePad,
                    child: Container(
                      height: 32,
                      width: double.infinity,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: ResQTheme.lightBorder),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: (_signatureUrl != null && _signatureUrl!.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(2),
                              child: Image.network(
                                _signatureUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  'Signature · Lagda',
                                  style: TextStyle(fontSize: 6.5, color: ResQTheme.textMuted),
                                ),
                              ),
                            )
                          : Text(
                              'Tap to\nsign · Lagda',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 7, color: ResQTheme.textMuted, height: 1.2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // The photo above is Expanded (takes whatever's left of
                  // the card's fixed height), so on a tight layout this
                  // fixed-size caption was the thing that ran out of room
                  // and got silently clipped by the card's ClipRRect —
                  // not truncated with an ellipsis, just gone. FittedBox
                  // shrinks it to whatever space is actually left instead,
                  // so it's always visible, just occasionally a hair
                  // smaller than its 6pt default.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Keep this card with you.',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(fontSize: 6, color: ResQTheme.textMuted, height: 1.2),
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

  Widget _buildFrontFields(
    _DonorTier tier,
    String surname,
    String given,
    String sex,
    DateTime? issued,
    DateTime? validUntil,
  ) {
    Widget field(String label, Widget value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [_cardLabel(label), value],
        );
    const gap = SizedBox(height: 5);

    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 10.0 + 10.0;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RingsPainter(color: ResQTheme.primaryCrimson.withValues(alpha: 0.06))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              // Scales the block down if it's ever taller than the space
              // the card leaves for it — shrink, never overflow.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth - hPad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.water_drop_rounded, color: ResQTheme.primaryCrimson, size: 15),
                          const SizedBox(width: 4),
                          const Text('ResQ', style: TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'BLOOD DONOR ID CARD · PAGKAKAKILANLAN NG DONOR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ResQTheme.textMuted, fontSize: 5.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: field('Surname · Apelyido', _cardValue(surname.isNotEmpty ? surname : widget.donorName))),
                          Expanded(
                            child: field(
                              'Blood type · Uri ng dugo',
                              Text(widget.bloodType,
                                  maxLines: 1,
                                  style: const TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      gap,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: field('Given names · Pangalan', _cardValue(given.isNotEmpty ? given : '—'))),
                          Expanded(child: field('Sex · Kasarian', _cardValue(sex))),
                        ],
                      ),
                      gap,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: field('Birth date · Kapanganakan', _cardValue(issuedDateOr(widget.birthDate)))),
                          Expanded(child: field('Donations · Donasyon', _cardValue('${widget.completedDonations}'))),
                        ],
                      ),
                      gap,
                      field('Donor ID · Numero ng donor', _cardValue(widget.donorCode.isNotEmpty ? widget.donorCode : '—')),
                      gap,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: field('Issued · Petsa ng pagbigay', _cardValue(issuedDateOr(issued)))),
                          Expanded(child: field('Valid until · Balido hanggang', _cardValue(issuedDateOr(validUntil)))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String issuedDateOr(DateTime? date) => date != null ? _formatDate(date) : 'N/A';

  Widget _cardLabel(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ResQTheme.textMuted, fontSize: 5.8),
      );

  Widget _cardValue(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.bold, fontSize: 10),
      );

  Widget _backLabel(String text, {Color? color}) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color ?? ResQTheme.textMuted, fontSize: 5.8, fontWeight: FontWeight.bold, letterSpacing: 0.3),
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
      width: _cardW,
      height: _cardH,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Stack(
        children: [
          Positioned.fill(child: _cardBackdrop()),
          Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bandText('IF FOUND · KUNG NATAGPUAN · RETURN TO ANY RESQ PARTNER BLOOD BANK', trailing: _shortDonorCode),
          // Everything between the band and the MRZ strip is scaled down if
          // it's ever taller than the card leaves for it — shrink, never
          // overflow.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _cardW,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _backLabel('REGISTERED AT · NAKATALA SA'),
                                const SizedBox(height: 1),
                                const Text(
                                  'Philippine Red Cross – Quezon Chapter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: ResQTheme.textDark, fontWeight: FontWeight.w900, fontSize: 9.5),
                                ),
                                const SizedBox(height: 5),
                                _backLabel('DONATION RECORD · TALA NG DONASYON'),
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(10, (i) {
                                    final filled = i < widget.completedDonations;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: Icon(
                                        filled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                                        size: 11,
                                        color: filled ? ResQTheme.primaryCrimson : ResQTheme.lightBorder,
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 5),
                                _backLabel('EMERGENCY CONTACT · KONTAK SA EMERHENSIYA', color: ResQTheme.primaryCrimson),
                                const SizedBox(height: 1),
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
                                    fontSize: 8.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            children: [
                              _buildBracketedQr(size: 78),
                              const SizedBox(height: 2),
                              Text(
                                'SCAN TO VERIFY',
                                style: TextStyle(fontSize: 5.5, fontWeight: FontWeight.bold, color: ResQTheme.textMuted, letterSpacing: 0.3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: ResQTheme.lightPinkTint,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('RECENT DONATIONS · TALA NG DONASYON',
                              style: TextStyle(color: ResQTheme.primaryCrimson, fontSize: 5.8, fontWeight: FontWeight.bold)),
                          Text('${widget.completedDonations} lifetime',
                              style: const TextStyle(color: ResQTheme.primaryCrimson, fontSize: 5.8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
                      child: _loadingHistory
                          ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)))
                          : _history.isEmpty
                              ? Text('No donation history yet.', style: TextStyle(color: ResQTheme.textMuted, fontSize: 8))
                              // Two most recent — the full history lives in
                              // Profile › Clinical & Donation Records.
                              : Column(
                                  children: _history.take(2).toList().asMap().entries.map((entry) {
                                    final row = entry.value;
                                    final dateStr = row['arrivedAt'] as String?;
                                    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
                                    final hospital = row['hospitalName'] as String? ?? 'ResQ Partner Hospital';
                                    final donNumber = widget.completedDonations - entry.key;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 58,
                                            child: Text(
                                              date != null ? _formatDate(date) : '—',
                                              style: const TextStyle(fontSize: 8, fontFamily: 'monospace', color: ResQTheme.textDark),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(hospital,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 8, color: ResQTheme.textDark)),
                                          ),
                                          Text(
                                            'DON-${donNumber.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ResQTheme.primaryCrimson),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Decorative MRZ strip, pinned to the bottom edge like a real card.
          Container(
            color: const Color(0xFFF0EDE7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildMrz(surname, given)
                  .map(
                    (line) => FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF5B5648), letterSpacing: 1, height: 1.15),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _buildBracketedQr({double size = 96}) {
    final bracketSize = size;
    final qrSize = bracketSize; // flush with the corner brackets, no gap
    return SizedBox(
      width: bracketSize,
      height: bracketSize,
      child: Stack(
        children: [
          Center(
            child: widget.donorCode.isEmpty
                ? Icon(Icons.qr_code_2_rounded, size: qrSize)
                : QrImageView(
                    data: 'https://resq-admin.me/donor-management?checkin=${Uri.encodeQueryComponent(widget.donorCode)}',
                    version: QrVersions.auto,
                    size: qrSize,
                    backgroundColor: Colors.transparent,
                    // QrImageView defaults to a 10px built-in quiet-zone
                    // padding on every side — with the brackets painted
                    // flush at 0/w/h (see _CornerBracketsPainter), that
                    // default padding was what actually made the QR look
                    // small inside its own corner guides, not the box size
                    // itself. Zeroing it lets the QR modules fill the same
                    // area the brackets frame, edge to edge.
                    padding: EdgeInsets.zero,
                  ),
          ),
          CustomPaint(size: Size.square(bracketSize), painter: _CornerBracketsPainter()),
        ],
      ),
    );
  }

  // Decorative only (not a real scannable MRZ) — built from the donor's
  // actual name/blood type/birth date/donor code so it's at least
  // consistent with the rest of the card, rather than fabricated digits.
  // Decorative MRZ-style strip — built entirely from this donor's own real
  // fields (name, donor code, gender, birth date, membership date), so it's
  // already unique per donor rather than a shared placeholder; two donors
  // only ever produce the same lines if they share the same name AND the
  // same donor code, which can't happen (donor_code is unique in the DB).
  // Each returned line is rendered stretched to the full card width (see
  // the FittedBox(fit: fitWidth) at the call site) rather than left small
  // and left-hugging, and padding only ever extends a short value — it
  // never truncates real content.
  List<String> _buildMrz(String surname, String given) {
    String minPad(String s, int minLen) => s.length >= minLen ? s : s.padRight(minLen, '<');
    final surnamePart = surname.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final givenPart = given.toUpperCase().replaceAll(RegExp(r'\s+'), '<');
    final line1 = minPad('RQD<PHL<$surnamePart<<$givenPart', 34);
    final codePart = widget.donorCode.toUpperCase().replaceAll('-', '');
    final sexLetter = widget.gender == 'female' ? 'F' : 'M';
    String ymd(DateTime? d) => d == null
        ? '000000'
        : '${(d.year % 100).toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final line2 = minPad('RQ$codePart<0<<${ymd(widget.birthDate)}$sexLetter${ymd(widget.memberSince)}', 34);
    return [line1, line2];
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
          // Count + label on the left, tier badge on the right. Both sides
          // can shrink/wrap, so a 2–3 digit count or a long tier name
          // ("Guardian of Life") never pushes "Life Donations" off screen.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$donations',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: ResQTheme.primaryCrimson, height: 1.0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  donations == 1 ? 'Life Donation' : 'Life Donations',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, color: ResQTheme.textDark, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: ResQTheme.lightPinkTint, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    tier.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ResQTheme.primaryCrimson, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
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

/// "Enlarge card" presentation — pushed by _openFullscreenCard, or shown
/// directly by cardOnly. Matches how the Philippine national ID app's own
/// "enlarge" view behaves: the screen and its status/nav bars stay upright
/// and in portrait (no SystemChrome orientation lock, no black takeover) —
/// only the card itself is rotated 90° in place to read like a landscape
/// card, on a plain light background with a couple of clean buttons below.
class _CardFullscreenView extends StatelessWidget {
  final Widget card;
  final double cardAspect;
  final VoidCallback onFlip;

  const _CardFullscreenView({required this.card, required this.cardAspect, required this.onFlip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The card's own AspectRatio/FittedBox sizing means it
                    // just needs a box of the right aspect ratio to fill —
                    // give RotatedBox a pre-rotation box whose dimensions
                    // are swapped so the box it reports back (post-rotation)
                    // fits the available portrait space without letterboxing.
                    var occupiedW = constraints.maxWidth;
                    var occupiedH = occupiedW * cardAspect;
                    if (occupiedH > constraints.maxHeight) {
                      occupiedH = constraints.maxHeight;
                      occupiedW = occupiedH / cardAspect;
                    }
                    return Center(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: SizedBox(width: occupiedH, height: occupiedW, child: card),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onFlip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ResQTheme.primaryCrimson,
                        backgroundColor: ResQTheme.lightPinkTint,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.flip_camera_android_rounded, size: 18),
                      label: const Text('Flip Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ResQTheme.textMuted,
                        side: BorderSide(color: ResQTheme.lightBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faint concentric-ring watermark behind the card front's identity fields —
/// the guilloche-pattern security-print look from the physical ID design,
/// approximated with plain circles rather than a real anti-counterfeiting
/// pattern (this is a display-only digital card, not something printed).
/// Faint engraved wave-line texture across the whole card — the kind of
/// fine, repeating guilloché pattern printed as an anti-counterfeit base
/// layer on real IDs/banknotes, rather than a flat color. Purely
/// decorative background (see _cardBackdrop) — never drawn over content.
class _SecurityWeavePainter extends CustomPainter {
  final Color color;
  const _SecurityWeavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    const spacing = 6.0;
    for (var y = -size.width.toDouble(); y < size.height + size.width; y += spacing) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 10) {
        path.quadraticBezierTo(x + 5, y - 5 + x / size.width * 5, x + 10, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SecurityWeavePainter oldDelegate) => oldDelegate.color != color;
}

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