import 'dart:io';

import 'constant.dart';
import 'launch.dart';

class LinuxAutoLaunch implements AutoLaunch {
  String get _desktopFile {
    final home = Platform.environment['HOME']!;
    return '$home/.config/autostart/$appName.desktop';
  }

  @override
  Future<bool> get isEnable async => File(_desktopFile).existsSync();

  @override
  Future<bool> enable() async {
    Directory(
      '${Platform.environment['HOME']}/.config/autostart',
    ).createSync(recursive: true);

    File(_desktopFile).writeAsStringSync('''
[Desktop Entry]
Type=Application
Version=1.0
Name=$appName
Exec=${Platform.resolvedExecutable}
Terminal=false
X-GNOME-Autostart-enabled=true
''');

    return true;
  }

  @override
  Future<bool> disable() async {
    final file = File(_desktopFile);

    if (file.existsSync()) {
      file.deleteSync();
    }

    return true;
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
