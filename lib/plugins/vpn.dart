import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/mihomo/mihomo.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}
}

class Vpn {
  factory Vpn() => _instance ??= Vpn._();
  Vpn._();
  static Vpn? _instance;

  String _cachedProfileName = 'MihoX';
  String _cachedServiceName = '';

  String get cachedProfileName => _cachedProfileName;
  String get cachedServiceName => _cachedServiceName;

  void updateProfileInfo({
    required String profileName,
    required String serviceName,
  }) {
    _cachedProfileName = profileName;
    _cachedServiceName = serviceName;
    _pushNotification();
  }

  Future<void> _pushNotification() async {
    try {
      final title = _cachedServiceName.isNotEmpty
          ? _cachedServiceName
          : _cachedProfileName;
      commonPrint.log(
        '[Vpn] pushNotification: title="$title" mihomoLib=${mihomoLib != null}',
      );
      // Leave the stop-button label to its localized default ("Остановить" / "Stop");
      // the service name already lives in the notification title above.
      await mihomoLib?.updateNotificationParams(title: title);
    } catch (e) {
      commonPrint.log('[Vpn] pushNotification FAILED: $e');
    }
  }

  /// Restore-pending: Kotlin side needs a matching method on the service
  /// channel. Kept as a best-effort call so Dart call-sites don't error.
  Future<bool?> showSubscriptionNotification({
    required String title,
    required String message,
    required String actionLabel,
    required String actionUrl,
  }) async {
    try {
      return await const MethodChannelShim().invoke<bool>(
        'showSubscriptionNotification',
        <String, String>{
          'title': title,
          'message': message,
          'actionLabel': actionLabel,
          'actionUrl': actionUrl,
        },
      );
    } catch (e) {
      commonPrint.log('showSubscriptionNotification (not wired): $e');
      return false;
    }
  }

  Future<bool> start(String optionsJson) async {
    final rt = await mihomoLib?.startVpn() ?? 0;
    return rt != 0;
  }

  Future<bool> stop() async {
    await mihomoLib?.stopVpn();
    return true;
  }

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();
  FutureOr<String> Function()? handleGetStartForegroundParams;

  void addListener(VpnListener listener) => _listeners.add(listener);
  void removeListener(VpnListener listener) => _listeners.remove(listener);
}

/// Thin wrapper to forward untyped invocations on the service channel — avoids
/// leaking a direct MethodChannel import from subscription_notification_service.
class MethodChannelShim {
  const MethodChannelShim();
  Future<T?> invoke<T>(String method, dynamic arguments) async {
    const channel = MethodChannel('org.remtrik.mihox/service');
    return channel.invokeMethod<T>(method, arguments);
  }
}

Vpn? get vpn => Platform.isAndroid ? Vpn() : null;
