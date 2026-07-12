import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/plugins/app.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/input.dart';

class System {
  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  System._internal();
  static System? _instance;
  List<String>? originDns;

  bool get isDesktop => Platform.isWindows || Platform.isLinux;

  bool get isMobile => Platform.isAndroid;

  Future<bool> get isAndroidTV async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.systemFeatures.contains('android.software.leanback');
  }

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      "android" => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      "windows" => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0
    };
  }

  Future<bool> checkIsAdmin() async {
    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
    if (Platform.isWindows) {
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    } else if (Platform.isLinux) {
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (Platform.isWindows) {
      // First, try to start existing service without UAC
      final startedWithoutUac = await windows?.tryStartExistingService();
      if (startedWithoutUac == true) {
        return AuthorizeCode.success;
      }

      // Service not installed or couldn't start - need to install with UAC
      final result = await windows?.installService();
      if (result == true) {
        return AuthorizeCode.success;
      }
      return AuthorizeCode.error;
    } else if (Platform.isLinux) {
      final shell = Platform.environment['SHELL'] ?? 'bash';
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      final arguments = [
        "-c",
        'echo "$password" | sudo -S chown root:root "$corePath" && echo "$password" | sudo -S chmod +sx "$corePath"'
      ];
      final result = await Process.run(shell, arguments);
      if (result.exitCode != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    }
    await window?.close();
  }
}

final system = System();
