import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/plugins/service.dart';
import 'package:mihox/state.dart';

import 'generated/mihomo_ffi.dart';
import 'interface.dart';

class MihomoLib extends MihomoHandlerInterface with AndroidMihomoInterface {
  factory MihomoLib() {
    _instance ??= MihomoLib._internal();
    return _instance!;
  }

  MihomoLib._internal() {
    _initService();
  }
  static MihomoLib? _instance;
  Completer<bool> _canSendCompleter = Completer();
  SendPort? sendPort;
  final receiverPort = ReceivePort();

  @override
  Future<bool> preload() async => true;

  Future<void> _initService() async {
    await service?.destroy();
    _registerMainPort(receiverPort.sendPort);
    receiverPort.listen((message) {
      if (message is SendPort) {
        if (_canSendCompleter.isCompleted) {
          sendPort = null;
          _canSendCompleter = Completer();
        }
        sendPort = message;
        _canSendCompleter.complete(true);
      } else if (message is Map) {
        // Ignore IPC responses (Map type) - they don't need processing
        return;
      } else {
        handleResult(ActionResult.fromJson(json.decode(message)));
      }
    });
    await service?.init();
  }

  void _registerMainPort(SendPort sendPort) {
    IsolateNameServer.removePortNameMapping(mainIsolate);
    IsolateNameServer.registerPortWithName(sendPort, mainIsolate);
  }

  @override
  Future<bool> destroy() async {
    await service?.destroy();
    return true;
  }

  @override
  void reStart() {
    _initService();
  }

  @override
  Future<bool> shutdown() async {
    await super.shutdown();
    await destroy();
    return true;
  }

  @override
  Future<void> sendMessage(String message) async {
    await _canSendCompleter.future;
    sendPort?.send(message);
  }

  /// Send a custom IPC message to service (for foreground notification updates)
  Future<void> sendIpcMessage(Map<String, dynamic> message) async {
    await _canSendCompleter.future;
    sendPort?.send(message);
  }

  @override
  Future<String> getAndroidVpnOptions() => invoke<String>(
        method: ActionMethod.getAndroidVpnOptions,
      );

  @override
  Future<bool> updateDns(String value) => invoke<bool>(
        method: ActionMethod.updateDns,
        data: value,
      );

  @override
  Future<DateTime?> getRunTime() async {
    final runTimeString = await invoke<String>(
      method: ActionMethod.getRunTime,
    );
    if (runTimeString.isEmpty) return null;

    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  @override
  Future<String> getCurrentProfileName() => invoke<String>(
        method: ActionMethod.getCurrentProfileName,
      );
}

class MihomoLibHandler {
  factory MihomoLibHandler() {
    _instance ??= MihomoLibHandler._internal();
    return _instance!;
  }

  MihomoLibHandler._internal() {
    lib = DynamicLibrary.open("libmihomo.so");
    mihomoFFI = MihomoFFI(lib);
    mihomoFFI.initNativeApiBridge(
      NativeApi.initializeApiDLData,
    );
  }
  static MihomoLibHandler? _instance;

  late final MihomoFFI mihomoFFI;

  late final DynamicLibrary lib;

  Future<String> invokeAction(String actionParams) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final actionParamsChar = actionParams.toNativeUtf8().cast<Char>();
    mihomoFFI.invokeAction(
      actionParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(actionParamsChar);
    return completer.future;
  }

  void attachMessagePort(int messagePort) {
    mihomoFFI.attachMessagePort(
      messagePort,
    );
  }

  void updateDns(String dns) {
    final dnsChar = dns.toNativeUtf8().cast<Char>();
    mihomoFFI.updateDns(dnsChar);
    malloc.free(dnsChar);
  }

  void setState(CoreState state) {
    final stateChar = json.encode(state).toNativeUtf8().cast<Char>();
    mihomoFFI.setState(stateChar);
    malloc.free(stateChar);
  }

  String getCurrentProfileName() {
    final currentProfileRaw = mihomoFFI.getCurrentProfileName();
    final currentProfile = currentProfileRaw.cast<Utf8>().toDartString();
    mihomoFFI.freeCString(currentProfileRaw);
    return currentProfile;
  }

  String getAndroidVpnOptions() {
    final vpnOptionsRaw = mihomoFFI.getAndroidVpnOptions();
    final vpnOptions = vpnOptionsRaw.cast<Utf8>().toDartString();
    mihomoFFI.freeCString(vpnOptionsRaw);
    return vpnOptions;
  }

  Traffic getTraffic() {
    final trafficRaw = mihomoFFI.getTraffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    mihomoFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) return Traffic();

    return Traffic.fromMap(json.decode(trafficString));
  }

  Traffic getTotalTraffic({bool value = false}) {
    final trafficRaw = mihomoFFI.getTotalTraffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    mihomoFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) return Traffic();

    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<bool> startListener() async {
    mihomoFFI.startListener();
    return true;
  }

  Future<bool> stopListener() async {
    mihomoFFI.stopListener();
    return true;
  }

  DateTime? getRunTime() {
    final runTimeRaw = mihomoFFI.getRunTime();
    final runTimeString = runTimeRaw.cast<Utf8>().toDartString();
    if (runTimeString.isEmpty) return null;

    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final path = await appPath.getProfilePath(id);
    final pathChar = path.toNativeUtf8().cast<Char>();
    final configRaw = mihomoFFI.getConfig(pathChar);
    final configString = configRaw.cast<Utf8>().toDartString();
    if (configString.isEmpty) return {};

    final config = json.decode(configString);
    malloc.free(pathChar);
    mihomoFFI.freeCString(configRaw);
    return config;
  }

  Future<String> quickStart(
    InitParams initParams,
    SetupParams setupParams,
    CoreState state,
  ) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final params = json.encode(setupParams);
    final initValue = json.encode(initParams);
    final stateParams = json.encode(state);
    final initParamsChar = initValue.toNativeUtf8().cast<Char>();
    final paramsChar = params.toNativeUtf8().cast<Char>();
    final stateParamsChar = stateParams.toNativeUtf8().cast<Char>();
    mihomoFFI.quickStart(
      initParamsChar,
      paramsChar,
      stateParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc
      ..free(initParamsChar)
      ..free(paramsChar)
      ..free(stateParamsChar);
    return completer.future;
  }
}

MihomoLib? get mihomoLib =>
    Platform.isAndroid && !globalState.isService ? MihomoLib() : null;

MihomoLibHandler? get mihomoLibHandler =>
    Platform.isAndroid && globalState.isService ? MihomoLibHandler() : null;
