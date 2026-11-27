import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminAgentsView extends StatefulWidget {
  final List<AgentUserModel> agents;
  final List<SaleOrderModel> orders;
  final VoidCallback onRefresh;

  const AdminAgentsView({
    super.key,
    required this.agents,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<AdminAgentsView> createState() => _AdminAgentsViewState();
}

class _AdminAgentsViewState extends State<AdminAgentsView> {
  final ApiService _api = ApiService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredAgents = widget.agents.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.fullName.toLowerCase().contains(q) || a.phone.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: AppTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Header with Add Agent Button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOGISTICS & DISPATCH',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.agents.length} Active Field Specialists',
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
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                label: const Text('Add Agent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () => _showAddAgentModal(context),
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
                hintText: 'Search agent name or phone number...',
                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryGreen),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (filteredAgents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.badge_outlined, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 10),
                    Text('No field agents found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...filteredAgents.map((agent) {
              // Count how many orders are assigned to this agent
              final assignedCount = widget.orders.where((o) {
                final agentIdVal = o.assignedAgent;
                if (agentIdVal == null) return false;
                if (agentIdVal is int) return agentIdVal == agent.id;
                if (agentIdVal is Map) return agentIdVal['id'] == agent.id;
                return false;
              }).length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Agent Badge
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          agent.fullName.isNotEmpty ? agent.fullName[0].toUpperCase() : 'A',
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
                              agent.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${agent.phone}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: assignedCount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$assignedCount Active Pickups',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: assignedCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Action - Reset Password
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 34),
                          side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.key_rounded, size: 14, color: AppTheme.primaryGreen),
                        label: const Text('Reset Pass', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                        onPressed: () => _showResetPasswordModal(context, agent),
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

  void _showAddAgentModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Onboard New Field Agent', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '10-Digit Mobile Number *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Initial Password (Min 6 chars) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            final pass = passCtrl.text;

                            if (name.isEmpty || phone.length != 10 || email.isEmpty || pass.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter valid agent details (10-digit phone, 6+ char password)')),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);
                            try {
                              await _api.createAgent({
                                'full_name': name,
                                'phone': phone,
                                'email': email,
                                'password': pass,
                              });
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              widget.onRefresh();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✓ Agent $name created successfully!'), backgroundColor: AppTheme.darkGreen),
                              );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Field Specialist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetPasswordModal(BuildContext context, AgentUserModel agent) {
    final passCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset Password for ${agent.fullName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter new password for this field specialist:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password (min 6 chars)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPass = passCtrl.text;
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        return;
                      }

                      setDlgState(() => isSaving = true);
                      try {
                        await _api.adminResetAgentPassword(agentId: agent.id, newPassword: newPass);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✓ Password reset for ${agent.fullName}'), backgroundColor: AppTheme.darkGreen),
                        );
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
