import 'dart:io';

import 'package:mihox/plugins/app.dart';
import 'package:mihox/state.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = Platform.isAndroid ? Android() : null;
