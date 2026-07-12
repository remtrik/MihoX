import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  Future<void> init(int version) async {
    final props = globalState.config.windowProps;
    
    if (!await singleInstanceLock.acquire()) {
      exit(0);
    }

    if (Platform.isWindows) {
      protocol
        ..register("mihox")
        ..register("miho");
    }

    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

    final left = props.left ?? 0;
    final top = props.top ?? 0;
    if (left == 0 && top == 0) {
      await windowManager.setAlignment(Alignment.center);
    } else if (await _isPositionValid(left, top, props.width, props.height)) {
      await windowManager.setPosition(Offset(left, top));
    }

    final windowOptions = WindowOptions(
      size: Size(props.width, props.height),
      minimumSize: const Size(380, 400),
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
  }

  Future<bool> _isPositionValid(
    double left,
    double top,
    double width,
    double height,
  ) async {
    final right = left + width;
    final bottom = top + height;
    final displays = await screenRetriever.getAllDisplays();
    return displays.any((display) {
      final bounds = Rect.fromLTWH(
        display.visiblePosition!.dx,
        display.visiblePosition!.dy,
        display.size.width,
        display.size.height,
      );
      return bounds.contains(Offset(left, top)) ||
          bounds.contains(Offset(right, bottom));
    });
  }

  Future<void> show() async {
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible async {
    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  Future<void> close() async {
    exit(0);
  }

  Future<void> hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;
