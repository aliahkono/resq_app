import 'package:flutter/material.dart';
import 'package:resq/services/notif_service.dart';
import 'package:resq/views/notifications/broadcast_view.dart';

class AppNotificationBell extends StatelessWidget {
  final bool isEligible;
  final String donorBloodType;
  // Needed both to load the real notification list (NotificationService
  // .refresh(token)) and so the "accept slot" flow can open
  // EligibleAppointView, which requires a real session token to book.
  final String token;
  // Shared with every other "book an appointment" entry point (see
  // home_view.dart's _handleBookingCompleted) so a booking accepted from a
  // broadcast notification also shows up on the Appointment tab.
  final void Function(Map<String, dynamic> appointment)? onBookingCompleted;
  final bool isVerified;

  const AppNotificationBell({
    super.key,
    required this.isEligible,
    required this.donorBloodType,
    required this.token,
    this.onBookingCompleted,
    this.isVerified = false,
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
              tooltip: 'Broadcasts & SMS',
              icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
              onPressed: () => _openBroadcasts(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: -2,
                child: IgnorePointer(
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
              ),
          ],
        );
      },
    );
  }

  /// Opens Hospital Broadcasts & SMS as a full screen (it used to be a
  /// bottom sheet). BroadcastsView refreshes the list itself on open.
  void _openBroadcasts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastsView(
          isEligible: isEligible,
          donorBloodType: donorBloodType,
          token: token,
          isVerified: isVerified,
          onBookingCompleted: onBookingCompleted,
        ),
      ),
    );
  }
}