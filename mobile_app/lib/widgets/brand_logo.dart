import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 1103 RECELL Signature Vector Emblem Painter
/// Renders an ultra-sharp, scalable smartphone inside an emerald circular renewal orbit.
class RecellLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double orbitRotation;

  RecellLogoPainter({
    this.primaryColor = AppTheme.primaryGreen,
    this.secondaryColor = AppTheme.darkGreen,
    this.orbitRotation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Ambient Glow Backing
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.35),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.05));
    canvas.drawCircle(center, radius * 1.05, glowPaint);

    // 2. Circular Renewal Orbit (Circular Flow Ring)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orbitRotation);
    canvas.translate(-center.dx, -center.dy);

    final ringRect = Rect.fromCircle(center: center, radius: radius * 0.82);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          primaryColor.withOpacity(0.15),
          primaryColor,
          secondaryColor,
          primaryColor.withOpacity(0.15),
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(ringRect);

    // Draw broken circular arcs to represent renewal orbit
    canvas.drawArc(ringRect, 0.2, math.pi * 0.75, false, ringPaint);
    canvas.drawArc(ringRect, math.pi * 1.1, math.pi * 0.75, false, ringPaint);

    // Little orbit nodes / arrowhead dots
    final dotPaint = Paint()..color = primaryColor;
    final dot1 = Offset(
      center.dx + radius * 0.82 * math.cos(0.2 + math.pi * 0.75),
      center.dy + radius * 0.82 * math.sin(0.2 + math.pi * 0.75),
    );
    canvas.drawCircle(dot1, size.width * 0.05, dotPaint);

    final dot2 = Offset(
      center.dx + radius * 0.82 * math.cos(math.pi * 1.1 + math.pi * 0.75),
      center.dy + radius * 0.82 * math.sin(math.pi * 1.1 + math.pi * 0.75),
    );
    canvas.drawCircle(dot2, size.width * 0.05, dotPaint);
    canvas.restore();

    // 3. Central Smartphone Silhouette
    final phoneWidth = size.width * 0.44;
    final phoneHeight = size.height * 0.62;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: phoneWidth, height: phoneHeight),
      Radius.circular(size.width * 0.09),
    );

    // Phone Body Shadow & Fill
    final phoneBgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF1F8F3)],
      ).createShader(phoneRect.outerRect);
    canvas.drawRRect(phoneRect, phoneBgPaint);

    final phoneBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      ).createShader(phoneRect.outerRect);
    canvas.drawRRect(phoneRect, phoneBorderPaint);

    // Screen Screen Notch / Camera
    final notchPaint = Paint()..color = secondaryColor.withOpacity(0.85);
    final notchRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - phoneHeight / 2 + size.width * 0.055),
        width: phoneWidth * 0.38,
        height: size.width * 0.03,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(notchRect, notchPaint);

    // Center Lightning/Refresh Spark (Symbolizing Instant Payout)
    final sparkPath = Path();
    final sx = center.dx;
    final sy = center.dy;
    final sw = size.width * 0.12;
    final sh = size.height * 0.18;

    sparkPath.moveTo(sx + sw * 0.2, sy - sh * 0.6);
    sparkPath.lineTo(sx - sw * 0.6, sy + sh * 0.05);
    sparkPath.lineTo(sx - sw * 0.05, sy + sh * 0.05);
    sparkPath.lineTo(sx - sw * 0.2, sy + sh * 0.6);
    sparkPath.lineTo(sx + sw * 0.6, sy - sh * 0.05);
    sparkPath.lineTo(sx + sw * 0.05, sy - sh * 0.05);
    sparkPath.close();

    final sparkPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
      ).createShader(sparkPath.getBounds());
    canvas.drawPath(sparkPath, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant RecellLogoPainter oldDelegate) {
    return oldDelegate.orbitRotation != orbitRotation ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Standalone Emblem Widget
class RecellLogoIcon extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double orbitRotation;

  const RecellLogoIcon({
    super.key,
    this.size = 64,
    this.primaryColor,
    this.secondaryColor,
    this.orbitRotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/dolly_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: RecellLogoPainter(
            primaryColor: primaryColor ?? AppTheme.primaryGreen,
            secondaryColor: secondaryColor ?? AppTheme.darkGreen,
            orbitRotation: orbitRotation,
          ),
        ),
      ),
    );
  }
}

/// Full 1103 RECELL Brand Logo (Emblem + Typography)
class RecellBrandLogo extends StatelessWidget {
  final double size;
  final bool showTagline;
  final bool isDark;

  const RecellBrandLogo({
    super.key,
    this.size = 80,
    this.showTagline = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/dolly_logo.png',
          width: size * 2.4,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RecellLogoIcon(size: size),
              const SizedBox(height: 12),
              Text(
                'DOLLY',
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'INSTANT DEVICE BUYBACK · 1103 TECHSTUDIOS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkGreen,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dynamic Animated Brand Loader for Seamless In-App Page Transitions
class RecellBrandLoader extends StatefulWidget {
  final String? message;
  final double size;

  const RecellBrandLoader({
    super.key,
    this.message,
    this.size = 54,
  });

  @override
  State<RecellBrandLoader> createState() => _RecellBrandLoaderState();
}

class _RecellBrandLoaderState extends State<RecellBrandLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = 0.95 + 0.08 * math.sin(_controller.value * 2 * math.pi);
              return Transform.scale(
                scale: scale,
                child: RecellLogoIcon(
                  size: widget.size,
                  orbitRotation: _controller.value * 2 * math.pi,
                ),
              );
            },
          ),
          if (widget.message != null && widget.message!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
