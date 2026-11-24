import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/draft_sell_service.dart';
import '../widgets/brand_logo.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _taglineSlideAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeIn),
      ),
    );

    _taglineSlideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
    _startSessionAndNavigate();
  }

  Future<void> _startSessionAndNavigate() async {
    // 1. Exact 5-second splash screen duration for brand impression
    final waitFuture = Future.delayed(const Duration(milliseconds: 5000));

    // 2. Comprehensive parallel background pre-warm sync
    final syncFuture = Future(() async {
      try {
        final api = ApiService();
        // Step A: Init auth token and user state
        await api.init();

        // Step B: Pre-warm backend and cache in parallel
        await Future.wait([
          api.pingHealth().catchError((_) => false),
          api.getCMSSections().catchError((_) => []),
          api.getDeviceCategories().catchError((_) => []),
          api.getBrands().catchError((_) => []),
          DraftSellService.getDraft().catchError((_) => null),
        ]);
      } catch (e) {
        debugPrint('Splash background pre-sync error (non-fatal): $e');
      }
    });

    await Future.wait([waitFuture, syncFuture]);

    if (!mounted) return;

    // 3. Fluid Cross-Fade Transition to HomeScreen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 650),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(
        children: [
          // 1. Organic Ambient Glow Meshes
          Positioned(
            top: -size.width * 0.3,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.18),
                    AppTheme.primaryGreen.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.4,
            right: -size.width * 0.3,
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.darkGreen.withOpacity(0.14),
                    AppTheme.darkGreen.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 2. Frosted Blur Filter
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),

          // 3. Single Central Brand Logo & Choreographed Reveal
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Single Prominent Dolly Brand Logo with Ambient Glow
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/dolly_logo.png',
                            width: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/dolly_icon.png',
                              width: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                'DOLLY',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryGreen,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Frosted Glass Subtitle Tagline
                        Transform.translate(
                          offset: Offset(0, _taglineSlideAnimation.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.glassBorder,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'DOORSTEP DEVICE BUYBACK & SPOT PAYOUT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkGreen,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Smooth Bottom Loading Indicator
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 72,
                height: 3.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE2ECE5),
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
