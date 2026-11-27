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
  Set<String> _agentBlacklist = {};
  final Set<String> _expandedCustomerKeys = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRegisteredCustomers();
  }

  Future<void> _fetchRegisteredCustomers() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getCustomers(),
        _api.getAgents().catchError((_) => <AgentUserModel>[]),
      ]);
      final custs = results[0] as List<Map<String, dynamic>>;
      final agents = results[1] as List<AgentUserModel>;

      final Set<String> agentIds = {};
      for (var a in agents) {
        if (a.phone.isNotEmpty) {
          final clean = a.phone.replaceAll(RegExp(r'\D'), '');
          agentIds.add(clean);
          if (clean.length >= 10) {
            agentIds.add(clean.substring(clean.length - 10));
          }
        }
        if (a.email.isNotEmpty) {
          agentIds.add(a.email.toLowerCase().trim());
        }
      }

      if (mounted) {
        setState(() {
          _registeredCustomers = custs;
          _agentBlacklist = agentIds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isAgent(String phone, String? email) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isNotEmpty) {
      if (_agentBlacklist.contains(clean)) return true;
      if (clean.length >= 10 && _agentBlacklist.contains(clean.substring(clean.length - 10))) {
        return true;
      }
    }
    if (email != null && email.isNotEmpty && _agentBlacklist.contains(email.toLowerCase().trim())) {
      return true;
    }
    return false;
  }

  void _showAddCustomerModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController(text: 'Dolly@123');
    final cityCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: AppTheme.primaryGreen, size: 22),
                    SizedBox(width: 8),
                    Text('Create Customer Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ],
                ),
                const Text('Add a new customer with login credentials and address', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),

                const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Rahul Sharma',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Phone Number *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '10-digit mobile number',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Email Address (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'customer@example.com',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Initial Password (min 6 characters)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Dolly@123',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('City (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: cityCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Bangalore',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text('Address (Optional)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'House / Street / Area',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final pwd = pwdCtrl.text.trim();

                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter customer name')));
                              return;
                            }
                            if (phone.isEmpty || phone.length < 10) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit phone number')));
                              return;
                            }
                            if (pwd.length < 6) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                              return;
                            }

                            setM(() => isSaving = true);
                            try {
                              final payload = <String, dynamic>{
                                'full_name': name,
                                'phone': phone,
                                'password': pwd,
                              };
                              if (emailCtrl.text.trim().isNotEmpty) {
                                payload['email'] = emailCtrl.text.trim();
                              }
                              if (cityCtrl.text.trim().isNotEmpty) {
                                payload['city'] = cityCtrl.text.trim();
                              }
                              if (addrCtrl.text.trim().isNotEmpty) {
                                payload['default_address'] = addrCtrl.text.trim();
                              }

                              await _api.createCustomer(payload);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Customer $name created successfully!')),
                                );
                              }
                              await _fetchRegisteredCustomers();
                              widget.onRefresh();
                            } catch (e) {
                              setM(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Customer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCustomerModal(_CustomerSummary customer) {
    if (customer.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This customer has not registered an account yet (guest order).')),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final emailCtrl = TextEditingController(text: customer.email ?? '');
    final cityCtrl = TextEditingController(text: customer.city ?? '');
    final addrCtrl = TextEditingController(text: customer.address ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 14),
                Text('Edit Customer: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const Text('Update customer contact and address details', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('City', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: cityCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            setM(() => isSaving = true);
                            try {
                              await _api.updateCustomer(customer.id!, {
                                'full_name': name,
                                'phone': phoneCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'city': cityCtrl.text.trim(),
                                'default_address': addrCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _fetchRegisteredCustomers();
                              widget.onRefresh();
                            } catch (e) {
                              setM(() => isSaving = false);
                              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Customer Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordModal(_CustomerSummary customer) {
    if (customer.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This customer has not registered an account yet (guest order).')),
      );
      return;
    }

    final pwdCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text('Reset Password: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Admin credential override for customer account', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('New Password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: pwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter new password (min 6 chars)',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final pwd = pwdCtrl.text.trim();
                          if (pwd.length < 6) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                            return;
                          }
                          setM(() => isSaving = true);
                          try {
                            await _api.adminResetCustomerPassword(customerId: customer.id!, newPassword: pwd);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully!')));
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Reset Password Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCustomer(_CustomerSummary customer) {
    if (customer.id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Customer: ${customer.name}?'),
        content: const Text('This will delete the customer profile permanently or unbind their registered access. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteCustomer(customer.id!);
                await _fetchRegisteredCustomers();
                widget.onRefresh();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group sales by unique customer (phone or customer name)
    final Map<String, _CustomerSummary> customersMap = {};

    // 1. Add registered users first (strictly CUSTOMER role only and exclude agents)
    for (var u in _registeredCustomers) {
      final role = (u['role'] ?? 'CUSTOMER').toString().toUpperCase();
      if (role != 'CUSTOMER') continue;

      final phone = (u['phone'] ?? '').toString();
      final email = u['email']?.toString();

      if (_isAgent(phone, email)) continue;

      final name = (u['full_name'] ?? (phone.isNotEmpty ? 'Customer ($phone)' : 'User')).toString();
      final key = phone.isNotEmpty ? phone : (email ?? 'user_${u['id']}');
      final id = int.tryParse(u['id']?.toString() ?? '');
      final isActive = u['is_active'] != false;
      final city = u['city']?.toString();
      final address = u['default_address']?.toString();

      customersMap[key] = _CustomerSummary(
        id: id,
        name: name,
        phone: phone,
        email: email,
        city: city,
        address: address,
        isActive: isActive,
        isRegistered: true,
        orders: [],
      );
    }

    // 2. Merge sales orders (strictly exclude orders linked to agents)
    for (var o in widget.orders) {
      if (_isAgent(o.customerPhone, o.customerEmail)) continue;

      final key = o.customerPhone.isNotEmpty ? o.customerPhone : (o.customerName.isNotEmpty ? o.customerName : 'Unknown_${o.id}');
      if (!customersMap.containsKey(key)) {
        customersMap[key] = _CustomerSummary(
          id: null,
          name: o.customerName.isNotEmpty ? o.customerName : 'Customer (${o.customerPhone})',
          phone: o.customerPhone,
          email: o.customerEmail,
          city: o.pickupCity,
          address: o.pickupAddress,
          isActive: true,
          isRegistered: false,
          orders: [o],
        );
      } else {
        final existing = customersMap[key]!;
        existing.orders.add(o);
        if ((existing.city == null || existing.city!.isEmpty) && o.pickupCity.isNotEmpty) {
          existing.city = o.pickupCity;
        }
        if ((existing.address == null || existing.address!.isEmpty) && o.pickupAddress.isNotEmpty) {
          existing.address = o.pickupAddress;
        }
      }
    }

    final customersList = customersMap.values.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false) ||
          (c.city?.toLowerCase().contains(q) ?? false);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRegisteredCustomers();
        widget.onRefresh();
      },
      color: AppTheme.primaryGreen,
      child: ListView(
        // High bottom padding so the bottom bar never overlaps items or buttons
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
        children: [
          // Header Bar
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
                      '${customersList.length} Customers',
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
              // Add Customer Button
              ElevatedButton.icon(
                onPressed: _showAddCustomerModal,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                    : const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
                onPressed: () {
                  _fetchRegisteredCustomers();
                  widget.onRefresh();
                },
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
                hintText: 'Search customer name, phone, email, city...',
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
              final customerKey = customer.id?.toString() ?? customer.phone;
              final isExpanded = _expandedCustomerKeys.contains(customerKey);
              final totalOrders = customer.orders.length;
              final totalPayout = customer.orders
                  .where((o) => o.status == 'PAYMENT_COMPLETED')
                  .fold<double>(0.0, (sum, o) => sum + (o.finalPrice ?? o.estimatedPrice));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar Initials
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: customer.isRegistered
                                ? AppTheme.primaryGreen.withOpacity(0.15)
                                : Colors.blueGrey.withOpacity(0.12),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: customer.isRegistered ? AppTheme.primaryGreen : Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customer.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                    if (customer.id != null)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
                                        onSelected: (val) {
                                          if (val == 'edit') _showEditCustomerModal(customer);
                                          if (val == 'pwd') _showResetPasswordModal(customer);
                                          if (val == 'toggle') {
                                            _api.deleteCustomer(customer.id!, toggleOnly: true).then((_) {
                                              _fetchRegisteredCustomers();
                                              widget.onRefresh();
                                            });
                                          }
                                          if (val == 'delete') _confirmDeleteCustomer(customer);
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                                          const PopupMenuItem(value: 'pwd', child: Text('Reset Password')),
                                          PopupMenuItem(value: 'toggle', child: Text(customer.isActive ? 'Deactivate' : 'Activate')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete Profile', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),

                                // Badges Row: Registered/Guest + Active/Inactive
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: customer.isRegistered ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            customer.isRegistered ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                                            size: 10,
                                            color: customer.isRegistered ? Colors.green.shade800 : Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            customer.isRegistered ? 'Registered' : 'Guest Order',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: customer.isRegistered ? Colors.green.shade800 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (customer.isRegistered) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: customer.isActive ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          customer.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: customer.isActive ? Colors.blue.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),

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
                                if (customer.city != null && customer.city!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.city!,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Action - Call Button
                          if (customer.phone.isNotEmpty)
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
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

                      const SizedBox(height: 8),

                      // Address preview if present
                      if (customer.address != null && customer.address!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.home_outlined, size: 14, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  customer.address!,
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Badges: Orders count and Lifetime Payout + View Orders Toggle
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
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
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${totalPayout.toStringAsFixed(0)} Disbursed',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ),
                          const Spacer(),
                          if (totalOrders > 0)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedCustomerKeys.remove(customerKey);
                                  } else {
                                    _expandedCustomerKeys.add(customerKey);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isExpanded ? 'Hide Orders' : 'View Orders ($totalOrders)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Expandable Orders Accordion
                      if (isExpanded && totalOrders > 0) ...[
                        const Divider(height: 16),
                        ...customer.orders.map((o) {
                          final statusColor = o.status == 'PAYMENT_COMPLETED'
                              ? Colors.green
                              : (o.status == 'CANCELLED' ? Colors.red : Colors.orange);
                          final price = o.finalPrice ?? o.estimatedPrice;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${o.id} • ${o.brandName} ${o.modelName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        o.status,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTheme.primaryGreen),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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
  final int? id;
  final String name;
  final String phone;
  final String? email;
  String? city;
  String? address;
  final bool isActive;
  final bool isRegistered;
  final List<SaleOrderModel> orders;

  _CustomerSummary({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.city,
    this.address,
    this.isActive = true,
    this.isRegistered = false,
    required this.orders,
  });
}
