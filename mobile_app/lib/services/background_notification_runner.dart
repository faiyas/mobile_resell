import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_notification_service.dart';
import 'app_update_service.dart';

class BackgroundNotificationRunner {
  static final BackgroundNotificationRunner _instance = BackgroundNotificationRunner._internal();
  factory BackgroundNotificationRunner() => _instance;
  BackgroundNotificationRunner._internal();

  bool _started = false;

  /// On-demand sync on app boot / resume (no continuous background polling)
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await AppNotificationService().init();
    Future.delayed(const Duration(seconds: 2), () => runBackgroundSyncCycle());
  }

  void stop() {
    _started = false;
  }

  static Future<void> runBackgroundSyncCycle() async {
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
      debugPrint('Notification sync cycle: $e');
    }
  }
}
