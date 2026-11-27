import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AdminCmsView extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminCmsView({super.key, required this.onRefresh});

  @override
  State<AdminCmsView> createState() => _AdminCmsViewState();
}

class _AdminCmsViewState extends State<AdminCmsView> {
  final ApiService _api = ApiService();
  List<CMSSectionModel> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCms();
  }

  Future<void> _loadCms() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCMSSections(forceRefresh: true);
      if (mounted) setState(() => _sections = res);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showBannerModal([CMSSectionModel? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final typeCtrl = TextEditingController(text: existing?.sectionType ?? 'HERO_BANNER');
    final orderCtrl = TextEditingController(text: (existing?.displayOrder ?? (_sections.length + 1)).toString());
    bool isActive = existing?.isActive ?? true;
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
              Text(existing == null ? 'Add CMS Hero Banner' : 'Edit Banner: ${existing.title}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const Text('Configure home page banners and announcements', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Banner Headline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Sell Your Used Phone in 60 Seconds',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Subtitle / Description', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: subCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Instant doorstep pickup & spot UPI cash transfer',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: typeCtrl.text.isNotEmpty ? typeCtrl.text : 'HERO_BANNER',
                      decoration: InputDecoration(
                        labelText: 'Section Type',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'HERO_BANNER', child: Text('Hero Banner')),
                        DropdownMenuItem(value: 'HOW_IT_WORKS', child: Text('How It Works')),
                        DropdownMenuItem(value: 'TRUST_BADGES', child: Text('Trust Badges')),
                      ],
                      onChanged: (val) => setM(() => typeCtrl.text = val ?? 'HERO_BANNER'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Display Order',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish Immediately (Active)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                value: isActive,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) => setM(() => isActive = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final ord = int.tryParse(orderCtrl.text) ?? 1;
                          setM(() => isSaving = true);
                          try {
                            await _api.saveCMSSection({
                              'section_type': typeCtrl.text.trim(),
                              'title': title,
                              'subtitle': subCtrl.text.trim(),
                              'display_order': ord,
                              'is_active': isActive,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadCms();
                          } catch (e) {
                            setM(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(existing == null ? 'Create Banner' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Add Hero Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: () => _showBannerModal(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCms,
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
                    children: const [
                      Text(
                        'WEBSITE CMS',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hero Banners & Content',
                        style: TextStyle(
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
                  onPressed: _loadCms,
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              )
            else if (_sections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.image_outlined, size: 48, color: AppTheme.textSecondary),
                      SizedBox(height: 10),
                      Text('No hero banners configured yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ..._sections.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                section.title.isNotEmpty ? section.title : 'Banner Section #${section.id}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: section.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                section.isActive ? 'ACTIVE' : 'DRAFT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: section.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: AppTheme.primaryGreen),
                              onPressed: () => _showBannerModal(section),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type: ${section.sectionType} · Order: ${section.displayOrder}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        if (section.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            section.subtitle,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
