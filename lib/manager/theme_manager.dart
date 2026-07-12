import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/constant.dart';
import 'package:mihox/common/measure.dart';
import 'package:mihox/common/theme.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/state.dart';

class ThemeManager extends ConsumerWidget {
  const ThemeManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.read(
      themeSettingProvider.select((state) => state.textScale),
    );
    final double textScaleFactor = max(
      min(
        textScale.enable ? textScale.scale : defaultTextScaleFactor,
        maxTextScale,
      ),
      minTextScale,
    );

    globalState.measure = Measure.of(context, textScaleFactor);
    globalState.theme = CommonTheme.of(context, textScaleFactor);
    final padding = MediaQuery.of(context).padding;
    final height = MediaQuery.of(context).size.height;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          textScaleFactor,
        ),
        padding: padding.copyWith(
          top: padding.top > height * 0.3 ? 20.0 : padding.top,
        ),
      ),
      child: LayoutBuilder(
        builder: (_, container) {
          globalState.appController.updateViewSize(
            Size(
              container.maxWidth,
              container.maxHeight,
            ),
          );
          return child;
        },
      ),
    );
  }
}
