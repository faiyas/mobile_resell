import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/theme.dart';
import 'screens/orders/track_order_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/app_notification_service.dart';
import 'services/app_update_service.dart';
import 'services/background_notification_runner.dart';
import 'widgets/notification_center_sheet.dart';
import 'widgets/server_unavailable_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotificationService().init();
  await BackgroundNotificationRunner().start();
  runApp(const RecellApp());
}

class RecellApp extends StatefulWidget {
  const RecellApp({super.key});
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<RecellApp> createState() => _RecellAppState();
}

class _RecellAppState extends State<RecellApp> {
  @override
  void initState() {
    super.initState();
    AppUpdateService.availableUpdateNotifier.addListener(_onUpdateAvailable);
    AppNotificationService.tapPayloadNotifier.addListener(_onNotificationTapped);
    ApiService.serverUnavailableNotifier.addListener(_onServerUnavailable);
  }

  @override
  void dispose() {
    AppUpdateService.availableUpdateNotifier.removeListener(_onUpdateAvailable);
    AppNotificationService.tapPayloadNotifier.removeListener(_onNotificationTapped);
    ApiService.serverUnavailableNotifier.removeListener(_onServerUnavailable);
    super.dispose();
  }

  void _onServerUnavailable() {
    final tag = ApiService.serverUnavailableNotifier.value;
    final ctx = RecellApp.navigatorKey.currentContext;
    if (tag != null && ctx != null) {
      ApiService.serverUnavailableNotifier.value = null;
      ServerUnavailableSheet.show(ctx, contextTag: tag);
    }
  }

  void _onUpdateAvailable() {
    final info = AppUpdateService.availableUpdateNotifier.value;
    final ctx = RecellApp.navigatorKey.currentContext;
    if (info != null && info.isUpdateAvailable && ctx != null) {
      AppUpdateService.showUpdateDialog(ctx, info);
      AppUpdateService.availableUpdateNotifier.value = null;
    }
  }

  Future<void> _onNotificationTapped() async {
    final payload = AppNotificationService.tapPayloadNotifier.value;
    if (payload == null) return;
    AppNotificationService.tapPayloadNotifier.value = null;

    final notifId = payload['id']?.toString() ?? '';
    if (notifId.isNotEmpty) {
      AppNotificationService().markAsRead(notifId);
    }

    final actionType = payload['actionType']?.toString().toUpperCase() ?? '';
    final actionUrl = payload['actionUrl']?.toString().trim() ?? '';
    final ctx = RecellApp.navigatorKey.currentContext;
    final nav = RecellApp.navigatorKey.currentState;
    if (ctx == null || nav == null) return;

    if (actionType == 'APP_UPDATE') {
      final info = await AppUpdateService().checkForUpdate();
      if (info.isUpdateAvailable && RecellApp.navigatorKey.currentContext != null) {
        AppUpdateService.showUpdateDialog(RecellApp.navigatorKey.currentContext!, info);
        return;
      }
      if (actionUrl.startsWith('http')) {
        final uri = Uri.tryParse(actionUrl);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return;
    }

    if (actionType == 'VIEW_ORDER' || actionUrl.contains('/track') || actionUrl.startsWith('PHN-')) {
      String code = '';
      if (actionUrl.contains('code=')) {
        code = Uri.tryParse(actionUrl)?.queryParameters['code'] ?? '';
      }
      if (code.isEmpty) {
        final match = RegExp(r'PHN-[A-Z0-9-]+', caseSensitive: false).firstMatch(actionUrl);
        code = match?.group(0) ?? actionUrl;
      }
      nav.push(MaterialPageRoute(builder: (_) => TrackOrderScreen(initialSaleCode: code.isNotEmpty ? code : null)));
      return;
    }

    if (actionUrl.startsWith('http://') || actionUrl.startsWith('https://')) {
      final uri = Uri.tryParse(actionUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    NotificationCenterSheet.show(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: RecellApp.navigatorKey,
      title: 'Dolly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
