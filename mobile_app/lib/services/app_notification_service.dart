import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'api_service.dart';

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
  static final ValueNotifier<Map<String, dynamic>?> tapPayloadNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  List<AppNotificationItem> _notifications = [];
  bool _initialized = false;
  bool _localNotificationsReady = false;

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

    await _initLocalNotifications();
    _initialized = true;
    notifyListeners();

    // Trigger asynchronous remote sync
    syncRemoteNotifications();
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          _handleNotificationTapPayload(response.payload);
        },
      );

      // Check if app was launched from a closed-state notification tap
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true && launchDetails?.notificationResponse?.payload != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNotificationTapPayload(launchDetails!.notificationResponse!.payload);
        });
      }

      // Request Android 13+ runtime notification permission
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }

      _localNotificationsReady = true;
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
  }

  void _handleNotificationTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        tapPayloadNotifier.value = Map<String, dynamic>.from(decoded);
        return;
      }
    } catch (_) {}
    tapPayloadNotifier.value = {'actionUrl': payload, 'actionType': ''};
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
  /// Also fires a native Android system notification into the status bar.
  Future<bool> addNotification({
    required String id,
    required String title,
    required String body,
    String category = 'SYSTEM',
    String? actionUrl,
    String? actionType,
    bool showSystemNotification = true,
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

    // Trigger native Android system notification popup
    if (showSystemNotification) {
      _showNativePopup(item);
    }

    return true;
  }

  Future<void> _showNativePopup(AppNotificationItem item) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'dolly_alerts_channel',
        'Dolly Alerts & Updates',
        channelDescription: 'Order status changes, payouts, and system updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      final notifId = item.id.hashCode & 0x7FFFFFFF;
      final payloadJson = jsonEncode({
        'id': item.id,
        'actionType': item.actionType ?? '',
        'actionUrl': item.actionUrl ?? '',
        'title': item.title,
        'body': item.body,
      });
      await _localNotifications.show(
        id: notifId,
        title: item.title,
        body: item.body,
        notificationDetails: notificationDetails,
        payload: payloadJson,
      );
    } catch (e) {
      debugPrint('Error showing native notification popup: $e');
    }
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

  Future<void> _recordDismissedId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dolly_dismissed_notif_ids_v1') ?? [];
      if (!list.contains(id)) {
        list.add(id);
        if (list.length > 250) list.removeRange(0, list.length - 250);
        await prefs.setStringList('dolly_dismissed_notif_ids_v1', list);
      }
    } catch (_) {}
  }

  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _recordDismissedId(id);
    await _save();
    notifyListeners();
  }

  Future<void> restoreNotification(AppNotificationItem item, int index) async {
    if (index >= 0 && index <= _notifications.length) {
      _notifications.insert(index, item);
    } else {
      _notifications.add(item);
    }
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final n in _notifications) {
      await _recordDismissedId(n.id);
    }
    _notifications.clear();
    await _save();
    notifyListeners();
  }

  /// Syncs notifications from server into device storage, then acks delivery
  Future<void> syncRemoteNotifications() async {
    if (!_initialized) {
      await init();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dolly_dismissed_notif_ids_v1') ?? [];
      final dismissedSet = dismissedList.toSet();
      final res = await ApiService().getNotifications();
      final results = res['results'];
      if (results is List && results.isNotEmpty) {
        bool hasNew = false;
        final List<int> ackIds = [];
        for (var item in results) {
          if (item is! Map) continue;
          final idNum = item['id'];
          final parsedInt = int.tryParse(idNum?.toString() ?? '');
          if (parsedInt != null) ackIds.add(parsedInt);
          final notifId = 'remote_$idNum';
          if (dismissedSet.contains(notifId)) continue;
          final exists = _notifications.any((n) => n.id == notifId);
          if (!exists) {
            final parsedTime = item['created_at'] != null 
                ? (DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()) 
                : DateTime.now();
            final newItem = AppNotificationItem(
              id: notifId,
              title: item['title']?.toString() ?? 'Notification',
              body: item['message']?.toString() ?? '',
              category: item['category']?.toString() ?? 'SYSTEM',
              timestamp: parsedTime,
              isRead: item['is_read'] == true,
              actionUrl: item['redirect_route']?.toString(),
              actionType: item['action_type']?.toString(),
            );
            _notifications.insert(0, newItem);
            hasNew = true;
            if (!newItem.isRead) {
              _showNativePopup(newItem);
            }
          }
        }
        if (ackIds.isNotEmpty) {
          ApiService().ackNotifications(ackIds);
        }
        if (hasNew) {
          _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          if (_notifications.length > 100) {
            _notifications = _notifications.sublist(0, 100);
          }
          await _save();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error syncing remote notifications: $e');
    }
  }

  /// Syncs order status changes into notifications for Customer or Field Agent
  Future<void> syncOrderNotifications(List<SaleOrderModel> orders, {bool isAgent = false}) async {
    for (final order in orders) {
      final code = order.saleCode;
      final status = order.status;
      final model = '${order.brandName} ${order.modelName}'.trim();

      String notifId = 'order_${code}_$status';
      String title = '';
      String body = '';
      String category = 'ORDERS';

      switch (status) {
        case 'SUBMITTED':
          if (!isAgent) {
            title = 'Order Request Placed';
            body = 'Your buyback order #$code for $model has been created and is waiting for pickup scheduling.';
          }
          break;
        case 'PICKUP_SCHEDULED':
          if (isAgent) {
            title = 'New Pickup Assigned';
            body = 'Order #$code for $model has been assigned to your doorstep inspection queue.';
          } else {
            title = 'Pickup Scheduled';
            body = 'A Dolly executive has scheduled doorstep verification for $model (#$code).';
          }
          break;
        case 'DEVICE_COLLECTED':
          title = isAgent ? 'Device Handed Over' : 'Device Verified & Collected';
          body = 'Physical QC passed for $model (#$code). Device is in custody.';
          break;
        case 'OWNERSHIP_TRANSFERRED':
          title = 'Transfer Receipt Generated';
          body = 'Ownership transfer complete for $model (#$code). Payout is queued.';
          break;
        case 'PAYMENT_COMPLETED':
          category = 'PAYOUTS';
          final amt = (order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0);
          title = 'Payout Disbursed (₹$amt)';
          body = 'Payment for $model (#$code) has been disbursed successfully to the registered UPI.';
          break;
        case 'CANCELLED':
          title = 'Order Cancelled';
          body = 'Order #$code for $model has been cancelled.';
          break;
        case 'CUSTOMER_REJECTED':
          title = 'Order Inspection Cancelled';
          body = 'Doorstep quotation for $model (#$code) was rejected.';
          break;
        default:
          break;
      }

      if (title.isNotEmpty && body.isNotEmpty) {
        await addNotification(
          id: notifId,
          title: title,
          body: body,
          category: category,
          actionType: 'VIEW_ORDER',
        );
      }
    }
  }
}
