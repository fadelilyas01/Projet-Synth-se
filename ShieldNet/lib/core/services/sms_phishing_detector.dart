enum PhishingRiskLevel { safe, suspicious, dangerous }

class PhishingAnalysisResult {
  final int riskScore; // 0 à 100
  final PhishingRiskLevel level;
  final String verdictTitle;
  final String verdictDescription;
  final List<String> extractedUrls;
  final List<String> detectedRedFlags;
  final List<String> recommendations;

  const PhishingAnalysisResult({
    required this.riskScore,
    required this.level,
    required this.verdictTitle,
    required this.verdictDescription,
    required this.extractedUrls,
    required this.detectedRedFlags,
    required this.recommendations,
  });
}

class SmsPhishingDetector {
  static final List<String> _urlShorteners = [
    'bit.ly',
    'tinyurl.com',
    'is.gd',
    't.co',
    'cutt.ly',
    'ow.ly',
    'buff.ly',
    'rb.gy',
    'rebrand.ly',
    'shorturl.at',
    'tiny.cc',
  ];

  static final Map<String, int> _deliveryKeywords = {
    'colis': 20,
    'livraison': 15,
    'chronopost': 25,
    'colissimo': 25,
    'mondial relay': 25,
    'fedex': 25,
    'dhl': 25,
    'frais de port': 25,
    'frais de douane': 30,
    'point relais': 15,
    'adresse incorrecte': 25,
  };

  static final Map<String, int> _administrativeKeywords = {
    'ameli': 35,
    'carte vitale': 35,
    'assurance maladie': 30,
    'impots': 35,
    'impots.gouv': 40,
    'antai': 35,
    'amende': 30,
    'contravention': 30,
    'infraction': 25,
    'remboursement': 20,
    'cpf': 30,
  };

  static final Map<String, int> _bankingKeywords = {
    'banque': 25,
    'compte bloque': 35,
    'compte suspendu': 35,
    'transaction suspecte': 30,
    'securite': 15,
    'identifiants': 30,
    'mot de passe': 35,
    'carte bancaire': 30,
    'code de confirmation': 25,
  };

  static final Map<String, int> _urgencyKeywords = {
    'urgent': 15,
    'immediat': 15,
    'dans les 24h': 20,
    'derniere relance': 25,
    'action requise': 20,
    'cliquez ici': 20,
    'mettre a jour': 15,
  };

  /// Normalise le texte pour la détection insensible aux accents
  static String _normalize(String input) {
    var str = input.toLowerCase();
    const withDia = 'àáâãäåèéêëìíîïòóôõöùúûüýñç';
    const withoutDia = 'aaaaaaeeeeiiiiooooouuuuync';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Analyse le contenu d'un SMS ou message
  static PhishingAnalysisResult analyze(String message) {
    if (message.trim().isEmpty) {
      return const PhishingAnalysisResult(
        riskScore: 0,
        level: PhishingRiskLevel.safe,
        verdictTitle: 'Texte vide',
        verdictDescription: 'Veuillez saisir ou coller un message à analyser.',
        extractedUrls: [],
        detectedRedFlags: [],
        recommendations: [],
      );
    }

    final normalized = _normalize(message);
    int totalRisk = 0;
    final redFlags = <String>[];
    final recommendations = <String>[];

    // 1. Extraction et analyse des liens URL
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+|(?:www\.)[^\s]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?)',
      caseSensitive: false,
    );
    final rawMatches = urlRegex.allMatches(message).map((m) => m.group(0)!).toList();
    final urls = rawMatches.where((u) => u.contains('.')).toList();

    bool hasShortener = false;
    bool hasIpUrl = false;
    bool hasSuspiciousTld = false;

