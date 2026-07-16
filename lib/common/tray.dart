import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mihox/common/utils.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';
import 'package:nativeapi/nativeapi.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'window.dart';

final trayIcon = TrayIcon();

class Tray {
  Future _updateSystemTray({
    required Brightness? brightness,
    required bool isRunning,
    bool force = false,
  }) async {
    if (Platform.isAndroid) return;

    trayIcon.icon = Image.fromAsset(
      utils.getTrayIconPath(
        brightness: brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        isRunning: isRunning,
      ),
    );
    trayIcon.isVisible = true;

    if (!Platform.isLinux) {
      trayIcon.tooltip = appName;
    }
  }

  void _addItem(
    Menu menu,
    String label,
    FutureOr<void> Function() onClick,
  ) {
    final item = MenuItem(label)..on<MenuItemClickedEvent>((_) => onClick());
    menu.addItem(item);
  }

  void _addCheckboxItem(
    Menu menu,
    String label,
    FutureOr<void> Function() onClick, {
    required bool checked,
  }) {
    final item = MenuItem(label, MenuItemType.checkbox)
      ..state = checked ? MenuItemState.checked : MenuItemState.unchecked
      ..on<MenuItemClickedEvent>((_) => onClick());
    menu.addItem(item);
  }

  Future<void> update({
    required TrayState trayState,
    bool focus = false,
  }) async {
    if (Platform.isAndroid) {
      // Skip tray on Android
      return;
    }
    if (!Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        isRunning: trayState.isStart,
        force: focus,
      );
    }

    final menu = Menu();

    _addItem(menu, appLocalizations.show, () {
      window?.show();
    });

    _addCheckboxItem(
      menu,
      trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      () {
        globalState.appController.updateStart();
      },
      checked: false,
    );

    if (trayState.globalModeEnabled) {
      menu.addSeparator();
      for (final mode in Mode.values) {
        _addCheckboxItem(
          menu,
          Intl.message(mode.name),
          () {
            globalState.appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        );
      }
    }

    menu.addSeparator();

    if (trayState.isStart) {
      _addCheckboxItem(
        menu,
        appLocalizations.tun,
        () {
          globalState.appController.updateTun();
        },
        checked: trayState.tunEnable,
      );
      _addCheckboxItem(
        menu,
        appLocalizations.systemProxy,
        () {
          globalState.appController.updateSystemProxy();
        },
        checked: trayState.systemProxy,
      );
      menu.addSeparator();
    }

    _addCheckboxItem(
      menu,
      appLocalizations.autoLaunch,
      () {
        globalState.appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );

    _addItem(menu, appLocalizations.copyEnvVar, () async {
      await _copyEnv(trayState.port);
    });

    menu.addSeparator();

    _addItem(menu, appLocalizations.restart, () async {
      await globalState.appController.handleRestart();
    });

    _addItem(menu, appLocalizations.exit, () async {
      await globalState.appController.handleExit();
    });

    trayIcon.contextMenu = menu;
    trayIcon.contextMenuTrigger = ContextMenuTrigger.rightClicked;

    if (Platform.isLinux) {
      unawaited(_updateSystemTray(
        brightness: trayState.brightness,
        isRunning: trayState.isStart,
        force: focus,
      ));
    }
  }

  Future<void> updateTrayTitle([Traffic? traffic]) async {
    //return;
  }

  Future<void> _copyEnv(int port) async {
    final url = "http://127.0.0.1:$port";

    final cmdline = Platform.isWindows
        ? "set \$env:all_proxy=$url"
        : "export all_proxy=$url";

    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final tray = Tray();
