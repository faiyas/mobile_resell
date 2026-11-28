import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class ServerUnavailableSheet extends StatefulWidget {
  final String contextTag;

  const ServerUnavailableSheet({super.key, this.contextTag = 'general'});

  static bool _isShowing = false;

  static Future<void> show(BuildContext context, {String contextTag = 'general'}) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ServerUnavailableSheet(contextTag: contextTag),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<ServerUnavailableSheet> createState() => _ServerUnavailableSheetState();
}

class _ServerUnavailableSheetState extends State<ServerUnavailableSheet> {
  Map<String, dynamic> _biz = {};
  bool _retrying = false;
  bool _retryFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCachedBusiness();
  }

  Future<void> _loadCachedBusiness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dolly_cached_business_settings');
      if (raw != null && raw.isNotEmpty && mounted) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          setState(() => _biz = Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}
  }

  Future<void> _retryHealth() async {
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final ok = await ApiService().pingHealth();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Connected! You can proceed now.'), backgroundColor: AppTheme.darkGreen),
      );
    } else {
      setState(() {
        _retrying = false;
        _retryFailed = true;
      });
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final helpline = (_biz['customer_helpline']?.toString().trim().isNotEmpty == true)
        ? _biz['customer_helpline'].toString().trim()
        : '+91 99885 52211';
    final waRaw = (_biz['whatsapp_number']?.toString().trim().isNotEmpty == true
            ? _biz['whatsapp_number'].toString()
            : helpline)
        .replaceAll(RegExp(r'\D'), '');
    final waNum = waRaw.length == 10 ? '91$waRaw' : waRaw;
    final email = (_biz['support_email']?.toString().trim().isNotEmpty == true)
        ? _biz['support_email'].toString().trim()
        : 'support@dollyresell.com';
    final company = _biz['company_name']?.toString() ?? 'Dolly Support';

    final isOrder = widget.contextTag.contains('order');
    final isAuth = widget.contextTag.contains('auth');
    final waText = Uri.encodeComponent(
      isOrder
          ? 'Hi $company, I tried placing a buyback order on the mobile app, but the server is temporarily unavailable. Please help me complete my pickup.'
          : isAuth
              ? 'Hi $company, I am unable to sign in/register right now as the server appears offline. Please assist.'
              : 'Hi $company, the app server is temporarily unavailable. Please assist.',
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.cloud_off_rounded, color: AppTheme.primaryGreen, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "We'll be back shortly",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Live services are temporarily paused. Your selections are safe.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_retryFailed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Server is still waking up. Try again shortly or contact our team below.',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.brown),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _retrying ? null : _retryHealth,
                  icon: _retrying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_retrying ? 'Checking...' : 'Try Again', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue Browsing', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'CONTACT ADMIN DIRECTLY',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.emerald.shade200)),
            tileColor: Colors.green.shade50,
            leading: const Icon(Icons.chat_rounded, color: AppTheme.primaryGreen),
            title: Text('WhatsApp Admin ($helpline)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _launch('https://wa.me/$waNum?text=$waText'),
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            leading: const Icon(Icons.call_rounded, color: AppTheme.textPrimary),
            title: Text('Call Helpline ($helpline)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _launch('tel:${helpline.replaceAll(RegExp(r'\s+'), '')}'),
          ),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            leading: const Icon(Icons.email_outlined, color: AppTheme.textPrimary),
            title: Text(email, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _launch('mailto:$email'),
          ),
        ],
      ),
    );
  }
}
