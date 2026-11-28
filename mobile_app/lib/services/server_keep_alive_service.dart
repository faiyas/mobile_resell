import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

@pragma('vm:entry-point')
void startKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(ServerKeepAliveTaskHandler());
}

class ServerKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _pingServer();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _pingServer();
  }

  Future<void> _pingServer() async {
    try {
      // Quick internet connectivity check before hitting the API
      final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      if (lookup.isEmpty || lookup.first.rawAddress.isEmpty) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/health/');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      final now = DateTime.now();
      final hh = now.hour.toString().padLeft(2, '0');
      final mm = now.minute.toString().padLeft(2, '0');

      FlutterForegroundTask.updateService(
        notificationTitle: 'Dolly Server Keep-Alive Active',
        notificationText: res.statusCode == 200
            ? 'Server online · Last ping $hh:$mm'
            : 'Ping status ${res.statusCode} at $hh:$mm',
      );
    } catch (e) {
      debugPrint('Keep-alive ping error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class ServerKeepAliveService {
  static final ServerKeepAliveService _instance = ServerKeepAliveService._internal();
  factory ServerKeepAliveService() => _instance;
  ServerKeepAliveService._internal();

  static const String _prefKey = 'dolly_admin_keep_alive_enabled';
  bool _initialized = false;

  void initForegroundTask() {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dolly_keep_alive_channel',
        channelName: 'Dolly Server Keep-Alive',
        channelDescription: 'Keeps the Dolly backend server awake with a 1-minute health ping',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // Every 1 minute
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<bool> isRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return await FlutterForegroundTask.isRunningService;
  }

  Future<void> restoreIfEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return;
    initForegroundTask();
    if (await isEnabled() && !(await isRunning())) {
      await start();
    }
  }

  /// Requests notification & battery optimization exemption, then starts 1-minute background ping
  Future<bool> start() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    initForegroundTask();

    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 1103,
      notificationTitle: 'Dolly Server Keep-Alive Active',
      notificationText: 'Pinging server every 1 minute to prevent sleep...',
      callback: startKeepAliveCallback,
    );
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    if (!kIsWeb && Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
