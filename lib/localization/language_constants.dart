import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_localization.dart';

const String language = 'languageCode';
const String english = 'en';
const String arabic = 'ar';

Future<Locale> setLocale(String languageCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(language, languageCode);
  return _locale(languageCode);
}

Future<Locale> getLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString(language) ?? english;
  return _locale(languageCode);
}

Future<String> getCurrentLanguageCode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(language) ?? english;
}

Locale _locale(String languageCode) {
  switch (languageCode) {
    case arabic:
      return const Locale(arabic, 'SA');
    case english:
    default:
      return const Locale(english, 'US');
  }
}

String getTranslated(BuildContext context, String key) {
  final localization = DemoLocalization.of(context);
  return localization?.translate(key) ??
      localization?.translate(key.trim()) ??
      key;
}

String getTranslatedWithArgs(
  BuildContext context,
  String key, [
  Map<String, String> args = const {},
]) {
  var value = getTranslated(context, key);
  args.forEach((placeholder, replacement) {
    value = value.replaceAll('{$placeholder}', replacement);
  });
  return value;
}

Future<String> getTranslatedForCurrentLocale(String key) async {
  final code = await getCurrentLanguageCode();
  return DemoLocalization.translateForLanguageCode(code, key);
}

Future<String> getTranslatedForLocaleCode(
  String languageCode,
  String key, {
  Map<String, String> args = const {},
}) async {
  var value = await DemoLocalization.translateForLanguageCode(
    languageCode,
    key,
  );
  args.forEach((placeholder, replacement) {
    value = value.replaceAll('{$placeholder}', replacement);
  });
  return value;
}

bool isArabicLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode == arabic;

String localizeCategoryName(BuildContext context, String category) {
  final translated = getTranslated(context, category);
  return translated == category ? category : translated;
}
