import 'dart:async';
import 'dart:io';

import 'package:mihox/mihomo/lib.dart';

class Service {
  factory Service() => _instance ??= Service._();
  Service._();

  static Service? _instance;

  Future<bool?> init() async {
    await mihomoLib?.preload();
    return true;
  }

  Future<bool?> destroy() async => mihomoLib?.destroy();

  Future<bool?> startVpn() async {
    final rt = await mihomoLib?.startVpn() ?? 0;
    return rt != 0;
  }

  Future<bool?> stopVpn() async => mihomoLib?.stopVpn();
}

Service? get service => Platform.isAndroid ? Service() : null;
