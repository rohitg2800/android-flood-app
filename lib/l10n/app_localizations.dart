import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_or.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
    Locale('or')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EQUINOX-BR05'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMonitors.
  ///
  /// In en, this message translates to:
  /// **'Monitors'**
  String get tabMonitors;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabAlerts;

  /// No description provided for @tabPredict.
  ///
  /// In en, this message translates to:
  /// **'Predict'**
  String get tabPredict;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @riverLevel.
  ///
  /// In en, this message translates to:
  /// **'River Level'**
  String get riverLevel;

  /// No description provided for @rainfall.
  ///
  /// In en, this message translates to:
  /// **'Rainfall'**
  String get rainfall;

  /// No description provided for @discharge.
  ///
  /// In en, this message translates to:
  /// **'Discharge'**
  String get discharge;

  /// No description provided for @safe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get safe;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @danger.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get danger;

  /// No description provided for @critical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get critical;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @stations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stations;

  /// No description provided for @forecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// No description provided for @floodRisk.
  ///
  /// In en, this message translates to:
  /// **'Flood Risk'**
  String get floodRisk;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeDay.
  ///
  /// In en, this message translates to:
  /// **'Day River'**
  String get themeDay;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Night River'**
  String get themeDark;

  /// No description provided for @themeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset Warm'**
  String get themeSunset;

  /// No description provided for @themeOcean.
  ///
  /// In en, this message translates to:
  /// **'Deep Ocean'**
  String get themeOcean;

  /// No description provided for @premiumFilters.
  ///
  /// In en, this message translates to:
  /// **'Premium Filters'**
  String get premiumFilters;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @bihar.
  ///
  /// In en, this message translates to:
  /// **'Bihar'**
  String get bihar;

  /// No description provided for @currentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get currentLevel;

  /// No description provided for @dangerLevel.
  ///
  /// In en, this message translates to:
  /// **'Danger Level'**
  String get dangerLevel;

  /// No description provided for @warningLevel.
  ///
  /// In en, this message translates to:
  /// **'Warning Level'**
  String get warningLevel;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @river.
  ///
  /// In en, this message translates to:
  /// **'River'**
  String get river;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @noAlerts.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get noAlerts;

  /// No description provided for @activeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get activeAlerts;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @meters.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get meters;

  /// No description provided for @mmRainfall.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get mmRainfall;

  /// No description provided for @cumecs.
  ///
  /// In en, this message translates to:
  /// **'cumecs'**
  String get cumecs;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search city…'**
  String get searchCity;

  /// No description provided for @monitoredCities.
  ///
  /// In en, this message translates to:
  /// **'Monitored Cities'**
  String get monitoredCities;

  /// No description provided for @liveData.
  ///
  /// In en, this message translates to:
  /// **'Live Data'**
  String get liveData;

  /// No description provided for @predictionModel.
  ///
  /// In en, this message translates to:
  /// **'Prediction Model'**
  String get predictionModel;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @riskIndex.
  ///
  /// In en, this message translates to:
  /// **'RISK INDEX'**
  String get riskIndex;

  /// No description provided for @allStationsSafe.
  ///
  /// In en, this message translates to:
  /// **'All stations within safe levels'**
  String get allStationsSafe;

  /// No description provided for @fetchingLiveData.
  ///
  /// In en, this message translates to:
  /// **'Fetching live flood data…'**
  String get fetchingLiveData;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'CWC  •  GloFAS  •  IMD  •  Open-Meteo'**
  String get dataSources;

  /// No description provided for @noStationsFound.
  ///
  /// In en, this message translates to:
  /// **'No stations found.'**
  String get noStationsFound;

  /// No description provided for @rivers.
  ///
  /// In en, this message translates to:
  /// **'Rivers'**
  String get rivers;

  /// No description provided for @floodAlerts.
  ///
  /// In en, this message translates to:
  /// **'Flood Alerts'**
  String get floodAlerts;

  /// No description provided for @mlModelInfo.
  ///
  /// In en, this message translates to:
  /// **'ML Model Info'**
  String get mlModelInfo;

  /// No description provided for @floodPredictionEngine.
  ///
  /// In en, this message translates to:
  /// **'Flood Prediction Engine'**
  String get floodPredictionEngine;

  /// No description provided for @stateMatrix.
  ///
  /// In en, this message translates to:
  /// **'State Matrix'**
  String get stateMatrix;

  /// No description provided for @primaryRivers.
  ///
  /// In en, this message translates to:
  /// **'Primary Rivers'**
  String get primaryRivers;

  /// No description provided for @vulnerableDistricts.
  ///
  /// In en, this message translates to:
  /// **'Vulnerable Districts'**
  String get vulnerableDistricts;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by:'**
  String get sortBy;

  /// No description provided for @fetchingWeather.
  ///
  /// In en, this message translates to:
  /// **'Fetching live weather…'**
  String get fetchingWeather;

  /// No description provided for @riverLevelTrend.
  ///
  /// In en, this message translates to:
  /// **'24-hr River Level Trend'**
  String get riverLevelTrend;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'capacity'**
  String get capacity;

  /// No description provided for @buildingTrend.
  ///
  /// In en, this message translates to:
  /// **'Building trend…'**
  String get buildingTrend;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @monitors.
  ///
  /// In en, this message translates to:
  /// **'Monitors'**
  String get monitors;

  /// No description provided for @biharLiveData.
  ///
  /// In en, this message translates to:
  /// **'Bihar Live Data'**
  String get biharLiveData;

  /// No description provided for @gloFasDischarge.
  ///
  /// In en, this message translates to:
  /// **'GloFAS Discharge'**
  String get gloFasDischarge;

  /// No description provided for @rainfall24h.
  ///
  /// In en, this message translates to:
  /// **'24h Rainfall'**
  String get rainfall24h;

  /// No description provided for @trend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get trend;

  /// No description provided for @rising.
  ///
  /// In en, this message translates to:
  /// **'Rising'**
  String get rising;

  /// No description provided for @falling.
  ///
  /// In en, this message translates to:
  /// **'Falling'**
  String get falling;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

  /// No description provided for @floodForecast.
  ///
  /// In en, this message translates to:
  /// **'Flood Forecast'**
  String get floodForecast;

  /// No description provided for @hfl.
  ///
  /// In en, this message translates to:
  /// **'HFL'**
  String get hfl;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @openCityDetail.
  ///
  /// In en, this message translates to:
  /// **'Open City Detail'**
  String get openCityDetail;

  /// No description provided for @biharRiverGaugeMap.
  ///
  /// In en, this message translates to:
  /// **'Bihar River Gauge Map'**
  String get biharRiverGaugeMap;

  /// No description provided for @locateMe.
  ///
  /// In en, this message translates to:
  /// **'Centre on my location'**
  String get locateMe;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get location'**
  String get couldNotGetLocation;

  /// No description provided for @allRivers.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allRivers;

  /// No description provided for @noCriticalStations.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get noCriticalStations;

  /// No description provided for @criticalStations.
  ///
  /// In en, this message translates to:
  /// **'critical'**
  String get criticalStations;

  /// No description provided for @inputParameters.
  ///
  /// In en, this message translates to:
  /// **'Input Parameters'**
  String get inputParameters;

  /// No description provided for @stateCity.
  ///
  /// In en, this message translates to:
  /// **'State / City'**
  String get stateCity;

  /// No description provided for @riverLevelM.
  ///
  /// In en, this message translates to:
  /// **'River Level (m)'**
  String get riverLevelM;

  /// No description provided for @rainfall7d.
  ///
  /// In en, this message translates to:
  /// **'Rainfall 7d (mm)'**
  String get rainfall7d;

  /// No description provided for @dischargeOptional.
  ///
  /// In en, this message translates to:
  /// **'Discharge m³/s (optional)'**
  String get dischargeOptional;

  /// No description provided for @runPrediction.
  ///
  /// In en, this message translates to:
  /// **'Run Prediction'**
  String get runPrediction;

  /// No description provided for @floodPrediction.
  ///
  /// In en, this message translates to:
  /// **'FLOOD PREDICTION'**
  String get floodPrediction;

  /// No description provided for @mlModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ML model · risk level + confidence'**
  String get mlModelSubtitle;

  /// No description provided for @modelConfidence.
  ///
  /// In en, this message translates to:
  /// **'Model confidence'**
  String get modelConfidence;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @predictAutoFillTip.
  ///
  /// In en, this message translates to:
  /// **'Navigate from a City Detail screen to auto-fill the river level and city name.'**
  String get predictAutoFillTip;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get restartRequired;

  /// No description provided for @tabNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get tabNews;

  /// No description provided for @newsFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Flood News & Advisories'**
  String get newsFeedTitle;

  /// No description provided for @imdAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'IMD Alerts'**
  String get imdAlertsTitle;

  /// No description provided for @ndmaAdvisoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'NDMA Advisories'**
  String get ndmaAdvisoriesTitle;

  /// No description provided for @officialSources.
  ///
  /// In en, this message translates to:
  /// **'Official Sources'**
  String get officialSources;

  /// No description provided for @noActiveImdAlerts.
  ///
  /// In en, this message translates to:
  /// **'No active IMD alerts'**
  String get noActiveImdAlerts;

  /// No description provided for @noActiveNdmaAdvisories.
  ///
  /// In en, this message translates to:
  /// **'No active NDMA advisories'**
  String get noActiveNdmaAdvisories;

  /// No description provided for @imdFloodForecasting.
  ///
  /// In en, this message translates to:
  /// **'IMD Flood Forecasting'**
  String get imdFloodForecasting;

  /// No description provided for @ndmaAdvisoriesLink.
  ///
  /// In en, this message translates to:
  /// **'NDMA Advisories'**
  String get ndmaAdvisoriesLink;

  /// No description provided for @cwcFloodBulletin.
  ///
  /// In en, this message translates to:
  /// **'CWC Flood Bulletin'**
  String get cwcFloodBulletin;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Real-Time Flood\nIntelligence'**
  String get onboardingTitle1;

  /// No description provided for @onboardingSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'Live data from Bihar WRD gauge stations, GloFAS discharge and IMD rainfall — updated every few minutes.'**
  String get onboardingSubtitle1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Interactive\nRiver Map'**
  String get onboardingTitle2;

  /// No description provided for @onboardingSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'Colour-coded risk pins across Bihar rivers. Tap any station to view current level versus danger threshold instantly.'**
  String get onboardingSubtitle2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'ML Flood\nPrediction'**
  String get onboardingTitle3;

  /// No description provided for @onboardingSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'Enter river level and rainfall to get an instant AI risk assessment: Safe, Warning, Danger or Critical.'**
  String get onboardingSubtitle3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'SOS &\nEmergency Help'**
  String get onboardingTitle4;

  /// No description provided for @onboardingSubtitle4.
  ///
  /// In en, this message translates to:
  /// **'One-tap SOS gives fast access to helplines, evacuation guidance and emergency help.'**
  String get onboardingSubtitle4;
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
      <String>['bn', 'en', 'hi', 'or'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'or':
      return AppLocalizationsOr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
