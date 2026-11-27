import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_notification_service.dart';
import 'app_update_service.dart';

class BackgroundNotificationRunner {
  static final BackgroundNotificationRunner _instance = BackgroundNotificationRunner._internal();
  factory BackgroundNotificationRunner() => _instance;
  BackgroundNotificationRunner._internal();

  Timer? _pollingTimer;
  bool _isRunning = false;

  /// Starts the pure Flutter background polling runner
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Run first check after 3 seconds
    Future.delayed(const Duration(seconds: 3), () => _runCheck());

    // Periodic check every 25 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) => _runCheck());
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
  }

  Future<void> _runCheck() async {
    try {
      // 1. Check for remote app updates from server settings
      final updateInfo = await AppUpdateService().checkForUpdate();
      if (updateInfo.isUpdateAvailable) {
        final updateId = 'sys_app_update_v${updateInfo.latestVersion}';
        await AppNotificationService().addNotification(
          id: updateId,
          title: 'Dolly Update Available (v${updateInfo.latestVersion})',
          body: 'A new version of Dolly is available. Tap here to download and install.',
          category: 'SYSTEM',
          actionUrl: updateInfo.apkDownloadUrl,
          actionType: 'APP_UPDATE',
          showSystemNotification: true,
        );
      }

      // 2. Check for order status changes if logged in
      final api = ApiService();
      if (api.currentUser != null) {
        final sales = await api.getSales();
        if (sales.isNotEmpty) {
          final isAgent = api.currentUser?.isAgent == true;
          await AppNotificationService().syncOrderNotifications(sales, isAgent: isAgent);
        }
      }

      // 3. Sync remote broadcast notifications from backend API
      await AppNotificationService().syncRemoteNotifications();
    } catch (e) {
      debugPrint('Background notification runner cycle: $e');
    }
  }
}
