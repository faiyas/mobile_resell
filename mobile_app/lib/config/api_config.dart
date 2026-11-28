import 'package:flutter/foundation.dart';

class ApiConfig {
  // Live Server Backend URL (Hosted on Bluehost Ubuntu VPS)
  static const String liveServerUrl = 'https://50-6-206-122.sslip.io/api/v1';

  // Local Development URLs (override with --dart-define=LOCAL_API_URL=http://192.168.x.x:8000/api/v1)
  static const String localAndroidUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localWebDesktopUrl = 'http://127.0.0.1:8000/api/v1';
  static const String customLocalUrl = String.fromEnvironment('LOCAL_API_URL', defaultValue: '');

  // Pass --dart-define=USE_LOCAL=true when running locally so debug builds never touch production
  static const bool useLocalInDebug = bool.fromEnvironment('USE_LOCAL', defaultValue: false);

  /// Returns the active API base URL.
  /// Release builds ALWAYS use liveServerUrl; Debug builds use local when USE_LOCAL=true.
  static String get baseUrl {
    if (!kReleaseMode && useLocalInDebug) {
      if (customLocalUrl.isNotEmpty) return customLocalUrl;
      if (kIsWeb) {
        return localWebDesktopUrl;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        return localAndroidUrl;
      } else {
        return localWebDesktopUrl;
      }
    }
    return liveServerUrl;
  }

  // Fallback production URL
  static const String fallbackProductionUrl = liveServerUrl;
}
