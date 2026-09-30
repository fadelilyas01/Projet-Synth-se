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

  /// Règles réglementaires locales hors-ligne pour résilience instantanée
  static Map<String, dynamic> getLocalNorm(String country, String provinceOrState) {
    final c = country.toUpperCase();
    final p = provinceOrState.toUpperCase();

    if (c == 'CA' && p == 'QC') {
      return {
        'norm_key': 'LOI_25_QC',
        'norm_name': 'Loi 25 du Québec (Protection de la vie privée)',
        'legal_framework': 'Loi sur la protection des renseignements personnels dans le secteur privé (Loi 25)',
        'regulator': "Commission d'accès à l'information du Québec (CAI) & CRTC",
        'description':
            'Protection rigoureuse sous la Loi 25 québécoise : chiffrement cryptographique HMAC-SHA256, zéro transmission de répertoire, consentement exprès et droit absolu d\'effacement sous 30 jours.',
        'data_retention_days': 30,
        'strict_consent_required': true,
        'telecom_standard': 'CRTC 2019-403 & STIR/SHAKEN',
        'principles': [
          'Confidentialité par défaut dès la conception (Privacy by Design)',
          'Zéro indexation ni extraction du carnet d\'adresses personnel',
          'Empreintes cryptographiques locales HMAC-SHA256 avec sel',
          'Droit d\'accès, de rectification et d\'effacement des données',
          'Purge automatique des signalements obsolètes après 30 jours',
        ],
        'emergency_numbers': [
          {'number': '911', 'label': 'Services d\'urgence (Police / Pompiers / Ambulance)', 'immune': true},
          {'number': '811', 'label': 'Info-Santé & Info-Social Québec', 'immune': true},
          {'number': '988', 'label': 'Ligne d\'aide en cas de crise de suicide', 'immune': true},
          {'number': '211', 'label': 'Services communautaires et sociaux', 'immune': true},
        ],
      };
    } else if (c == 'CA') {
      final pName = canadianProvinces[p] ?? p;
      return {
        'norm_key': 'PIPEDA_CASL_CRTC',
        'norm_name': 'LPRPDE / PIPEDA & LCAP / CASL (Canada)',
        'legal_framework': 'Loi sur la protection des renseignements personnels et les documents électroniques (LPRPDE) & LCAP',
        'regulator': 'Commissariat à la protection de la vie privée du Canada (CPVP) & CRTC',
        'description':
            'Conformité fédérale canadienne pour $pName : chiffrement des flux de réputation, signalement d\'abus au Centre antifraude du Canada et filtrage conforme aux ordonnances CRTC.',
        'data_retention_days': 60,
        'strict_consent_required': true,
        'telecom_standard': 'CRTC 2019-403 / STIR-SHAKEN Canada',
        'principles': [
          'Protection et conformité sous la législation fédérale LPRPDE',
          'Filtrage télécom conforme aux directives du CRTC',
          'Consentement exprès pour le blocage préventif des appels suspects',
          'Signalement direct coordonné avec le Centre antifraude du Canada',
        ],
        'emergency_numbers': [
          {'number': '911', 'label': 'Services d\'urgence', 'immune': true},
          {'number': '811', 'label': 'Ligne santé provinciale', 'immune': true},
          {'number': '988', 'label': 'Ligne de crise de suicide', 'immune': true},
          {'number': '211', 'label': 'Ressources communautaires et sociales', 'immune': true},
        ],
      };
    } else if (c == 'US' && p == 'CA') {
      return {
        'norm_key': 'TCPA_CCPA_CALIFORNIA',
        'norm_name': 'TCPA & CCPA / CPRA (Californie)',
        'legal_framework': 'Telephone Consumer Protection Act (47 U.S.C. § 227) & California Consumer Privacy Act (CCPA/CPRA)',
        'regulator': 'California Privacy Protection Agency (CPPA) & FCC / FTC',
        'description':
            'Protection de haut niveau en Californie : clause stricte "Do Not Sell/Share My Personal Information", vérification des attestations STIR/SHAKEN mandatée par la FCC et bouclier anti-robocall.',
        'data_retention_days': 45,
        'strict_consent_required': true,
        'telecom_standard': 'FCC Robocall Mitigation Database & STIR/SHAKEN',
        'principles': [
          'Garantie "Do Not Sell or Share My Personal Information" (CCPA/CPRA)',
          'Filtrage des robocalls selon la norme fédérale TCPA',
          'Attestations d\'opérateurs STIR/SHAKEN vérifiées (Niveaux A/B/C)',
          'Protection locale étanche sans commercialisation des métadonnées',
        ],
        'emergency_numbers': [
          {'number': '911', 'label': 'Emergency Services (Police / Fire / EMS)', 'immune': true},
          {'number': '988', 'label': 'Suicide & Crisis Lifeline', 'immune': true},
          {'number': '311', 'label': 'Non-Emergency Municipal Services', 'immune': true},
          {'number': '211', 'label': 'Essential Community Resources', 'immune': true},
        ],
      };
    } else {
      final sName = usStates[p] ?? p;
      return {
        'norm_key': 'TCPA_TRACED_FCC',
        'norm_name': 'TCPA & Pallone-Thune TRACED Act (FCC / FTC)',
        'legal_framework': 'Telephone Consumer Protection Act (TCPA) & Pallone-Thune TRACED Act',
        'regulator': 'Federal Communications Commission (FCC) & Federal Trade Commission (FTC)',
        'description':
            'Cadre réglementaire américain pour $sName : atténuation fédérale des appels automatisés non sollicités, conformité National DNC Registry et authentification d\'appels FCC.',
        'data_retention_days': 60,
        'strict_consent_required': false,
        'telecom_standard': 'FCC TRACED Act STIR/SHAKEN Mandate',
        'principles': [
          'Interception des robocalls non sollicités (TCPA)',
          'Validation cryptographique STIR/SHAKEN de l\'appelant',
          'Respect strict du registre fédéral National Do Not Call (DNC)',
          'Calcul d\'empreintes local sécurisé sans téléversement de contacts',
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
