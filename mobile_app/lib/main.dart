import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecellApp());
}

class RecellApp extends StatelessWidget {
  const RecellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1103 RECELL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
