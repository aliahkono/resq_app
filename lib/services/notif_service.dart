import 'package:flutter/material.dart';
import 'package:resq/model/broadcast_notif_model.dart';
import 'package:resq/services/api_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialized empty — dynamically populated via hospital dashboard web broadcasts/SMS
  final List<BloodBroadcastNotification> _notifications = [];

  List<BloodBroadcastNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool _loading = false;
  bool get isLoading => _loading;

  /// GET /api/donor/notifications — replaces the in-memory list with what's
  /// actually on the backend. This is the only real data source for the
  /// bell now; nothing simulates broadcasts locally anymore. Silent on
  /// failure (keeps whatever was last loaded) since this runs on app open,
  /// not in direct response to a donor action.
  Future<void> refresh(String token) async {
    if (token.isEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final response = await ApiService.getMyNotifications(token);
      final rawList = (response['notifications'] as List<dynamic>?) ?? [];
      final parsed = rawList
          .map((n) => BloodBroadcastNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      syncHospitalBroadcasts(parsed);
    } catch (_) {
      // Keep the last-known list rather than clearing it on a network hiccup.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// PATCH /api/donor/notifications/read — marks every row read server-side
  /// too, not just in this in-memory copy, so the unread badge doesn't come
  /// back after the next refresh(). Optimistically flips the local state
  /// first (markAllAsRead already does this instantly); this just makes it
  /// stick.
  Future<void> markAllAsReadRemote(String token) async {
    markAllAsRead();
    if (token.isEmpty) return;
    try {
      await ApiService.markNotificationsRead(token);
    } catch (_) {
      // Best-effort — the donor already sees them as read locally; a failed
      // sync here just means the badge could reappear on next refresh(),
      // which is a safe failure mode (never worse than "shows unread").
    }
  }

  /// Filters broadcasts relevant to the donor's eligibility and blood type
  List<BloodBroadcastNotification> getEligibleBroadcasts({
    required bool isEligible,
    required String donorBloodType,
  }) {
    if (!isEligible) return [];
    return _notifications.where((n) {
      return n.bloodType == donorBloodType || donorBloodType.isEmpty || donorBloodType == 'Unknown';
    }).toList();
  }

  /// Triggered when the Hospital Web Dashboard dispatches an SMS & Web Push broadcast
  void receiveHospitalBroadcast({
    required String hospitalName,
    required String bloodType,
    required int unitsNeeded,
    required UrgencyLevel urgency,
    required String location,
  }) {
    final newBroadcast = BloodBroadcastNotification(
      id: 'BCAST-${DateTime.now().millisecondsSinceEpoch % 10000}',
      hospitalName: hospitalName,
      bloodType: bloodType,
      unitsNeeded: unitsNeeded,
      urgency: urgency,
      location: location,
      timestamp: DateTime.now(),
      isRead: false,
      smsDispatched: true,
    );

    _notifications.insert(0, newBroadcast);
    notifyListeners();
  }

  /// Batch sync from hospital API / WebSocket stream
  void syncHospitalBroadcasts(List<BloodBroadcastNotification> incoming) {
    _notifications.clear();
    _notifications.addAll(incoming);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}