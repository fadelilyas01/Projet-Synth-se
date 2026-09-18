import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget de bouclier avec radar pulsant à multi-ondes concentriques
class PulseRadarShield extends StatefulWidget {
  final bool isActive;
  final bool isContactsOnly;
  final VoidCallback? onTap;

  const PulseRadarShield({
    super.key,
    required this.isActive,
    this.isContactsOnly = false,
    this.onTap,
  });

  @override
  State<PulseRadarShield> createState() => _PulseRadarShieldState();
}

class _PulseRadarShieldState extends State<PulseRadarShield> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.isActive
        ? (widget.isContactsOnly ? AppTheme.accentOrange : AppTheme.accentCyan)
        : const Color(0xFFF87171);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap?.call();
      },
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radar à ondes concentriques animées
            if (widget.isActive)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(140, 140),
                    painter: _RadarWavesPainter(
                      progress: _controller.value,
                      waveColor: ringColor,
                    ),
                  );
                },
              ),

            // Halo central fixe doux
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: widget.isActive ? 0.22 : 0.12),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: widget.isActive ? 0.4 : 0.15),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Bouton du bouclier
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.isActive
                    ? (widget.isContactsOnly ? Icons.verified_user_rounded : Icons.shield_rounded)
                    : Icons.shield_outlined,
                size: 32,
                color: widget.isActive
                    ? (widget.isContactsOnly ? AppTheme.accentOrange : AppTheme.primaryColor)
                    : AppTheme.accentRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarWavesPainter extends CustomPainter {
  final double progress;
  final Color waveColor;

  _RadarWavesPainter({required this.progress, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const maxRadius = 68.0;
    const minRadius = 38.0;

    // 3 ondes concentriques déphasées
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = minRadius + (maxRadius - minRadius) * waveProgress;
      // Opacité décroissante avec la distance
      final opacity = (1.0 - waveProgress) * 0.5 * math.sin(waveProgress * math.pi);

      final paint = Paint()
        ..color = waveColor.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - (1.0 * waveProgress);

      canvas.drawCircle(center, radius, paint);

      // Disque translucide très léger
      final fillPaint = Paint()
        ..color = waveColor.withValues(alpha: (opacity * 0.25).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveColor != waveColor;
  }
}
