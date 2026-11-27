import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

enum AdminNavSection {
  operations,
  payouts,
  catalog,
  triage,
  agents,
}

class AdminSidebarDrawer extends StatelessWidget {
  final AdminNavSection currentSection;
  final Function(AdminNavSection) onSelectSection;
  final VoidCallback? onRefresh;
  final int pendingOrdersCount;
  final int pendingPayoutsCount;

  const AdminSidebarDrawer({
    super.key,
    required this.currentSection,
    required this.onSelectSection,
    this.onRefresh,
    this.pendingOrdersCount = 0,
    this.pendingPayoutsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;

    return Drawer(
      backgroundColor: Colors.white.withValues(alpha: 0.94),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOLLY CONSOLE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName : 'Super Admin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
                      onPressed: onRefresh,
                      tooltip: 'Sync Data',
                    ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8, bottom: 6),
                    child: Text(
                      'OPERATIONS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.8),
                    ),
                  ),
                  _buildNavItem(
                    section: AdminNavSection.operations,
                    icon: Icons.dashboard_rounded,
                    label: 'Live Operations Desk',
                    badge: pendingOrdersCount > 0 ? pendingOrdersCount.toString() : null,
                    badgeColor: Colors.amber.shade700,
                  ),
                  _buildNavItem(
                    section: AdminNavSection.payouts,
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Smart Payout Desk',
                    badge: pendingPayoutsCount > 0 ? pendingPayoutsCount.toString() : null,
                    badgeColor: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8, bottom: 6),
                    child: Text(
                      'CATALOG & VALUATION',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.8),
                    ),
                  ),
                  _buildNavItem(
                    section: AdminNavSection.catalog,
                    icon: Icons.phone_android_rounded,
                    label: 'Catalogue & Pricing',
                  ),
                  _buildNavItem(
                    section: AdminNavSection.triage,
                    icon: Icons.rule_folder_rounded,
                    label: 'Triage Questions & Rules',
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8, bottom: 6),
                    child: Text(
                      'TEAM & LOGISTICS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.8),
                    ),
                  ),
                  _buildNavItem(
                    section: AdminNavSection.agents,
                    icon: Icons.people_alt_rounded,
                    label: 'Field Agents & Dispatch',
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  const Text('Dolly Buyback v2.0', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Exit Admin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required AdminNavSection section,
    required IconData icon,
    required String label,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = currentSection == section;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelectSection(section),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? AppTheme.darkGreen : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
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
