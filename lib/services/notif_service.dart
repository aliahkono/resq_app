import 'package:flutter/material.dart';
import 'package:resq/model/broadcast_notif_model.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<BloodBroadcastNotification> _notifications = [
    BloodBroadcastNotification(
      id: 'BCAST-101',
      hospitalName: 'Quezon Medical Center (QMC)',
      bloodType: 'O+',
      unitsNeeded: 4,
      urgency: UrgencyLevel.critical,
      location: 'Lucena City (1.2 km)',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      isRead: false,
    ),
    BloodBroadcastNotification(
      id: 'BCAST-102',
      hospitalName: 'Philippine Red Cross - Quezon',
      bloodType: 'A+',
      unitsNeeded: 2,
      urgency: UrgencyLevel.urgent,
      location: 'Quezon Ave (2.5 km)',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    BloodBroadcastNotification(
      id: 'BCAST-103',
      hospitalName: 'St. Anne General Hospital',
      bloodType: 'O+',
      unitsNeeded: 1,
      urgency: UrgencyLevel.normal,
      location: 'Gulang-Gulang (3.8 km)',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
  ];

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

  /// Triggered when the Hospital Web Dashboard dispatches an SMS & Web Push
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
}