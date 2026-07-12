import 'package:flutter/cupertino.dart';
import 'package:mihox/common/file_logger.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';

class CommonPrint {
  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  CommonPrint._internal();
  static CommonPrint? _instance;

  void log(String? text) {
    final payload = "[MihoX] $text";
    debugPrint(payload);

    // Write to file log
    fileLogger.log(payload);

    if (!globalState.isInit) {
      return;
    }
    globalState.appController.addLog(
      Log.app(payload),
    );
  }
}

final commonPrint = CommonPrint();
