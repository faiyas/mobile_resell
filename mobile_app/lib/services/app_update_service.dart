import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import 'api_service.dart';
import 'app_notification_service.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String minSupportedVersion;
  final bool isUpdateAvailable;
  final bool isForceUpdate;
  final String apkDownloadUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.isUpdateAvailable,
    required this.isForceUpdate,
    required this.apkDownloadUrl,
    required this.releaseNotes,
  });
}

class AppUpdateService {
  static const String currentVersion = '2.4.0';
  static const String defaultApkUrl = 'https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/downloads/dolly-latest.apk';
  static final ValueNotifier<AppUpdateInfo?> availableUpdateNotifier = ValueNotifier<AppUpdateInfo?>(null);
  static String? _promptedVersionInSession;

  final ApiService _api = ApiService();

  /// Checks if a remote update is available by querying settings / version
  Future<AppUpdateInfo> checkForUpdate() async {
    String remoteVersion = currentVersion;
    String minVersion = currentVersion;
    bool forceUpdate = false;
    String downloadUrl = defaultApkUrl;
    String notes = '• Brand & Model Catalogue CRUD\n• Real-Time Agent History & Lead Pool\n• Live Valuation Simulator\n• Milestone Push Notifications';

    try {
      // Query system settings from backend
      final settings = await _api.getSystemSettings();
      if (settings.isNotEmpty) {
        final rawLatest = settings['latest_version']?.toString().trim() ?? '';
        if (rawLatest.isNotEmpty) remoteVersion = rawLatest;
        final rawMin = settings['min_version']?.toString().trim() ?? '';
        if (rawMin.isNotEmpty) minVersion = rawMin;
        final rawForce = settings['force_update'];
        forceUpdate = rawForce == true || rawForce?.toString().toLowerCase() == 'true';
        if (settings['apk_download_url'] != null && settings['apk_download_url'].toString().trim().isNotEmpty) {
          downloadUrl = settings['apk_download_url'].toString().trim();
        }
        if (settings['release_notes'] != null && settings['release_notes'].toString().trim().isNotEmpty) {
          notes = settings['release_notes'].toString().trim();
        }
      }
    } catch (_) {
      // In case of offline or unreachable, default to current version
    }

    final cleanRemote = _cleanVersion(remoteVersion);
    final isNewer = _compareVersions(cleanRemote, currentVersion) > 0;
    final isBelowMin = _compareVersions(currentVersion, _cleanVersion(minVersion)) < 0;

    final info = AppUpdateInfo(
      latestVersion: cleanRemote,
      minSupportedVersion: _cleanVersion(minVersion),
      isUpdateAvailable: isNewer,
      isForceUpdate: forceUpdate || isBelowMin,
      apkDownloadUrl: downloadUrl,
      releaseNotes: notes,
    );

    // If an update is available, register it in the in-app notification center & trigger system popup!
    if (info.isUpdateAvailable) {
      await AppNotificationService().addNotification(
        id: 'app_update_$cleanRemote',
        title: '🚀 Dolly Update Available (v$cleanRemote)',
        body: 'A new version of Dolly Buyback is ready to install! Tap to update now.\n$notes',
        category: 'SYSTEM',
        actionUrl: downloadUrl,
        actionType: 'APP_UPDATE',
        showSystemNotification: true,
      );
      if (_promptedVersionInSession != cleanRemote || info.isForceUpdate) {
        _promptedVersionInSession = cleanRemote;
        availableUpdateNotifier.value = info;
      }
    }

    return info;
  }

  static String _cleanVersion(String v) {
    return v.trim().replaceFirst(RegExp(r'^[vV]+'), '');
  }

  /// Compares two semver strings (e.g. "2.5.0" vs "2.4.0").
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, and 0 if equal.
  static int _compareVersions(String v1, String v2) {
    try {
      final p1 = _cleanVersion(v1).split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final p2 = _cleanVersion(v2).split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final num1 = i < p1.length ? p1[i] : 0;
        final num2 = i < p2.length ? p2[i] : 0;
        if (num1 != num2) return num1.compareTo(num2);
      }
    } catch (_) {}
    return 0;
  }

  /// Shows the glassmorphic App Update Dialog to the user
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (ctx) => PopScope(
        canPop: !info.isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Available', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('v${info.latestVersion} is now ready', style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What\'s New in this release:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  info.releaseNotes,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              if (info.isForceUpdate) ...[
                const SizedBox(height: 10),
                Text(
                  '⚠️ This update contains critical operational upgrades and is required to continue using Dolly.',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            if (!info.isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final uri = Uri.parse(info.apkDownloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
