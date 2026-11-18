import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactLauncher {
  static const String hotline = '+919025232453';
  static const String displayPhone = '+91 90252 32453';
  static const String email = 'aiothamizha@gmail.com';

  /// Automatically launches the phone dialer with +91 90252 32453
  static Future<void> callHotline(BuildContext context) async {
    final uri = Uri.parse('tel:$hotline');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyAndNotify(context, hotline, 'Phone number copied to clipboard');
      }
    } catch (_) {
      _copyAndNotify(context, hotline, 'Phone number copied to clipboard');
    }
  }

  /// Automatically launches the phone dialer to call a customer directly
  static Future<void> callCustomer(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyAndNotify(context, phone, 'Customer phone number copied to clipboard');
      }
    } catch (_) {
      _copyAndNotify(context, phone, 'Customer phone number copied to clipboard');
    }
  }

  /// Automatically launches the default mail client with To: aiothamizha@gmail.com
  static Future<void> sendEmail(
    BuildContext context, {
    String subject = '1103 RECELL Customer Support Request',
    String body = 'Hello 1103 RECELL Team,\n\nI need assistance with: ',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyAndNotify(context, email, 'Email copied to clipboard');
      }
    } catch (_) {
      _copyAndNotify(context, email, 'Email copied to clipboard');
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
