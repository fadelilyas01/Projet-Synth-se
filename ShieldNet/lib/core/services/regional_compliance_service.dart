import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../providers/auth_provider.dart';

class RegionalState {
  final String country;
  final String provinceOrState;
  final String countryName;
  final String provinceName;
  final String countryFlag;
  final Map<String, dynamic> complianceNorm;
  final bool isLoading;

  const RegionalState({
    required this.country,
    required this.provinceOrState,
    required this.countryName,
    required this.provinceName,
    required this.countryFlag,
    required this.complianceNorm,
    this.isLoading = false,
  });

  RegionalState copyWith({
    String? country,
    String? provinceOrState,
    String? countryName,
    String? provinceName,
    String? countryFlag,
    Map<String, dynamic>? complianceNorm,
    bool? isLoading,
  }) {
    return RegionalState(
      country: country ?? this.country,
      provinceOrState: provinceOrState ?? this.provinceOrState,
      countryName: countryName ?? this.countryName,
      provinceName: provinceName ?? this.provinceName,
      countryFlag: countryFlag ?? this.countryFlag,
      complianceNorm: complianceNorm ?? this.complianceNorm,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  String getLocalizedCountryName(String lang) {
    if (lang == 'en') {
      return country == 'CA' ? 'Canada' : 'United States';
    }
    return country == 'CA' ? 'Canada' : 'États-Unis';
  }

  String getLocalizedProvinceName(String lang) {
    if (country == 'CA') {
      return lang == 'en'
          ? (RegionalComplianceManager.canadianProvincesEn[provinceOrState] ?? provinceOrState)
          : (RegionalComplianceManager.canadianProvinces[provinceOrState] ?? provinceOrState);
    } else {
      return lang == 'en'
          ? (RegionalComplianceManager.usStatesEn[provinceOrState] ?? provinceOrState)
          : (RegionalComplianceManager.usStates[provinceOrState] ?? provinceOrState);
    }
  }

  Map<String, dynamic> getLocalizedNorm(String lang) {
    return RegionalComplianceManager.getLocalNorm(country, provinceOrState, lang: lang);
  }
}

class RegionalComplianceManager {
  static const String keyCountry = 'regional_user_country';
  static const String keyProvince = 'regional_user_province';

  static const Map<String, String> canadianProvinces = {
    'QC': 'Québec',
    'ON': 'Ontario',
    'BC': 'Colombie-Britannique',
    'AB': 'Alberta',
    'MB': 'Manitoba',
    'SK': 'Saskatchewan',
    'NS': 'Nouvelle-Écosse',
    'NB': 'Nouveau-Brunswick',
    'NL': 'Terre-Neuve-et-Labrador',
    'PE': 'Île-du-Prince-Édouard',
    'NT': 'Territoires du Nord-Ouest',
    'YT': 'Yukon',
    'NU': 'Nunavut',
  };

  static const Map<String, String> usStates = {
    'CA': 'Californie (California)',
    'NY': 'New York',
    'TX': 'Texas',
    'FL': 'Floride (Florida)',
    'IL': 'Illinois',
    'WA': 'Washington',
    'MA': 'Massachusetts',
    'PA': 'Pennsylvanie',
    'OH': 'Ohio',
    'GA': 'Géorgie (Georgia)',
    'NC': 'Caroline du Nord',
    'MI': 'Michigan',
    'NJ': 'New Jersey',
    'VA': 'Virginie',
    'AZ': 'Arizona',
    'CO': 'Colorado',
    'MD': 'Maryland',
    'MN': 'Minnesota',
    'NV': 'Nevada',
    'OR': 'Oregon',
  };

  static const Map<String, String> canadianProvincesEn = {
    'QC': 'Quebec',
    'ON': 'Ontario',
    'BC': 'British Columbia',
    'AB': 'Alberta',
    'MB': 'Manitoba',
    'SK': 'Saskatchewan',
    'NS': 'Nova Scotia',
    'NB': 'New Brunswick',
    'NL': 'Newfoundland and Labrador',
    'PE': 'Prince Edward Island',
    'NT': 'Northwest Territories',
    'YT': 'Yukon',
    'NU': 'Nunavut',
  };

  static const Map<String, String> usStatesEn = {
    'CA': 'California',
    'NY': 'New York',
    'TX': 'Texas',
    'FL': 'Florida',
    'IL': 'Illinois',
    'WA': 'Washington',
    'MA': 'Massachusetts',
    'PA': 'Pennsylvania',
    'OH': 'Ohio',
    'GA': 'Georgia',
    'NC': 'North Carolina',
    'MI': 'Michigan',
    'NJ': 'New Jersey',
    'VA': 'Virginia',
    'AZ': 'Arizona',
    'CO': 'Colorado',
    'MD': 'Maryland',
    'MN': 'Minnesota',
    'NV': 'Nevada',
    'OR': 'Oregon',
  };

  /// Règles réglementaires locales hors-ligne pour résilience instantanée
  static Map<String, dynamic> getLocalNorm(String country, String provinceOrState, {String lang = 'fr'}) {
    final c = country.toUpperCase();
    final p = provinceOrState.toUpperCase();
    final isEn = lang == 'en';

    if (c == 'CA' && p == 'QC') {
      return {
        'norm_key': 'LOI_25_QC',
        'norm_name': isEn
            ? 'Quebec Regional Protection'
            : 'Protection régionale Québec',
        'legal_framework': isEn
            ? 'Protected by design (Quebec standard)'
            : 'Protection intégrée par défaut (Standard Québec)',
        'regulator': isEn
            ? 'Strict privacy & telecom standards'
            : 'Protection de la vie privée & normes télécom',
        'description': isEn
            ? 'Protection tailored for Quebec: your contact list stays strictly on your phone, spoofed local calls are blocked, and reports are automatically purged after 30 days.'
            : 'Protection adaptée au Québec : votre carnet d\'adresses ne quitte jamais votre appareil, les faux numéros locaux sont bloqués et les données sont purgées après 30 jours.',
        'data_retention_days': 30,
        'strict_consent_required': true,
        'telecom_standard': 'STIR/SHAKEN Canada',
        'principles': isEn
            ? [
                'Zero contact list extraction or sharing',
                'Protection against local neighborhood spoofing',
                'Automatic history purge after 30 days',
                'Emergency calls (911, 811, 988) always ring through',
              ]
            : [
                'Zéro transfert de votre carnet d\'adresses personnel',
                'Blocage ciblé des faux numéros et arnaques locales',
                'Purge automatique de l\'historique après 30 jours',
                'Numéros d\'urgence (911, 811, 988) toujours garantis',
              ],
        'emergency_numbers': [
          {'number': '911', 'label': isEn ? 'Emergency Services (Police / Fire / EMS)' : 'Services d\'urgence (Police / Pompiers / Ambulance)', 'immune': true},
          {'number': '811', 'label': isEn ? 'Info-Santé & Info-Social Quebec' : 'Info-Santé & Info-Social Québec', 'immune': true},
          {'number': '988', 'label': isEn ? 'Suicide Crisis Helpline' : 'Ligne d\'aide en cas de crise de suicide', 'immune': true},
          {'number': '211', 'label': isEn ? 'Community and Social Services' : 'Services communautaires et sociaux', 'immune': true},
        ],
      };
    } else if (c == 'CA') {
      final pName = isEn ? (canadianProvincesEn[p] ?? p) : (canadianProvinces[p] ?? p);
      return {
        'norm_key': 'PIPEDA_CASL_CRTC',
        'norm_name': isEn ? 'Canada Regional Protection' : 'Protection régionale Canada',
        'legal_framework': isEn
            ? 'Canadian telecom & privacy standards'
            : 'Normes canadiennes de protection et télécom',
        'regulator': isEn
            ? 'Canadian telecom & privacy standards'
            : 'Normes canadiennes de protection et télécom',
        'description': isEn
            ? 'Optimized protection for $pName: blocks telemarketing spam and fraudulent callers while ensuring verified callers and emergency lines ring through.'
            : 'Protection optimisée pour $pName : bloque les appels indésirables et frauduleux tout en garantissant le passage immédiat de vos urgences.',
        'data_retention_days': 60,
        'strict_consent_required': true,
        'telecom_standard': 'STIR/SHAKEN Canada',
        'principles': isEn
            ? [
                'Protection tailored to Canadian area codes',
                'Verified caller identification',
                'Emergency numbers (911, 811, 988) always ring through',
                '100% private: contacts stay on your phone',
              ]
            : [
                'Protection ciblée sur les indicatifs canadiens',
                'Identification des appels légitimes et vérifiés',
                'Numéros d\'urgence (911, 811, 988) toujours garantis',
                '100% confidentiel : vos contacts restent sur votre téléphone',
              ],
        'emergency_numbers': [
          {'number': '911', 'label': isEn ? 'Emergency Services' : 'Services d\'urgence', 'immune': true},
          {'number': '811', 'label': isEn ? 'Provincial Healthline' : 'Ligne santé provinciale', 'immune': true},
          {'number': '988', 'label': isEn ? 'Suicide Crisis Helpline' : 'Ligne de crise de suicide', 'immune': true},
          {'number': '211', 'label': isEn ? 'Community and Social Resources' : 'Ressources communautaires et sociales', 'immune': true},
        ],
      };
    } else if (c == 'US' && p == 'CA') {
      return {
        'norm_key': 'TCPA_CCPA_CALIFORNIA',
        'norm_name': isEn ? 'California Regional Protection' : 'Protection régionale Californie',
        'legal_framework': isEn
            ? 'California privacy & anti-robocall standards'
            : 'Normes californiennes de protection et anti-robocall',
        'regulator': isEn
            ? 'Privacy & telecom protection'
            : 'Protection de la vie privée et télécom',
        'description': isEn
            ? 'Advanced anti-robocall protection for California: zero personal data selling or sharing, instant spoofing detection, and guaranteed emergency line access.'
            : 'Protection anti-robocall avancée pour la Californie : aucune vente de données personnelles, détection des faux numéros et urgences garanties.',
        'data_retention_days': 45,
        'strict_consent_required': true,
        'telecom_standard': 'FCC STIR/SHAKEN',
        'principles': isEn
            ? [
                'Zero selling or sharing of personal data',
                'Automated robocall blocking',
                'Emergency lines (911, 988) fully protected',
                'Private on-device spam detection',
              ]
            : [
                'Zéro vente ou partage de vos données personnelles',
                'Blocage automatique des appels robotisés (robocalls)',
                'Lignes d\'urgence (911, 988) toujours protégées',
                'Détection du spam directement sur votre appareil',
              ],
        'emergency_numbers': [
          {'number': '911', 'label': 'Emergency Services (Police / Fire / EMS)', 'immune': true},
          {'number': '988', 'label': 'Suicide & Crisis Lifeline', 'immune': true},
          {'number': '311', 'label': 'Non-Emergency Municipal Services', 'immune': true},
          {'number': '211', 'label': 'Essential Community Resources', 'immune': true},
        ],
      };
    } else {
      final sName = isEn ? (usStatesEn[p] ?? p) : (usStates[p] ?? p);
      return {
        'norm_key': 'TCPA_TRACED_FCC',
        'norm_name': isEn ? 'United States Regional Protection' : 'Protection régionale États-Unis',
        'legal_framework': isEn
            ? 'US telecom & anti-robocall standards'
            : 'Normes américaines anti-robocall et télécom',
        'regulator': isEn
            ? 'Telecom & consumer protection standards'
            : 'Protection des télécommunications et consommateurs',
        'description': isEn
            ? 'Protection tailored for $sName: intercepts aggressive robocalls and fraudulent phone scams while keeping your personal contacts private.'
            : 'Protection adaptée pour $sName : bloque les robocalls et arnaques téléphoniques tout en gardant vos contacts strictement privés.',
        'data_retention_days': 60,
        'strict_consent_required': false,
        'telecom_standard': 'FCC STIR/SHAKEN Mandate',
        'principles': isEn
            ? [
                'Robocall and telephone spam interception',
                'Protection against spoofed numbers',
                'Emergency numbers (911, 988) always protected',
                'Contacts never leave your phone',
              ]
            : [
                'Interception des robocalls et du spam téléphonique',
                'Protection contre les faux numéros usurpés',
                'Numéros d\'urgence (911, 988) toujours protégés',
                'Vos contacts ne quittent jamais votre téléphone',
              ],
        'emergency_numbers': [
          {'number': '911', 'label': 'Emergency Services', 'immune': true},
          {'number': '988', 'label': 'Suicide & Crisis Lifeline', 'immune': true},
          {'number': '311', 'label': 'Non-Emergency City Services', 'immune': true},
          {'number': '211', 'label': 'Community Resources', 'immune': true},
        ],
      };
    }
  }
}

class RegionalNotifier extends StateNotifier<RegionalState> {
  final AuthService _authService;

  RegionalNotifier([AuthService? authService])
      : _authService = authService ?? AuthService(),
        super(
          RegionalState(
            country: 'CA',
            provinceOrState: 'QC',
            countryName: 'Canada',
            provinceName: 'Québec',
            countryFlag: '🇨🇦',
            complianceNorm: RegionalComplianceManager.getLocalNorm('CA', 'QC'),
            isLoading: false,
          ),
        ) {
    loadSavedRegion();
  }

  Future<void> loadSavedRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCountry = prefs.getString(RegionalComplianceManager.keyCountry) ?? 'CA';
      final savedProv = prefs.getString(RegionalComplianceManager.keyProvince) ?? (savedCountry == 'CA' ? 'QC' : 'NY');

      _applyRegion(savedCountry, savedProv);
    } catch (_) {}
  }

