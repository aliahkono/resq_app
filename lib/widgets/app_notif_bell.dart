import 'package:flutter/material.dart';
import 'package:resq/model/broadcast_notif_model.dart';
import 'package:resq/services/notif_service.dart';
import 'package:resq/views/appointment/eligible_appoint_view.dart';

class AppNotificationBell extends StatelessWidget {
  final bool isEligible;
  final String donorBloodType;
  // Needed both to load the real notification list (NotificationService
  // .refresh(token), triggered by HomeView on open) and so the "accept
  // slot" flow below can open EligibleAppointView, which requires a real
  // session token to book for real.
  final String token;
  // Shared with every other "book an appointment" entry point (see
  // home_view.dart's _handleBookingCompleted) so a booking accepted from a
  // broadcast notification also shows up on the Appointment tab, instead of
  // being the one entry point that silently forgets about it.
  final void Function(Map<String, dynamic> appointment)? onBookingCompleted;

  const AppNotificationBell({
    super.key,
    required this.isEligible,
    required this.donorBloodType,
    required this.token,
    this.onBookingCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationService(),
      builder: (context, _) {
        final unreadCount = NotificationService().unreadCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
              onPressed: () => _showBroadcastSheet(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showBroadcastSheet(BuildContext context) {
    final service = NotificationService();
    final list = service.notifications;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BroadcastModalSheet(
        notifications: list,
        isEligible: isEligible,
        onMarkAllRead: () => service.markAllAsReadRemote(token),
        onSelectBroadcast: (item) {
          service.markAsRead(item.id);
          Navigator.pop(ctx);
          if (!isEligible) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are temporarily deferred. Please complete your recovery period before accepting slots.'),
                backgroundColor: Color(0xFF7D1B22),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          if (!item.isStillOpen) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This request has already been closed out — check the Home tab for other open broadcasts.'),
                backgroundColor: Color(0xFF7D1B22),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EligibleAppointView(
                isFirstTimeDonor: false,
                token: token,
                preselectedHospitalId: item.hospitalId,
                onBookingCompleted: (appointment) {
                  Navigator.pop(context);
                  onBookingCompleted?.call(appointment);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reserved slot at ${appointment['hospitalName']}!'),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BroadcastModalSheet extends StatelessWidget {
  final List<BloodBroadcastNotification> notifications;
  final bool isEligible;
  final VoidCallback onMarkAllRead;
  final Function(BloodBroadcastNotification) onSelectBroadcast;

  const _BroadcastModalSheet({
    required this.notifications,
    required this.isEligible,
    required this.onMarkAllRead,
    required this.onSelectBroadcast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Color(0xFF7D1B22), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Hospital Broadcasts & SMS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E1E)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onMarkAllRead,
                  child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: Color(0xFF7D1B22), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notification List
          Expanded(
            child: notifications.isEmpty
                ? const Center(
              child: Text('No active emergency blood broadcasts.'),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationCard(context, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, BloodBroadcastNotification item) {
    Color badgeBg;
    Color badgeColor;
    IconData badgeIcon;

    switch (item.urgency) {
      case UrgencyLevel.critical:
        badgeBg = const Color(0xFFFFEBEE);
        badgeColor = const Color(0xFFC62828);
        badgeIcon = Icons.warning_amber_rounded;
        break;
      case UrgencyLevel.urgent:
        badgeBg = const Color(0xFFFFF3E0);
        badgeColor = const Color(0xFFE65100);
        badgeIcon = Icons.priority_high_rounded;
        break;
      case UrgencyLevel.normal:
        badgeBg = const Color(0xFFE8F5E9);
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.info_outline_rounded;
        break;
    }

    return InkWell(
      onTap: () => onSelectBroadcast(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFFFF7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? const Color(0xFFE5E7EB) : const Color(0xFF7D1B22),
            width: item.isRead ? 1.0 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.urgencyLabel,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (item.smsDispatched) ...[
                      const Icon(Icons.sms_outlined, size: 13, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      const Text('SMS Sent', style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                      const SizedBox(width: 8),
                    ],
                    if (!item.isRead)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Color(0xFF7D1B22), shape: BoxShape.circle),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.hospitalName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E1E1E)),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.location} • Requires ${item.unitsNeeded} unit(s) of Type ${item.bloodType}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => onSelectBroadcast(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: item.urgency == UrgencyLevel.critical
                      ? const Color(0xFF8A1E26)
                      : const Color(0xFF7D1B22),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('RESPOND & ACCEPT SLOT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}