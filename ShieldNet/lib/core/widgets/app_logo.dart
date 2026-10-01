import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Painter vectoriel pur du logo ShieldNet.
/// Rendu GPU natif, netteté vectorielle 100% à n'importe quelle résolution.
class ShieldLogoPainter extends CustomPainter {
  final bool isDark;

  const ShieldLogoPainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 128.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Corps du bouclier externe (Dégradé Bleu Sécurité)
    final outerPath = Path()
      ..moveTo(64, 8)
      ..lineTo(108, 24)
      ..cubicTo(108, 68, 88, 102, 64, 120)
      ..cubicTo(40, 102, 20, 68, 20, 24)
      ..close();

    final outerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
      ).createShader(const Rect.fromLTWH(20, 8, 88, 112));
    canvas.drawPath(outerPath, outerPaint);

    // 2. Bouclier intérieur (Contraste sombre & bordure fine)
    final innerPath = Path()
      ..moveTo(64, 16)
      ..lineTo(100, 29)
      ..cubicTo(100, 66, 83, 95, 64, 110)
      ..cubicTo(45, 95, 28, 66, 28, 29)
      ..close();

    final innerPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);

    final innerBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(innerPath, innerBorder);

    // 3. Ondes radio télécom
    final wavePaint1 = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final waveRect1 = Rect.fromCircle(center: const Offset(64, 52), radius: 16);
    canvas.drawArc(waveRect1, 3.14159, 3.14159, false, wavePaint1);

    final wavePaint2 = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final waveRect2 = Rect.fromCircle(center: const Offset(64, 62), radius: 10);
    canvas.drawArc(waveRect2, 3.14159, 3.14159, false, wavePaint2);

    // 4. Crochet de validation vert sécurité
    final checkPath = Path()
      ..moveTo(48, 76)
      ..lineTo(59, 87)
      ..lineTo(82, 60);

    final checkPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      ).createShader(const Rect.fromLTWH(48, 60, 34, 27))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, checkPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget officiel ShieldNetLogo réutilisable dans toute l'application.
/// Supporte les constructeurs constants, le mode badge et le mode titre textuel.
class ShieldNetLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double fontSize;
  final Color? textColor;
  final bool isBadge;
  final double badgePadding;
  final double badgeRadius;
  final bool useAssetImage;

  const ShieldNetLogo({
    super.key,
    this.size = 32,
    this.showText = false,
    this.fontSize = 17,
    this.textColor,
    this.isBadge = false,
    this.badgePadding = 8,
    this.badgeRadius = 10,
    this.useAssetImage = false,
  });

  /// Constructeur avec le titre officiel "ShieldNet"
  const ShieldNetLogo.withText({
    super.key,
    this.size = 28,
    this.fontSize = 17,
    this.textColor,
    this.useAssetImage = false,
  })  : showText = true,
        isBadge = false,
        badgePadding = 8,
        badgeRadius = 10;

  /// Constructeur encapsulé dans un badge arrondi avec fond d'accentuation
  const ShieldNetLogo.badge({
    super.key,
    this.size = 24,
    this.badgePadding = 8,
    this.badgeRadius = 10,
    this.useAssetImage = false,
  })  : showText = false,
        fontSize = 17,
        textColor = null,
        isBadge = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget logoWidget = useAssetImage
        ? Image.asset(
            'assets/images/shieldnet_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => CustomPaint(
              size: Size(size, size),
              painter: ShieldLogoPainter(isDark: isDark),
            ),
          )
        : CustomPaint(
            size: Size(size, size),
            painter: ShieldLogoPainter(isDark: isDark),
          );

    if (isBadge) {
      logoWidget = Container(
        padding: EdgeInsets.all(badgePadding),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(badgeRadius),
        ),
        child: logoWidget,
      );
    }

    if (showText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: size + 6,
            height: size + 6,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: logoWidget,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'ShieldNet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
                letterSpacing: -0.5,
                color: textColor ?? (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return logoWidget;
  }
}
