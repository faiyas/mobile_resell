import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

enum AdminNavSection {
  overview,
  operations,
  customers,
  payouts,
  payoutHistory,
  agents,
  catalog,
  triage,
  simulator,
  cms,
  settings,
}

class AdminSidebarDrawer extends StatelessWidget {
  final AdminNavSection currentSection;
  final Function(AdminNavSection) onSelectSection;
  final VoidCallback? onRefresh;
  final int pendingOrdersCount;
  final int customersCount;
  final int pendingPayoutsCount;
  final int paidPayoutsCount;
  final int agentsCount;
  final int brandsCount;

  const AdminSidebarDrawer({
    super.key,
    required this.currentSection,
    required this.onSelectSection,
    this.onRefresh,
    this.pendingOrdersCount = 0,
    this.customersCount = 0,
    this.pendingPayoutsCount = 0,
    this.paidPayoutsCount = 0,
    this.agentsCount = 0,
    this.brandsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;

    return Drawer(
      backgroundColor: const Color(0xFF082F1D), // Dark emerald theme matching Web Admin
      elevation: 20,
      child: SafeArea(
        child: Column(
          children: [
            // Header - Dolly BUYBACK Branding
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF062617),
                border: Border(bottom: BorderSide(color: Color(0xFF0D442B))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Dolly',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'BUYBACK',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName : 'Super Admin',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Navigation Items Scrollable List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                children: [
                  // OVERVIEW
                  _buildSectionHeader('OVERVIEW'),
                  _buildNavItem(
                    section: AdminNavSection.overview,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                  ),

                  const SizedBox(height: 12),
                  // SALES
                  _buildSectionHeader('SALES'),
                  _buildNavItem(
                    section: AdminNavSection.operations,
                    icon: Icons.shopping_bag_outlined,
                    label: 'Customer Sales',
                    badgeCount: pendingOrdersCount,
                  ),
                  _buildNavItem(
                    section: AdminNavSection.customers,
                    icon: Icons.people_outline_rounded,
                    label: 'Customers',
                    badgeCount: customersCount > 0 ? customersCount : null,
                  ),

                  const SizedBox(height: 12),
                  // OPERATIONS
                  _buildSectionHeader('OPERATIONS'),
                  _buildNavItem(
                    section: AdminNavSection.payouts,
                    icon: Icons.currency_rupee_rounded,
                    label: 'Payout Desk',
                    badgeCount: pendingPayoutsCount,
                    isAlert: pendingPayoutsCount > 0,
                  ),
                  _buildNavItem(
                    section: AdminNavSection.payoutHistory,
                    icon: Icons.history_rounded,
                    label: 'Payout History',
                    badgeCount: paidPayoutsCount > 0 ? paidPayoutsCount : null,
                  ),
                  _buildNavItem(
                    section: AdminNavSection.agents,
                    icon: Icons.badge_outlined,
                    label: 'Field Agents',
                    badgeCount: agentsCount > 0 ? agentsCount : null,
                  ),

                  const SizedBox(height: 12),
                  // CATALOGUE & PRICING
                  _buildSectionHeader('CATALOGUE & PRICING'),
                  _buildNavItem(
                    section: AdminNavSection.catalog,
                    icon: Icons.phone_android_rounded,
                    label: 'Brands, Models & Prices',
                    badgeCount: brandsCount > 0 ? brandsCount : null,
                  ),

                  const SizedBox(height: 12),
                  // VALUATION
                  _buildSectionHeader('VALUATION'),
                  _buildNavItem(
                    section: AdminNavSection.triage,
                    icon: Icons.quiz_outlined,
                    label: 'Questionnaire Builder',
                  ),
                  _buildNavItem(
                    section: AdminNavSection.simulator,
                    icon: Icons.calculate_outlined,
                    label: 'Valuation Simulator',
                  ),

                  const SizedBox(height: 12),
                  // WEBSITE CMS
                  _buildSectionHeader('WEBSITE CMS'),
                  _buildNavItem(
                    section: AdminNavSection.cms,
                    icon: Icons.image_outlined,
                    label: 'Hero Banners (CMS)',
                  ),

                  const SizedBox(height: 12),
                  // SYSTEM
                  _buildSectionHeader('SYSTEM'),
                  _buildNavItem(
                    section: AdminNavSection.settings,
                    icon: Icons.tune_rounded,
                    label: 'Settings & Diagnostics',
                  ),
                ],
              ),
            ),

            // Footer Status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF062617),
                border: Border(top: BorderSide(color: Color(0xFF0D442B))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Engine Online · v2.4',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Dolly Buyback',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF34D399).withValues(alpha: 0.65),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required AdminNavSection section,
    required IconData icon,
    required String label,
    int? badgeCount,
    bool isAlert = false,
  }) {
    final isSelected = currentSection == section;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelectSection(section),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F8ED) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? const Color(0xFF087C38) : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF087C38) : Colors.white,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF087C38)
                          : (isAlert ? Colors.amber.shade700 : Colors.white.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isAlert ? Colors.white : Colors.white70),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
