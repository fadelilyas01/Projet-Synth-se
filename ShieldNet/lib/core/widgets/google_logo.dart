import 'package:flutter/material.dart';
import 'google_logo_data.dart';

/// Widget officiel haute définition pour le logo Google "G"
/// Utilise l'image binaire officielle Google pré-intégrée (instantanée, 0 latence, 0 bug réseau).
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      kGoogleLogoBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.g_mobiledata, size: size, color: const Color(0xFF4285F4)),
    );
  }
}
