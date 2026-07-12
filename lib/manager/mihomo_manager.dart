import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/app.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/providers/state.dart';
import 'package:mihox/state.dart';

class MihomoManager extends ConsumerStatefulWidget {
  const MihomoManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<MihomoManager> createState() => _MihomoContainerState();
}

class _MihomoContainerState extends ConsumerState<MihomoManager>
    with AppMessageListener {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void initState() {
    super.initState();
    mihomoMessage.addListener(this);
    ref
      ..listenManual(needSetupProvider, (prev, next) {
        if (prev != next) {
          globalState.appController.handleChangeProfile();
        }
      })
      ..listenManual(coreStateProvider, (prev, next) async {
        if (prev != next) {
          await mihomoCore.setState(next);
        }
      })
      ..listenManual(updateParamsProvider, (prev, next) {
        if (prev != next) {
          globalState.appController.updateMihomoConfigDebounce();
        }
      })
      ..listenManual(
        appSettingProvider.select((state) => state.openLogs),
        (prev, next) {
          if (next) {
            mihomoCore.startLog();
          } else {
            mihomoCore.stopLog();
          }
        },
      );
  }

  @override
  Future<void> dispose() async {
    mihomoMessage.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onDelay(Delay delay) async {
    super.onDelay(delay);
    final appController = globalState.appController..setDelay(delay);
    debouncer.call(
      FunctionTag.updateDelay,
      () async {
        appController.updateGroupsDebounce();
      },
      duration: const Duration(milliseconds: 5000),
    );
  }

  @override
  void onLog(Log log) {
    ref.read(logsProvider.notifier).addLog(log);

    // Write core logs to file
    fileLogger.log("[${log.logLevel.name.toUpperCase()}] ${log.payload}");

    if (log.logLevel == LogLevel.error) {
      globalState.showNotifier(log.payload);
    }
    super.onLog(log);
  }

  @override
  void onRequest(Connection connection) async {
    ref.read(requestsProvider.notifier).addRequest(connection);
    super.onRequest(connection);
  }

  @override
  Future<void> onLoaded(String providerName) async {
    ref.read(providersProvider.notifier).setProvider(
          await mihomoCore.getExternalProvider(
            providerName,
          ),
        );
    globalState.appController.updateGroupsDebounce();
    super.onLoaded(providerName);
  }
}
