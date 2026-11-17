import 'package:flutter/foundation.dart';

class ApiConfig {
  // Change this to your deployed backend URL or local IP address
  // Android Emulator: 10.0.2.2:8000
  // iOS Simulator / Web / Desktop: 127.0.0.1:8000 or localhost:8000
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    } else {
      return 'http://127.0.0.1:8000/api';
    }
  }

  // Fallback production URL if needed
  static const String fallbackProductionUrl = 'https://mobile-resell.vercel.app/api';
}
