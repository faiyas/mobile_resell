import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../widgets/glass_container.dart';

class AdminOperationsView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final List<AgentUserModel> agents;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(SaleOrderModel, String) onUpdateStatus;
  final Function(SaleOrderModel, dynamic) onAssignAgent;

  const AdminOperationsView({
    super.key,
    required this.orders,
    required this.agents,
    required this.isLoading,
    required this.onRefresh,
    required this.onUpdateStatus,
    required this.onAssignAgent,
  });

  @override
  State<AdminOperationsView> createState() => _AdminOperationsViewState();
}

class _AdminOperationsViewState extends State<AdminOperationsView> {
  String _statusFilter = 'ALL';
  String _searchQuery = '';

  List<SaleOrderModel> get _filteredOrders {
    return widget.orders.where((o) {
      if (_statusFilter != 'ALL') {
        if (o.status.toUpperCase() != _statusFilter) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesId = o.id.toString().contains(q) || o.saleCode.toLowerCase().contains(q);
        final matchesCustomer = o.customerName.toLowerCase().contains(q) || o.customerPhone.contains(q);
        final matchesDevice = o.modelName.toLowerCase().contains(q) || o.brandName.toLowerCase().contains(q);
        final matchesImei = o.imeiNumber != null && o.imeiNumber!.toLowerCase().contains(q);
        if (!matchesId && !matchesCustomer && !matchesDevice && !matchesImei) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'PENDING_PICKUP':
        return Colors.amber.shade700;
      case 'IN_PROGRESS':
      case 'INSPECTION':
        return Colors.blue.shade700;
      case 'OFFER_REVISED':
        return Colors.purple.shade700;
      case 'PAID':
      case 'COMPLETED':
        return AppTheme.primaryGreen;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red.shade700;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              // Search input
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search order #, customer, phone, IMEI...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              // Status horizontal scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Orders (${widget.orders.length})'),
                    _buildFilterChip('PENDING_PICKUP', 'Pickups'),
                    _buildFilterChip('INSPECTION', 'Inspection'),
                    _buildFilterChip('OFFER_REVISED', 'Revised Offer'),
                    _buildFilterChip('READY_FOR_PAYOUT', 'Ready for Payout'),
                    _buildFilterChip('PAID', 'Completed/Paid'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Orders List
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : _filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('No orders match your filter', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => widget.onRefresh(),
                      color: AppTheme.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (ctx, idx) => _buildOrderCard(_filteredOrders[idx]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.lightGreen,
        checkmarkColor: AppTheme.primaryGreen,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected ? AppTheme.darkGreen : AppTheme.textSecondary,
        ),
        onSelected: (_) => setState(() => _statusFilter = key),
      ),
    );
  }

  Widget _buildOrderCard(SaleOrderModel order) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Order ID, Date & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      order.saleCode.isNotEmpty ? order.saleCode : '#${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.pickupDate ?? '',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Device details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.brandName} ${order.modelName}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Storage: ${order.storage} · Est: ₹${order.estimatedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.darkGreen),
                      ),
                      if (order.finalPrice != null && order.finalPrice! > 0)
                        Text(
                          'Final Agreed: ₹${order.finalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blue.shade800),
                        ),
                    ],
                  ),
                ),
                if (order.imeiNumber != null && order.imeiNumber!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'IMEI: ${order.imeiNumber}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer & Address
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${order.customerName} (${order.customerPhone}) · ${order.pickupCity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Agent & Action Buttons
            Row(
              children: [
                // Agent badge / Assign
                InkWell(
                  onTap: () => _showAssignAgentSheet(order),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: AppTheme.primaryGreen),
                        const SizedBox(width: 6),
                        Text(
                          order.assignedAgentName ?? 'Assign Agent',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryGreen),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Status dropdown button
                PopupMenuButton<String>(
                  onSelected: (newStatus) => widget.onUpdateStatus(order, newStatus),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'PENDING_PICKUP', child: Text('Mark Pending Pickup')),
                    const PopupMenuItem(value: 'INSPECTION', child: Text('Mark In Inspection')),
                    const PopupMenuItem(value: 'READY_FOR_PAYOUT', child: Text('Mark Ready for Payout')),
                    const PopupMenuItem(value: 'PAID', child: Text('Mark Paid / Completed')),
                    const PopupMenuItem(value: 'CANCELLED', child: Text('Cancel Order')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Text('Change Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        Icon(Icons.more_vert, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignAgentSheet(SaleOrderModel order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign Field Agent · Order ${order.saleCode.isNotEmpty ? order.saleCode : '#${order.id}'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 14),
            if (widget.agents.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No active agents found in system'),
              )
            else
              ...widget.agents.map((ag) {
                final isCurrent = order.assignedAgent?.toString() == ag.id.toString();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Text(ag.fullName.isNotEmpty ? ag.fullName[0].toUpperCase() : 'A', style: const TextStyle(color: AppTheme.darkGreen, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(ag.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(ag.phone, style: const TextStyle(fontSize: 12)),
                  trailing: isCurrent ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onAssignAgent(order, ag.id);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}
