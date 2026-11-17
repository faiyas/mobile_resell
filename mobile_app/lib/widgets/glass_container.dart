import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    dynamic borderRadius,
    this.blur = 16.0,
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
    this.onTap,
  }) : borderRadius = borderRadius == null
            ? BorderRadius.circular(24.0)
            : (borderRadius is num
                ? BorderRadius.circular(borderRadius.toDouble())
                : (borderRadius as BorderRadiusGeometry));

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: const Color(0xFF0BAA4B).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.78),
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.90),
                      Colors.white.withValues(alpha: 0.65),
                      const Color(0xFFE8F8ED).withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius is BorderRadius ? (borderRadius as BorderRadius) : BorderRadius.circular(24.0),
        child: content,
      );
    }
    return content;
  }
}

/// A background widget that creates a stunning ambient pastel green & mint mesh orbs backdrop
class GlassBackgroundMesh extends StatelessWidget {
  final Widget child;

  const GlassBackgroundMesh({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base canvas
        Container(
          color: const Color(0xFFF7FAF8),
        ),

        // Glowing mint orb - top right
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0BAA4B).withValues(alpha: 0.16),
                  const Color(0xFF10B981).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
          ),
        ),

        // Glowing soft emerald orb - middle left
        Positioned(
          top: 240,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF34D399).withValues(alpha: 0.14),
                  const Color(0xFFE8F8ED).withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                radius: 0.85,
              ),
            ),
          ),
        ),

        // Glowing soft orb - bottom right
        Positioned(
          bottom: 100,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF087C38).withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                radius: 0.75,
              ),
            ),
          ),
        ),

        // Foreground content
        child,
      ],
    );
  }
}
