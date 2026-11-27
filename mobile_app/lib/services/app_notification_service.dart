import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

enum NotificationCategory {
  all,
  orders,
  payouts,
  system,
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String category; // 'ORDERS', 'PAYOUTS', 'SYSTEM'
  final DateTime timestamp;
  bool isRead;
  final String? actionUrl;
  final String? actionType; // 'APP_UPDATE', 'VIEW_ORDER', 'NONE'

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.actionUrl,
    this.actionType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'actionUrl': actionUrl,
    'actionType': actionType,
  };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    category: json['category'] ?? 'SYSTEM',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    isRead: json['isRead'] ?? false,
    actionUrl: json['actionUrl'],
    actionType: json['actionType'],
  );
}

class AppNotificationService extends ChangeNotifier {
  static final AppNotificationService _instance = AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  static const String _storageKey = 'dolly_in_app_notifications_v1';
  List<AppNotificationItem> _notifications = [];
  bool _initialized = false;

  List<AppNotificationItem> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        _notifications = decoded.map((e) => AppNotificationItem.fromJson(Map<String, dynamic>.from(e))).toList();
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_notifications.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Adds a notification with automatic deduplication (idempotent).
  /// Returns true if newly added, false if already existed.
  Future<bool> addNotification({
    required String id,
    required String title,
    required String body,
    String category = 'SYSTEM',
    String? actionUrl,
    String? actionType,
  }) async {
    await init();

    // Deduplication check: if id already exists, do not add duplicate
    final exists = _notifications.any((n) => n.id == id);
    if (exists) return false;

    final item = AppNotificationItem(
      id: id,
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      actionUrl: actionUrl,
      actionType: actionType,
    );

    _notifications.insert(0, item);
    // Keep max 100 notifications to prevent storage bloat
    if (_notifications.length > 100) {
      _notifications = _notifications.sublist(0, 100);
    }

    await _save();
    notifyListeners();
    return true;
  }

  Future<void> markAsRead(String id) async {
    for (var n in _notifications) {
      if (n.id == id) {
        n.isRead = true;
        break;
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _save();
    notifyListeners();
  }

  /// Automatically generates lifecycle milestone notifications for orders
  /// with 100% deduplication guarantees.
  Future<void> syncOrderNotifications(List<SaleOrderModel> orders, {bool isAgent = false}) async {
    await init();
    for (var order in orders) {
      final orderCode = order.saleCode.isNotEmpty ? order.saleCode : '#${order.id}';
      final devName = '${order.brandName} ${order.modelName}'.trim();

      // Milestone 1: Order Submitted
      if (order.status == 'SUBMITTED') {
        await addNotification(
          id: 'order_${order.id}_SUBMITTED',
          title: 'Order $orderCode Submitted',
          body: 'Your device $devName sell request has been received. Pickup will be assigned shortly.',
          category: 'ORDERS',
          actionType: 'VIEW_ORDER',
        );
      }

      // Milestone 2: Pickup Scheduled / Agent Assigned
      if (order.status == 'PICKUP_SCHEDULED') {
        final agentName = order.assignedAgentName ?? 'a field specialist';
        await addNotification(
          id: 'order_${order.id}_PICKUP_SCHEDULED',
          title: 'Specialist Assigned ($orderCode)',
          body: isAgent
              ? 'New pickup in ${order.pickupCity} on ${order.pickupDate ?? "today"} (${order.pickupSlot ?? "Standard"}).'
              : '$agentName has been assigned to inspect and collect your $devName.',
          category: 'ORDERS',
          actionType: 'VIEW_ORDER',
        );
      }

      // Milestone 3: Inspection Completed / Offer Sent
      if (order.status == 'FINAL_OFFER_SENT') {
        final offerAmt = order.finalPrice ?? order.estimatedPrice;
        await addNotification(
          id: 'order_${order.id}_FINAL_OFFER_SENT',
          title: 'Final Offer Ready ($orderCode)',
          body: 'Doorstep inspection completed. Revised valuation of ₹${offerAmt.toStringAsFixed(0)} awaits your confirmation.',
          category: 'ORDERS',
          actionType: 'VIEW_ORDER',
        );
      }

      // Milestone 4: Customer Accepted Offer
      if (order.status == 'CUSTOMER_ACCEPTED' || order.status == 'OWNERSHIP_TRANSFERRED') {
        await addNotification(
          id: 'order_${order.id}_ACCEPTED',
          title: 'Offer Accepted ($orderCode)',
          body: isAgent
              ? 'Customer confirmed the valuation. Proceed with device collection and handover.'
              : 'Valuation accepted! Device handover recorded and payout queued for disbursement.',
          category: 'ORDERS',
          actionType: 'VIEW_ORDER',
        );
      }

      // Milestone 5: Payment Completed
      if (order.status == 'PAYMENT_COMPLETED') {
        final amt = order.finalPrice ?? order.estimatedPrice;
        await addNotification(
          id: 'order_${order.id}_PAYMENT_COMPLETED',
          title: 'Payout Disbursed (₹${amt.toStringAsFixed(0)})',
          body: 'Funds credited for $orderCode to your account/UPI. Thank you for using Dolly!',
          category: 'PAYOUTS',
          actionType: 'VIEW_ORDER',
        );
      }
    }
  }
}
