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

  // OTA App Release & Update Pipeline
  final _latestVerCtrl = TextEditingController();
  final _minVerCtrl = TextEditingController();
  final _apkUrlCtrl = TextEditingController();
  final _releaseNotesCtrl = TextEditingController();
  bool _forceUpdate = false;
  bool _isSavingOta = false;
  Map<String, dynamic> _loadedSettings = {};

  // Business Profile, Contacts & Legal Links
  final _bizWebsiteCtrl = TextEditingController();
  final _bizPolicyUrlCtrl = TextEditingController();
  final _bizTermsUrlCtrl = TextEditingController();
  final _bizHelplineCtrl = TextEditingController();
  final _bizWhatsappCtrl = TextEditingController();
  final _bizEmailCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  bool _isSavingBiz = false;

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
    _loadBusinessSettings();
  }

  Future<void> _loadBusinessSettings() async {
    final b = await _api.getBusinessSettings();
    if (!mounted || b.isEmpty) return;
    setState(() {
      _bizWebsiteCtrl.text = b['website_url']?.toString() ?? '';
      _bizPolicyUrlCtrl.text = b['privacy_policy_url']?.toString() ?? '';
      _bizTermsUrlCtrl.text = b['terms_url']?.toString() ?? '';
      _bizHelplineCtrl.text = b['customer_helpline']?.toString() ?? '';
      _bizWhatsappCtrl.text = b['whatsapp_number']?.toString() ?? '';
      _bizEmailCtrl.text = b['support_email']?.toString() ?? '';
      _bizAddressCtrl.text = b['office_address']?.toString() ?? '';
    });
  }

  Future<void> _saveBusinessSettings() async {
    setState(() => _isSavingBiz = true);
    try {
      await _api.updateBusinessSettings({
        'website_url': _bizWebsiteCtrl.text.trim(),
        'privacy_policy_url': _bizPolicyUrlCtrl.text.trim(),
        'terms_url': _bizTermsUrlCtrl.text.trim(),
        'customer_helpline': _bizHelplineCtrl.text.trim(),
        'whatsapp_number': _bizWhatsappCtrl.text.trim(),
        'support_email': _bizEmailCtrl.text.trim(),
        'office_address': _bizAddressCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Business contacts, website & policy URLs updated!'),
          backgroundColor: AppTheme.darkGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save business settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBiz = false);
    }
  }

  Future<void> _loadSystemSettings() async {
    final s = await _api.getSystemSettings();
    if (!mounted || s.isEmpty) return;
    setState(() {
      _loadedSettings = Map<String, dynamic>.from(s);
      _latestVerCtrl.text = s['latest_version']?.toString() ?? '';
      _minVerCtrl.text = s['min_version']?.toString() ?? '';
      _apkUrlCtrl.text = s['apk_download_url']?.toString() ?? '';
      _releaseNotesCtrl.text = s['release_notes']?.toString() ?? '';
      _forceUpdate = s['force_update'] == true || s['force_update']?.toString().toLowerCase() == 'true';
    });
  }

  Future<void> _saveOtaUpdate() async {
    final latest = _latestVerCtrl.text.trim();
    if (latest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Latest App Version (e.g. 2.5.0)'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSavingOta = true);
    try {
      final payload = Map<String, dynamic>.from(_loadedSettings);
      payload['latest_version'] = latest;
      payload['min_version'] = _minVerCtrl.text.trim().isNotEmpty ? _minVerCtrl.text.trim() : latest;
      payload['force_update'] = _forceUpdate;
      payload['apk_download_url'] = _apkUrlCtrl.text.trim();
      payload['release_notes'] = _releaseNotesCtrl.text.trim();

      final updated = await _api.updateSystemSettings(payload);
      if (!mounted) return;
      setState(() => _loadedSettings = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ App update v$latest published & broadcast to all devices!'),
          backgroundColor: AppTheme.darkGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update publish failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingOta = false);
    }
  }

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _latestVerCtrl.dispose();
    _minVerCtrl.dispose();
    _apkUrlCtrl.dispose();
    _releaseNotesCtrl.dispose();
    _bizWebsiteCtrl.dispose();
    _bizPolicyUrlCtrl.dispose();
    _bizTermsUrlCtrl.dispose();
    _bizHelplineCtrl.dispose();
    _bizWhatsappCtrl.dispose();
    _bizEmailCtrl.dispose();
    _bizAddressCtrl.dispose();
    super.dispose();
  }

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

        // Business Contacts, Website URL & Policy Links Card
        GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.language_rounded, color: AppTheme.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Website, Contacts & Policy Links', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Update live website URL, privacy/terms page links, helpline, and support email across Web & Mobile:',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bizWebsiteCtrl,
                decoration: InputDecoration(
                  labelText: 'Website URL',
                  hintText: 'https://mobile-resell.vercel.app',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bizPolicyUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Privacy Policy Page URL',
                  hintText: 'https://mobile-resell.vercel.app/privacy-policy',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bizTermsUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Terms & Conditions Page URL',
                  hintText: 'https://mobile-resell.vercel.app/terms',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bizHelplineCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Customer Helpline',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bizWhatsappCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bizEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Support Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bizAddressCtrl,
                decoration: InputDecoration(
                  labelText: 'Office Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSavingBiz ? null : _saveBusinessSettings,
                  icon: _isSavingBiz
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                  label: Text(
                    _isSavingBiz ? 'Saving...' : 'Save Contacts & Links',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // OTA App Release & Update Pipeline Card
        GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: AppTheme.primaryGreen, size: 20),
                  SizedBox(width: 8),
                  Text('Mobile App Release & OTA Update', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Push an app version update & release alert directly to all mobile devices:',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latestVerCtrl,
                      decoration: InputDecoration(
                        labelText: 'Latest Version *',
                        hintText: 'e.g. 2.5.0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _minVerCtrl,
                      decoration: InputDecoration(
                        labelText: 'Min Supported',
                        hintText: 'e.g. 2.4.0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apkUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'APK Download URL',
                  hintText: 'https://.../dolly-latest.apk',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _releaseNotesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Release Notes / What\'s New',
                  hintText: '• Bug fixes and new features...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _forceUpdate,
                activeTrackColor: Colors.redAccent,
                title: const Text('Force Mandatory Update', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                onChanged: (v) => setState(() => _forceUpdate = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSavingOta ? null : _saveOtaUpdate,
                  icon: _isSavingOta
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.white),
                  label: Text(
                    _isSavingOta ? 'Publishing Update...' : 'Publish App Update',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
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
