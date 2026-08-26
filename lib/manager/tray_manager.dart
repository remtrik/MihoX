import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/providers/state.dart';
import 'package:mihox/state.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:win32/win32.dart';

class TrayManager extends ConsumerStatefulWidget {
  const TrayManager({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> {
  final List<ListenerId> _listenerIds = [];

  void _applyWindowsMenuDarkMode() {
    if (!Platform.isWindows) return;

    try {
      final className = '#32768'.toPcwstr();
      final hwnd = FindWindow(className, nullptr as PCWSTR?);
      calloc.free(className);

      if (hwnd != 0) {
        windows?.applyDarkModeToMenu(hwnd as int);
      }
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();

    trayIcon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);

    _listenerIds
      ..add(
        trayIcon.getContextMenu()?.addListener((event) {
              if (event is MenuOpenedEvent) {
                _applyWindowsMenuDarkMode();
              }
            }) ??
            -1,
      )
      ..add(
        trayIcon.getContextMenu()?.addListener((event) {
              if (event is MenuItemClickedEvent) {
                render?.active();
              }
            }) ??
            -1,
      )
      ..add(
        trayIcon.addListener((event) {
          if (event is TrayIconClickedEvent) {
            trayIcon.closeContextMenu();
            if (!Platform.isLinux) {
              window?.show();
            }
          }
        }),
      );

    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.updateTray();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    for (final id in _listenerIds) {
      if (id >= 0) {
        trayIcon.getContextMenu()?.removeListener(id);
        trayIcon.removeListener(id);
      }
    }
    trayIcon.dispose();
    super.dispose();
  }
}
