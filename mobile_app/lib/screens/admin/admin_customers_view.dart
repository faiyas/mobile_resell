import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminCustomersView extends StatefulWidget {
  final List<SaleOrderModel> orders;
  final VoidCallback onRefresh;

  const AdminCustomersView({
    super.key,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<AdminCustomersView> createState() => _AdminCustomersViewState();
}

class _AdminCustomersViewState extends State<AdminCustomersView> {
  final ApiService _api = ApiService();
  String _searchQuery = '';
  List<Map<String, dynamic>> _registeredCustomers = [];

  @override
  void initState() {
    super.initState();
    _fetchRegisteredCustomers();
  }

  Future<void> _fetchRegisteredCustomers() async {
    try {
      final res = await _api.getCustomers();
      if (mounted) setState(() => _registeredCustomers = res);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Group sales by unique customer (phone or customer name)
    final Map<String, _CustomerSummary> customersMap = {};

    // 1. Add registered users first
    for (var u in _registeredCustomers) {
      final phone = (u['phone'] ?? '').toString();
      final name = (u['full_name'] ?? u['email'] ?? 'User').toString();
      final email = u['email']?.toString();
      final key = phone.isNotEmpty ? phone : (email ?? 'user_${u['id']}');
      customersMap[key] = _CustomerSummary(
        name: name,
        phone: phone,
        email: email,
        city: null,
        orders: [],
      );
    }

    // 2. Merge sales orders
    for (var o in widget.orders) {
      final key = o.customerPhone.isNotEmpty ? o.customerPhone : (o.customerName.isNotEmpty ? o.customerName : 'Unknown_${o.id}');
      if (!customersMap.containsKey(key)) {
        customersMap[key] = _CustomerSummary(
          name: o.customerName.isNotEmpty ? o.customerName : 'Customer (${o.customerPhone})',
          phone: o.customerPhone,
          email: o.customerEmail,
          city: o.pickupCity,
          orders: [o],
        );
      } else {
        customersMap[key]!.orders.add(o);
      }
    }

    final customersList = customersMap.values.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q) || (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRegisteredCustomers();
        widget.onRefresh();
      },
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CUSTOMERS DIRECTORY',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${customersList.length} Registered Customers',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
                onPressed: widget.onRefresh,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Box
          GlassContainer(
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search customer name, phone, or email...',
                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (customersList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.person_search_rounded, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 10),
                    Text('No customers matched your search', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...customersList.map((customer) {
              final totalOrders = customer.orders.length;
              final totalPayout = customer.orders
                  .where((o) => o.status == 'PAYMENT_COMPLETED')
                  .fold<double>(0.0, (sum, o) => sum + (o.finalPrice ?? o.estimatedPrice));

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar Initials
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            if (customer.phone.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, size: 13, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.phone,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            if (customer.email != null && customer.email!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.mail_outline_rounded, size: 13, color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      customer.email!,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Badges: Orders count and Lifetime Payout
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$totalOrders ${totalOrders == 1 ? "Sale Order" : "Sale Orders"}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (totalPayout > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '₹${totalPayout.toStringAsFixed(0)} Disbursed',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action - Call Button
                      if (customer.phone.isNotEmpty)
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_rounded, size: 18, color: AppTheme.primaryGreen),
                          ),
                          onPressed: () async {
                            final uri = Uri.parse('tel:${customer.phone}');
                            if (await canLaunchUrl(uri)) launchUrl(uri);
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CustomerSummary {
  final String name;
  final String phone;
  final String? email;
  final String? city;
  final List<SaleOrderModel> orders;

  _CustomerSummary({
    required this.name,
    required this.phone,
    this.email,
    this.city,
    required this.orders,
  });
}
