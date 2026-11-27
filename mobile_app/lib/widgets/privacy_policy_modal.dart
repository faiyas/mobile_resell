import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/api_config.dart';

class PrivacyPolicyModal extends StatelessWidget {
  const PrivacyPolicyModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrivacyPolicyModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Privacy & Data Wiping Policy',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Updated: November 2026 · Dolly Technologies Pvt Ltd',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Policy Content Scrollable View
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildPolicySection(
                  icon: Icons.cleaning_services_outlined,
                  title: '1. Certified Data Sanitization (Data Wiping)',
                  content:
                      'Before any device purchased through Dolly is refurbished or resold, it undergoes a mandatory multi-pass data sanitization protocol compliant with DoD 5220.22-M and NIST 800-88 guidelines.\n\n'
                      'All photos, contacts, credentials, biometric caches, and residual system files are irreversibly erased. Our field agents verify that Google Account, Apple ID / iCloud, and Knox locks are removed in your presence.',
                ),
                const SizedBox(height: 16),

                _buildPolicySection(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '2. IMEI & Ownership Verification',
                  content:
                      'To protect customers and comply with national cyber laws, every device\'s unique International Mobile Equipment Identity (IMEI) is verified in real-time against law enforcement and telecom lost/stolen registries.\n\n'
                      'We do not accept blacklisted, financed, or reported devices. Government ID verification (Aadhaar / Voter ID / Driving License) is used solely for legitimate buyback invoicing.',
                ),
                const SizedBox(height: 16),

                _buildPolicySection(
                  icon: Icons.payments_outlined,
                  title: '3. Instant Payout Data Security',
                  content:
                      'Bank accounts and UPI VPA IDs provided for doorstep payouts are tokenized and processed via RBI-authorized NPCI / IMPS banking gateways. Dolly never stores debit/credit card CVVs, netbanking passwords, or UPI MPINs.',
                ),
                const SizedBox(height: 16),

                _buildPolicySection(
                  icon: Icons.delete_forever_outlined,
                  title: '4. Account & Profile Deletion (App Compliance)',
                  content:
                      'In accordance with Google Play Section 4.8 and Apple App Store Guideline 5.1.1, you have the absolute right to request the permanent deletion of your customer profile, phone number, and history.\n\n'
                      'You can initiate account deletion at any time from Profile → Delete Account, or by writing to support@dollyresell.com. All records except statutory tax invoices will be purged within 48 hours.',
                ),
                const SizedBox(height: 16),

                _buildPolicySection(
                  icon: Icons.headset_mic_outlined,
                  title: '5. Grievance Redressal & Contact',
                  content:
                      'For any queries regarding this policy or your personal data:\n'
                      '• Grievance Officer: Mohamed Faiyas M\n'
                      '• Email: privacy@dollyresell.com / support@dollyresell.com\n'
                      '• Support Helpline: +91 99885 52211 (Mon-Sat, 9AM-8PM)',
                ),

                const SizedBox(height: 24),

                // External Link fallback button
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: AppTheme.primaryGreen),
                    label: const Text(
                      'Open Official Web Policy',
                      style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('${ApiConfig.baseUrl}/catalog/settings/');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
