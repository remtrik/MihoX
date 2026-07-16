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
  const TrayManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<TrayManager> createState() => _TrayContainerState();
}

class _TrayContainerState extends ConsumerState<TrayManager> {
  final List<int> _listenerIds = [];

  void _applyWindowsMenuDarkMode() {
    if (!Platform.isWindows) return;

    try {
      final className = '#32768'.toNativeUtf16();
      final hwnd = FindWindow(className, nullptr);
      calloc.free(className);

      if (hwnd != 0) {
        windows?.applyDarkModeToMenu(hwnd);
      }
    } catch (e) {}
  }

  @override
  void initState() {
    super.initState();

    trayIcon.contextMenuTrigger = ContextMenuTrigger.rightClicked;

    _listenerIds
      ..add(
        trayIcon.contextMenu?.on<MenuOpenedEvent>((event) {
              _applyWindowsMenuDarkMode();
            }) ??
            -1,
      )
      ..add(
        trayIcon.contextMenu?.on<MenuItemClickedEvent>((event) {
              render?.active();
            }) ??
            -1,
      )
      ..add(
        trayIcon.on<TrayIconClickedEvent>((event) {
          trayIcon.closeContextMenu();
          if (!Platform.isLinux) {
            window?.show();
          }
        }),
      );

    ref.listenManual(
      trayStateProvider,
      (prev, next) {
        if (prev != next) {
          globalState.appController.updateTray();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    for (final id in _listenerIds) {
      if (id >= 0) {
        trayIcon.contextMenu?.removeListener(id);
        trayIcon.removeListener(id);
      }
    }
    trayIcon.dispose();
    super.dispose();
  }
}
