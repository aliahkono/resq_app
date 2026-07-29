/// Utility class for consistent date, time, and countdown formatting across ResQ.
class DateFormatter {
  DateFormatter._();

  static const List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Formats date to: "August 18, 2026"
  static String formatFullDate(DateTime date) {
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  /// Formats date to: "Aug 18, 2026"
  static String formatShortDate(DateTime date) {
    final month = shortMonths[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  /// Formats date to: "08/18/2026" or "MM/dd/yyyy"
  static String formatNumericDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  /// Formats time to 12-hour format: "09:30 AM" or "02:15 PM"
  static String formatTime12Hour(DateTime date) {
    int hour = date.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    final String minute = date.minute.toString().padLeft(2, '0');
    final String formattedHour = hour.toString().padLeft(2, '0');

    return '$formattedHour:$minute $period';
  }

  /// Formats appointment slot header: "Saturday, July 23, 2026 • 09:30 AM"
  static String formatAppointmentHeader(DateTime date) {
    final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[date.weekday - 1];
    return '$dayName, ${formatFullDate(date)} • ${formatTime12Hour(date)}';
  }

  /// Returns remaining days countdown text: "27 Days Remaining" or "Eligible Today"
  static String formatRemainingDaysText(DateTime targetClearanceDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final clearanceDay = DateTime(targetClearanceDate.year, targetClearanceDate.month, targetClearanceDate.day);

    final difference = clearanceDay.difference(today).inDays;

    if (difference <= 0) {
      return "Eligible Today";
    } else if (difference == 1) {
      return "1 Day Remaining";
    } else {
      return "$difference Days Remaining";
    }
  }

  /// Formats time elapsed for request feeds: "Just now", "15m ago", "2h ago", or "3d ago"
  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return formatShortDate(date);
    }
  }
}