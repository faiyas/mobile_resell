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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
