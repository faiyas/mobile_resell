import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';
import 'services/app_notification_service.dart';
import 'services/app_update_service.dart';
import 'services/background_notification_runner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotificationService().init();
  BackgroundNotificationRunner().start();
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
  }

  @override
  void dispose() {
    AppUpdateService.availableUpdateNotifier.removeListener(_onUpdateAvailable);
    super.dispose();
  }

  void _onUpdateAvailable() {
    final info = AppUpdateService.availableUpdateNotifier.value;
    final ctx = RecellApp.navigatorKey.currentContext;
    if (info != null && info.isUpdateAvailable && ctx != null) {
      AppUpdateService.showUpdateDialog(ctx, info);
      AppUpdateService.availableUpdateNotifier.value = null;
    }
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
