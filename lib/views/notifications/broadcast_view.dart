import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:resq/model/broadcast_notif_model.dart';
import 'package:resq/services/notif_service.dart';
import 'package:resq/views/appointment/eligible_appoint_view.dart';
import 'package:resq/widgets/resq_ui.dart';

enum _BroadcastFilter { all, critical, urgent, unread }

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[t.month - 1]} ${t.day}';
}

/// Shared "respond / share" logic for the list and the detail screen, so
/// both behave exactly like the old bottom sheet did.
class _BroadcastActions {
  final BuildContext context;
  final bool isEligible;
  final bool isVerified;
  final String token;
  final void Function(Map<String, dynamic> appointment)? onBookingCompleted;

  _BroadcastActions({
    required this.context,
    required this.isEligible,
    required this.isVerified,
    required this.token,
    this.onBookingCompleted,
  });

  void respond(BloodBroadcastNotification item) {
    NotificationService().markAsRead(item.id);
    final messenger = ScaffoldMessenger.of(context);
    if (!isEligible) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You are temporarily deferred. Please complete your recovery period before accepting slots.'),
          backgroundColor: RQColors.blood,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!item.isStillOpen) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This request has already been closed. Check the Home tab for other open broadcasts.'),
          backgroundColor: RQColors.blood,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => EligibleAppointView(
          isFirstTimeDonor: false,
          token: token,
          isVerified: isVerified,
          preselectedHospitalId: item.hospitalId,
          onBookingCompleted: (appointment) {
            Navigator.pop(routeContext);
            onBookingCompleted?.call(appointment);
            messenger.showSnackBar(
              SnackBar(
                content: Text('Reserved slot at ${appointment['hospitalName']}!'),
                backgroundColor: RQColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  void share(BuildContext anchor, BloodBroadcastNotification item) {
    NotificationService().markAsRead(item.id);
    final text = 'ResQ Alert: ${item.hospitalName} needs ${item.bloodType} blood donors '
        '(${item.location}). If you know someone who\'s ${item.bloodType} and eligible to donate, '
        'please share this with them. Every donor helps.';
    // sharePositionOrigin anchors the share sheet on iPad and keeps it from
    // silently failing on recent iOS versions.
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
    SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  }
}

// =============================================================================
// Full-screen list
// =============================================================================

/// Hospital Broadcasts & SMS — full-screen list opened from the bell (was a
/// bottom sheet).
class BroadcastsView extends StatefulWidget {
  final bool isEligible;
  final String donorBloodType;
  final String token;
  final bool isVerified;
  final void Function(Map<String, dynamic> appointment)? onBookingCompleted;

  const BroadcastsView({
    super.key,
    required this.isEligible,
    required this.donorBloodType,
    required this.token,
    this.isVerified = false,
    this.onBookingCompleted,
  });

  @override
  State<BroadcastsView> createState() => _BroadcastsViewState();
}

class _BroadcastsViewState extends State<BroadcastsView> {
  _BroadcastFilter _filter = _BroadcastFilter.all;

  _BroadcastActions get _actions => _BroadcastActions(
        context: context,
        isEligible: widget.isEligible,
        isVerified: widget.isVerified,
        token: widget.token,
        onBookingCompleted: widget.onBookingCompleted,
      );

  @override
  void initState() {
    super.initState();
    // Re-fetch every time this opens so a broadcast sent while the app was
    // already open shows up without a restart.
    NotificationService().refresh(widget.token);
  }

  List<BloodBroadcastNotification> _applyFilter(List<BloodBroadcastNotification> all) {
    switch (_filter) {
      case _BroadcastFilter.all:
        return all;
      case _BroadcastFilter.critical:
        return all.where((n) => n.urgency == UrgencyLevel.critical).toList();
      case _BroadcastFilter.urgent:
        return all.where((n) => n.urgency == UrgencyLevel.urgent).toList();
      case _BroadcastFilter.unread:
        return all.where((n) => !n.isRead).toList();
    }
  }

  void _openDetail(BloodBroadcastNotification item) {
    NotificationService().markAsRead(item.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastDetailView(
          item: item,
          isEligible: widget.isEligible,
          isVerified: widget.isVerified,
          token: widget.token,
          onBookingCompleted: widget.onBookingCompleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final all = service.notifications;
        final items = _applyFilter(all);
        final unread = service.unreadCount;
        final critical = all.where((n) => n.urgency == UrgencyLevel.critical).length;
        final urgent = all.where((n) => n.urgency == UrgencyLevel.urgent).length;
        final anySms = all.any((n) => n.smsDispatched);

        return Scaffold(
          backgroundColor: RQColors.surface,
          appBar: AppBar(
            backgroundColor: RQColors.blood,
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Broadcasts & SMS',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: Colors.white)),
                Text(
                  unread == 0 ? 'All caught up' : '$unread unread ${unread == 1 ? 'request' : 'requests'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xD9FFFFFF)),
                ),
              ],
            ),
            actions: [
              if (service.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              TextButton(
                onPressed: unread == 0 ? null : () => service.markAllAsReadRemote(widget.token),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0x80FFFFFF),
                ),
                child: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: RQColors.card,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('All · ${all.length}', _BroadcastFilter.all),
                      _chip('Critical · $critical', _BroadcastFilter.critical),
                      _chip('Urgent · $urgent', _BroadcastFilter.urgent),
                      _chip('Unread · $unread', _BroadcastFilter.unread),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: RQColors.hairline),
              Expanded(
                child: RefreshIndicator(
                  color: RQColors.blood,
                  onRefresh: () => service.refresh(widget.token),
                  child: items.isEmpty
                      ? _buildEmpty(service.isLoading)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: items.length + (anySms ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (anySms && index == 0) return _smsNote();
                            final item = items[index - (anySms ? 1 : 0)];
                            return item.isReferral ? _referralCard(item) : _requestCard(item);
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, _BroadcastFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 36,
        child: selected
            ? ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: RQColors.blood,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )
            : OutlinedButton(
                onPressed: () => setState(() => _filter = value),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RQColors.ink,
                  side: const BorderSide(color: RQColors.hairline, width: 1.5),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
      ),
    );
  }

  Widget _smsNote() {
    return const Row(
      children: [
        Icon(Icons.mark_chat_read_outlined, size: 16, color: RQColors.success),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'These alerts are also sent to you by SMS.',
            style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(bool loading) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: loading
              ? const CircularProgressIndicator(color: RQColors.blood)
              : Column(
                  children: [
                    const RQIconBox(icon: Icons.campaign_outlined, size: 64),
                    const SizedBox(height: 14),
                    Text(
                      _filter == _BroadcastFilter.all ? 'No blood requests right now' : 'Nothing in this filter',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "We'll alert you here and by SMS when a hospital needs you.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: RQColors.muted),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _urgencyTag(UrgencyLevel level) {
    switch (level) {
      case UrgencyLevel.critical:
        return const RQPill(label: 'CRITICAL', background: RQColors.blood, color: Colors.white, uppercase: true, radius: 6);
      case UrgencyLevel.urgent:
        return const RQPill(label: 'URGENT', background: RQColors.warningTint, color: RQColors.warning, uppercase: true, radius: 6);
      case UrgencyLevel.normal:
        return const RQPill(label: 'ROUTINE', background: RQColors.successTint, color: RQColors.success, uppercase: true, radius: 6);
    }
  }

  Widget _bloodBadge(BloodBroadcastNotification item) {
    return Container(
      width: 58,
      height: 62,
      decoration: BoxDecoration(color: RQColors.bloodTint, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.bloodType,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: RQColors.bloodText)),
          Text('${item.unitsNeeded} ${item.unitsNeeded == 1 ? 'unit' : 'units'}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: RQColors.bloodText)),
        ],
      ),
    );
  }

  Widget _cardHeader(BloodBroadcastNotification item, {Widget? tag}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bloodBadge(item),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  tag ?? _urgencyTag(item.urgency),
                  const Spacer(),
                  Text(_timeAgo(item.timestamp), style: const TextStyle(fontSize: 11, color: RQColors.muted)),
                  if (!item.isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: RQColors.warning, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(item.hospitalName,
                  style: const TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, color: RQColors.ink)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(item.location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                  ),
                  if (item.smsDispatched) ...[
                    const Text('  ·  ', style: TextStyle(fontSize: 12, color: RQColors.muted)),
                    const Icon(Icons.sms_outlined, size: 12, color: RQColors.muted),
                    const SizedBox(width: 4),
                    const Text('SMS sent', style: TextStyle(fontSize: 12, color: RQColors.muted)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailsButton(BloodBroadcastNotification item) {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: () => _openDetail(item),
        style: OutlinedButton.styleFrom(
          foregroundColor: RQColors.ink,
          side: const BorderSide(color: RQColors.hairline, width: 1.5),
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Icon(Icons.chevron_right_rounded, semanticLabel: 'View details'),
      ),
    );
  }

  Widget _requestCard(BloodBroadcastNotification item) {
    final bool open = item.isStillOpen;
    final bool critical = item.urgency == UrgencyLevel.critical;
    return Opacity(
      opacity: open ? 1 : 0.7,
      child: Material(
        color: RQColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _cardHeader(
                  item,
                  tag: open
                      ? null
                      : const RQPill(label: 'CLOSED', background: RQColors.surface, color: RQColors.muted, uppercase: true, radius: 6),
                ),
                if (open) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: critical
                            ? RQButton(label: 'Respond & accept slot', height: 44, onPressed: () => _actions.respond(item))
                            : RQButton.secondary(
                                label: 'Respond & accept slot',
                                height: 44,
                                color: RQColors.blood,
                                onPressed: () => _actions.respond(item),
                              ),
                      ),
                      const SizedBox(width: 8),
                      _detailsButton(item),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Shown to a donor who was deferred when this broadcast went out — they
  // can't donate, so the ask is to pass it on to someone who can.
  Widget _referralCard(BloodBroadcastNotification item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            item,
            tag: const RQPill(label: 'REFER A FRIEND', background: RQColors.navyTint, color: RQColors.navy, uppercase: true, radius: 6),
          ),
          const SizedBox(height: 10),
          Text(
            "You're on a recovery hold, so this one isn't for you. If you know someone who's "
            '${item.bloodType} and eligible, ${item.hospitalName} could use their help.',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: RQColors.body),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (btnContext) => RQButton.secondary(
              label: 'Share with a friend',
              icon: Icons.ios_share_rounded,
              height: 44,
              color: RQColors.navy,
              onPressed: () => _actions.share(btnContext, item),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Full-screen detail
// =============================================================================

class BroadcastDetailView extends StatelessWidget {
  final BloodBroadcastNotification item;
  final bool isEligible;
  final bool isVerified;
  final String token;
  final void Function(Map<String, dynamic> appointment)? onBookingCompleted;

  const BroadcastDetailView({
    super.key,
    required this.item,
    required this.isEligible,
    required this.isVerified,
    required this.token,
    this.onBookingCompleted,
  });

  Future<void> _openDirections(BuildContext context) async {
    final query = Uri.encodeComponent(item.hospitalName);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps on this device.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _BroadcastActions(
      context: context,
      isEligible: isEligible,
      isVerified: isVerified,
      token: token,
      onBookingCompleted: onBookingCompleted,
    );
    final int needed = item.unitsNeeded;
    final int filled = item.unitsFulfilled.clamp(0, needed);
    final double progress = needed > 0 ? filled / needed : 0;
    final int remaining = needed - filled;
    final bool open = item.isStillOpen;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: RQColors.card,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Red emergency header
                  Container(
                    width: double.infinity,
                    color: RQColors.blood,
                    padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _headerButton(Icons.close_rounded, 'Close', () => Navigator.of(context).maybePop()),
                            const Expanded(
                              child: Text('Hospital Broadcast',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                            ),
                            Builder(
                              builder: (btnContext) =>
                                  _headerButton(Icons.ios_share_rounded, 'Share', () => actions.share(btnContext, item)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${open ? item.urgencyLabel : 'CLOSED'} · ${_timeAgo(item.timestamp).toUpperCase()}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: RQColors.blood),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.water_drop_rounded, size: 16, color: RQColors.blood),
                                  Text(item.bloodType,
                                      style: const TextStyle(
                                          fontSize: 34, height: 1.15, fontWeight: FontWeight.w700, color: RQColors.blood)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.bloodType} blood needed',
                                      style: const TextStyle(
                                          fontSize: 21, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text('$needed ${needed == 1 ? 'unit' : 'units'} · ${item.location}',
                                      style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text('$filled of $needed units filled',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            const Spacer(),
                            if (open && remaining > 0)
                              Text('$remaining more ${remaining == 1 ? 'donor' : 'donors'} needed',
                                  style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0x40FFFFFF),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // White body overlapping the header
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      decoration: const BoxDecoration(
                        color: RQColors.card,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: RQColors.hairline),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const RQIconBox(icon: Icons.local_hospital_outlined, size: 44),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.hospitalName,
                                              style: const TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                                          Text(item.location,
                                              style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                RQButton.secondary(
                                  label: 'Directions',
                                  icon: Icons.near_me_outlined,
                                  height: 44,
                                  onPressed: () => _openDirections(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: RQColors.navy),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.isReferral
                                        ? "You're on a recovery hold, so you can't donate for this one. Sharing it with an eligible friend still helps."
                                        : 'You got this because your blood type can help with this request.'
                                            '${item.smsDispatched ? ' A copy was also sent by SMS.' : ''}',
                                    style: const TextStyle(fontSize: 13, height: 1.5, color: RQColors.ink),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!item.isReferral) ...[
                            const SizedBox(height: 18),
                            const Text('Before you go',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.bloodText)),
                            const SizedBox(height: 10),
                            _check('Bring a valid ID'),
                            _check('Eat a light meal 2–3 hours before'),
                            _check('Drink plenty of water'),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sticky footer
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: RQColors.card,
              border: Border(top: BorderSide(color: RQColors.hairline)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isReferral)
                  Builder(
                    builder: (btnContext) => RQButton(
                      label: 'Share with a friend',
                      icon: Icons.ios_share_rounded,
                      color: RQColors.navy,
                      onPressed: () => actions.share(btnContext, item),
                    ),
                  )
                else
                  RQButton(
                    label: open ? 'Respond & accept slot' : 'Request closed',
                    onPressed: open ? () => actions.respond(item) : null,
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(foregroundColor: RQColors.muted),
                    child: Text(item.isReferral || !open ? 'Back to broadcasts' : 'Not available this time',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x29FFFFFF),
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _check(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: RQColors.successTint, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 15, color: RQColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: RQColors.ink))),
        ],
      ),
    );
  }
}