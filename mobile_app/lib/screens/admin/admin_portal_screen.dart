import 'package:flutter/material.dart';
export 'admin_sidebar_drawer.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'admin_sidebar_drawer.dart';
import 'admin_overview_dashboard_view.dart';
import 'admin_operations_view.dart';
import 'admin_customers_view.dart';
import 'admin_payout_desk_view.dart';
import 'admin_payout_history_view.dart';
import 'admin_agents_view.dart';
import 'admin_catalog_pricing_view.dart';
import 'admin_triage_valuation_view.dart';
import 'admin_valuation_simulator_view.dart';
import 'admin_cms_view.dart';
import 'admin_settings_view.dart';
import '../../widgets/notification_center_sheet.dart';
import '../../services/app_notification_service.dart';

class AdminPortalScreen extends StatefulWidget {
  final AdminNavSection initialSection;

  const AdminPortalScreen({
    super.key,
    this.initialSection = AdminNavSection.overview,
  });

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AdminNavSection _currentSection;
  bool _isLoading = true;

  List<SaleOrderModel> _orders = [];
  List<AgentUserModel> _agents = [];
  List<BrandModel> _brands = [];

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection;
    _loadAllAdminData();
  }

  @override
  void didUpdateWidget(covariant AdminPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() => _currentSection = widget.initialSection);
    }
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
        AppNotificationService().syncOrderNotifications(orders);
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
          SnackBar(
            content: Text('Order ${order.saleCode.isNotEmpty ? order.saleCode : "#${order.id}"} marked as $newStatus'),
            backgroundColor: AppTheme.darkGreen,
          ),
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

  Future<void> _handleConfirmPayout(SaleOrderModel order, String codeOrUtr) async {
    final isCash = order.beneficiaryType == 'CASH';
    try {
      final payload = <String, dynamic>{
        'amount': order.finalPrice ?? order.estimatedPrice,
        'payment_method': isCash ? 'CASH' : 'GPAY',
      };
      if (isCash) {
        payload['cash_otp'] = codeOrUtr;
      } else {
        payload['utr_number'] = codeOrUtr;
        payload['payment_proof_base64'] = 'ADMIN_APP_MANUAL_UTR_ENTRY';
      }

      await _api.recordPayment(order.id, payload);
      _loadAllAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCash ? 'Cash payout verified via Customer OTP!' : 'Order payout recorded with UTR $codeOrUtr'),
            backgroundColor: AppTheme.darkGreen,
          ),
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
      case AdminNavSection.overview:
        return 'Operations Dashboard';
      case AdminNavSection.operations:
        return 'Customer Sales';
      case AdminNavSection.customers:
        return 'Customers Registry';
      case AdminNavSection.payouts:
        return 'Smart Payout Desk';
      case AdminNavSection.payoutHistory:
        return 'Payout History';
      case AdminNavSection.agents:
        return 'Field Agents & Dispatch';
      case AdminNavSection.catalog:
        return 'Catalogue & Pricing';
      case AdminNavSection.triage:
        return 'Questionnaire Builder';
      case AdminNavSection.simulator:
        return 'Valuation Simulator';
      case AdminNavSection.cms:
        return 'Hero Banners (CMS)';
      case AdminNavSection.settings:
        return 'Settings & Diagnostics';
    }
  }

  Widget _buildBody() {
    switch (_currentSection) {
      case AdminNavSection.overview:
        return AdminOverviewDashboardView(
          orders: _orders,
          agents: _agents,
          onRefresh: _loadAllAdminData,
          onNavigateSection: (sec) => setState(() => _currentSection = sec),
        );
      case AdminNavSection.operations:
        return AdminOperationsView(
          orders: _orders,
          agents: _agents,
          isLoading: _isLoading,
          onRefresh: _loadAllAdminData,
          onUpdateStatus: _handleUpdateStatus,
          onAssignAgent: _handleAssignAgent,
        );
      case AdminNavSection.customers:
        return AdminCustomersView(
          orders: _orders,
          onRefresh: _loadAllAdminData,
        );
      case AdminNavSection.payouts:
        return AdminPayoutDeskView(
          orders: _orders,
          onRefresh: _loadAllAdminData,
          onConfirmPayout: _handleConfirmPayout,
        );
      case AdminNavSection.payoutHistory:
        return AdminPayoutHistoryView(
          orders: _orders,
          onRefresh: _loadAllAdminData,
        );
      case AdminNavSection.agents:
        return AdminAgentsView(
          agents: _agents,
          orders: _orders,
          onRefresh: _loadAllAdminData,
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
      case AdminNavSection.simulator:
        return AdminValuationSimulatorView(
          brands: _brands,
        );
      case AdminNavSection.cms:
        return AdminCmsView(
          onRefresh: _loadAllAdminData,
        );
      case AdminNavSection.settings:
        return const AdminSettingsView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingOrders = _orders.where((o) => ['SUBMITTED', 'PICKUP_SCHEDULED', 'INSPECTION_PENDING'].contains(o.status)).length;
    final pendingPayouts = _orders.where((o) => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].contains(o.status)).length;
    final paidPayouts = _orders.where((o) => o.status == 'PAYMENT_COMPLETED').length;

    // Count unique customers
    final customerPhones = _orders.map((o) => o.customerPhone).where((p) => p.isNotEmpty).toSet().length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: AdminSidebarDrawer(
        currentSection: _currentSection,
        pendingOrdersCount: pendingOrders,
        customersCount: customerPhones,
        pendingPayoutsCount: pendingPayouts,
        paidPayoutsCount: paidPayouts,
        agentsCount: _agents.length,
        brandsCount: _brands.length,
        onSelectSection: (sec) {
          setState(() => _currentSection = sec);
          Navigator.pop(context); // Close drawer
        },
        onRefresh: _loadAllAdminData,
      ),
      appBar: AppBar(
        title: Text(
          _getSectionTitle(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.primaryGreen),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Open navigation',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryGreen),
            onPressed: () => NotificationCenterSheet.show(context),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
            onPressed: _loadAllAdminData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            )
          : _buildBody(),
    );
  }
}
