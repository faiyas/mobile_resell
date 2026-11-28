import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ContactLauncher {
  static const String defaultPhone = '+91 90252 32453';
  static const String defaultEmail = 'aiothamizha@gmail.com';

  static String _displayPhone = defaultPhone;
  static String _email = defaultEmail;

  static String get displayPhone => _displayPhone;
  static String get hotline => _displayPhone.replaceAll(RegExp(r'[^\d+]'), '');
  static String get email => _email;

  static Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dolly_cached_business_settings');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw);
        if (map is Map) {
          _applyMap(map);
        }
      }
    } catch (_) {}
  }

  static Future<void> refreshFromServer() async {
    await loadCached();
    try {
      final map = await ApiService().getBusinessSettings();
      if (map.isNotEmpty) {
        _applyMap(map);
      }
    } catch (_) {}
  }

  static void _applyMap(Map map) {
    final phone = map['customer_helpline']?.toString().trim() ?? '';
    final mail = map['support_email']?.toString().trim() ?? '';
    if (phone.isNotEmpty) _displayPhone = phone;
    if (mail.isNotEmpty) _email = mail;
  }

  /// Automatically launches the phone dialer with the configured support number
  static Future<void> callHotline(BuildContext context) async {
    await loadCached();
    final cleaned = hotline;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _copyAndNotify(context, _displayPhone, 'Phone number copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        _copyAndNotify(context, _displayPhone, 'Phone number copied to clipboard');
      }
    }
  }

  /// Automatically launches the phone dialer to call a customer directly
  static Future<void> callCustomer(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _copyAndNotify(context, phone, 'Customer phone number copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        _copyAndNotify(context, phone, 'Customer phone number copied to clipboard');
      }
    }
  }

  /// Automatically launches the default mail client with To: configured support email
  /// Uses RFC 3986 percent-encoding (%20) so email clients like Gmail show natural spaces without '+'
  static Future<void> sendEmail(
    BuildContext context, {
    String subject = 'Dolly Customer Support Request',
    String body = 'Hello Dolly Support Team,\n\nI need assistance with: ',
  }) async {
    await loadCached();
    final targetEmail = _email.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: targetEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        _copyAndNotify(context, targetEmail, 'Email copied to clipboard');
      }
    } catch (_) {
      if (context.mounted) {
        _copyAndNotify(context, targetEmail, 'Email copied to clipboard');
      }
    }
  }

  static void _copyAndNotify(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $message! ($text)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
