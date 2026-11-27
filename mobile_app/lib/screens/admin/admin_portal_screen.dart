import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'admin_sidebar_drawer.dart';
import 'admin_operations_view.dart';
import 'admin_payout_desk_view.dart';
import 'admin_catalog_pricing_view.dart';
import 'admin_triage_valuation_view.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AdminNavSection _currentSection = AdminNavSection.operations;
  bool _isLoading = true;

  List<SaleOrderModel> _orders = [];
  List<AgentUserModel> _agents = [];
  List<BrandModel> _brands = [];

  @override
  void initState() {
    super.initState();
    _loadAllAdminData();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _api.getSales();
      final agents = await _api.getAgents();
      final brands = await _api.getBrands();

      if (mounted) {
        setState(() {
          _orders = orders;
          _agents = agents;
          _brands = brands;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpdateStatus(SaleOrderModel order, String newStatus) async {
    try {
      await _api.updateSaleStatus(order.id, newStatus);
      _loadAllAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${order.saleCode.isNotEmpty ? order.saleCode : "#${order.id}"} marked as $newStatus'), backgroundColor: AppTheme.darkGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleAssignAgent(SaleOrderModel order, dynamic agentId) async {
    try {
      await _api.assignPickup(order.id, {'agent_id': agentId});
      _loadAllAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field Agent assigned successfully'), backgroundColor: AppTheme.darkGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleConfirmPayout(SaleOrderModel order, String utr) async {
    try {
      await _api.recordPayment(order.id, {
        'utr': utr,
        'method': 'UPI',
        'amount': order.finalPrice ?? order.estimatedPrice,
      });
      _loadAllAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order payout recorded with UTR $utr'), backgroundColor: AppTheme.darkGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getSectionTitle() {
    switch (_currentSection) {
      case AdminNavSection.operations:
        return 'Operations Live Desk';
      case AdminNavSection.payouts:
        return 'Smart Payout Desk';
      case AdminNavSection.catalog:
        return 'Catalogue & Pricing';
      case AdminNavSection.triage:
        return 'Triage Questions';
      case AdminNavSection.agents:
        return 'Field Agents & Dispatch';
    }
  }

  Widget _buildBody() {
    switch (_currentSection) {
      case AdminNavSection.operations:
        return AdminOperationsView(
          orders: _orders,
          agents: _agents,
          isLoading: _isLoading,
          onRefresh: _loadAllAdminData,
          onUpdateStatus: _handleUpdateStatus,
          onAssignAgent: _handleAssignAgent,
        );
      case AdminNavSection.payouts:
        return AdminPayoutDeskView(
          orders: _orders,
          onRefresh: _loadAllAdminData,
          onConfirmPayout: _handleConfirmPayout,
        );
      case AdminNavSection.catalog:
        return AdminCatalogPricingView(
          brands: _brands,
          onRefresh: _loadAllAdminData,
        );
      case AdminNavSection.triage:
        return AdminTriageValuationView(
          onRefresh: _loadAllAdminData,
        );
      case AdminNavSection.agents:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 10),
              Text('${_agents.length} Field Agents Active', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Manage agent onboarding & assigned zip codes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingOrders = _orders.where((o) => o.status == 'PENDING_PICKUP' || o.status == 'PENDING').length;
    final pendingPayouts = _orders.where((o) => o.status == 'READY_FOR_PAYOUT').length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      drawer: AdminSidebarDrawer(
        currentSection: _currentSection,
        pendingOrdersCount: pendingOrders,
        pendingPayoutsCount: pendingPayouts,
        onRefresh: _loadAllAdminData,
        onSelectSection: (section) {
          setState(() => _currentSection = section);
          Navigator.of(context).pop(); // close drawer
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _getSectionTitle(),
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            onPressed: _loadAllAdminData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
