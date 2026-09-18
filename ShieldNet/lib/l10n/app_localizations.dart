import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet Pro Anti-Spam'**
  String get appTitle;

  /// No description provided for @tabProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get tabProtection;

  /// No description provided for @tabActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get tabActivity;

  /// No description provided for @tabHistory.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get tabHistory;

  /// No description provided for @tabBlacklist.
  ///
  /// In fr, this message translates to:
  /// **'Liste Noire'**
  String get tabBlacklist;

  /// No description provided for @tabReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get tabReport;

  /// No description provided for @tabSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get tabSettings;

  /// No description provided for @shieldRealtime.
  ///
  /// In fr, this message translates to:
  /// **'Bouclier en temps réel'**
  String get shieldRealtime;

  /// No description provided for @shieldSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage suspendu'**
  String get shieldSuspended;

  /// No description provided for @shieldProtected.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes protégé'**
  String get shieldProtected;

  /// No description provided for @shieldInactive.
  ///
  /// In fr, this message translates to:
  /// **'Protection inactive'**
  String get shieldInactive;

  /// No description provided for @shieldActiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet filtre automatiquement les appels malveillants.'**
  String get shieldActiveDesc;

  /// No description provided for @shieldInactiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Activez le filtrage pour bloquer les appels indésirables.'**
  String get shieldInactiveDesc;

  /// No description provided for @btnActivateProtection.
  ///
  /// In fr, this message translates to:
  /// **'Activer la protection'**
  String get btnActivateProtection;

  /// No description provided for @protectionActiveSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Protection ShieldNet activée avec succès !'**
  String get protectionActiveSuccess;

  /// No description provided for @protectionPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez accorder les autorisations pour activer la protection.'**
  String get protectionPermissionRequired;

  /// No description provided for @shieldStrictBadge.
  ///
  /// In fr, this message translates to:
  /// **'Bouclier Strict (Contacts Seuls)'**
  String get shieldStrictBadge;

  /// No description provided for @shieldStrictTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection Maximale'**
  String get shieldStrictTitle;

  /// No description provided for @shieldStrictDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seuls vos contacts enregistrés sont autorisés à sonner.'**
  String get shieldStrictDesc;

  /// No description provided for @settingContactsOnly.
  ///
  /// In fr, this message translates to:
  /// **'Mode Contacts Uniquement'**
  String get settingContactsOnly;

  /// No description provided for @settingContactsOnlyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ne laisser sonner que vos contacts enregistrés'**
  String get settingContactsOnlyDesc;

  /// No description provided for @searchSuspectNumber.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un numéro suspect'**
  String get searchSuspectNumber;

  /// No description provided for @searchSuspectDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher instantanément dans la base anti-spam'**
  String get searchSuspectDesc;

  /// No description provided for @statSpamIntercepted.
  ///
  /// In fr, this message translates to:
  /// **'Spams interceptés'**
  String get statSpamIntercepted;

  /// No description provided for @statNumbersBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Numéros bloqués'**
  String get statNumbersBlocked;

  /// No description provided for @recentBlockedSpams.
  ///
  /// In fr, this message translates to:
  /// **'Derniers Spams Bloqués'**
  String get recentBlockedSpams;

  /// No description provided for @verifyCallAction.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un appel'**
  String get verifyCallAction;

  /// No description provided for @calmLineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ligne calme et sécurisée'**
  String get calmLineTitle;

  /// No description provided for @calmLineDesc.
  ///
  /// In fr, this message translates to:
  /// **'Aucune menace récente détectée sur votre appareil.'**
  String get calmLineDesc;

  /// No description provided for @badgeBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué'**
  String get badgeBlocked;

  /// No description provided for @maskedNumberDefault.
  ///
  /// In fr, this message translates to:
  /// **'Numéro masqué'**
  String get maskedNumberDefault;

  /// No description provided for @dialogCheckNumber.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un numéro'**
  String get dialogCheckNumber;

  /// No description provided for @dialogCheckPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un numéro pour vérifier s\'il est signalé comme spam :'**
  String get dialogCheckPrompt;

  /// No description provided for @btnCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get btnCancel;

  /// No description provided for @btnVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get btnVerify;

  /// No description provided for @btnUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get btnUnderstood;

  /// No description provided for @dialogVerified.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Vérifié'**
  String get dialogVerified;

  /// No description provided for @dialogSpamDetected.
  ///
  /// In fr, this message translates to:
  /// **'Attention : Spam Détecté'**
  String get dialogSpamDetected;

  /// No description provided for @dialogSafeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Sûr'**
  String get dialogSafeNumber;

  /// No description provided for @dialogVerifiedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est vérifié et certifié par l\'administrateur.'**
  String get dialogVerifiedDesc;

  /// No description provided for @dialogSpamDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro a été identifié comme indésirable.'**
  String get dialogSpamDesc;

  /// No description provided for @dialogSafeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signalement malveillant pour ce numéro.'**
  String get dialogSafeDesc;

  /// No description provided for @activityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activité Téléphonique'**
  String get activityTitle;

  /// No description provided for @tabRecentCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels Récents'**
  String get tabRecentCalls;

  /// No description provided for @tabBlockedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Numéros Bloqués'**
  String get tabBlockedNumbers;

  /// No description provided for @noRecentCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel récent'**
  String get noRecentCalls;

  /// No description provided for @noRecentCallsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les appels récents s\'afficheront ici avec leur état de sécurité.'**
  String get noRecentCallsDesc;

  /// No description provided for @noBlockedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro bloqué'**
  String get noBlockedNumbers;

  /// No description provided for @noBlockedNumbersDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.'**
  String get noBlockedNumbersDesc;

  /// No description provided for @noResultsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat trouvé'**
  String get noResultsFound;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In fr, this message translates to:
  /// **'Essayez avec un autre terme de recherche.'**
  String get tryAnotherSearch;

  /// No description provided for @searchBlockedPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un numéro bloqué...'**
  String get searchBlockedPlaceholder;

  /// No description provided for @blockAndReport.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer & Signaler'**
  String get blockAndReport;

  /// No description provided for @reportReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif du signalement :'**
  String get reportReason;

  /// No description provided for @categoryScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque'**
  String get categoryScam;

  /// No description provided for @categoryTelemarketing.
  ///
  /// In fr, this message translates to:
  /// **'Démarchage'**
  String get categoryTelemarketing;

  /// No description provided for @categoryPhishing.
  ///
  /// In fr, this message translates to:
  /// **'Phishing'**
  String get categoryPhishing;

  /// No description provided for @categoryRobocall.
  ///
  /// In fr, this message translates to:
  /// **'Automate / Silence'**
  String get categoryRobocall;

  /// No description provided for @btnBlockThisNumber.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce numéro'**
  String get btnBlockThisNumber;

  /// No description provided for @incomingCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel entrant'**
  String get incomingCall;

  /// No description provided for @spamBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Spam bloqué'**
  String get spamBlocked;

  /// No description provided for @riskWord.
  ///
  /// In fr, this message translates to:
  /// **'risque'**
  String get riskWord;

  /// No description provided for @timeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get timeJustNow;

  /// No description provided for @timeTodayAt.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui à'**
  String get timeTodayAt;

  /// No description provided for @timeYesterdayAt.
  ///
  /// In fr, this message translates to:
  /// **'Hier à'**
  String get timeYesterdayAt;

  /// No description provided for @unknownCaller.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknownCaller;

  /// No description provided for @reportSuccessMessage.
  ///
  /// In fr, this message translates to:
  /// **'Numéro bloqué et signalé avec succès.'**
  String get reportSuccessMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @sectionSecurity.
  ///
  /// In fr, this message translates to:
  /// **'SÉCURITÉ'**
  String get sectionSecurity;

  /// No description provided for @sectionPreferences.
  ///
  /// In fr, this message translates to:
  /// **'PRÉFÉRENCES'**
  String get sectionPreferences;

  /// No description provided for @sectionAdmin.
  ///
  /// In fr, this message translates to:
  /// **'ADMINISTRATION'**
  String get sectionAdmin;

  /// No description provided for @settingCallFiltering.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage d\'appels'**
  String get settingCallFiltering;

  /// No description provided for @settingSmsFiltering.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage des SMS'**
  String get settingSmsFiltering;

  /// No description provided for @settingBgSync.
  ///
  /// In fr, this message translates to:
  /// **'Sync en arrière-plan'**
  String get settingBgSync;

  /// No description provided for @settingUpdateDb.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour la base'**
  String get settingUpdateDb;

  /// No description provided for @btnSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser'**
  String get btnSync;

  /// No description provided for @syncSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation réussie'**
  String get syncSuccess;

  /// No description provided for @syncSuccessDetail.
  ///
  /// In fr, this message translates to:
  /// **'Protection à jour : numéros synchronisés.'**
  String get syncSuccessDetail;

  /// No description provided for @settingTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @settingLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingLanguage;

  /// No description provided for @langFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @adminConsoleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Console d\'Administration'**
  String get adminConsoleTitle;

  /// No description provided for @userAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte Utilisateur'**
  String get userAccountTitle;

  /// No description provided for @userAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter ou s\'inscrire'**
  String get userAccountSubtitle;

  /// No description provided for @btnLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get btnLogout;

  /// No description provided for @logoutSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion réussie.'**
  String get logoutSuccess;

  /// No description provided for @protectionActive.
  ///
  /// In fr, this message translates to:
  /// **'100% PROTÉGÉ'**
  String get protectionActive;

  /// No description provided for @protectionPartial.
  ///
  /// In fr, this message translates to:
  /// **'PROTECTION PARTIELLE'**
  String get protectionPartial;

  /// No description provided for @protectionActiveDescOld.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet bloque les appels indésirables en temps réel avant sonnerie.'**
  String get protectionActiveDescOld;

  /// No description provided for @protectionPartialDesc.
  ///
  /// In fr, this message translates to:
  /// **'Activez le filtrage natif Android pour activer la protection complète.'**
  String get protectionPartialDesc;

  /// No description provided for @btnEnableNative.
  ///
  /// In fr, this message translates to:
  /// **'Activer le Filtrage Natif'**
  String get btnEnableNative;

  /// No description provided for @statLocalDb.
  ///
  /// In fr, this message translates to:
  /// **'Base Locale'**
  String get statLocalDb;

  /// No description provided for @statFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Numéros filtrés'**
  String get statFiltered;

  /// No description provided for @statProtectedZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone Protégée'**
  String get statProtectedZone;

  /// No description provided for @statZoneDesc.
  ///
  /// In fr, this message translates to:
  /// **'+1 (Canada / É-U)'**
  String get statZoneDesc;

  /// No description provided for @callLogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des Appels'**
  String get callLogTitle;

  /// No description provided for @callLogReportPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce numéro ?'**
  String get callLogReportPrompt;

  /// No description provided for @callLogReportDesc.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous signaler ce numéro comme étant du spam ? Ce signalement sera partagé avec la communauté.'**
  String get callLogReportDesc;

  /// No description provided for @btnReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get btnReport;

  /// No description provided for @reportSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Signalement réussi !'**
  String get reportSuccess;

  /// No description provided for @reportLocal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré localement.'**
  String get reportLocal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
