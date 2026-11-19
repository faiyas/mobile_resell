import 'package:flutter/material.dart';

/// Comprehensive Indian Standard Time (IST / UTC+5:30) Engine
class TimeHelper {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Current wall-clock time in Indian Standard Time (IST)
  static DateTime nowIST() {
    return DateTime.now().toUtc().add(istOffset);
  }

  /// Format an ISO timestamp or DateTime to readable Indian Standard Time string
  static String formatToIST(dynamic dateInput, {bool includeTime = true}) {
    if (dateInput == null) return '';

    DateTime dt;
    if (dateInput is DateTime) {
      dt = dateInput.isUtc ? dateInput.add(istOffset) : dateInput;
    } else {
      final parsed = DateTime.tryParse(dateInput.toString());
      if (parsed == null) return dateInput.toString();
      dt = parsed.isUtc ? parsed.add(istOffset) : parsed;
    }

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    if (!includeTime) {
      return '$day $month $year (IST)';
    }

    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour12:$minute $ampm IST';
  }

  /// Evaluates pickup date and preferred slot against current live Indian Standard Time
  static ScheduleEvaluation evaluateSchedule({
    required String? pickupDateStr,
    required String? pickupSlotStr,
    required String status,
  }) {
    final now = nowIST();

    if (pickupDateStr == null || pickupDateStr.trim().isEmpty) {
      return ScheduleEvaluation(
        isOverdue: false,
        isDueToday: false,
        statusLabel: 'UNSCHEDULED',
        alertMessage: 'Pickup slot pending scheduling',
        color: Colors.grey,
        icon: Icons.calendar_today_rounded,
        displaySlot: 'Slot Unscheduled',
      );
    }

    final dateParts = pickupDateStr.split('-');
    DateTime? scheduledDate;
    if (dateParts.length == 3) {
      final y = int.tryParse(dateParts[0]);
      final m = int.tryParse(dateParts[1]);
      final d = int.tryParse(dateParts[2]);
      if (y != null && m != null && d != null) {
        scheduledDate = DateTime.utc(y, m, d);
      }
    } else {
      scheduledDate = DateTime.tryParse(pickupDateStr);
    }

    if (scheduledDate == null) {
      return ScheduleEvaluation(
        isOverdue: false,
        isDueToday: false,
        statusLabel: 'SCHEDULED',
        alertMessage: pickupDateStr,
        color: const Color(0xFF0BAA4B),
        icon: Icons.access_time_rounded,
        displaySlot: pickupSlotStr ?? 'Standard Slot (IST)',
      );
    }

    // Determine slot end time in IST
    final slot = (pickupSlotStr ?? '').toLowerCase();
    int endHour = 18;
    if (slot.contains('morning') || slot.contains('1:00 pm') || slot.contains('1 pm')) {
      endHour = 13; // 1:00 PM IST
    } else if (slot.contains('afternoon') || slot.contains('5:00 pm') || slot.contains('5 pm')) {
      endHour = 17; // 5:00 PM IST
    } else if (slot.contains('evening') || slot.contains('8:00 pm') || slot.contains('8 pm')) {
      endHour = 20; // 8:00 PM IST
    }

    final deadlineIST = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      endHour,
      0,
    );

    final isTerminal = status == 'DEVICE_COLLECTED' ||
        status == 'CUSTOMER_ACCEPTED' ||
        status == 'OWNERSHIP_TRANSFERRED' ||
        status == 'PAYMENT_PENDING' ||
        status == 'PAYMENT_COMPLETED' ||
        status == 'CANCELLED';

    final cleanSlot = pickupSlotStr?.replaceAll('(IST)', '').trim() ?? 'Slot';
    final formattedDate = formatToIST(scheduledDate, includeTime: false);

    if (isTerminal) {
      return ScheduleEvaluation(
        isOverdue: false,
        isDueToday: false,
        statusLabel: 'COMPLETED',
        alertMessage: 'Inspection/Handover Completed',
        color: const Color(0xFF0BAA4B),
        icon: Icons.check_circle_rounded,
        displaySlot: '$formattedDate · $cleanSlot',
      );
    }

    if (now.isAfter(deadlineIST)) {
      final diff = now.difference(deadlineIST);
      String overdueText;
      if (diff.inDays > 0) {
        overdueText = 'OVERDUE BY ${diff.inDays} DAY(S)';
      } else {
        final hrs = diff.inHours < 1 ? 1 : diff.inHours;
        overdueText = 'OVERDUE BY $hrs HR(S)';
      }

      return ScheduleEvaluation(
        isOverdue: true,
        isDueToday: scheduledDate.year == now.year &&
            scheduledDate.month == now.month &&
            scheduledDate.day == now.day,
        statusLabel: 'MISSED SCHEDULE',
        alertMessage: '⚠️ $overdueText · MISSED PICKUP',
        color: const Color(0xFFE53935), // Vivid Alert Red
        icon: Icons.alarm_off_rounded,
        displaySlot: '$formattedDate · $cleanSlot',
        hoursOverdue: diff.inHours,
      );
    }

    // Due today
    if (scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day) {
      return ScheduleEvaluation(
        isOverdue: false,
        isDueToday: true,
        statusLabel: 'DUE TODAY',
        alertMessage: '⚡ Scheduled Today in Indian Standard Time (IST)',
        color: const Color(0xFFD97706), // Amber
        icon: Icons.bolt_rounded,
        displaySlot: 'Today: $cleanSlot (IST)',
      );
    }

    // Upcoming future date
    return ScheduleEvaluation(
      isOverdue: false,
      isDueToday: false,
      statusLabel: 'UPCOMING',
      alertMessage: 'Upcoming Pickup (IST)',
      color: const Color(0xFF0BAA4B), // Emerald Green
      icon: Icons.calendar_month_rounded,
      displaySlot: '$formattedDate · $cleanSlot',
    );
  }
}

class ScheduleEvaluation {
  final bool isOverdue;
  final bool isDueToday;
  final String statusLabel;
  final String alertMessage;
  final Color color;
  final IconData icon;
  final String displaySlot;
  final int hoursOverdue;

  ScheduleEvaluation({
    required this.isOverdue,
    required this.isDueToday,
    required this.statusLabel,
    required this.alertMessage,
    required this.color,
    required this.icon,
    required this.displaySlot,
    this.hoursOverdue = 0,
  });
}
