import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

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
          SnackBar(content: Text('Failed to load admin data: $e'), behavior: SnackBarBehavior.floating),
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

  void _showCreateAgentDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'agent123');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Create Field Agent Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Only Admins can issue credentials for collection agents.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Agent Full Name *',
                    hintText: 'e.g. Ramesh Kumar',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Agent Mobile Number *',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Agent Email Address *',
                    hintText: 'e.g. ramesh@buyback.in',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password *',
                    hintText: 'e.g. agent123',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final pass = passCtrl.text;

                          if (name.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          try {
                            await _api.register({
                              'full_name': name,
                              'phone': phone,
                              'email': email,
                              'password': pass,
                              'role': 'COLLECTION_AGENT',
                            });
                            _loadAdminData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Collection Agent $name created successfully!'),
                                backgroundColor: AppTheme.primaryGreen,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to create agent: $e')),
                            );
                          }
                        },
                        child: const Text('Create Agent'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignAgentDialog(SaleOrderModel order) {
    if (_agents.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group_off_rounded, size: 40, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text('No Collection Agents Found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Create an agent account first to assign doorstep pickup requests.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateAgentDialog();
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Create Agent Account'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
        ),
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
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assign Field Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                            Text(order.saleCode, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Select Pickup Specialist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedAgentId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const Text('Pickup Date (YYYY-MM-DD):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryGreen),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Time Slot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                              SnackBar(
                                content: Text('✓ Agent successfully assigned to ${order.saleCode}'),
                                backgroundColor: AppTheme.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _loadAdminData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        child: const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRecordPayoutDialog(SaleOrderModel order) {
    final utrController = TextEditingController();
    final double amount = order.finalPrice ?? order.estimatedPrice;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.currency_rupee_rounded, color: AppTheme.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Release Instant Payout', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                          Text('${order.saleCode} · ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Beneficiary: ${order.customerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('Device: ${order.brandName} ${order.modelName} (${order.storage})', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (order.otherDefectsNotes != null && order.otherDefectsNotes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Custom Notes: ${order.otherDefectsNotes}', style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                  ),
                Text('Payout Mode: ${order.beneficiaryType}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (order.beneficiaryUpiId != null)
                  Text('UPI ID: ${order.beneficiaryUpiId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkGreen)),
                const SizedBox(height: 14),
                TextField(
                  controller: utrController,
                  decoration: InputDecoration(
                    labelText: 'Bank / UPI UTR Reference Number *',
                    hintText: 'e.g. 429184920194',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.85),
                    prefixIcon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: () async {
                        final utr = utrController.text.trim();
                        if (utr.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter UTR reference number'), behavior: SnackBarBehavior.floating),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await _api.recordPayment(order.id, {
                            'amount': amount,
                            'method': order.beneficiaryType,
                            'transaction_reference': utr,
                            'notes': 'Disbursed via 1103 RECELL Admin Desk',
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Payout of ₹${amount.toStringAsFixed(0)} recorded successfully!'),
                              backgroundColor: AppTheme.primaryGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _loadAdminData();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      child: const Text('Confirm Disbursal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        title: const Text('1103 RECELL · Admin Desk', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: GlassBackgroundMesh(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : RefreshIndicator(
                  color: AppTheme.primaryGreen,
                  onRefresh: _loadAdminData,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Executive Header Glass Banner
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
                                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '1103 RECELL Central Control',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Payout Approvals · Field Dispatch · Pricing Rules',
                                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 4 Executive Frosted KPI Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard('Total Orders', '${_sales.length}', Icons.smartphone_rounded, AppTheme.primaryGreen),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildKpiCard('Pending Pickups', '$_pendingPickupsCount', Icons.motorcycle_rounded, Colors.orange),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard('Awaiting Payout', '$_awaitingPayoutCount', Icons.payments_rounded, const Color(0xFF059669)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Total Disbursed',
                                      '₹${_paymentSummary.totalDisbursed.toStringAsFixed(0)}',
                                      Icons.account_balance_rounded,
                                      Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Frosted Glass Tab Bar
                              GlassContainer(
                                padding: const EdgeInsets.all(4),
                                borderRadius: BorderRadius.circular(18),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: AppTheme.primaryGreen,
                                  unselectedLabelColor: AppTheme.textSecondary,
                                  indicatorColor: AppTheme.primaryGreen,
                                  indicatorWeight: 3,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
          child: GlassContainer(
            padding: const EdgeInsets.all(28),
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 54, color: AppTheme.primaryGreen.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('No Payouts Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'Orders inspected and accepted by customers will appear here for instant UPI/Bank release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
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

        return GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      order.saleCode,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppTheme.primaryGreen),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${order.brandName} ${order.modelName} (${order.storage})',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary),
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
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
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
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search order ID, phone, customer...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ),
        // Filter Chips & Agent Creation Action
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                label: const Text('+ Add Field Agent', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: AppTheme.primaryGreen,
                onPressed: _showCreateAgentDialog,
              ),
              const SizedBox(width: 8),
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
              ? const Center(child: Text('No matching orders found', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = _filteredSales[index];
                    return GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(order.saleCode, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                              _buildStatusBadge(order.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${order.brandName} ${order.modelName} (${order.storage})',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                              ),
                              Text(
                                order.assignedAgentName != null ? 'Agent: ${order.assignedAgentName}' : 'No Agent Assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: order.assignedAgentName != null ? AppTheme.darkGreen : Colors.orange.shade800,
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
                                    side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.6)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppTheme.primaryGreen),
                                  label: const Text('Assign Agent', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
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
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary)),
        selected: isSelected,
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Colors.white.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryGreen : AppTheme.glassBorder)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }

  void _editConditionOption(ConditionOptionModel opt) {
    final valController = TextEditingController(text: opt.defaultDeductionValue.toStringAsFixed(0));
    final imgController = TextEditingController(text: opt.imageBase64 ?? '');
    String deductionType = opt.deductionType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.tune_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Edit Defect & Reference Photo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(opt.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Deduction Amount *',
                      prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Flat (₹)'),
                        selected: deductionType == 'FLAT',
                        onSelected: (v) => setDlgState(() => deductionType = 'FLAT'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Percentage (%)'),
                        selected: deductionType == 'PERCENTAGE',
                        onSelected: (v) => setDlgState(() => deductionType = 'PERCENTAGE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Defect Reference Image Guide (Base64 / URL):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: imgController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'data:image/png;base64,...',
                      prefixIcon: Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Sample Scratch', style: TextStyle(fontSize: 10)),
                        onPressed: () => setDlgState(() => imgController.text = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='),
                      ),
                      ActionChip(
                        label: const Text('Sample Cracked Glass', style: TextStyle(fontSize: 10)),
                        onPressed: () => setDlgState(() => imgController.text = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNkYGD4z0AEYBxVGPoDAH70BAV+q2dMAAAAAElFTkSuQmCC'),
                      ),
                      if (imgController.text.isNotEmpty)
                        ActionChip(
                          label: const Text('Clear Photo', style: TextStyle(fontSize: 10, color: Colors.red)),
                          onPressed: () => setDlgState(() => imgController.text = ''),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final val = double.tryParse(valController.text.trim()) ?? opt.defaultDeductionValue;
                            final img = imgController.text.trim();
                            Navigator.pop(ctx);
                            try {
                              await _api.updateConditionOption(opt.id, {
                                'default_deduction_value': val,
                                'deduction_type': deductionType,
                                'image_base64': img,
                              });
                              _loadAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Defect rule & image updated successfully!')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update: $e')),
                              );
                            }
                          },
                          child: const Text('Save Rule'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _uploadLogoForBrand(BrandModel brand) {
    final urlController = TextEditingController(text: brand.logoBase64 ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload Logo: ${brand.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Enter image Base64 data or choose a preset emblem to display on customer brand tiles.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: urlController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Image Data (Base64 string) *',
                      hintText: 'data:image/png;base64,...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Preset Quick Emblems:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Clean Default', style: TextStyle(fontSize: 10)),
                        onPressed: () => setModalState(() => urlController.text = ''),
                      ),
                      ActionChip(
                        label: const Text('HD Badge Icon', style: TextStyle(fontSize: 10)),
                        onPressed: () => setModalState(() => urlController.text = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAEpJREFUeNpi/P//PwM1AQtjIzO6OCMBzUQrw8jIyAASZgZSYyMjgKkEZmNjYwM4jQzEpxpGg4vI04xO08kOQJphgA4WkGU4zQABBgCE1Ao0n/nF9gAAAABJRU5ErkJggg=='),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final val = urlController.text.trim();
                            Navigator.pop(ctx);
                            try {
                              await _api.updateBrand(brand.id, {'logo_base64': val});
                              _loadAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✓ ${brand.name} logo updated successfully!'), backgroundColor: AppTheme.primaryGreen),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update logo: $e')),
                              );
                            }
                          },
                          child: const Text('Save Logo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBrandLogosManager() async {
    List<BrandModel> brands = [];
    try {
      brands = await _api.getBrands();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.image_rounded, color: AppTheme.primaryGreen),
                      SizedBox(width: 10),
                      Text('Brand Logos & Image Manager', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Upload or change logos to display in the customer mobile app.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: brands.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final b = brands[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.phone_android, size: 20, color: AppTheme.primaryGreen),
                          ),
                          title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(b.logoBase64 != null ? 'Custom logo active' : 'Default emblem', style: const TextStyle(fontSize: 10)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 14),
                            label: const Text('Upload', style: TextStyle(fontSize: 11)),
                            onPressed: () => _uploadLogoForBrand(b),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _uploadImageForCategory(DeviceCategoryModel cat) {
    final urlController = TextEditingController(text: cat.imageBase64 ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category Image: ${cat.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Enter Base64 image data to replace emojis/icons on the customer home screen boxes.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: urlController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Image Data (Base64 string) *',
                      hintText: 'data:image/png;base64,...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Quick Preset Graphics:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Clear / Default Icon', style: TextStyle(fontSize: 10)),
                        onPressed: () => setModalState(() => urlController.text = ''),
                      ),
                      ActionChip(
                        label: const Text('Modern Phone Graphic', style: TextStyle(fontSize: 10)),
                        onPressed: () => setModalState(() => urlController.text = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAEpJREFUeNpi/P//PwM1AQtjIzO6OCMBzUQrw8jIyAASZgZSYyMjgKkEZmNjYwM4jQzEpxpGg4vI04xO08kOQJphgA4WkGU4zQABBgCE1Ao0n/nF9gAAAABJRU5ErkJggg=='),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          onPressed: () async {
                            final val = urlController.text.trim();
                            Navigator.pop(ctx);
                            try {
                              await _api.updateDeviceCategory(cat.id, {'image_base64': val});
                              _loadAdminData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✓ ${cat.name} image updated successfully!'), backgroundColor: AppTheme.primaryGreen),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update category image: $e')),
                              );
                            }
                          },
                          child: const Text('Save Image'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryImagesManager() async {
    List<DeviceCategoryModel> categories = [];
    try {
      categories = await _api.getDeviceCategories(forceRefresh: true);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.category_rounded, color: AppTheme.primaryGreen),
                      SizedBox(width: 10),
                      Text('Category Visual Images (Base64)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Set Base64 images for Mobile, Tablet, Dead Phone & Other to replace emojis on the home screen.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final c = categories[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.devices_rounded, size: 20, color: AppTheme.primaryGreen),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(c.imageBase64 != null && c.imageBase64!.isNotEmpty ? 'Custom Base64 Image Active' : 'Default Icon Fallback', style: const TextStyle(fontSize: 10)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.image_outlined, size: 14),
                            label: const Text('Change', style: TextStyle(fontSize: 11)),
                            onPressed: () => _uploadImageForCategory(c),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingTab() {
    return Column(
      children: [
        // Quick Action Bar for CMS & Catalogue
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showCategoryImagesManager,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_rounded, size: 15, color: AppTheme.primaryGreen),
                      SizedBox(width: 4),
                      Text('Category Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showBrandLogosManager,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_search_rounded, size: 15, color: AppTheme.primaryGreen),
                      SizedBox(width: 4),
                      Text('Brand Logos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _conditionCategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cat = _conditionCategories[index];
              return GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Step ${cat.stepNumber}: ${cat.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${cat.options.length} options', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cat.options.map((opt) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _editConditionOption(opt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${opt.title}: -₹${opt.defaultDeductionValue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 12, color: AppTheme.primaryGreen),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
}
