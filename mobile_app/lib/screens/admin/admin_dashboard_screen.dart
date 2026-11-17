import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<SaleOrderModel> _sales = [];
  PaymentSummaryModel _paymentSummary = PaymentSummaryModel(totalCount: 0, totalDisbursed: 0.0, payments: []);
  List<AgentUserModel> _agents = [];
  List<ConditionCategoryModel> _conditionCategories = [];
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await _api.getSales();
      final summary = await _api.getPaymentsSummary();
      final agents = await _api.getAgents();
      final conditions = await _api.getConditionCategories();

      if (mounted) {
        setState(() {
          _sales = sales;
          _paymentSummary = summary;
          _agents = agents;
          _conditionCategories = conditions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load admin data: $e')),
        );
      }
    }
  }

  int get _pendingPickupsCount => _sales.where((s) => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].contains(s.status)).length;
  int get _awaitingPayoutCount => _sales.where((s) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(s.status)).length;

  List<SaleOrderModel> get _payoutQueue =>
      _sales.where((s) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(s.status)).toList();

  List<SaleOrderModel> get _filteredSales {
    return _sales.where((s) {
      final matchesStatus = _statusFilter == 'ALL' ? true : s.status == _statusFilter;
      final matchesQuery = _searchQuery.isEmpty
          ? true
          : s.saleCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.customerPhone.contains(_searchQuery);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  void _showAssignAgentDialog(SaleOrderModel order) {
    if (_agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active collection agents found. Seed agent accounts first.')),
      );
      return;
    }

    int selectedAgentId = _agents.first.id;
    String selectedSlot = order.pickupSlot ?? 'Morning (10:00 AM - 1:00 PM)';
    final dateController = TextEditingController(
      text: order.pickupDate ?? DateTime.now().toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Field Agent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(order.saleCode, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Pickup Specialist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: selectedAgentId,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _agents.map((a) {
                    return DropdownMenuItem<int>(
                      value: a.id,
                      child: Text('${a.fullName} (${a.phone})', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAgentId = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Pickup Date (YYYY-MM-DD):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Time Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedSlot,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Morning (10:00 AM - 1:00 PM)', child: Text('Morning (10:00 AM - 1:00 PM)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Afternoon (1:00 PM - 4:00 PM)', child: Text('Afternoon (1:00 PM - 4:00 PM)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Evening (4:00 PM - 7:00 PM)', child: Text('Evening (4:00 PM - 7:00 PM)', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSlot = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _api.assignPickup(order.id, {
                    'agent_id': selectedAgentId,
                    'pickup_date': dateController.text.trim(),
                    'pickup_slot': selectedSlot,
                  });
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Agent successfully assigned to ${order.saleCode}')),
                  );
                  _loadAdminData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPayoutDialog(SaleOrderModel order) {
    final utrController = TextEditingController();
    final double amount = order.finalPrice ?? order.estimatedPrice;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.currency_rupee, color: AppTheme.primaryGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Release Payout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('${order.saleCode} · ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beneficiary: ${order.beneficiaryName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (order.beneficiaryUpiId != null && order.beneficiaryUpiId!.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'UPI ID: ${order.beneficiaryUpiId}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: AppTheme.primaryGreen),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: order.beneficiaryUpiId!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('UPI ID copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Enter 12-digit UTR / Reference No:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: utrController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 432109876543',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final utr = utrController.text.trim();
              if (utr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter bank UTR reference number')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _api.recordPayout({
                  'sale_id': order.id,
                  'amount': amount,
                  'payment_method': order.beneficiaryType == 'BANK_TRANSFER' ? 'BANK_NEFT' : 'UPI',
                  'utr_number': utr,
                  'payment_proof_base64': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAA=',
                  'admin_notes': 'Authorized via 1103 RECELL Mobile Admin Desk',
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✓ Payout confirmed for ${order.saleCode}! Order marked as PAID.')),
                );
                _loadAdminData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payout error: $e')),
                );
              }
            },
            child: const Text('Confirm Payment Released', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              color: AppTheme.primaryGreen,
              onRefresh: _loadAdminData,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.deepForest, AppTheme.darkGreen, AppTheme.primaryGreen],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withOpacity(0.2),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '1103 RECELL Admin Desk',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Payout Approvals · Agent Dispatch · Pricing Control',
                                        style: TextStyle(color: AppTheme.lightGreen, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4 Executive KPI Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard('Total Orders', '${_sales.length}', Icons.smartphone, Colors.blue),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard('Pending Pickups', '$_pendingPickupsCount', Icons.motorcycle, Colors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard('Awaiting Payout', '$_awaitingPayoutCount', Icons.payments, AppTheme.primaryGreen),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  'Total Disbursed',
                                  '₹${_paymentSummary.totalDisbursed.toStringAsFixed(0)}',
                                  Icons.account_balance,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Tab Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: AppTheme.primaryGreen,
                              unselectedLabelColor: AppTheme.textSecondary,
                              indicatorColor: AppTheme.primaryGreen,
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              tabs: [
                                Tab(text: 'Payouts (${_payoutQueue.length})'),
                                Tab(text: 'Orders (${_sales.length})'),
                                const Tab(text: 'Pricing & Rules'),
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
                    _buildPayoutsTab(),
                    _buildOrdersTab(),
                    _buildPricingTab(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTab() {
    if (_payoutQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: AppTheme.primaryGreen.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text('No Payouts Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'Orders inspected and accepted by customers will appear here for instant UPI/Bank release.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _payoutQueue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _payoutQueue[index];
        final amount = order.finalPrice ?? order.estimatedPrice;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.saleCode,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.darkGreen),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${order.brandName} ${order.modelName} (${order.storage})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${order.customerName} · ${order.customerPhone}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              if (order.beneficiaryUpiId != null && order.beneficiaryUpiId!.isNotEmpty)
                Text(
                  'UPI: ${order.beneficiaryUpiId}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text(
                    'Authorize & Release Payout',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: () => _showRecordPayoutDialog(order),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Search & Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search order ID, phone, customer...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All Orders'),
              _buildFilterChip('SUBMITTED', 'Submitted'),
              _buildFilterChip('PICKUP_SCHEDULED', 'Scheduled'),
              _buildFilterChip('OWNERSHIP_TRANSFERRED', 'Awaiting Payout'),
              _buildFilterChip('PAYMENT_COMPLETED', 'Completed'),
            ],
          ),
        ),
        Expanded(
          child: _filteredSales.isEmpty
              ? const Center(child: Text('No matching orders found'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = _filteredSales[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(order.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                              _buildStatusBadge(order.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${order.brandName} ${order.modelName} (${order.storage})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.customerName} · ${order.customerPhone}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Est: ₹${order.estimatedPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGreen),
                              ),
                              Text(
                                order.assignedAgentName != null ? 'Agent: ${order.assignedAgentName}' : 'No Agent Assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: order.assignedAgentName != null ? AppTheme.darkGreen : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primaryGreen),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1, size: 16, color: AppTheme.primaryGreen),
                                  label: const Text('Assign Agent', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                                  onPressed: () => _showAssignAgentDialog(order),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary)),
        selected: isSelected,
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.border)),
        onSelected: (val) => setState(() => _statusFilter = key),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'PAYMENT_COMPLETED':
        color = Colors.green;
        break;
      case 'OWNERSHIP_TRANSFERRED':
      case 'CUSTOMER_ACCEPTED':
        color = Colors.teal;
        break;
      case 'PICKUP_SCHEDULED':
        color = Colors.blue;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildPricingTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _conditionCategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cat = _conditionCategories[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step ${cat.stepNumber}: ${cat.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  Text('${cat.options.length} options', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: cat.options.map((opt) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      '${opt.title}: -₹${opt.defaultDeductionValue.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
