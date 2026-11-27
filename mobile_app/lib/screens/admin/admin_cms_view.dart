import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/image_helper.dart';
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
  bool _isSaving = false;

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

  CMSSectionModel? get _heroSection {
    return _sections.cast<CMSSectionModel?>().firstWhere(
      (s) => s?.sectionType.toUpperCase() == 'HERO_CAROUSEL',
      orElse: () => null,
    );
  }

  List<Map<String, dynamic>> get _heroSlides {
    final hero = _heroSection;
    if (hero != null && hero.dataJson['slides'] is List) {
      final list = hero.dataJson['slides'] as List;
      return list
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  List<CMSSectionModel> get _otherSections {
    return _sections.where((s) => s.sectionType.toUpperCase() != 'HERO_CAROUSEL').toList();
  }

  Future<void> _saveHeroCarousel(List<Map<String, dynamic>> slides) async {
    setState(() => _isSaving = true);
    try {
      final activeSlide = slides.firstWhere(
        (s) => s['is_active'] != false,
        orElse: () => slides.isNotEmpty ? slides.first : {},
      );

      final payload = {
        'section_type': 'HERO_CAROUSEL',
        'title': activeSlide['title']?.toString() ?? 'Promotional Hero Banners',
        'subtitle': activeSlide['subtitle']?.toString() ?? 'Fast access to your buyback operations',
        'display_order': 0,
        'is_active': slides.any((s) => s['is_active'] != false),
        'data_json': {
          'badge': activeSlide['badge']?.toString() ?? '1103 RECELL · Buyback Company',
          'slides': slides,
          'image_base64': activeSlide['image_base64']?.toString() ?? '',
        },
      };

      await _api.saveCMSSection(payload);
      await _loadCms();
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Hero Banners saved to Database! Live on Web & Mobile.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving hero banners: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _restoreDefaultBanners() {
    final defaultSlides = [
      {
        'id': 'slide_1',
        'type': 'TEXT',
        'badge': '1103 RECELL · The Device Buyback Company',
        'title': 'Sell Your Old Device in 60 Seconds',
        'subtitle': 'Get the best value for your phone, tablet, laptop & more with instant doorstep payout.',
        'cta_text': 'Start Selling Now',
        'image_base64': '',
        'is_active': true,
      },
      {
        'id': 'slide_2',
        'type': 'TEXT',
        'badge': 'Spot UPI Cash Transfer',
        'title': 'Doorstep Pickup & Instant UPI',
        'subtitle': 'Verified field agent arrives at your door, inspects phone, and transfers payment on spot.',
        'cta_text': 'Check Phone Value',
        'image_base64': '',
        'is_active': true,
      },
      {
        'id': 'slide_3',
        'type': 'TEXT',
        'badge': '100% Data Safe & Certified',
        'title': 'Zero-Hassle Certified Buyback',
        'subtitle': 'Government-ID verified field team with instant digital bill of sale generated.',
        'cta_text': 'Sell With Confidence',
        'image_base64': '',
        'is_active': true,
      },
    ];

    _saveHeroCarousel(defaultSlides);
  }

  void _showAddEditSlideModal({Map<String, dynamic>? existing, int? index}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final subCtrl = TextEditingController(text: existing?['subtitle'] ?? '');
    final badgeCtrl = TextEditingController(text: existing?['badge'] ?? '1103 RECELL · Certified Buyback');
    final ctaCtrl = TextEditingController(text: existing?['cta_text'] ?? 'Start Selling Now');
    String? imageBase64 = existing?['image_base64']?.toString();
    bool isActive = existing?['is_active'] != false;
    String slideType = (imageBase64 != null && imageBase64.isNotEmpty) ? 'IMAGE' : (existing?['type'] ?? 'TEXT');

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
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 14),
                Text(
                  existing == null ? 'Add Hero Banner Slide' : 'Edit Hero Slide #${(index ?? 0) + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const Text('Configure promotional graphic, text overlay, and call-to-action', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),

                // Live Banner Preview Box
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                    color: const Color(0xFF0F172A),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (imageBase64 != null && imageBase64!.isNotEmpty)
                        ? Image.memory(
                            ImageHelper.decodeBase64(imageBase64!)!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 140,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('Invalid Banner Image', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0D4722), Color(0xFF0BAA4B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  badgeCtrl.text.isNotEmpty ? badgeCtrl.text : 'PROMOTIONAL BANNER',
                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Headline Preview',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subCtrl.text.isNotEmpty ? subCtrl.text : 'Subtitle Preview',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Image Picker Controls
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightGreen,
                        foregroundColor: AppTheme.darkGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: AppTheme.primaryGreen),
                      label: Text(
                        imageBase64 != null ? 'Change Banner Picture' : 'Pick Banner Picture (Gallery)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () async {
                        final b64 = await ImageHelper.pickImageAsBase64(maxWidth: 1200, maxHeight: 600, imageQuality: 85);
                        if (b64 != null) {
                          setM(() {
                            imageBase64 = b64;
                            slideType = 'IMAGE';
                          });
                        }
                      },
                    ),
                    if (imageBase64 != null && imageBase64!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: 'Remove Picture (Use Text Banner)',
                        onPressed: () => setM(() {
                          imageBase64 = null;
                          slideType = 'TEXT';
                        }),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                const Text('Banner Headline *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  onChanged: (_) => setM(() {}),
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
                  onChanged: (_) => setM(() {}),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Badge / Eyebrow', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: badgeCtrl,
                            onChanged: (_) => setM(() {}),
                            decoration: InputDecoration(
                              hintText: 'e.g. 1103 RECELL',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CTA Button Text', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: ctaCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Start Selling Now',
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

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publish Immediately (Active in Live Carousel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  value: isActive,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => setM(() => isActive = val),
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
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a banner headline')));
                        return;
                      }

                      final updatedSlide = <String, dynamic>{
                        'id': existing?['id'] ?? 'slide_${DateTime.now().millisecondsSinceEpoch}',
                        'type': slideType,
                        'title': title,
                        'subtitle': subCtrl.text.trim(),
                        'badge': badgeCtrl.text.trim(),
                        'cta_text': ctaCtrl.text.trim(),
                        'image_base64': imageBase64 ?? '',
                        'is_active': isActive,
                      };

                      final currentSlides = List<Map<String, dynamic>>.from(_heroSlides);
                      if (index != null && index >= 0 && index < currentSlides.length) {
                        currentSlides[index] = updatedSlide;
                      } else {
                        currentSlides.add(updatedSlide);
                      }

                      Navigator.pop(ctx);
                      _saveHeroCarousel(currentSlides);
                    },
                    child: Text(
                      existing == null ? 'Add Slide to Live Carousel' : 'Save Slide Changes',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
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

  void _showOtherSectionModal(CMSSectionModel section) {
    final titleCtrl = TextEditingController(text: section.title);
    final subCtrl = TextEditingController(text: section.subtitle);
    final orderCtrl = TextEditingController(text: section.displayOrder.toString());
    bool isActive = section.isActive;

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
              Text('Edit Section: ${section.title}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              Text('Section Type: ${section.sectionType}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Title', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Subtitle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: subCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                value: isActive,
                activeColor: AppTheme.primaryGreen,
                onChanged: (val) => setM(() => isActive = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await _api.saveCMSSection({
                        'section_type': section.sectionType,
                        'title': titleCtrl.text.trim(),
                        'subtitle': subCtrl.text.trim(),
                        'display_order': int.tryParse(orderCtrl.text) ?? section.displayOrder,
                        'is_active': isActive,
                        'data_json': section.dataJson,
                      });
                      _loadCms();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _heroSlides;
    final other = _otherSections;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
        label: const Text('Add Hero Slide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: () => _showAddEditSlideModal(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCms,
        color: AppTheme.primaryGreen,
        child: ListView(
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
                        'WEBSITE & APP CMS',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Hero Carousel Banners',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${slides.length} Slides',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isSaving)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                else
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
            else ...[
              // Empty State with Restore Banners button
              if (slides.isEmpty)
                GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        const Text('No Hero Carousel Slides Configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text(
                          'Your live home page hero carousel currently has no active slides in the database.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                              icon: const Icon(Icons.restore_page_rounded, size: 16),
                              label: const Text('Restore Default Banners', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: _restoreDefaultBanners,
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Slide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _showAddEditSlideModal(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...slides.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final slide = entry.value;
                  final hasImage = slide['image_base64'] != null && slide['image_base64'].toString().isNotEmpty;
                  final isActive = slide['is_active'] != false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Slide #, Type, Active Badge, Actions
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'SLIDE #${idx + 1}',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasImage ? Colors.purple.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasImage ? 'PICTURE BANNER' : 'TEXT GRADIENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: hasImage ? Colors.purple.shade700 : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  final copy = List<Map<String, dynamic>>.from(slides);
                                  copy[idx]['is_active'] = !isActive;
                                  _saveHeroCarousel(copy);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'DISABLED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                                tooltip: 'Edit Slide Details',
                                onPressed: () => _showAddEditSlideModal(existing: slide, index: idx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                tooltip: 'Delete Slide',
                                onPressed: () {
                                  final copy = List<Map<String, dynamic>>.from(slides);
                                  copy.removeAt(idx);
                                  _saveHeroCarousel(copy);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Banner Graphic / Text Preview Card
                          Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFF0F172A),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: hasImage
                                  ? Image.memory(
                                      ImageHelper.decodeBase64(slide['image_base64'])!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 120,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Text('Corrupt Image Data', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF0D4722), Color(0xFF0BAA4B)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            (slide['badge'] ?? '1103 RECELL').toString(),
                                            style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (slide['title'] ?? 'Headline').toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            (slide['subtitle'] ?? 'Description').toString(),
                                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Details Text
                          Text(
                            slide['title']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                          ),
                          if (slide['subtitle'] != null && slide['subtitle'].toString().isNotEmpty)
                            Text(
                              slide['subtitle'].toString(),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),

                          const SizedBox(height: 10),

                          // Action Buttons: Change Picture from Gallery / Remove Picture
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.lightGreen,
                                  foregroundColor: AppTheme.darkGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                icon: const Icon(Icons.photo_library_rounded, size: 14, color: AppTheme.primaryGreen),
                                label: Text(
                                  hasImage ? 'Replace Picture' : 'Pick Picture (Gallery)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  final b64 = await ImageHelper.pickImageAsBase64(maxWidth: 1200, maxHeight: 600, imageQuality: 85);
                                  if (b64 != null) {
                                    final copy = List<Map<String, dynamic>>.from(slides);
                                    copy[idx]['image_base64'] = b64;
                                    copy[idx]['type'] = 'IMAGE';
                                    _saveHeroCarousel(copy);
                                  }
                                },
                              ),
                              if (hasImage) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                  label: const Text('Remove Picture', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    final copy = List<Map<String, dynamic>>.from(slides);
                                    copy[idx]['image_base64'] = '';
                                    copy[idx]['type'] = 'TEXT';
                                    _saveHeroCarousel(copy);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 14),

              // Other CMS Sections (Secondary)
              if (other.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'OTHER CMS SECTIONS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...other.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    'Type: ${s.sectionType}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.isActive ? 'ACTIVE' : 'DRAFT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: s.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGreen),
                              onPressed: () => _showOtherSectionModal(s),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
