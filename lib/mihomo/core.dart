import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/common/process_icon.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/interface.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';
import 'package:path/path.dart';

class MihomoCore {
  factory MihomoCore() {
    _instance ??= MihomoCore._internal();
    return _instance!;
  }

  MihomoCore._internal() {
    if (Platform.isAndroid) {
      mihomoInterface = mihomoLib!;
    } else {
      mihomoInterface = mihomoService!;
    }
  }
  static MihomoCore? _instance;
  late MihomoHandlerInterface mihomoInterface;

  Future<bool> preload() => mihomoInterface.preload();

  static Future<void> initGeo() async {
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    final isExists = homeDir.existsSync();
    if (!isExists) {
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(
          join(homePath, geoFileName),
        );
        final isExists = geoFile.existsSync();
        if (isExists) {
          continue;
        }
        final data = await rootBundle.load('assets/data/$geoFileName');
        final List<int> bytes = data.buffer.asUint8List();
        await geoFile.writeAsBytes(bytes, flush: true);
      }
    } catch (e) {
      exit(0);
    }
  }

  Future<bool> init() async {
    await initGeo();
    if (globalState.config.appSetting.openLogs) {
      mihomoCore.startLog();
    } else {
      mihomoCore.stopLog();
    }
    final homeDirPath = await appPath.homeDirPath;
    return mihomoInterface.init(
      InitParams(
        homeDir: homeDirPath,
        version: globalState.appState.version,
      ),
    );
  }

  Future<bool> setState(CoreState state) => mihomoInterface.setState(state);

  Future<void> shutdown() async {
    await mihomoInterface.shutdown();
  }

  FutureOr<bool> get isInit => mihomoInterface.isInit;

  FutureOr<String> validateConfig(String data) =>
      mihomoInterface.validateConfig(data);

  Future<String> updateConfig(UpdateParams updateParams) =>
      mihomoInterface.updateConfig(updateParams);

  Future<String> setupConfig(SetupParams setupParams) =>
      mihomoInterface.setupConfig(setupParams);

  Future<List<Group>> getProxiesGroups() async {
    final proxies = await mihomoInterface.getProxies();
    if (proxies.isEmpty) return [];
    final groupNames = [
      UsedProxy.GLOBAL.name,
      ...(proxies[UsedProxy.GLOBAL.name]["all"] as List).where((e) {
        final proxy = proxies[e] ?? {};
        return GroupTypeExtension.valueList.contains(proxy['type']);
      })
    ];
    final groupsRaw = groupNames.map((groupName) {
      final group = proxies[groupName];
      group["all"] = ((group["all"] ?? []) as List)
          .map(
            (name) => proxies[name],
          )
          .where((proxy) => proxy != null)
          .toList();
      return group;
    }).toList();
    return groupsRaw
        .map(
          (e) => Group.fromJson(e),
        )
        .toList();
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async =>
      await mihomoInterface.changeProxy(changeProxyParams);

  Future<List<Connection>> getConnections() async {
    final res = await mihomoInterface.getConnections();
    final connectionsData = json.decode(res) as Map;
    final connectionsRaw = connectionsData['connections'] as List? ?? [];
    return connectionsRaw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      // Capture processPath (dropped by the Connection model) so desktop can show the
      // originating app's exe icon.
      final meta = map['metadata'];
      final id = map['id']?.toString();
      if (meta is Map && id != null) {
        final pp = meta['processPath']?.toString() ?? '';
        if (pp.isNotEmpty) connectionProcessPaths[id] = pp;
      }
      return Connection.fromJson(map);
    }).toList();
  }

  void closeConnection(String id) {
    mihomoInterface.closeConnection(id);
  }

  void closeConnections() {
    mihomoInterface.closeConnections();
  }

  void resetConnections() {
    mihomoInterface.resetConnections();
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString =
        await mihomoInterface.getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    return Isolate.run<List<ExternalProvider>>(
      () {
        final externalProviders =
            (json.decode(externalProvidersRawString) as List<dynamic>)
                .map(
                  (item) => ExternalProvider.fromJson(item),
                )
                .toList();
        return externalProviders;
      },
    );
  }

  Future<ExternalProvider?> getExternalProvider(
      String externalProviderName) async {
    final externalProvidersRawString =
        await mihomoInterface.getExternalProvider(externalProviderName);
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) =>
      mihomoInterface.updateGeoData(params);

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) =>
      mihomoInterface.sideLoadExternalProvider(
          providerName: providerName, data: data);

  Future<String> updateExternalProvider({
    required String providerName,
  }) async =>
      mihomoInterface.updateExternalProvider(providerName);

  Future<void> startListener() async {
    await mihomoInterface.startListener();
  }

  Future<void> stopListener() async {
    await mihomoInterface.stopListener();
  }

  Future<void> healthCheck([String groupName = '']) => mihomoInterface.healthCheck(groupName);

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await mihomoInterface.asyncTestDelay(url, proxyName);
    return Delay.fromJson(json.decode(data));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final profilePath = await appPath.getProfilePath(id);
    final res = await mihomoInterface.getConfig(profilePath);
    if (res.isSuccess) {
      return res.data as Map<String, dynamic>;
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic() async {
    final trafficString = await mihomoInterface.getTraffic();
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await mihomoInterface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(
      ip: ip,
      countryCode: countryCode,
    );
  }

  Future<Traffic> getTotalTraffic() async {
    final totalTrafficString = await mihomoInterface.getTotalTraffic();
    if (totalTrafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(totalTrafficString));
  }

  Future<int> getMemory() async {
    final value = await mihomoInterface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  void resetTraffic() {
    mihomoInterface.resetTraffic();
  }

  void startLog() {
    mihomoInterface.startLog();
  }

  void stopLog() {
    mihomoInterface.stopLog();
  }

  void requestGc() {
    mihomoInterface.forceGc();
  }

  Future<void> destroy() async {
    await mihomoInterface.destroy();
  }
}

final mihomoCore = MihomoCore();
