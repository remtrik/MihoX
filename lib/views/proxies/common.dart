import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
    ProxyCardType.oneline => 16 + measure.bodyMediumHeight + 4,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final state = appController.getProxyCardState(proxy.name);
  final url = state.testUrl.getSafeValue(appController.getRealTestUrl(testUrl));
  if (state.proxyName.isEmpty) {
    return;
  }
  appController.setDelay(Delay(url: url, name: state.proxyName, value: 0));
  try {
    appController.setDelay(await mihomoCore.getDelay(url, state.proxyName));
  } catch (_) {
    appController.setDelay(Delay(url: url, name: state.proxyName, value: -1));
  }
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies.map((proxy) => proxy.name).toSet().toList();

  final loadingDelays = <Delay>[];
  final proxyData = <({String url, String name})>[];

  for (final proxyName in proxyNames) {
    final state = appController.getProxyCardState(proxyName);
    final url = state.testUrl.getSafeValue(
      appController.getRealTestUrl(testUrl),
    );
    final name = state.proxyName;
    if (name.isEmpty) continue;
    loadingDelays.add(Delay(url: url, name: name, value: 0));
    proxyData.add((url: url, name: name));
  }

  appController.setDelays(loadingDelays);

  final resultDelays = <Delay>[];
  final batches = proxyData.batch(15);
  for (final batch in batches) {
    final batchResults = batch.map<Future<Delay>>((data) async {
      final delay = await mihomoCore.getDelay(data.url, data.name);
      return Delay(url: data.url, name: data.name, value: delay.value);
    }).toList();
    resultDelays.addAll(await Future.wait(batchResults));
  }

  appController
    ..setDelays(resultDelays)
    ..addSortNum();
}
