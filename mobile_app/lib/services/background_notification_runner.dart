import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'app_notification_service.dart';
import 'app_update_service.dart';

const String _bgSyncTaskName = 'dollyBackgroundSyncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await ApiService().init();
      await AppNotificationService().init();
      await BackgroundNotificationRunner.runBackgroundSyncCycle();
    } catch (e) {
      debugPrint('WorkManager background sync error: $e');
    }
    return Future.value(true);
  });
}

class BackgroundNotificationRunner {
  static final BackgroundNotificationRunner _instance = BackgroundNotificationRunner._internal();
  factory BackgroundNotificationRunner() => _instance;
  BackgroundNotificationRunner._internal();

  Timer? _pollingTimer;
  bool _isRunning = false;
  bool _workmanagerInitialized = false;

  /// Starts both foreground polling (15s) and closed-app WorkManager sync (15m)
  Future<void> start() async {
    if (!_workmanagerInitialized) {
      try {
        await Workmanager().initialize(callbackDispatcher);
        await Workmanager().registerPeriodicTask(
          'dolly_bg_notif_sync',
          _bgSyncTaskName,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
        _workmanagerInitialized = true;
      } catch (e) {
        debugPrint('Workmanager init error (non-mobile or already registered): $e');
      }
    }

    if (_isRunning) return;
    _isRunning = true;
    AppNotificationService().init();

    // Run first check after 2 seconds
    Future.delayed(const Duration(seconds: 2), () => runBackgroundSyncCycle());

    // Periodic check every 15 seconds for near-real-time web-to-mobile sync while open
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) => runBackgroundSyncCycle());
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
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
      debugPrint('Background notification runner cycle: $e');
    }
  }
}
