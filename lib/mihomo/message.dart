import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';

class MihomoMessage {
  MihomoMessage._() {
    controller.stream.listen(
      (message) {
        if (message.isEmpty || _listeners.isEmpty) {
          return;
        }
        final m = AppMessage.fromJson(message);
        for (final listener in _listeners) {
          switch (m.type) {
            case AppMessageType.log:
              listener.onLog(Log.fromJson(m.data));
              break;
            case AppMessageType.delay:
              listener.onDelay(Delay.fromJson(m.data));
              break;
            case AppMessageType.request:
              listener.onRequest(Connection.fromJson(m.data));
              break;
            case AppMessageType.loaded:
              listener.onLoaded(m.data);
              break;
          }
        }
      },
    );
  }
  final controller = StreamController<Map<String, Object?>>();

  static final MihomoMessage instance = MihomoMessage._();

  final ObserverList<AppMessageListener> _listeners =
      ObserverList<AppMessageListener>();

  bool get hasListeners => _listeners.isNotEmpty;

  void addListener(AppMessageListener listener) {
    _listeners.add(listener);
  }

  void removeListener(AppMessageListener listener) {
    _listeners.remove(listener);
  }
  
  Future<void> dispose() async {
    _listeners.clear();
    await controller.close();
  }
}

final mihomoMessage = MihomoMessage.instance;
