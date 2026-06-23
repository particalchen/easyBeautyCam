import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('zh')
  ];

  /// 应用顶部标题
  ///
  /// In zh, this message translates to:
  /// **'Easy Pose'**
  String get appTitle;

  /// 通用取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// 滤镜浮层标题
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get actionEdit;

  /// 保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// 通用返回按钮
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get actionBack;

  /// 相机页面相册入口
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get cameraAlbum;

  /// 相机页面菜单按钮
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get cameraMenu;

  /// 1 倍镜头
  ///
  /// In zh, this message translates to:
  /// **'1x'**
  String get zoom1x;

  /// 2 倍镜头
  ///
  /// In zh, this message translates to:
  /// **'2x'**
  String get zoom2x;

  /// 3 倍镜头
  ///
  /// In zh, this message translates to:
  /// **'3x'**
  String get zoom3x;

  /// 无滤镜
  ///
  /// In zh, this message translates to:
  /// **'原图'**
  String get filterOriginal;

  /// 珊瑚色调
  ///
  /// In zh, this message translates to:
  /// **'珊瑚'**
  String get filterCoral;

  /// 港风色调
  ///
  /// In zh, this message translates to:
  /// **'港风'**
  String get filterGangfeng;

  /// 日系色调
  ///
  /// In zh, this message translates to:
  /// **'日系'**
  String get filterRixi;

  /// 胶片色调
  ///
  /// In zh, this message translates to:
  /// **'胶片'**
  String get filterJiaopian;

  /// 磨皮滑杆标签
  ///
  /// In zh, this message translates to:
  /// **'磨皮'**
  String get beautySmooth;

  /// 美白滑杆标签
  ///
  /// In zh, this message translates to:
  /// **'美白'**
  String get beautyWhiten;

  /// 瘦脸滑杆标签
  ///
  /// In zh, this message translates to:
  /// **'瘦脸'**
  String get beautySlim;

  /// 菜单弹层标题
  ///
  /// In zh, this message translates to:
  /// **'菜单'**
  String get menuTitle;

  /// 浏览/管理姿势模板
  ///
  /// In zh, this message translates to:
  /// **'姿势库'**
  String get menuPoseLibrary;

  /// 应用设置入口
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get menuSettings;

  /// 关于应用
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get menuAbout;

  /// BeautySlider 顶部提示：未在照片中检测到人脸时显示
  ///
  /// In zh, this message translates to:
  /// **'未检测到人脸，美颜未生效'**
  String get beautyNoFaceDetected;

  /// BeautySlider 顶部提示：检测到 N 张人脸时显示
  ///
  /// In zh, this message translates to:
  /// **'已检测 {count} 张人脸'**
  String beautyFaceDetected(int count);
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