  void _applyRegion(String country, String provinceOrState, [Map<String, dynamic>? remoteNorm]) {
    final c = country.toUpperCase();
    final p = provinceOrState.toUpperCase();
    final cName = c == 'CA' ? 'Canada' : 'États-Unis';
    final pName = c == 'CA'
        ? (RegionalComplianceManager.canadianProvinces[p] ?? p)
        : (RegionalComplianceManager.usStates[p] ?? p);
    final flag = c == 'CA' ? '🇨🇦' : '🇺🇸';
    final norm = remoteNorm ?? RegionalComplianceManager.getLocalNorm(c, p);

    state = state.copyWith(
      country: c,
      provinceOrState: p,
      countryName: cName,
      provinceName: pName,
      countryFlag: flag,
      complianceNorm: norm,
      isLoading: false,
    );
  }

  Future<void> setRegion({
    required String country,
    required String provinceOrState,
    UserModel? currentUser,
  }) async {
    state = state.copyWith(isLoading: true);
    final c = country.trim().toUpperCase();
    final p = provinceOrState.trim().toUpperCase();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(RegionalComplianceManager.keyCountry, c);
      await prefs.setString(RegionalComplianceManager.keyProvince, p);
    } catch (_) {}

    Map<String, dynamic>? remoteNorm;
    try {
      remoteNorm = await _authService.getComplianceNorms(country: c, provinceOrState: p);
    } catch (_) {}

    if (currentUser != null) {
      try {
        await _authService.updateRegion(country: c, provinceOrState: p);
      } catch (_) {}
    }

    _applyRegion(c, p, remoteNorm);
  }
}

final regionalComplianceProvider = StateNotifierProvider<RegionalNotifier, RegionalState>((ref) {
  return RegionalNotifier(ref.watch(authServiceProvider));
});
