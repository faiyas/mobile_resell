import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/brand_logo.dart';
import '../../utils/contact_launcher.dart';
import '../../utils/time_helper.dart';
import '../splash_screen.dart';
import 'agent_inspection_screen.dart';

class AgentDashboardScreen extends StatefulWidget {
  final Function(SaleOrderModel)? onStartInspection;

  const AgentDashboardScreen({super.key, this.onStartInspection});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = false;
  List<SaleOrderModel> _sales = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAgentData() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getSales();
      if (mounted) {
        setState(() {
          _sales = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load agent orders: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // Active Pickup Queue: Orders assigned or pending inspection
  // Auto-prioritized in Indian Standard Time (IST): Missed/Overdue -> Today Active -> Upcoming
  List<SaleOrderModel> get _queueOrders {
    final list = _sales.where((s) {
      final isPending = ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING', 'FINAL_OFFER_SENT', 'CUSTOMER_ACCEPTED'].contains(s.status);
      if (!isPending) return false;
      if (_searchQuery.isEmpty) return true;
      return s.saleCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.customerPhone.contains(_searchQuery) ||
          s.modelName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    list.sort((a, b) {
      final evalA = TimeHelper.evaluateSchedule(
        pickupDateStr: a.pickupDate,
        pickupSlotStr: a.pickupSlot,
        status: a.status,
      );
      final evalB = TimeHelper.evaluateSchedule(
        pickupDateStr: b.pickupDate,
        pickupSlotStr: b.pickupSlot,
        status: b.status,
      );

      // 1. Overdue orders prioritized at the very top
      if (evalA.isOverdue && !evalB.isOverdue) return -1;
      if (!evalA.isOverdue && evalB.isOverdue) return 1;
      if (evalA.isOverdue && evalB.isOverdue) {
        return evalB.hoursOverdue.compareTo(evalA.hoursOverdue);
      }

      // 2. Today's pickups next
      if (evalA.isDueToday && !evalB.isDueToday) return -1;
      if (!evalA.isDueToday && evalB.isDueToday) return 1;

      return 0;
    });

    return list;
  }

  // Completed Handover History: Orders where QC was finished and device was collected / paid
  List<SaleOrderModel> get _historyOrders {
    return _sales.where((s) {
      final isCompleted = ['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED', 'CUSTOMER_REJECTED'].contains(s.status);
      if (!isCompleted) return false;
      if (_searchQuery.isEmpty) return true;
      return s.saleCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.customerPhone.contains(_searchQuery) ||
          s.modelName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  double get _totalInspectedValue {
    return _historyOrders.fold<double>(
      0.0,
      (sum, s) => sum + (s.finalPrice ?? s.estimatedPrice),
    );
  }

  void _openInspectionForOrder(SaleOrderModel order) {
    if (widget.onStartInspection != null) {
      widget.onStartInspection!(order);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgentInspectionScreen(initialSale: order),
        ),
      ).then((_) => _loadAgentData());
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.blue;
      case 'PICKUP_SCHEDULED':
        return Colors.orange.shade700;
      case 'PICKED_UP':
      case 'INSPECTION_PENDING':
        return Colors.purple;
      case 'FINAL_OFFER_SENT':
        return Colors.amber.shade900;
      case 'CUSTOMER_ACCEPTED':
      case 'OWNERSHIP_TRANSFERRED':
        return AppTheme.primaryGreen;
      case 'PAYMENT_COMPLETED':
        return AppTheme.darkGreen;
      case 'CUSTOMER_REJECTED':
      case 'CANCELLED':
        return Colors.red.shade700;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _handleMarkCollected(SaleOrderModel order) async {
    try {
      await _api.markDeviceCollected(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Device ${order.saleCode} physically collected!\nUnlocked for Super Admin payout release.'),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadAgentData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from Agent Desk?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.70),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.glassBorder.withOpacity(0.5))),
              ),
            ),
          ),
        ),
        title: const Text('1103 RECELL · Agent Desk', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Support Hotline',
            onPressed: () => ContactLauncher.callHotline(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            tooltip: 'Refresh Queue',
            onPressed: _loadAgentData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: _loading
              ? const RecellBrandLoader(message: 'Syncing live agent queue...')
              : RefreshIndicator(
                  color: AppTheme.primaryGreen,
                  onRefresh: _loadAgentData,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Agent Executive Header Glass Banner
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0BAA4B), Color(0xFF06612A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen.withOpacity(0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.motorcycle_rounded, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Field Agent Workspace',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Doorstep Inspections · Pickup Queue · Handover History',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Agent KPI Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard('Assigned Queue', '${_queueOrders.length}', Icons.pending_actions_rounded, Colors.orange),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildKpiCard('Completed', '${_historyOrders.length}', Icons.task_alt_rounded, AppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildKpiCard(
                                'Total Inspected Value',
                                '₹${_totalInspectedValue.toStringAsFixed(0)}',
                                Icons.currency_rupee_rounded,
                                AppTheme.darkGreen,
                              ),
                              const SizedBox(height: 14),

                              // Search Bar
                              TextField(
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Search by Order ID, Customer, Phone, or Model...',
                                  hintStyle: const TextStyle(fontSize: 12),
                                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.primaryGreen),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () => setState(() => _searchQuery = ''),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.85),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Segmented Tabs: Queue vs History
                              Container(
                                height: 46,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.glassBorder, width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  indicator: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withOpacity(0.32),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: AppTheme.textSecondary,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  tabs: [
                                    Tab(text: 'Pickup Queue (${_queueOrders.length})'),
                                    Tab(text: 'Handover History (${_historyOrders.length})'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildQueueList(),
                        _buildHistoryList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    final list = _queueOrders;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 54, color: AppTheme.primaryGreen),
              const SizedBox(height: 12),
              const Text('Pickup Queue is Clear!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('All assigned pickups have been completed or no pending orders in queue.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryGreen),
                label: const Text('Refresh Queue', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                onPressed: _loadAgentData,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = list[index];
        final statusColor = _getStatusColor(order.status);
        final eval = TimeHelper.evaluateSchedule(
          pickupDateStr: order.pickupDate,
          pickupSlotStr: order.pickupSlot,
          status: order.status,
        );

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          border: eval.isOverdue
              ? Border.all(color: Colors.redAccent.withOpacity(0.85), width: 1.6)
              : (eval.isDueToday ? Border.all(color: Colors.orange.withOpacity(0.6), width: 1.4) : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overdue Alert Banner
              if (eval.isOverdue) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_off_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eval.alertMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HIGH PRIORITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.primaryGreen)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (eval.isOverdue ? Colors.red : statusColor).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      eval.isOverdue ? 'PICKUP OVERDUE' : order.status.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: eval.isOverdue ? Colors.red : statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.brandName} ${order.modelName} (${order.storage})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Quoted Price: ₹${order.estimatedPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.darkGreen),
              ),
              const Divider(height: 18),

              // Customer Details & Shortcuts
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.lightGreen,
                      foregroundColor: AppTheme.darkGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.phone, size: 12, color: AppTheme.primaryGreen),
                    label: Text(order.customerPhone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => ContactLauncher.callCustomer(context, order.customerPhone),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.pickupAddress}, ${order.pickupCity} - ${order.pickupPincode}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Indian Standard Time (IST) Pickup Slot Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: eval.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: eval.color.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(eval.icon, size: 15, color: eval.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eval.displaySlot,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: eval.color,
                        ),
                      ),
                    ),
                    if (eval.isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ACTION REQ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lifecycle Action Buttons based on Order Status
              if (order.status == 'FINAL_OFFER_SENT') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Final buyback offer ₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)} sent to customer.\nAwaiting customer acceptance before collection.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (order.status == 'CUSTOMER_ACCEPTED') ...[
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✓ Customer accepted offer (₹${(order.finalPrice ?? order.estimatedPrice).toStringAsFixed(0)})!',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.darkGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded, size: 18),
                        label: const Text('Mark Device Collected (Handover Signed)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        onPressed: () => _handleMarkCollected(order),
                      ),
                    ),
                  ],
                ),
              ] else if (order.status == 'OWNERSHIP_TRANSFERRED') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Device Collected · Awaiting Super Admin Payout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.fact_check_rounded, size: 18),
                      label: const Text(
                        'Start Doorstep QC Inspection',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
                      ),
                      onPressed: () => _openInspectionForOrder(order),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    final list = _historyOrders;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, size: 54, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              const Text('No Handover History Yet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('Completed inspections will appear here with final agreed prices and proof records.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = list[index];
        final statusColor = _getStatusColor(order.status);
        final finalVal = order.finalPrice ?? order.estimatedPrice;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.primaryGreen)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status == 'OWNERSHIP_TRANSFERRED' ? 'PICKUP COMPLETED' : order.status.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${order.brandName} ${order.modelName} (${order.storage})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Final Handover Price: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  Text(
                    '₹${finalVal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (order.imeiNumber != null && order.imeiNumber!.isNotEmpty)
                Text(
                  'Verified IMEI: ${order.imeiNumber}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 6),
              Text(
                'Customer: ${order.customerName} (${order.customerPhone})',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              if (order.status == 'OWNERSHIP_TRANSFERRED')
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 14, color: AppTheme.primaryGreen),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Device in custody · Payout unlocked for Super Admin',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