    for (final url in urls) {
      final lowUrl = url.toLowerCase();
      // Détection des raccourcisseurs
      for (final shortener in _urlShorteners) {
        if (lowUrl.contains(shortener)) {
          hasShortener = true;
          totalRisk += 35;
          redFlags.add('Lien masqué via un raccourcisseur d\'URL ($shortener).');
          break;
        }
      }

      // Détection d'URL par IP brute
      if (RegExp(r'https?:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(lowUrl)) {
        hasIpUrl = true;
        totalRisk += 45;
        redFlags.add('Lien pointant directement vers une adresse IP numérique brute.');
      }

      // Extensions suspectes courantes en hameçonnage
      final suspiciousExtensions = ['.xyz', '.top', '.club', '.buzz', '.rest', '.sbs', '.cfd', '.click', '.tk', '.ga', '.ml'];
      for (final ext in suspiciousExtensions) {
        if (lowUrl.contains(ext)) {
          hasSuspiciousTld = true;
          totalRisk += 30;
          redFlags.add('Extension de domaine suspecte souvent utilisée pour les escroqueries ($ext).');
          break;
        }
      }
    }

    // 2. Mots-clés de fausse livraison
    for (final entry in _deliveryKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add('Mention d\'arnaque au colis / livraison : "${entry.key}".');
      }
    }

    // 3. Mots-clés administratifs / organismes publics
    for (final entry in _administrativeKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add('Usurpation d\'organisme officiel : "${entry.key}".');
      }
    }

    // 4. Mots-clés bancaires / mots de passe
    for (final entry in _bankingKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add('Demande sensible de sécurité ou bancaire : "${entry.key}".');
      }
    }

    // 5. Mots-clés d'urgence
    for (final entry in _urgencyKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add('Incitation pressante à l\'action rapide : "${entry.key}".');
      }
    }

    // Combinaison Lien + Mots-clés = Danger démultiplié
    if (urls.isNotEmpty && (redFlags.isNotEmpty)) {
      totalRisk += 20;
    }

    // Calcul du score plafonné
    final finalScore = totalRisk.clamp(0, 100);

    PhishingRiskLevel level;
    String verdictTitle;
    String verdictDesc;

    if (finalScore >= 65 || hasIpUrl || (hasShortener && urls.isNotEmpty && redFlags.length >= 2) || hasSuspiciousTld) {
      level = PhishingRiskLevel.dangerous;
      verdictTitle = 'Hameçonnage Très Probable';
      verdictDesc = 'Ce message présente tous les indicateurs d\'une tentative d\'escroquerie ou de vol d\'identifiants.';
      recommendations.add('Ne cliquez surtout sur aucun lien présent dans ce message.');
      recommendations.add('Ne communiquez jamais vos coordonnées bancaires ou mots de passe par SMS.');
      recommendations.add('Bloquez l\'expéditeur et supprimez le message.');
    } else if (finalScore >= 30 || urls.isNotEmpty) {
      level = PhishingRiskLevel.suspicious;
      verdictTitle = 'Message Suspect';
      verdictDesc = 'Ce message contient des formulations ou des liens inhabituels justifiant une vigilance accrue.';
      recommendations.add('Vérifiez directement sur le site ou l\'application officielle de l\'organisme sans utiliser le lien reçu.');
      recommendations.add('Prenez garde aux demandes de paiement ou de mise à jour d\'adresse.');
    } else {
      level = PhishingRiskLevel.safe;
      verdictTitle = 'Message Sécuritaire';
      verdictDesc = 'Aucun indicateur majeur d\'escroquerie ou de hameçonnage n\'a été détecté dans ce message.';
      recommendations.add('Restez vigilant si un correspondant inconnu vous demande de l\'argent ou des informations privées.');
    }

    return PhishingAnalysisResult(
      riskScore: finalScore,
      level: level,
      verdictTitle: verdictTitle,
      verdictDescription: verdictDesc,
      extractedUrls: urls,
      detectedRedFlags: redFlags.toSet().toList(),
      recommendations: recommendations,
    );
  }
}
