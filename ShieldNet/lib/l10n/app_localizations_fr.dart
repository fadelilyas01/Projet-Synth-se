// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ShieldNet Pro Anti-Spam';

  @override
  String get tabProtection => 'Protection';

  @override
  String get tabActivity => 'Activité';

  @override
  String get tabHistory => 'Activité';

  @override
  String get tabBlacklist => 'Liste Noire';

  @override
  String get tabReport => 'Signaler';

  @override
  String get tabSettings => 'Paramètres';

  @override
  String get shieldRealtime => 'Bouclier en temps réel';

  @override
  String get shieldSuspended => 'Filtrage suspendu';

  @override
  String get shieldProtected => 'Vous êtes protégé';

  @override
  String get shieldInactive => 'Protection inactive';

  @override
  String get shieldActiveDesc =>
      'ShieldNet filtre automatiquement les appels malveillants.';

  @override
  String get shieldInactiveDesc =>
      'Activez le filtrage pour bloquer les appels indésirables.';

  @override
  String get btnActivateProtection => 'Activer la protection';

  @override
  String get protectionActiveSuccess =>
      'Protection ShieldNet activée avec succès !';

  @override
  String get protectionPermissionRequired =>
      'Veuillez accorder les autorisations pour activer la protection.';

  @override
  String get shieldStrictBadge => 'Bouclier Strict (Contacts Seuls)';

  @override
  String get shieldStrictTitle => 'Protection Maximale';

  @override
  String get shieldStrictDesc =>
      'Seuls vos contacts enregistrés sont autorisés à sonner.';

  @override
  String get settingContactsOnly => 'Mode Contacts Uniquement';

  @override
  String get settingContactsOnlyDesc =>
      'Ne laisser sonner que vos contacts enregistrés';

  @override
  String get searchSuspectNumber => 'Vérifier un numéro suspect';

  @override
  String get searchSuspectDesc =>
      'Rechercher instantanément dans la base anti-spam';

  @override
  String get statSpamIntercepted => 'Spams interceptés';

  @override
  String get statNumbersBlocked => 'Numéros bloqués';

  @override
  String get recentBlockedSpams => 'Derniers Spams Bloqués';

  @override
  String get verifyCallAction => 'Vérifier un appel';

  @override
  String get calmLineTitle => 'Ligne calme et sécurisée';

  @override
  String get calmLineDesc =>
      'Aucune menace récente détectée sur votre appareil.';

  @override
  String get badgeBlocked => 'Bloqué';

  @override
  String get maskedNumberDefault => 'Numéro masqué';

  @override
  String get dialogCheckNumber => 'Vérifier un numéro';

  @override
  String get dialogCheckPrompt =>
      'Saisissez un numéro pour vérifier s\'il est signalé comme spam :';

  @override
  String get btnCancel => 'Annuler';

  @override
  String get btnVerify => 'Vérifier';

  @override
  String get btnUnderstood => 'Compris';

  @override
  String get dialogVerified => 'Numéro Vérifié';

  @override
  String get dialogSpamDetected => 'Attention : Spam Détecté';

  @override
  String get dialogSafeNumber => 'Numéro Sûr';

  @override
  String get dialogVerifiedDesc =>
      'Ce numéro est vérifié et certifié par l\'administrateur.';

  @override
  String get dialogSpamDesc => 'Ce numéro a été identifié comme indésirable.';

  @override
  String get dialogSafeDesc => 'Aucun signalement malveillant pour ce numéro.';

  @override
  String get activityTitle => 'Activité Téléphonique';

  @override
  String get tabRecentCalls => 'Appels Récents';

  @override
  String get tabBlockedNumbers => 'Numéros Bloqués';

  @override
  String get noRecentCalls => 'Aucun appel récent';

  @override
  String get noRecentCallsDesc =>
      'Les appels récents s\'afficheront ici avec leur état de sécurité.';

  @override
  String get noBlockedNumbers => 'Aucun numéro bloqué';

  @override
  String get noBlockedNumbersDesc =>
      'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get tryAnotherSearch => 'Essayez avec un autre terme de recherche.';

  @override
  String get searchBlockedPlaceholder => 'Rechercher un numéro bloqué...';

  @override
  String get blockAndReport => 'Bloquer & Signaler';

  @override
  String get reportReason => 'Motif du signalement :';

  @override
  String get categoryScam => 'Arnaque';

  @override
  String get categoryTelemarketing => 'Démarchage';

  @override
  String get categoryPhishing => 'Phishing';

  @override
  String get categoryRobocall => 'Automate / Silence';

  @override
  String get btnBlockThisNumber => 'Bloquer ce numéro';

  @override
  String get incomingCall => 'Appel entrant';

  @override
  String get spamBlocked => 'Spam bloqué';

  @override
  String get riskWord => 'risque';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String get timeTodayAt => 'Aujourd\'hui à';

  @override
  String get timeYesterdayAt => 'Hier à';

  @override
  String get unknownCaller => 'Inconnu';

  @override
  String get reportSuccessMessage => 'Numéro bloqué et signalé avec succès.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get sectionSecurity => 'SÉCURITÉ';

  @override
  String get sectionPreferences => 'PRÉFÉRENCES';

  @override
  String get sectionAdmin => 'ADMINISTRATION';

  @override
  String get settingCallFiltering => 'Filtrage d\'appels';

  @override
  String get settingSmsFiltering => 'Filtrage des SMS';

  @override
  String get settingBgSync => 'Sync en arrière-plan';

  @override
  String get settingUpdateDb => 'Mettre à jour la base';

  @override
  String get btnSync => 'Synchroniser';

  @override
  String get syncSuccess => 'Synchronisation réussie';

  @override
  String get syncSuccessDetail => 'Protection à jour : numéros synchronisés.';

  @override
  String get settingTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingLanguage => 'Langue';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get adminConsoleTitle => 'Console d\'Administration';

  @override
  String get userAccountTitle => 'Compte Utilisateur';

  @override
  String get userAccountSubtitle => 'Se connecter ou s\'inscrire';

  @override
  String get btnLogout => 'Déconnexion';

  @override
  String get logoutSuccess => 'Déconnexion réussie.';

  @override
  String get protectionActive => '100% PROTÉGÉ';

  @override
  String get protectionPartial => 'PROTECTION PARTIELLE';

  @override
  String get protectionActiveDescOld =>
      'ShieldNet bloque les appels indésirables en temps réel avant sonnerie.';

  @override
  String get protectionPartialDesc =>
      'Activez le filtrage natif Android pour activer la protection complète.';

  @override
  String get btnEnableNative => 'Activer le Filtrage Natif';

  @override
  String get statLocalDb => 'Base Locale';

  @override
  String get statFiltered => 'Numéros filtrés';

  @override
  String get statProtectedZone => 'Zone Protégée';

  @override
  String get statZoneDesc => '+1 (Canada / É-U)';

  @override
  String get callLogTitle => 'Historique des Appels';

  @override
  String get callLogReportPrompt => 'Signaler ce numéro ?';

  @override
  String get callLogReportDesc =>
      'Voulez-vous signaler ce numéro comme étant du spam ? Ce signalement sera partagé avec la communauté.';

  @override
  String get btnReport => 'Signaler';

  @override
  String get reportSuccess => 'Signalement réussi !';

  @override
  String get reportLocal => 'Enregistré localement.';
}
