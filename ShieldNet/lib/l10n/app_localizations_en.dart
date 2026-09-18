// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ShieldNet Pro Anti-Spam';

  @override
  String get tabProtection => 'Protection';

  @override
  String get tabActivity => 'Activity';

  @override
  String get tabHistory => 'Activity';

  @override
  String get tabBlacklist => 'Blacklist';

  @override
  String get tabReport => 'Report';

  @override
  String get tabSettings => 'Settings';

  @override
  String get shieldRealtime => 'Real-time shield';

  @override
  String get shieldSuspended => 'Filtering suspended';

  @override
  String get shieldProtected => 'You are protected';

  @override
  String get shieldInactive => 'Protection inactive';

  @override
  String get shieldActiveDesc =>
      'ShieldNet automatically filters malicious calls.';

  @override
  String get shieldInactiveDesc => 'Enable filtering to block unwanted calls.';

  @override
  String get btnActivateProtection => 'Activate protection';

  @override
  String get protectionActiveSuccess =>
      'ShieldNet protection activated successfully!';

  @override
  String get protectionPermissionRequired =>
      'Please grant permissions to activate protection.';

  @override
  String get shieldStrictBadge => 'Strict Shield (Contacts Only)';

  @override
  String get shieldStrictTitle => 'Maximum Protection';

  @override
  String get shieldStrictDesc =>
      'Only your saved contacts are allowed to ring.';

  @override
  String get settingContactsOnly => 'Contacts Only Mode';

  @override
  String get settingContactsOnlyDesc => 'Only allow saved contacts to ring';

  @override
  String get searchSuspectNumber => 'Check a suspect number';

  @override
  String get searchSuspectDesc => 'Instantly search the anti-spam database';

  @override
  String get statSpamIntercepted => 'Spam intercepted';

  @override
  String get statNumbersBlocked => 'Blocked numbers';

  @override
  String get recentBlockedSpams => 'Recent Blocked Spams';

  @override
  String get verifyCallAction => 'Check a call';

  @override
  String get calmLineTitle => 'Quiet and secure line';

  @override
  String get calmLineDesc => 'No recent threats detected on your device.';

  @override
  String get badgeBlocked => 'Blocked';

  @override
  String get maskedNumberDefault => 'Masked number';

  @override
  String get dialogCheckNumber => 'Check a number';

  @override
  String get dialogCheckPrompt =>
      'Enter a number to check if it has been reported as spam:';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnVerify => 'Check';

  @override
  String get btnUnderstood => 'Got it';

  @override
  String get dialogVerified => 'Verified Number';

  @override
  String get dialogSpamDetected => 'Warning: Spam Detected';

  @override
  String get dialogSafeNumber => 'Safe Number';

  @override
  String get dialogVerifiedDesc =>
      'This number is verified and certified by the administrator.';

  @override
  String get dialogSpamDesc => 'This number has been identified as unwanted.';

  @override
  String get dialogSafeDesc => 'No malicious reports found for this number.';

  @override
  String get activityTitle => 'Phone Activity';

  @override
  String get tabRecentCalls => 'Recent Calls';

  @override
  String get tabBlockedNumbers => 'Blocked Numbers';

  @override
  String get noRecentCalls => 'No recent calls';

  @override
  String get noRecentCallsDesc =>
      'Recent calls will appear here with their security status.';

  @override
  String get noBlockedNumbers => 'No blocked numbers';

  @override
  String get noBlockedNumbersDesc =>
      'All numbers reported or blocked by automatic filter will appear here.';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryAnotherSearch => 'Try another search term.';

  @override
  String get searchBlockedPlaceholder => 'Search blocked number...';

  @override
  String get blockAndReport => 'Block & Report';

  @override
  String get reportReason => 'Reason for report:';

  @override
  String get categoryScam => 'Scam';

  @override
  String get categoryTelemarketing => 'Telemarketing';

  @override
  String get categoryPhishing => 'Phishing';

  @override
  String get categoryRobocall => 'Robocall / Silence';

  @override
  String get btnBlockThisNumber => 'Block this number';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get spamBlocked => 'Spam blocked';

  @override
  String get riskWord => 'risk';

  @override
  String get timeJustNow => 'Just now';

  @override
  String get timeTodayAt => 'Today at';

  @override
  String get timeYesterdayAt => 'Yesterday at';

  @override
  String get unknownCaller => 'Unknown';

  @override
  String get reportSuccessMessage =>
      'Number blocked and reported successfully.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionSecurity => 'SECURITY';

  @override
  String get sectionPreferences => 'PREFERENCES';

  @override
  String get sectionAdmin => 'ADMINISTRATION';

  @override
  String get settingCallFiltering => 'Call filtering';

  @override
  String get settingSmsFiltering => 'SMS filtering';

  @override
  String get settingBgSync => 'Background sync';

  @override
  String get settingUpdateDb => 'Update database';

  @override
  String get btnSync => 'Sync';

  @override
  String get syncSuccess => 'Synchronization successful';

  @override
  String get syncSuccessDetail =>
      'Protection up to date: numbers synchronized.';

  @override
  String get settingTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingLanguage => 'Language';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get adminConsoleTitle => 'Admin Console';

  @override
  String get userAccountTitle => 'User Account';

  @override
  String get userAccountSubtitle => 'Sign in or register';

  @override
  String get btnLogout => 'Sign out';

  @override
  String get logoutSuccess => 'Successfully signed out.';

  @override
  String get protectionActive => '100% PROTECTED';

  @override
  String get protectionPartial => 'PARTIAL PROTECTION';

  @override
  String get protectionActiveDescOld =>
      'ShieldNet blocks unwanted calls in real time before ringing.';

  @override
  String get protectionPartialDesc =>
      'Enable native Android filtering to activate full protection.';

  @override
  String get btnEnableNative => 'Enable Native Filtering';

  @override
  String get statLocalDb => 'Local Database';

  @override
  String get statFiltered => 'Filtered numbers';

  @override
  String get statProtectedZone => 'Protected Zone';

  @override
  String get statZoneDesc => '+1 (Canada / US)';

  @override
  String get callLogTitle => 'Call History';

  @override
  String get callLogReportPrompt => 'Report this number?';

  @override
  String get callLogReportDesc =>
      'Do you want to report this number as spam? It will be shared with the community.';

  @override
  String get btnReport => 'Report';

  @override
  String get reportSuccess => 'Report successful!';

  @override
  String get reportLocal => 'Saved locally.';
}
