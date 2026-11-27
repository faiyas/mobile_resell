import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/draft_sell_service.dart';
import '../services/customer_cache_service.dart';
import '../widgets/glass_container.dart';
import 'sell_wizard/category_selection_screen.dart';
import 'sell_wizard/device_health_check_screen.dart';
import 'sell_wizard/questionnaire_screen.dart';
import 'sell_wizard/quote_and_booking_screen.dart';
import 'orders/track_order_screen.dart';
import 'agent/agent_dashboard_screen.dart';
import 'agent/agent_inspection_screen.dart';
import 'admin/admin_portal_screen.dart';
import 'auth/auth_modal_sheet.dart';
import '../widgets/privacy_policy_modal.dart';
import '../services/app_update_service.dart';
import '../services/app_notification_service.dart';
import '../services/background_notification_runner.dart';
import '../utils/contact_launcher.dart';
import '../widgets/brand_logo.dart';
import '../utils/image_helper.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;
  bool _isLoading = false;

  List<CMSSectionModel> _cmsSections = [];
  List<DeviceCategoryModel> _categories = [];
  List<BrandModel> _brands = [];
  SellDraftData? _savedDraft;
  SaleOrderModel? _agentActiveSale;
  final ScrollController _brandsScrollController = ScrollController();
  Timer? _brandsAutoScrollTimer;

  // Hero Carousel Controllers
  final PageController _heroPageController = PageController();
  int _currentHeroSlide = 0;
  Timer? _heroAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    BackgroundNotificationRunner().start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppUpdates());
  }

  Future<void> _checkAppUpdates() async {
    try {
      final info = await AppUpdateService().checkForUpdate();
      if (mounted && info.isUpdateAvailable) {
        AppUpdateService.showUpdateDialog(context, info);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _heroAutoScrollTimer?.cancel();
    _heroPageController.dispose();
    _brandsAutoScrollTimer?.cancel();
    _brandsScrollController.dispose();
    super.dispose();
  }

  void _startHeroAutoScroll() {
    _heroAutoScrollTimer?.cancel();
    _heroAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroPageController.hasClients) return;
      final hero = _cmsSections.isNotEmpty
          ? _cmsSections.firstWhere(
              (s) => s.sectionType.toUpperCase() == 'HERO_CAROUSEL',
              orElse: () => _cmsSections.firstWhere(
                (s) => s.dataJson.containsKey('slides'),
                orElse: () => _cmsSections.first,
              ),
            )
          : null;
      int count = 1;
      if (hero != null && hero.dataJson['slides'] is List) {
        final list = hero.dataJson['slides'] as List;
        final validSlides = list
            .where((e) => e != null && e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((s) => s['is_active'] != false)
            .toList();
        if (validSlides.isNotEmpty) count = validSlides.length;
      }
      if (count <= 1) return;
      final next = (_currentHeroSlide + 1) % count;
      _heroPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startBrandsAutoScroll() {
    _brandsAutoScrollTimer?.cancel();
    _brandsAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_brandsScrollController.hasClients) return;
      final maxExtent = _brandsScrollController.position.maxScrollExtent;
      final currentOffset = _brandsScrollController.offset;
      if (currentOffset >= maxExtent) {
        _brandsScrollController.jumpTo(0);
      } else {
        _brandsScrollController.jumpTo(currentOffset + 1.2);
      }
    });
  }

  Future<void> _loadInitialData() async {
    // 1. Instant Load from Local Device Storage (or ApiService memory preloaded during splash)
    await CustomerCacheService.hydrateApiFromLocalCache(_api);
    var cachedCms = await CustomerCacheService.getCachedCMSSections();
    var cachedCats = await CustomerCacheService.getCachedCategories();
    var cachedBrands = await CustomerCacheService.getCachedBrands();
    final draft = await DraftSellService.getDraft();

    // If local storage is empty, fetch real live data directly from ApiService
    if (cachedCats.isEmpty || cachedBrands.isEmpty) {
      try {
        final results = await Future.wait<dynamic>([
          _api.getCMSSections(),
          _api.getDeviceCategories(),
          _api.getBrands(),
        ]);
        if (results[0] is List<CMSSectionModel> && (results[0] as List).isNotEmpty) {
          cachedCms = results[0] as List<CMSSectionModel>;
        }
        if (results[1] is List<DeviceCategoryModel> && (results[1] as List).isNotEmpty) {
          cachedCats = results[1] as List<DeviceCategoryModel>;
        }
        if (results[2] is List<BrandModel> && (results[2] as List).isNotEmpty) {
          cachedBrands = results[2] as List<BrandModel>;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _cmsSections = cachedCms;
        _categories = cachedCats;
        _brands = cachedBrands;
        _isLoading = false;
        _savedDraft = draft;
      });

      if (_brands.isNotEmpty) _startBrandsAutoScroll();
      _startHeroAutoScroll();
    }

    // 2. Silent Background Delta Sync (Runs in background without blocking UI or showing spinner)
    CustomerCacheService.syncCustomerDataSilently(_api).then((hasChanges) async {
      if (hasChanges && mounted) {
        final freshCms = await CustomerCacheService.getCachedCMSSections();
        final freshCats = await CustomerCacheService.getCachedCategories();
        final freshBrands = await CustomerCacheService.getCachedBrands();

        setState(() {
          _cmsSections = freshCms;
          _categories = freshCats;
          _brands = freshBrands;
        });

        if (freshBrands.isNotEmpty) _startBrandsAutoScroll();
        _startHeroAutoScroll();
      }
    }).catchError((_) {});
  }

  void _resumeDraft(SellDraftData draft) {
    if (draft.brand == null || draft.model == null || draft.variant == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySelectionScreen()));
      return;
    }

    if (draft.isQuestionnaireCompleted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteAndBookingScreen(
            brand: draft.brand!,
            model: draft.model!,
            variant: draft.variant!,
            selectedOptionCodes: draft.selectedOptionCodes,
            isCustomDevice: draft.isCustomDevice,
            customDeviceName: draft.customDeviceName,
            customDeviceCategory: draft.customDeviceCategory,
            customDeviceSpecs: draft.customDeviceSpecs,
            customExpectedPrice: draft.customExpectedPrice,
            otherDefectsNotes: draft.otherDefectsNotes,
            customStepNotes: draft.customStepNotes,
          ),
        ),
      ).then((_) => _loadInitialData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionnaireScreen(
            brand: draft.brand!,
            model: draft.model!,
            variant: draft.variant!,
            isCustomDevice: draft.isCustomDevice,
            customDeviceName: draft.customDeviceName,
            customDeviceCategory: draft.customDeviceCategory,
            customDeviceSpecs: draft.customDeviceSpecs,
            customExpectedPrice: draft.customExpectedPrice,
            initialStepIndex: draft.currentStepIndex,
            initialSelectedOptionCodes: draft.selectedOptionCodes,
            initialCustomStepNotes: draft.customStepNotes,
          ),
        ),
      ).then((_) => _loadInitialData());
    }
  }

  Widget _buildBrandLogo(BrandModel brand) {
    if (brand.logoBase64 != null && brand.logoBase64!.trim().isNotEmpty) {
      try {
        final clean = brand.logoBase64!.contains(',') ? brand.logoBase64!.split(',').last : brand.logoBase64!;
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _getBrandEmblem(brand.name),
        );
      } catch (_) {
        return _getBrandEmblem(brand.name);
      }
    }
    return _getBrandEmblem(brand.name);
  }

  Widget _getBrandEmblem(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('apple')) {
      return const Icon(Icons.apple, size: 24, color: Colors.black87);
    } else if (lower.contains('samsung')) {
      return const Text('S', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1428A0)));
    } else if (lower.contains('oneplus')) {
      return const Text('1+', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red));
    } else if (lower.contains('google')) {
      return const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4285F4)));
    } else if (lower.contains('xiaomi') || lower.contains('mi')) {
      return const Text('mi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFF6900)));
    } else if (lower.contains('nothing')) {
      return const Text('//', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87));
    }
    return const Icon(Icons.phone_android, color: AppTheme.primaryGreen, size: 20);
  }

  Widget _buildResumeDraftCard(SellDraftData draft) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFE8F8EE).withOpacity(0.92),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35), width: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'RESUME SELLING',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await DraftSellService.clearDraft();
                    setState(() => _savedDraft = null);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.12), blurRadius: 6),
                    ],
                  ),
                  child: Center(
                    child: draft.brand != null
                        ? _buildBrandLogo(draft.brand!)
                        : const Icon(Icons.devices_other_rounded, color: AppTheme.primaryGreen, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.deviceDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${draft.specSubtitle} · Est. ₹${draft.estimatedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.darkGreen),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _resumeDraft(draft),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAuth() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthModalSheet(onSuccess: () => setState(() {})),
    );
  }

  void _showOtherCategoryGadgetModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final specsCtrl = TextEditingController(text: '128GB');
    final priceCtrl = TextEditingController(text: '10000');
    String selectedCat = 'Laptop';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Icon(Icons.devices_other_rounded, color: AppTheme.primaryGreen),
                        SizedBox(width: 10),
                        Text('Sell Other Gadget Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Select category and describe your device for an instant offer.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),

                    const Text('Which device are you selling?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'label': 'Laptop / Mac', 'icon': Icons.laptop_mac, 'val': 'Laptop'},
                        {'label': 'Smartwatch', 'icon': Icons.watch, 'val': 'Smartwatch'},
                        {'label': 'Earbuds / Audio', 'icon': Icons.headphones, 'val': 'Audio'},
                        {'label': 'Gaming Console', 'icon': Icons.sports_esports, 'val': 'Console'},
                        {'label': 'Custom Gadget', 'icon': Icons.devices_other, 'val': 'Others'},
                      ].map((item) {
                        final val = item['val'] as String;
                        final isSel = selectedCat == val;
                        return ChoiceChip(
                          avatar: Icon(item['icon'] as IconData, size: 16, color: isSel ? Colors.white : AppTheme.primaryGreen),
                          label: Text(item['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppTheme.textPrimary)),
                          selected: isSel,
                          selectedColor: AppTheme.primaryGreen,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSel ? AppTheme.primaryGreen : AppTheme.border),
                          onSelected: (selected) {
                            if (selected) setModalState(() => selectedCat = val);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Brand & Device Model *',
                        hintText: 'e.g. Apple MacBook Air M1, Galaxy Watch 4, PS5...',
                        prefixIcon: Icon(Icons.drive_file_rename_outline, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: specsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Specs / RAM / Storage / Condition *',
                        hintText: 'e.g. 256GB SSD 8GB RAM, Flawless condition...',
                        prefixIcon: Icon(Icons.memory_rounded, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expected Buyback Value (₹) *',
                        hintText: 'e.g. 15000',
                        prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter device name')));
                          return;
                        }
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 10000.0;
                        Navigator.pop(ctx);

                        final virtualBrand = BrandModel(id: 0, name: selectedCat, slug: selectedCat.toLowerCase());
                        final virtualModel = PhoneModelItem(id: 0, name: name, slug: name.toLowerCase(), releaseYear: 2024);
                        final virtualVariant = StorageVariantModel(id: 0, storage: specsCtrl.text.trim(), basePrice: price, minPrice: 500.0);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceHealthCheckScreen(
                              brand: virtualBrand,
                              model: virtualModel,
                              variant: virtualVariant,
                              isCustomDevice: true,
                              customDeviceName: name,
                              customDeviceCategory: selectedCat,
                              customDeviceSpecs: specsCtrl.text.trim(),
                              customExpectedPrice: price,
                            ),
                          ),
                        );
                      },
                      child: const Text('Continue to Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _api.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final isAgent = user?.isAgent ?? false;

    // Strict Role-Based Screens
    Widget body;
    List<BottomNavigationBarItem> navItems;

    if (isAdmin) {
      if (_currentIndex >= 3) _currentIndex = 0;
      if (_currentIndex == 0) {
        body = const AdminPortalScreen(initialSection: AdminNavSection.overview);
      } else if (_currentIndex == 1) {
        body = const AdminPortalScreen(initialSection: AdminNavSection.operations);
      } else {
        body = _buildProfileContent(user);
      }

      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: 'Admin Desk',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Orders Matrix',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    } else if (isAgent) {
      if (_currentIndex >= 3) _currentIndex = 0;
      if (_currentIndex == 0) {
        body = AgentDashboardScreen(
          onStartInspection: (order) {
            setState(() {
              _agentActiveSale = order;
              _currentIndex = 1;
            });
          },
        );
      } else if (_currentIndex == 1) {
        body = AgentInspectionScreen(initialSale: _agentActiveSale);
      } else {
        body = _buildProfileContent(user);
      }

      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Queue & History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fact_check_rounded),
          label: 'Doorstep QC',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    } else {
      // Customer / Guest
      if (_currentIndex >= 4) _currentIndex = 0;
      if (_currentIndex == 0) {
        body = _buildHomeContent(user);
      } else if (_currentIndex == 1) {
        body = const TrackOrderScreen();
      } else if (_currentIndex == 2) {
        body = const CategorySelectionScreen();
      } else {
        body = _buildProfileContent(user);
      }

      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Track',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sell_outlined),
          label: 'Sell Device',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    }

    PreferredSizeWidget? appBar;
    if (isAdmin || isAgent) {
      if (_currentIndex == 2) {
        appBar = PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AppBar(
                backgroundColor: Colors.white.withOpacity(0.70),
                elevation: 0,
                title: Text(
                  isAdmin ? 'Dolly · Admin Profile' : 'Dolly · Agent Profile',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen),
                    tooltip: 'Support Help Desk',
                    onPressed: _showContactSupportModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    tooltip: 'Log Out',
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        appBar = null;
      }
    } else {
      if (_currentIndex == 1 || _currentIndex == 2) {
        appBar = null;
      } else {
        appBar = PreferredSize(
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/dolly_icon.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DOLLY',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen, size: 20),
                          tooltip: 'Support & Help Desk',
                          onPressed: _showContactSupportModal,
                        ),
                        const SizedBox(width: 4),
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
                                _confirmLogout();
                              } else if (val == 'profile') {
                                setState(() => _currentIndex = 3);
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
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 16, color: AppTheme.primaryGreen),
                                    SizedBox(width: 8),
                                    Text('My Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Log Out', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
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
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      extendBody: true,
      appBar: appBar,
      body: GlassBackgroundMesh(child: body),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
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
                  currentIndex: _currentIndex.clamp(0, navItems.length - 1),
                  onTap: (index) => setState(() => _currentIndex = index),
                  backgroundColor: Colors.transparent,
                  selectedItemColor: AppTheme.primaryGreen,
                  unselectedItemColor: AppTheme.textSecondary,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  items: navItems,
                ),
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
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: RecellBrandLoader(message: 'Loading Dolly catalog...'),
        ),
      );
    }

    // CMS Hero Section
    final hero = _cmsSections.isNotEmpty
        ? _cmsSections.firstWhere(
            (s) => s.sectionType.toUpperCase() == 'HERO_CAROUSEL',
            orElse: () => _cmsSections.firstWhere(
              (s) => s.dataJson.containsKey('slides'),
              orElse: () => _cmsSections.first,
            ),
          )
        : null;

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Promotional Hero Banner Carousel (Image or Text with 1200x480 Aspect Ratio)
            _buildPromotionalHeroCarousel(hero),

            const SizedBox(height: 20),

            if (_savedDraft != null) _buildResumeDraftCard(_savedDraft!),

            // 2. EXCLUSIVELY 2x2 CATEGORIES GRID (Like Reference Image)
            _buildBigCategoryGrid(),

            const SizedBox(height: 20),

            // 3. 2 QUICK SERVICE RECTANGLE BOXES (Instant Valuation, Track Pickup)
            _buildQuickActionBoxes(),

            const SizedBox(height: 22),

            // 4. AUTO-SCROLLING TOP BRANDS TICKER MARQUEE
            _buildAutoScrollingBrandsMarquee(),

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
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  // ================= DYNAMIC CATEGORIES GRID DIRECTLY FROM DATABASE =================
  Widget _buildPromotionalHeroCarousel(CMSSectionModel? hero) {
    List<Map<String, dynamic>> rawSlides = [];
    if (hero != null && hero.dataJson['slides'] is List) {
      final list = hero.dataJson['slides'] as List;
      rawSlides = list
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((s) => s['is_active'] != false)
          .toList();
    }

    if (rawSlides.isEmpty) {
      final hasRootImage = hero != null &&
          hero.dataJson['image_base64'] != null &&
          hero.dataJson['image_base64'].toString().isNotEmpty;
      rawSlides = [
        {
          'type': hasRootImage ? 'IMAGE' : 'TEXT',
          'title': hero?.title ?? 'Sell Your Old Device',
          'subtitle': hero?.subtitle ?? 'Get the best value for your phone with instant doorstep payout.',
          'badge': hero?.dataJson['badge'] ?? 'Dolly · Certified Buyback',
          'cta_text': 'Start Selling Now',
          'image_base64': hero?.dataJson['image_base64'] ?? '',
        }
      ];
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.5 / 1, // Matches 1200x480 admin banner ratio
          child: PageView.builder(
            controller: _heroPageController,
            itemCount: rawSlides.length,
            onPageChanged: (idx) {
              setState(() => _currentHeroSlide = idx);
            },
            itemBuilder: (ctx, index) {
              final slide = rawSlides[index];
              final imageStr = (slide['image_base64'] ?? slide['image_url'] ?? '').toString();
              final isImage = slide['type']?.toString().toUpperCase() == 'IMAGE' || imageStr.isNotEmpty;
              final bool isNetworkUrl = imageStr.startsWith('http://') || imageStr.startsWith('https://');
              final imageBytes = isNetworkUrl ? null : ImageHelper.decodeBase64(imageStr);

              if (isImage && (imageBytes != null || isNetworkUrl)) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isNetworkUrl)
                        Image.network(
                          imageStr,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.darkGreen,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 36),
                          ),
                        )
                      else
                        Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.darkGreen,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 36),
                          ),
                        ),
                      if (slide['title'] != null && slide['title'].toString().isNotEmpty)
                        Positioned(
                          bottom: 10,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Text(
                              slide['title'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }

              // Text & Gradient Banner Slide (Clean, no 60 mins)
              final title = slide['title']?.toString() ?? 'Sell Your Old Phone';
              final subtitle = slide['subtitle']?.toString() ?? 'Instant doorstep valuation and payout.';
              final badge = slide['badge']?.toString() ?? 'Dolly · Buyback';

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.deepForest, AppTheme.darkGreen, AppTheme.primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.lightGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Carousel Dot Indicators
        if (rawSlides.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(rawSlides.length, (i) {
              final isCurrent = i == _currentHeroSlide;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isCurrent ? AppTheme.primaryGreen : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildBigCategoryGrid() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const Text(
          'EXCLUSIVELY',
          style: TextStyle(
            color: Color(0xFFD32F2F),
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'From Phones to Consoles, Sell It All on Dolly!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B2A20),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, idx) {
            final cat = _categories[idx];

            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategorySelectionScreen(selectedCategory: cat),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _buildCategoryGraphic(cat, false),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1B2A20),
                      ),
                    ),
                    if (cat.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cat.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ================= 2 QUICK SERVICE FEATURE RECTANGLES =================
  Widget _buildQuickActionBoxes() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickRectangleCard(
            icon: Icons.smartphone_rounded,
            title: 'Instant Valuation',
            subtitle: 'Get 60s Live Quote',
            color: AppTheme.primaryGreen,
            bgColor: AppTheme.lightGreen.withOpacity(0.6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickRectangleCard(
            icon: Icons.local_shipping_outlined,
            title: 'Track Pickup',
            subtitle: 'Live Status & Payout',
            color: Colors.amber.shade800,
            bgColor: Colors.amber.shade50,
            onTap: () {
              setState(() => _currentIndex = 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRectangleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
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

  // ================= 4. AUTO-SCROLLING TOP BRANDS MARQUEE =================
  Widget _buildAutoScrollingBrandsMarquee() {
    if (_brands.isEmpty) return const SizedBox.shrink();

    // Multiply list so continuous loop is seamless
    final displayList = [..._brands, ..._brands, ..._brands];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Brands',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
                );
              },
              child: const Text('View All', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notif) {
              if (notif is ScrollStartNotification) {
                _brandsAutoScrollTimer?.cancel();
              } else if (notif is ScrollEndNotification) {
                _startBrandsAutoScroll();
              }
              return false;
            },
            child: ListView.builder(
              controller: _brandsScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayList.length,
              itemBuilder: (context, idx) {
                final b = displayList[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategorySelectionScreen(initialBrandId: b.id),
                        ),
                      );
                    },
                    child: Container(
                      width: 82,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: _buildBrandLogo(b),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64, color: AppTheme.primaryGreen),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to Dolly',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to manage orders, track payouts, or access role-based staff portals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
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
                        user.fullName.isNotEmpty ? user.fullName : user.email,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                        ),
                        child: Text(
                          user.role,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryGreen,
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
          // Stored Customer Details Editor
          _ProfileDetailsCard(user: user, onSaved: () => setState(() {})),
          const SizedBox(height: 16),
          if (user.isAdmin) ...[
            GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              color: AppTheme.primaryGreen.withOpacity(0.08),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Central Desk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.textPrimary)),
                        SizedBox(height: 2),
                        Text('Manage orders, field agents, payout approvals & catalog pricing rules.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _currentIndex = 0),
                    child: const Text('Open Desk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 24x7 Support & Helpline Card
          GlassContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text('24x7 Customer & Agent Support', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => ContactLauncher.callHotline(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('+91 90252 32453', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.phone_forwarded_rounded, size: 12),
                        label: const Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => ContactLauncher.callHotline(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => ContactLauncher.sendEmail(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('aiothamizha@gmail.com', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 12),
                        label: const Text('Mail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => ContactLauncher.sendEmail(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Change Password Option
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.key_rounded, color: Colors.amber.shade800, size: 20),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'Update your login security password',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: _showChangePasswordModal,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.25), width: 1.2),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              subtitle: const Text(
                'Safely disconnect this device from your Dolly session',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
              onTap: _confirmLogout,
            ),
          ),
          const SizedBox(height: 12),

          // Privacy Policy (Mandatory App Store 5.1.1 & Google Play Compliance)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryGreen, size: 20),
              ),
              title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
              subtitle: const Text('Read how Dolly handles and protects your data', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.primaryGreen),
              onTap: () => PrivacyPolicyModal.show(context),
            ),
          ),
          const SizedBox(height: 12),

          // Account Deletion (Mandatory Apple 5.1.1(v) & Google Play User Data Compliance)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
              ),
              title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              subtitle: const Text('Erase account data and personal records', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: _confirmDeleteAccount,
            ),
          ),
          const SizedBox(height: 24),

          // Official Copyright & Version Footer
          Center(
            child: Column(
              children: [
                const Text(
                  'Copyrights reserved to 1103 TechStudios',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dolly Platform · Version 2.4.0 (Build 1103)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  void _showChangePasswordModal() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool loading = false;
    String error = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change Password',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Update your Dolly login credentials',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: oldPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password * (Min 6 chars)',
                        prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password *',
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                                final oldP = oldPassCtrl.text;
                                final newP = newPassCtrl.text.trim();
                                final confP = confirmPassCtrl.text.trim();

                                if (oldP.isEmpty) {
                                  setModalState(() => error = 'Please enter your current password');
                                  return;
                                }
                                if (newP.length < 6) {
                                  setModalState(() => error = 'New password must be at least 6 characters');
                                  return;
                                }
                                if (newP != confP) {
                                  setModalState(() => error = 'New passwords do not match');
                                  return;
                                }

                                setModalState(() {
                                  loading = true;
                                  error = '';
                                });

                                try {
                                  await _api.changePassword(oldPassword: oldP, newPassword: newP);
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTheme.primaryGreen,
                                        content: Text('✓ Password changed successfully!'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    loading = false;
                                    error = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
                              },
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from Dolly?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.logout();
              if (mounted) {
                setState(() {
                  _currentIndex = 0;
                });
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          'Are you sure you want to permanently delete your Dolly account?\n\n'
          'All your personal data, default address, and saved profiles will be permanently erased. '
          'This action cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteAccount();
                if (mounted) {
                  setState(() {
                    _currentIndex = 0;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your Dolly account has been deleted successfully.'),
                      backgroundColor: Colors.black87,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showContactSupportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.headset_mic_rounded, color: AppTheme.primaryGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dolly Help Desk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary)),
                          SizedBox(height: 2),
                          Text('Doorstep Pickup Assistance & Dispatch Center', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.lightGreen, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer & Agent Hotline', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('+91 90252 32453', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.phone_forwarded_rounded, size: 14),
                        label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => ContactLauncher.callHotline(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GlassContainer(
                  padding: const EdgeInsets.all(14),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => ContactLauncher.sendEmail(context),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.email_outlined, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Official Support Email', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('aiothamizha@gmail.com', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 14),
                        label: const Text('Mail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => ContactLauncher.sendEmail(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text('24x7 Doorstep Pickup Assistance & Dispute Resolution', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
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

  Widget _buildCategoryGraphic(DeviceCategoryModel cat, bool isOther) {
    if (cat.imageBase64 != null && cat.imageBase64!.trim().isNotEmpty) {
      try {
        String base64Str = cat.imageBase64!.trim();
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallbackCategoryIcon(cat, isOther),
          ),
        );
      } catch (_) {}
    }
    return _fallbackCategoryIcon(cat, isOther);
  }

  Widget _fallbackCategoryIcon(DeviceCategoryModel cat, bool isOther) {
    return Icon(
      isOther ? Icons.devices_other_rounded : _getCategoryIcon(cat.iconName),
      color: AppTheme.primaryGreen,
      size: 26,
    );
  }
}

class _ProfileDetailsCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;

  const _ProfileDetailsCard({required this.user, required this.onSaved});

  @override
  State<_ProfileDetailsCard> createState() => _ProfileDetailsCardState();
}

class _ProfileDetailsCardState extends State<_ProfileDetailsCard> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _upiCtrl;

  bool _isSaving = false;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.fullName);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
    _addressCtrl = TextEditingController(text: widget.user.defaultAddress);
    _cityCtrl = TextEditingController(text: widget.user.city);
    _pincodeCtrl = TextEditingController(text: widget.user.pincode);
    _upiCtrl = TextEditingController(text: widget.user.defaultUpiId);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'default_address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'default_upi_id': _upiCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Profile & Doorstep Details saved to DB! Auto-applied to future bookings.'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: AppTheme.primaryGreen, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doorstep Pickup & Payout Details',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Stored in database & auto-applied on all future sell orders',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryGreen),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Number *',
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                ),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit number' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Default Doorstep Pickup Address *',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter complete address' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: InputDecoration(
                        labelText: 'City *',
                        prefixIcon: const Icon(Icons.location_city_rounded, color: AppTheme.primaryGreen, size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter city' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Pincode *',
                        prefixIcon: const Icon(Icons.pin_drop_outlined, color: AppTheme.primaryGreen, size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (val) => val == null || val.trim().length < 6 ? 'Enter pincode' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _upiCtrl,
                decoration: InputDecoration(
                  labelText: 'Default Instant UPI ID (e.g. name@okhdfcbank)',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryGreen, size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _isSaving ? 'Saving to Database...' : 'Save Details to Database',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
