import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final ApiService _api = ApiService();

  // Pincode lookup tool
  final _pincodeCtrl = TextEditingController();
  bool _isCheckingPincode = false;
  String _pincodeResult = '';
  bool _pincodeServiceable = false;

  // Password change
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _isSavingPass = false;

  Future<void> _checkPincode() async {
    final code = _pincodeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _pincodeResult = 'Please enter a 6-digit postal code');
      return;
    }

    setState(() {
      _isCheckingPincode = true;
      _pincodeResult = '';
    });

    try {
      final res = await _api.lookupPincode(code);
      if (!mounted) return;
      setState(() {
        _isCheckingPincode = false;
        if (res != null && res['serviceable'] == true) {
          _pincodeServiceable = true;
          _pincodeResult = '✓ Serviceable: ${res['city'] ?? "Covered zone"}, ${res['state'] ?? "India"}';
        } else {
          _pincodeServiceable = false;
          _pincodeResult = '✗ Out of direct pickup coverage area';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCheckingPincode = false;
        _pincodeResult = 'Lookup error: $e';
      });
    }
  }

  Future<void> _changeAdminPassword() async {
    final oldPass = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;

    if (oldPass.isEmpty || newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter current password and a new password (min 6 chars)')),
      );
      return;
    }

    setState(() => _isSavingPass = true);
    try {
      await _api.changePassword(oldPassword: oldPass, newPassword: newPass);
      if (!mounted) return;
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Admin password updated successfully!'), backgroundColor: AppTheme.darkGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password update failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSavingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'CONTROL & DIAGNOSTICS',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'System Settings & Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Diagnostics Card
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Engine Online · Dolly Buyback v2.4',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildDiagRow('API Environment', 'AWS / Instabox Production'),
              _buildDiagRow('Database Cluster', 'PostgreSQL 16 (SSL Enforced)'),
              _buildDiagRow('Image Processing Gate', 'Valid Aspect 0.4-2.5, Res >120px'),
              _buildDiagRow('Role Access', 'Super Admin (Full Administrative Gate)'),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Pincode Serviceability Tester
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pincode Serviceability Checker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text('Test whether doorstep pickup is currently serviceable for a zip code:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit Pincode (e.g. 600001)',
                        hintStyle: const TextStyle(fontSize: 12),
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isCheckingPincode ? null : _checkPincode,
                    child: _isCheckingPincode
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              if (_pincodeResult.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _pincodeResult,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _pincodeServiceable ? Colors.green.shade800 : Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Admin Security & Password Change
        GlassContainer(
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Password Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text('Update your administrative login credentials:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: _oldPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password * (Min 6 chars)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSavingPass ? null : _changeAdminPassword,
                  child: _isSavingPass
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save New Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
