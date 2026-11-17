import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';
import 'sell_wizard/category_selection_screen.dart';
import 'orders/track_order_screen.dart';
import 'agent/agent_inspection_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth/auth_modal_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;
  bool _isLoading = true;

  List<CMSSectionModel> _cmsSections = [];
  List<DeviceCategoryModel> _categories = [];
  List<BrandModel> _brands = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cms = await _api.getCMSSections();
      final cats = await _api.getDeviceCategories();
      final br = await _api.getBrands();

      if (mounted) {
        setState(() {
          _cmsSections = cms;
          _categories = cats;
          _brands = br;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthModalSheet(onSuccess: () => setState(() {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _api.currentUser;
    final isAdmin = user?.role == 'ADMIN';
    final isAgent = user?.role == 'COLLECTION_AGENT';

    // Body based on dynamic role navigation
    Widget body;
    if (isAdmin) {
      if (_currentIndex == 0) {
        body = _buildHomeContent(user);
      } else if (_currentIndex == 1) {
        body = const TrackOrderScreen();
      } else if (_currentIndex == 2) {
        body = const AgentInspectionScreen();
      } else if (_currentIndex == 3) {
        body = const AdminDashboardScreen();
      } else {
        body = _buildProfileContent(user);
      }
    } else if (isAgent) {
      if (_currentIndex == 0) {
        body = _buildHomeContent(user);
      } else if (_currentIndex == 1) {
        body = const TrackOrderScreen();
      } else if (_currentIndex == 2) {
        body = const AgentInspectionScreen();
      } else {
        body = _buildProfileContent(user);
      }
    } else {
      if (_currentIndex == 0) {
        body = _buildHomeContent(user);
      } else if (_currentIndex == 1) {
        body = const TrackOrderScreen();
      } else if (_currentIndex == 2) {
        body = const CategorySelectionScreen();
      } else {
        body = _buildProfileContent(user);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.darkGreen, AppTheme.primaryGreen],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          '1103 RECELL',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Text('📍', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 3),
                            Text(
                              'Tirupur',
                              style: TextStyle(
                                color: AppTheme.darkGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (user == null)
                        TextButton.icon(
                          onPressed: _showAuth,
                          icon: const Icon(Icons.login, size: 16, color: AppTheme.primaryGreen),
                          label: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        PopupMenuButton<String>(
                          icon: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.lightGreen,
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          onSelected: (val) {
                            if (val == 'logout') {
                              _api.logout().then((_) => setState(() {}));
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                '${user.fullName} (${user.role})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Text('Logout', style: TextStyle(color: Colors.red, fontSize: 13)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: GlassBackgroundMesh(child: body),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0BAA4B).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex.clamp(0, (isAdmin ? 4 : 3)),
                onTap: (index) => setState(() => _currentIndex = index),
                backgroundColor: Colors.transparent,
                selectedItemColor: AppTheme.primaryGreen,
                unselectedItemColor: AppTheme.textSecondary,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long),
                    label: 'Track',
                  ),
                  if (isAdmin) ...[
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.verified_outlined),
                      label: 'Agent QC',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.admin_panel_settings),
                      label: 'Admin Desk',
                    ),
                  ] else if (isAgent) ...[
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.verified_outlined),
                      label: 'Agent QC',
                    ),
                  ] else ...[
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.sell_outlined),
                      label: 'Sell Device',
                    ),
                  ],
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(UserModel? user) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    // CMS Hero Section
    final hero = _cmsSections.isNotEmpty
        ? _cmsSections.firstWhere(
            (s) => s.sectionType == 'hero_carousel',
            orElse: () => _cmsSections.first,
          )
        : null;

    final heroTitle = hero?.title ?? 'Sell Your Old Phone for Instant Cash';
    final heroSubtitle = hero?.subtitle ?? 'Get a rule-based valuation in 60s & instant doorstep payout.';
    final heroBadge = hero?.dataJson['badge'] ?? '1103 RECELL · Certified Buyback';

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Promotional Hero Banner (Green Gradient Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.deepForest, AppTheme.darkGreen, AppTheme.primaryGreen],
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      heroBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heroTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    heroSubtitle,
                    style: const TextStyle(
                      color: AppTheme.lightGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategorySelectionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.darkGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '📱 SELL MY PHONE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Quick Action Tiles
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.smartphone,
                    title: 'Sell Device',
                    subtitle: 'Instant Quote',
                    bgColor: AppTheme.lightGreen,
                    iconColor: AppTheme.primaryGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategorySelectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Track Pickup',
                    subtitle: 'Agent Status',
                    bgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Payout',
                    subtitle: 'UPI Receipt',
                    bgColor: const Color(0xFFEDE9FE),
                    iconColor: const Color(0xFF7C3AED),
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Choose Category (Device Categories)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Device Category',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategorySelectionScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                return GlassContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 20,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategorySelectionScreen(selectedCategory: cat),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(cat.iconName),
                          color: AppTheme.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Sell now',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 4. Top Brands
            const Text(
              'Top Phone Brands',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _brands.length,
                itemBuilder: (context, idx) {
                  final brand = _brands[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GlassContainer(
                      width: 95,
                      borderRadius: 18,
                      padding: const EdgeInsets.all(8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategorySelectionScreen(
                              initialBrandId: brand.id,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGreen.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.phone_android, color: AppTheme.primaryGreen, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            brand.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 5. Trust & Certified Security Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 22,
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.lightGreen,
                    child: Icon(Icons.shield_outlined, color: AppTheme.primaryGreen),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Certified Data Wipe',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Every device undergoes certified factory wipe upon doorstep physical handover.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(UserModel? user) {
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 64, color: AppTheme.primaryGreen),
              const SizedBox(height: 12),
              const Text(
                'Welcome to 1103 RECELL',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to manage orders, track payouts, or access staff portals.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showAuth,
                child: const Text('Sign In / Register'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.lightGreen,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _api.logout().then((_) => setState(() {})),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'tablet':
        return Icons.tablet_android;
      case 'laptop':
        return Icons.laptop_mac;
      case 'smartwatch':
      case 'watch':
        return Icons.watch;
      case 'dead':
        return Icons.phone_locked;
      default:
        return Icons.smartphone;
    }
  }
}
