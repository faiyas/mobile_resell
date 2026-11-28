import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminNotificationsView extends StatefulWidget {
  const AdminNotificationsView({super.key});

  @override
  State<AdminNotificationsView> createState() => _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  final ApiService _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();

  String _audience = 'ALL';
  String _category = 'SYSTEM';
  bool _sending = false;
  bool _loadingHistory = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await _api.getNotifications();
      final results = res['results'];
      if (mounted) {
        setState(() {
          _history = results is List
              ? results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _titleCtrl.text.trim();
    final msg = _messageCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Title and Message'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _api.broadcastNotification({
        'title': title,
        'message': msg,
        'target_audience': _audience,
        'category': _category,
        'redirect_route': _routeCtrl.text.trim(),
      });
      if (!mounted) return;
      _titleCtrl.clear();
      _messageCtrl.clear();
      _routeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Notification broadcast sent to mobile & web users!'),
          backgroundColor: AppTheme.darkGreen,
        ),
      );
      _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        const Text(
          'COMMUNICATIONS & ALERTS',
          style: TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        const SizedBox(height: 2),
        const Text(
          'Push Notification Desk',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.5),
        ),
        const SizedBox(height: 14),

        GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Compose Broadcast', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _audience,
                      decoration: InputDecoration(
                        labelText: 'Audience',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Users')),
                        DropdownMenuItem(value: 'CUSTOMERS', child: Text('Customers Only')),
                        DropdownMenuItem(value: 'AGENTS', child: Text('Field Agents')),
                      ],
                      onChanged: (v) => setState(() => _audience = v ?? 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'SYSTEM', child: Text('System / News')),
                        DropdownMenuItem(value: 'ORDERS', child: Text('Orders')),
                        DropdownMenuItem(value: 'PAYOUTS', child: Text('Payouts')),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? 'SYSTEM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Notification Title *',
                  hintText: 'e.g. Weekend Bonus Offer!',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message Body *',
                  hintText: 'Enter announcement or operational notice...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _routeCtrl,
                decoration: InputDecoration(
                  labelText: 'Redirect Route / URL (Optional)',
                  hintText: 'e.g. /track?code=PHN-1234 or https://...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _sending ? null : _sendBroadcast,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Sending...' : 'Send Broadcast', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Dispatches', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
            IconButton(onPressed: _loadHistory, icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.primaryGreen)),
          ],
        ),
        if (_loadingHistory)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          )
        else if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No notifications dispatched yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          )
        else
          ..._history.take(25).map((n) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GlassContainer(
                borderRadius: 14,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n['title']?.toString() ?? 'Notification',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${n['target_audience'] ?? 'ALL'} · ${n['category'] ?? 'SYSTEM'}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.darkGreen),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['message']?.toString() ?? '',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
