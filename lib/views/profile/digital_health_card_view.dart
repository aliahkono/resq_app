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

  Widget _buildFlipCard(_DonorTier tier) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, child) {
          final angle = _flipController.value * math.pi;
          final showFront = angle < math.pi / 2;
          final content = showFront ? _buildCardFront(tier) : Transform(
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
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        gradient: const LinearGradient(
          colors: [ResQTheme.primaryCrimson, ResQTheme.logoDeepMaroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      );

  Widget _bandText(String text) {
    return Container(
      color: Colors.black.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCardFront(_DonorTier tier) {
    final (surname, given) = _splitName(widget.donorName);
    final issued = widget.memberSince;
    final validUntil = issued?.add(const Duration(days: 365 * 2));

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bandText('BLOOD DONOR  ·  DONOR NG DUGO  ·  RESQ  ·  BLOOD DONOR'),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  backgroundImage: (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                      ? NetworkImage(widget.photoUrl!)
                      : null,
                  child: (widget.photoUrl == null || widget.photoUrl!.isEmpty)
                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.water_drop_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('ResQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      Text(
                        'BLOOD DONOR CARD · KARD NG DONOR',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    widget.bloodType,
                    style: const TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel('Surname · Apelyido'),
                      _cardValue(surname.isNotEmpty ? surname : widget.donorName),
                      const SizedBox(height: 8),
                      _cardLabel('Given name · Pangalan'),
                      _cardValue(given.isNotEmpty ? given : '—'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel('Donor ID · Numero ng donor'),
                      _cardValue(widget.donorCode.isNotEmpty ? widget.donorCode : '—'),
                      const SizedBox(height: 8),
                      _cardLabel('Blood priority · Prayoridad'),
                      _cardValue('LEVEL ${tier.level} · ACTIVE'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel('Donations · Donasyon'),
                      _cardValue('${widget.completedDonations}'),
                      const SizedBox(height: 8),
                      _cardLabel('Verification · Beripikasyon'),
                      Row(
                        children: [
                          if (widget.verificationStatus.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                            ),
                          Flexible(child: _cardValue(widget.verificationStatus.label.toUpperCase())),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel('Date of issue · Petsa ng pagbigay'),
                      _cardValue(issued != null ? _formatDate(issued) : 'N/A'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardLabel('Valid until · Balido hanggang'),
                      _cardValue(validUntil != null ? _formatDate(validUntil) : 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bandText('SAVE A LIFE  ·  MAGSAVE NG BUHAY  ·  RESQ  ·  SAVE A LIFE'),
        ],
      ),
    );
  }

  Widget _cardLabel(String text) => Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9),
      );

  Widget _cardValue(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      );

  Widget _buildCardBack() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('SCAN AT ANY RESQ PARTNER HOSPITAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: widget.donorCode.isEmpty
                  ? const SizedBox(width: 140, height: 140, child: Icon(Icons.qr_code_2_rounded, size: 80))
                  : QrImageView(
                      data: 'https://resq-admin.me/donor-management?checkin=${Uri.encodeQueryComponent(widget.donorCode)}',
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: Colors.white,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          const Text('RECENT DONATION RECORD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
          else if (_history.isEmpty)
            Text('No donation history yet.', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12))
          else
            ..._history.take(3).map((row) {
              final dateStr = row['arrivedAt'] as String?;
              final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
              final hospital = row['hospitalName'] as String? ?? 'ResQ Partner Hospital';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(date != null ? _formatDate(date) : '—', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    Flexible(
                      child: Text(
                        hospital,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
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
