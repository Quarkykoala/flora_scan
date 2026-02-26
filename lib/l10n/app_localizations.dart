import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

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
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'FloraScan'**
  String get appTitle;

  /// Plants tab label
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get plants;

  /// Scan tab label
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// History tab label
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Add plant button label
  ///
  /// In en, this message translates to:
  /// **'Add Plant'**
  String get addPlant;

  /// Scan plant button label
  ///
  /// In en, this message translates to:
  /// **'Scan Plant'**
  String get scanPlant;

  /// Diagnosis screen title
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// Treatment section title
  ///
  /// In en, this message translates to:
  /// **'Recommended Treatment'**
  String get treatment;

  /// Visual symptoms section title
  ///
  /// In en, this message translates to:
  /// **'Visual Symptoms'**
  String get visualSymptoms;

  /// Environmental context section title
  ///
  /// In en, this message translates to:
  /// **'Environmental Context'**
  String get environmentalContext;

  /// Health score label
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get healthScore;

  /// Confidence label
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// High confidence label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get confidenceHigh;

  /// Medium confidence label
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get confidenceMedium;

  /// Low confidence label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get confidenceLow;

  /// Sign in button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign up button label
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUp;

  /// Sign out button label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Plant nickname field label
  ///
  /// In en, this message translates to:
  /// **'Plant Nickname'**
  String get plantNickname;

  /// Common name field label
  ///
  /// In en, this message translates to:
  /// **'Common Name'**
  String get commonName;

  /// Scientific name field label
  ///
  /// In en, this message translates to:
  /// **'Scientific Name'**
  String get scientificName;

  /// Environment section label
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get environment;

  /// Location label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Light source label
  ///
  /// In en, this message translates to:
  /// **'Light Source'**
  String get lightSource;

  /// Pot type label
  ///
  /// In en, this message translates to:
  /// **'Pot Type'**
  String get potType;

  /// Soil mix label
  ///
  /// In en, this message translates to:
  /// **'Soil Mix'**
  String get soilMix;

  /// Sun exposure label
  ///
  /// In en, this message translates to:
  /// **'Sun Exposure'**
  String get sunExposure;

  /// Care log section title
  ///
  /// In en, this message translates to:
  /// **'Care Log'**
  String get careLog;

  /// Water care action
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// Fertilize care action
  ///
  /// In en, this message translates to:
  /// **'Fertilize'**
  String get fertilize;

  /// Repot care action
  ///
  /// In en, this message translates to:
  /// **'Repot'**
  String get repot;

  /// Prune care action
  ///
  /// In en, this message translates to:
  /// **'Prune'**
  String get prune;

  /// Feedback question
  ///
  /// In en, this message translates to:
  /// **'Was this diagnosis helpful?'**
  String get wasThisHelpful;

  /// Helpful feedback option
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get helpful;

  /// Not helpful feedback option
  ///
  /// In en, this message translates to:
  /// **'Not Helpful'**
  String get notHelpful;

  /// Wrong diagnosis feedback option
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get wrongDiagnosis;

  /// Feedback thank you message
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get thankYouFeedback;

  /// Analyzing status text
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// Empty scan history message
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get noScansYet;

  /// Empty plant list message
  ///
  /// In en, this message translates to:
  /// **'No plants added yet'**
  String get noPlantsYet;

  /// Welcome screen title
  ///
  /// In en, this message translates to:
  /// **'Welcome to FloraScan!'**
  String get welcomeTitle;

  /// Welcome screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Add your first plant to start scanning and get AI-powered health diagnostics.'**
  String get welcomeSubtitle;

  /// Location permission prompt
  ///
  /// In en, this message translates to:
  /// **'Enable location for weather-aware diagnostics'**
  String get enableLocation;

  /// Low photo quality warning
  ///
  /// In en, this message translates to:
  /// **'Low photo quality detected. For better results, ensure good lighting and hold the camera steady.'**
  String get lowPhotoQuality;

  /// Pending uploads label
  ///
  /// In en, this message translates to:
  /// **'Pending Uploads'**
  String get pendingUploads;

  /// Force sync button label
  ///
  /// In en, this message translates to:
  /// **'Force Sync Now'**
  String get forceSyncNow;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Research consent setting label
  ///
  /// In en, this message translates to:
  /// **'Research Consent'**
  String get researchConsent;

  /// Research consent description
  ///
  /// In en, this message translates to:
  /// **'Allow anonymized data for research'**
  String get researchConsentSubtitle;

  /// Privacy policy link label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Processing details section title
  ///
  /// In en, this message translates to:
  /// **'Processing Details'**
  String get processingDetails;

  /// View all scans button
  ///
  /// In en, this message translates to:
  /// **'View All Scans'**
  String get viewAllScans;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Archive button label
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Archive confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to archive this plant?'**
  String get archivePlantConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'it',
        'ja',
        'ko',
        'pt',
        'ru',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
