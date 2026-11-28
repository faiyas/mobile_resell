import 'package:flutter/foundation.dart';

class ApiConfig {
  // Live Server Backend URL (Hosted on Bluehost Ubuntu VPS)
  static const String liveServerUrl = 'https://50-6-206-122.sslip.io/api/v1';

  // Local Development URLs
  static const String localAndroidUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localWebDesktopUrl = 'http://127.0.0.1:8000/api/v1';

  // Toggle this to true if explicitly testing against local Django instance on localhost
  static const bool useLocalInDebug = false;

  /// Returns the active API base URL.
  /// Defaults to the Live Server for both Release and Debug builds,
  /// unless `useLocalInDebug` is explicitly set to true.
  static String get baseUrl {
    if (!kReleaseMode && useLocalInDebug) {
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
