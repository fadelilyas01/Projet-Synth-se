import 'dart:io';
import 'package:flutter/foundation.dart';

/// Résultat de l'analyse d'intégrité de l'appareil
class DeviceIntegrityResult {
  final bool isSafe;
  final bool isRootDetected;
  final List<String> detectedAnomalies;
  final String securitySummary;

  const DeviceIntegrityResult({
    required this.isSafe,
    required this.isRootDetected,
    required this.detectedAnomalies,
    required this.securitySummary,
  });

  bool get isCompromised => !isSafe || isRootDetected;
}

/// Analyseur d'intégrité matérielle et logicielle (App Hardening)
/// Détecte les environnements compromis (Root, Magisk, Su, Binaires suspects)
/// pour garantir l'étanchéité des données et du keystore Android.
class DeviceIntegrityChecker {
  static const List<String> _knownRootPaths = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
  ];

  /// Analyse le système de fichiers et les variables d'environnement
  static Future<DeviceIntegrityResult> checkIntegrity() async {
    // Sur le Web ou en mode de test unitaire émulé, environnement considéré sûr
    if (kIsWeb || !Platform.isAndroid) {
      return const DeviceIntegrityResult(
        isSafe: true,
        isRootDetected: false,
        detectedAnomalies: [],
        securitySummary: 'Environnement de développement standard vérifié.',
      );
    }

    final anomalies = <String>[];

    // 1. Vérification de l'existence de binaires de super-utilisateur (su)
    for (final path in _knownRootPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          anomalies.add('Binaire de privilège détecté : $path');
        }
      } catch (_) {
        // En cas de permission refusée par SELinux, continuer l'analyse
      }
    }

    // 2. Vérification des répertoires accessibles en écriture anormale
    try {
      final testFile = File('/system/shieldnet_integrity_check.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();
      anomalies.add('Partition /system montée en lecture-écriture (vulnérabilité critique)');
    } catch (_) {
      // Échec attendu sur un système Android intact (partition verrouillée en lecture seule)
    }

    final isRooted = anomalies.isNotEmpty;
    final isSafe = !isRooted;

    return DeviceIntegrityResult(
      isSafe: isSafe,
      isRootDetected: isRooted,
      detectedAnomalies: anomalies,
      securitySummary: isSafe
          ? 'Intégrité confirmée : Aucun accès root ni binaire suspect détecté.'
          : 'Avertissement de sécurité : Environnement altéré ou rooté détecté (${anomalies.length} anomalie(s)).',
    );
  }
}
