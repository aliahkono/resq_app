import 'package:flutter/material.dart';
import 'package:resq/model/broadcast_notif_model.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialized empty — dynamically populated via hospital dashboard web broadcasts/SMS
  final List<BloodBroadcastNotification> _notifications = [];

  List<BloodBroadcastNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

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