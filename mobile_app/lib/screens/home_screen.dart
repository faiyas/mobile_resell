import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/draft_sell_service.dart';
import '../widgets/glass_container.dart';
import 'sell_wizard/category_selection_screen.dart';
import 'sell_wizard/questionnaire_screen.dart';
import 'sell_wizard/quote_and_booking_screen.dart';
import 'orders/track_order_screen.dart';
import 'agent/agent_dashboard_screen.dart';
import 'agent/agent_inspection_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth/auth_modal_sheet.dart';
import '../utils/contact_launcher.dart';
import '../widgets/brand_logo.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;
  bool _isLoading = true;

  List<CMSSectionModel> _cmsSections = [];
  List<DeviceCategoryModel> _categories = [];
  List<BrandModel> _brands = [];
  SellDraftData? _savedDraft;
  SaleOrderModel? _agentActiveSale;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final cms = await _api.getCMSSections();
      final cats = await _api.getDeviceCategories();
      final br = await _api.getBrands();
      final draft = await DraftSellService.getDraft();

      if (mounted) {
        setState(() {
          _cmsSections = cms;
          _categories = cats;
          _brands = br;
          _savedDraft = draft;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resumeDraft(SellDraftData draft) {
    if (draft.brand == null || draft.model == null || draft.variant == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySelectionScreen()));
      return;
    }

    if (draft.selectedOptionCodes.isNotEmpty && draft.estimatedPrice > 0) {
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
                            builder: (_) => QuestionnaireScreen(
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
    final isAdmin = user?.role == 'ADMIN';
    final isAgent = user?.role == 'COLLECTION_AGENT';

    // Strict Role-Based Screens
    Widget body;
    List<BottomNavigationBarItem> navItems;

    if (isAdmin) {
      if (_currentIndex >= 3) _currentIndex = 0;
      if (_currentIndex == 0) {
        body = const AdminDashboardScreen();
      } else if (_currentIndex == 1) {
        body = const TrackOrderScreen();
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
                  isAdmin ? '1103 RECELL · Admin Profile' : '1103 RECELL · Agent Profile',
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.darkGreen, AppTheme.primaryGreen],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '1103 RECELL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
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
          child: RecellBrandLoader(message: 'Loading 1103 RECELL catalog...'),
        ),
      );
    }

    // CMS Hero Section
    final hero = _cmsSections.isNotEmpty
        ? _cmsSections.firstWhere(
            (s) => s.sectionType == 'hero_carousel',
            orElse: () => _cmsSections.first,
          )
        : null;

    final heroTitle = hero?.title ?? 'Sell Your Old Phone for Instant Cash';
    final heroSubtitle = hero?.subtitle ?? 'Get a rule-based valuation in 60s & instant doorstep payout.';
    final heroBadge = hero?.dataJson['badge'] ?? '1103 RECELL · Certified Buyback';

    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Promotional Hero Banner (Green Gradient Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.deepForest, AppTheme.darkGreen, AppTheme.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      heroBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heroTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    heroSubtitle,
                    style: const TextStyle(
                      color: AppTheme.lightGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategorySelectionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.darkGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CHECK RESALE VALUE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_savedDraft != null) _buildResumeDraftCard(_savedDraft!),

            // 2. Quick Action Tiles
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.smartphone,
                    title: 'Instant Valuation',
                    subtitle: 'Get 60s Quote',
                    bgColor: AppTheme.lightGreen,
                    iconColor: AppTheme.primaryGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategorySelectionScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Track Pickup',
                    subtitle: 'Agent Status',
                    bgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Payout',
                    subtitle: 'UPI Receipt',
                    bgColor: const Color(0xFFEDE9FE),
                    iconColor: const Color(0xFF7C3AED),
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. Choose Category (Device Categories)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Device Category',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategorySelectionScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Builder(
              builder: (context) {
                // Only show active categories (defaults: Mobile, Tablet, Gaming Console)
                final activeCats = _categories.where((c) => c.isActive).toList();
                final displayCats = activeCats.isNotEmpty
                    ? activeCats
                    : _categories.where((c) {
                        final n = c.name.toLowerCase();
                        return n == 'mobile' || n == 'tablet' || n == 'gaming console';
                      }).toList();

                final isThree = displayCats.length <= 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isThree ? displayCats.length : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isThree ? 0.95 : 1.35,
                  ),
                  itemCount: displayCats.length,
                  itemBuilder: (context, idx) {
                    final cat = displayCats[idx];
                    final isOther = cat.name.toLowerCase() == 'other' || cat.name.toLowerCase() == 'others';

                    return GlassContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: 20,
                      onTap: () {
                        if (isOther) {
                          _showOtherCategoryGadgetModal(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategorySelectionScreen(selectedCategory: cat),
                            ),
                          );
                        }
                      },
                      child: isThree
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreen.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withValues(alpha: 0.18),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _buildCategoryGraphic(cat, isOther),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOther ? 'Custom' : 'Instant Offer',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isOther ? AppTheme.darkGreen : AppTheme.textSecondary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightGreen.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryGreen.withValues(alpha: 0.20),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _buildCategoryGraphic(cat, isOther),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOther ? 'Custom Gadget' : 'Instant Offer',
                                        style: TextStyle(
                                          color: isOther ? AppTheme.darkGreen : AppTheme.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 14),

            // 4. Top Brands (Scrollable showcase only, not clickable)
            const Text(
              'Top Phone Brands',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _brands.length,
                itemBuilder: (context, idx) {
                  final brand = _brands[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GlassContainer(
                      width: 95,
                      borderRadius: 18,
                      padding: const EdgeInsets.all(8),
                      onTap: null, // Display only, not clickable
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.12), blurRadius: 4),
                              ],
                            ),
                            child: Center(child: _buildBrandLogo(brand)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            brand.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

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
                  'Welcome to 1103 RECELL',
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
          // Switch Role Quick Button
          GlassContainer(
            padding: const EdgeInsets.all(6),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryGreen),
              title: const Text('Switch Account Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
              subtitle: const Text('Fast switch between Admin, Agent & Customer', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryGreen),
              onTap: _showAuth,
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
                'Safely disconnect this device from your 1103 session',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
              onTap: _confirmLogout,
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from 1103 RECELL?'),
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
                          Text('1103 RECELL Help Desk', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.textPrimary)),
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
