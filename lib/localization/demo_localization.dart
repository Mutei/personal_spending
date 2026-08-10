import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DemoLocalization {
  DemoLocalization(this.locale);

  final Locale locale;
  static final Map<String, Map<String, String>> _cache =
      <String, Map<String, String>>{};

  static DemoLocalization? of(BuildContext context) {
    return Localizations.of<DemoLocalization>(context, DemoLocalization);
  }

  late Map<String, String> _localizedValues;

  Future<void> load() async {
    _localizedValues = await loadLanguageMap(locale.languageCode);
  }

  String? translate(String key) {
    return _localizedValues[key];
  }

  static Future<Map<String, String>> loadLanguageMap(
    String languageCode,
  ) async {
    if (_cache.containsKey(languageCode)) {
      return _cache[languageCode]!;
    }

    final jsonStringValues = await rootBundle.loadString(
      'lib/language/$languageCode.json',
    );
    final mappedJson = json.decode(jsonStringValues) as Map<String, dynamic>;
    final localizedValues = mappedJson.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    _cache[languageCode] = localizedValues;
    return localizedValues;
  }

  static Future<String> translateForLanguageCode(
    String languageCode,
    String key,
  ) async {
    final values = await loadLanguageMap(languageCode);
    return values[key] ?? key;
  }

  static String translateCached(String languageCode, String key) {
    return _cache[languageCode]?[key] ?? key;
  }

  static const LocalizationsDelegate<DemoLocalization> delegate =
      _DemoLocalizationsDelegate();
}

class _DemoLocalizationsDelegate
    extends LocalizationsDelegate<DemoLocalization> {
  const _DemoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<DemoLocalization> load(Locale locale) async {
    final localization = DemoLocalization(locale);
    await localization.load();
    return localization;
  }

  @override
  bool shouldReload(LocalizationsDelegate<DemoLocalization> old) => false;
}
