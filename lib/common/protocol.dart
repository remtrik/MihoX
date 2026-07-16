import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

class Protocol {
  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  Protocol._internal();
  static Protocol? _instance;

  void register(String scheme) {
    final root = CURRENT_USER.create(r'Software\Classes\$scheme');

    try {
      root.setValue('URL Protocol', const RegistryValue.string(''));

      final command = root.create(r'shell\open\command');

      try {
        command.setValue(
          '',
          RegistryValue.string('"${Platform.resolvedExecutable}" "%1"'),
        );
      } finally {
        command.close();
      }
    } finally {
      root.close();
    }
  }
}

final protocol = Protocol();
