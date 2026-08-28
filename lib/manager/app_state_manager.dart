import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/core.dart';
import 'package:mihox/mihomo/lib.dart';
import 'package:mihox/plugins/tile.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/state.dart';

class AppStateManager extends ConsumerStatefulWidget {
  const AppStateManager({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref
      ..listenManual(layoutChangeProvider, (prev, next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (prev != next) {
            globalState.cacheHeightMap = {};
          }
        });
      })
      ..listenManual(checkIpProvider, (prev, next) {
        if (prev != next && next.b) {
          detectionState.startCheck();
        }
      }, fireImmediately: true)
      ..listenManual(configStateProvider, (prev, next) {
        if (prev != next) {
          globalState.appController.savePreferencesDebounce();
        }
      })
      ..listenManual(autoSetSystemDnsStateProvider, (prev, next) {
        if (prev == next) {
          return;
        }
      })
      ..listenManual(patchMihomoConfigProvider.select((state) => state.mode), (
        prev,
        next,
      ) {
        if (prev != next) {
          tile?.updateMode(next.name);
        }
      }, fireImmediately: true)
      ..listenManual(globalModeEnabledProvider, (prev, next) {
        if (prev != next) {
          tile?.updateGlobalModeEnabled(enabled: next);
        }
      }, fireImmediately: true)
      ..listenManual(globalModeEnabledProvider, (prev, next) {
        if (next) {
          return;
        }
        final currentMode = ref.read(
          patchMihomoConfigProvider.select((state) => state.mode),
        );
        if (currentMode != Mode.global) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          globalState.appController.changeMode(Mode.rule);
        });
      }, fireImmediately: true);
  }

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log("$state");
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      await globalState.appController.savePreferences();
      if (Platform.isAndroid) {
        globalState.stopUpdateTasks();
        globalState.appController.stopRunTimeTimer();
        globalState.stopGroupsUpdateTask();
        // Tell the core the UI is backgrounded: it pauses the request forwarder
        // and stretches the health-check forwarder to a slow interval so it stops
        // pinging every proxy every few seconds for a UI nobody is looking at.
        mihomoCore.setUiActive(false);
      }
    } else if (state == AppLifecycleState.hidden) {
      // Desktop window hidden (tray/minimize). Falling through to the generic
      // resume branch cancelled the throttled render pause armed by
      // window.hide(), so the engine kept rasterizing dashboard animations in
      // an invisible window.
      render?.pause();
    } else {
      render?.resume();
      if (state == AppLifecycleState.resumed && Platform.isAndroid) {
        // Re-assert the per-session core wiring against the (possibly recycled)
        // :remote core. A warm app-open after a headless tile start keeps this
        // engine's one-time event-pipe registration + log/request producers, but the
        // :remote core has been replaced — so logs/journal/delays silently stop
        // arriving (only the polled traffic survives). All idempotent and mirror what
        // the cold-start path already does.
        mihomoLib?.reconnectIfNeeded();
        mihomoCore.setUiActive(true);
        // Re-subscribe the log stream: the log subscriber lives in :remote and is gone
        // after a recycle, and nothing else re-issues it on resume. Gated on openLogs.
        if (globalState.config.appSetting.openLogs) {
          mihomoCore.startLog();
        } else {
          mihomoCore.stopLog();
        }
        globalState.startGroupsUpdateTask();
        globalState.appController.updateGroupsDebounce();
        // Optimistically restart timers from the cached state so the runtime
        // display doesn't stall while the probe below is in flight...
        if (globalState.isStart) {
          globalState.startUpdateTasks();
          globalState.appController.startRunTimeTimer();
        }
        // ...then align with the native truth: STOP/START events are lost
        // while the process is frozen/killed, and the cached state never
        // self-heals without this.
        unawaited(globalState.appController.syncVpnStateOnResume());
      }
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerHover: (_) {
      render?.resume();
    },
    child: widget.child,
  );
}

class AppEnvManager extends StatelessWidget {
  const AppEnvManager({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
