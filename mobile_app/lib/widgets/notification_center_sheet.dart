import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/app_notification_service.dart';
import '../screens/orders/track_order_screen.dart';

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationCenterSheet(),
    );
  }

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  final AppNotificationService _service = AppNotificationService();
  NotificationCategory _selectedCat = NotificationCategory.all;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    // Fetch latest notifications from backend immediately on open
    _service.syncRemoteNotifications();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final allList = _service.notifications;
    final filtered = allList.where((n) {
      if (_selectedCat == NotificationCategory.all) return true;
      if (_selectedCat == NotificationCategory.orders) return n.category == 'ORDERS';
      if (_selectedCat == NotificationCategory.payouts) return n.category == 'PAYOUTS';
      if (_selectedCat == NotificationCategory.system) return n.category == 'SYSTEM';
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryGreen, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notification Center',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${_service.unreadCount} Unread Alerts',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (allList.isNotEmpty) ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _service.markAllAsRead(),
                    child: const Text('Read All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                  ),
                  const SizedBox(width: 2),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _service.clearAll(),
                    child: Text('Delete All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildCatChip('All (${allList.length})', NotificationCategory.all),
                const SizedBox(width: 8),
                _buildCatChip('Orders', NotificationCategory.orders),
                const SizedBox(width: 8),
                _buildCatChip('Payouts', NotificationCategory.payouts),
                const SizedBox(width: 8),
                _buildCatChip('System & Updates', NotificationCategory.system),
              ],
            ),
          ),

          const SizedBox(height: 6),
          const Divider(height: 1),

          // List of Notifications
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.notifications_none_rounded, size: 48, color: AppTheme.textSecondary),
                        SizedBox(height: 10),
                        Text('No notifications in this section', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.primaryGreen,
                    onRefresh: () async {
                      await _service.syncRemoteNotifications();
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        return Dismissible(
                          key: Key('notif_${item.id}'),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.open_in_new_rounded, color: AppTheme.primaryGreen, size: 20),
                                SizedBox(width: 8),
                                Text('Swipe to Open', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Swipe to Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                SizedBox(width: 8),
                                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Swipe Right -> Open/Navigate
                              _handleOpenNotification(context, item);
                              return false; // Don't remove on open
                            } else {
                              // Swipe Left -> Dismiss with Undo option
                              final originalIndex = _service.notifications.indexOf(item);
                              await _service.removeNotification(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Dismissed: "${item.title}"'),
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      textColor: AppTheme.primaryGreen,
                                      onPressed: () {
                                        _service.restoreNotification(item, originalIndex);
                                      },
                                    ),
                                  ),
                                );
                              }
                              return true;
                            }
                          },
                          child: _buildNotificationCard(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _handleOpenNotification(BuildContext context, AppNotificationItem item) async {
    _service.markAsRead(item.id);

    // 1. App Update
    if (item.actionType == 'APP_UPDATE' && item.actionUrl != null && item.actionUrl!.isNotEmpty) {
      final uri = Uri.parse(item.actionUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 2. Order Navigation
    String? orderCode;
    if (item.actionUrl != null && item.actionUrl!.contains('code=')) {
      final uri = Uri.tryParse(item.actionUrl!);
      orderCode = uri?.queryParameters['code'];
    } else if (item.id.startsWith('order_')) {
      final parts = item.id.split('_');
      if (parts.length >= 2) orderCode = parts[1];
    } else if (item.body.contains('#PHN-') || item.title.contains('#PHN-')) {
      final match = RegExp(r'#(PHN-[A-Z0-9\-]+)').firstMatch('${item.title} ${item.body}');
      if (match != null) orderCode = match.group(1);
    }

    if (orderCode != null && orderCode.isNotEmpty && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackOrderScreen(initialSaleCode: orderCode),
        ),
      );
      return;
    }

    // 3. Web URL or External Link
    if (item.actionUrl != null && (item.actionUrl!.startsWith('http://') || item.actionUrl!.startsWith('https://'))) {
      final uri = Uri.parse(item.actionUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
  }

  Widget _buildCatChip(String label, NotificationCategory cat) {
    final isSel = _selectedCat == cat;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSel ? Colors.white : AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSel,
      selectedColor: AppTheme.primaryGreen,
      backgroundColor: Colors.grey.shade100,
      onSelected: (val) {
        if (val) setState(() => _selectedCat = cat);
      },
    );
  }

  Widget _buildNotificationCard(AppNotificationItem item) {
    Color iconColor;
    IconData icon;

    switch (item.category) {
      case 'PAYOUTS':
        icon = Icons.currency_rupee_rounded;
        iconColor = Colors.green.shade700;
        break;
      case 'ORDERS':
        icon = Icons.local_shipping_outlined;
        iconColor = Colors.blue.shade700;
        break;
      case 'SYSTEM':
      default:
        icon = item.actionType == 'APP_UPDATE' ? Icons.rocket_launch_rounded : Icons.info_outline_rounded;
        iconColor = item.actionType == 'APP_UPDATE' ? Colors.deepPurple : Colors.orange.shade800;
        break;
    }

    return InkWell(
      onTap: () => _handleOpenNotification(context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.grey.shade50 : AppTheme.primaryGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? Colors.grey.shade200 : AppTheme.primaryGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.bold : FontWeight.w900,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      if (item.actionType == 'APP_UPDATE')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.deepPurple.shade200),
                          ),
                          child: const Text('Update Now →', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
