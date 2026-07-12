import 'dart:async';
import 'dart:convert';

import 'package:mihox/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, __) => sharedPreferencesCompleter.complete(null));
  }
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Future<MihomoConfig?> getMihomoConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final mihomoConfigString = preferences?.getString(mihomoConfigKey);
    if (mihomoConfigString == null) return null;
    final mihomoConfigMap = json.decode(mihomoConfigString);
    return MihomoConfig.fromJson(mihomoConfigMap);
  }

  Future<Config?> getConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    final configString = preferences?.getString(configKey);
    if (configString == null) return null;
    final configMap = json.decode(configString);
    return Config.compatibleFromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return await preferences?.setString(
          configKey,
          json.encode(config),
        ) ??
        false;
  }

  Future<void> clearMihomoConfig() async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.remove(mihomoConfigKey);
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }
}

final preferences = Preferences();
