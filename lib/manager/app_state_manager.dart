import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/plugins/tile.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/state.dart';

class AppStateManager extends ConsumerStatefulWidget {
  const AppStateManager({
    super.key,
    required this.child,
  });
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
      ..listenManual(
        checkIpProvider,
        (prev, next) {
          if (prev != next && next.b) {
            detectionState.startCheck();
          }
        },
        fireImmediately: true,
      )
      ..listenManual(configStateProvider, (prev, next) {
        if (prev != next) {
          globalState.appController.savePreferencesDebounce();
        }
      })
      ..listenManual(
        autoSetSystemDnsStateProvider,
        (prev, next) async {
          if (prev == next) {
            return;
          }
        },
      )
      ..listenManual(
        patchMihomoConfigProvider.select((state) => state.mode),
        (prev, next) {
          if (prev != next) {
            tile?.updateMode(next.name);
          }
        },
        fireImmediately: true,
      )
      ..listenManual(
        globalModeEnabledProvider,
        (prev, next) {
          if (prev != next) {
            tile?.updateGlobalModeEnabled(enabled: next);
          }
        },
        fireImmediately: true,
      )
      ..listenManual(
        globalModeEnabledProvider,
        (prev, next) {
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
        },
        fireImmediately: true,
      );
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
    } else {
      render?.resume();
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
  const AppEnvManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
