import 'dart:io';

import 'launch_linux.dart';
import 'launch_windows.dart';
import 'system.dart';

abstract class AutoLaunch {
  factory AutoLaunch() {
    if (Platform.isWindows) {
      return WindowsAutoLaunch();
    }

    if (Platform.isLinux) {
      return LinuxAutoLaunch();
    }

    throw UnsupportedError(
      'AutoLaunch is not supported on ${Platform.operatingSystem}',
    );
  }

  Future<bool> get isEnable;

  Future<bool> enable();

  Future<bool> disable();

  Future<void> updateStatus({required bool isAutoLaunch}) async {
    if (await isEnable == isAutoLaunch) return;

    if (isAutoLaunch) {
      await enable();
    } else {
      await disable();
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;
