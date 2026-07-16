import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import 'constant.dart';
import 'launch.dart';

class WindowsAutoLaunch implements AutoLaunch {
  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  Future<bool> get isEnable async {
    final key = CURRENT_USER.open(_runKey);

    try {
      return key.getValue(appName) != null;
    } finally {
      key.close();
    }
  }

  @override
  Future<bool> enable() async {
    final key = CURRENT_USER.create(_runKey);
    try {
      key.setValue(
        appName,
        RegistryValue.string(Platform.resolvedExecutable),
      );

      return true;
    } finally {
      key.close();
    }
  }

  @override
  Future<bool> disable() async {
    final key = CURRENT_USER.create(_runKey);
    try {
      if (key.getValue(appName) != null) {
        key.removeValue(appName);
      }

      return true;
    } finally {
      key.close();
    }
  }

  @override
  Future<void> updateStatus({
    required bool isAutoLaunch,
  }) async {
    if (await isEnable == isAutoLaunch) return;

    if (isAutoLaunch) {
      await enable();
    } else {
      await disable();
    }
  }
}
