// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/selector.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

class ThemeModeItem {
  const ThemeModeItem({
    required this.themeMode,
    required this.iconData,
    required this.label,
  });
  final ThemeMode themeMode;
  final IconData iconData;
  final String label;
}

class FontFamilyItem {
  const FontFamilyItem({
    required this.fontFamily,
    required this.label,
  });
  final FontFamily fontFamily;
  final String label;
}

class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
        child: Column(
          spacing: 24,
          children: [
            _ThemeModeItem(),
            _PrimaryColorItem(),
            _PureBlackItem(),
            _TextScaleFactorItem(),
            SizedBox(height: 64),
          ],
        ),
      );
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.info,
    required this.child,
    this.actions = const [],
  });
  final Widget child;
  final Info info;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
        runSpacing: 16,
        children: [
          InfoHeader(info: info, actions: actions),
          child,
        ],
      );
}

List<ThemeModeItem> _buildThemeModeItems() => [
      ThemeModeItem(
        iconData: Icons.auto_mode,
        label: appLocalizations.auto,
        themeMode: ThemeMode.system,
      ),
      ThemeModeItem(
        iconData: Icons.light_mode,
        label: appLocalizations.light,
        themeMode: ThemeMode.light,
      ),
      ThemeModeItem(
        iconData: Icons.dark_mode,
        label: appLocalizations.dark,
        themeMode: ThemeMode.dark,
      ),
    ];

class _ThemeModeItem extends ConsumerWidget {
  const _ThemeModeItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeSettingProvider.select((s) => s.themeMode));
    final themeModeItems = _buildThemeModeItems();

    return ItemCard(
      info: Info(
        label: appLocalizations.themeMode,
        iconData: Icons.brightness_high,
      ),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themeModeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final item = themeModeItems[index];
              return CommonCard(
                isSelected: item.themeMode == themeMode,
                onPressed: () {
                  ref.read(themeSettingProvider.notifier).updateState(
                        (s) => s.copyWith(themeMode: item.themeMode),
                      );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Icon(item.iconData, size: 18)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrimaryColorItem extends ConsumerStatefulWidget {
  const _PrimaryColorItem();

  @override
  ConsumerState<_PrimaryColorItem> createState() => _PrimaryColorItemState();
}

class _PrimaryColorItemState extends ConsumerState<_PrimaryColorItem> {
  int? _removablePrimaryColor;

  int _calcColumns(double maxWidth) => math.max((maxWidth / 96).ceil(), 3);

  Future<void> _handleReset() async {
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.resetTip),
    );
    if (res != true) return;
    ref.read(themeSettingProvider.notifier).updateState(
          (s) => s.copyWith(
            primaryColors: defaultPrimaryColors,
            primaryColor: defaultPrimaryColor,
            schemeVariant: DynamicSchemeVariant.tonalSpot,
          ),
        );
  }

  Future<void> _handleDel() async {
    if (_removablePrimaryColor == null) return;
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.colorSchemes),
      ),
    );
    if (res != true) return;
    ref.read(themeSettingProvider.notifier).updateState((s) {
      final newColors = List<int>.from(s.primaryColors)
        ..remove(_removablePrimaryColor);
      final newColor = s.primaryColor == _removablePrimaryColor
          ? (newColors.contains(defaultPrimaryColor)
              ? defaultPrimaryColor
              : null)
          : s.primaryColor;
      return s.copyWith(primaryColors: newColors, primaryColor: newColor);
    });
    if (mounted) setState(() => _removablePrimaryColor = null);
  }

  Future<void> _handleAdd() async {
    final res = await globalState.showCommonDialog<int>(
      child: const _PaletteDialog(),
    );
    if (res == null) return;
    final isExists = ref.read(
      themeSettingProvider.select((s) => s.primaryColors.contains(res)),
    );
    if (isExists) {
      if (mounted) {
        await context.showNotifier(
          appLocalizations.existsTip(appLocalizations.colorSchemes),
        );
      }
      return;
    }
    ref.read(themeSettingProvider.notifier).updateState(
          (s) => s.copyWith(
            primaryColors: List<int>.from(s.primaryColors)..add(res),
          ),
        );
  }

  Future<void> _handleChangeSchemeVariant() async {
    final schemeVariant = ref.read(
      themeSettingProvider.select((s) => s.schemeVariant),
    );
    final value = await globalState.showCommonDialog<DynamicSchemeVariant>(
      child: OptionsDialog<DynamicSchemeVariant>(
        title: appLocalizations.colorSchemes,
        options: DynamicSchemeVariant.values,
        textBuilder: (item) => Intl.message('${item.name}Scheme'),
        value: schemeVariant,
      ),
    );
    if (value == null) return;
    ref.read(themeSettingProvider.notifier).updateState(
          (s) => s.copyWith(schemeVariant: value),
        );
  }

  @override
  Widget build(BuildContext context) {
    final vm4 = ref.watch(
      themeSettingProvider.select(
        (s) => VM4(
          a: s.primaryColor,
          b: s.primaryColors,
          c: s.schemeVariant,
          d: s.primaryColor == defaultPrimaryColor &&
              intListEquality.equals(s.primaryColors, defaultPrimaryColors),
        ),
      ),
    );
    final primaryColor = vm4.a;
    final primaryColors = [null, ...vm4.b];
    final schemeVariant = vm4.c;
    final isDefault = vm4.d;

    return CommonPopScope(
      onPop: () {
        if (_removablePrimaryColor != null) {
          setState(() => _removablePrimaryColor = null);
          return false;
        }
        return true;
      },
      child: ItemCard(
        info: Info(
          label: appLocalizations.themeColor,
          iconData: Icons.palette,
        ),
        actions: genActions(
          [
            if (_removablePrimaryColor == null)
              FilledButton(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onPressed: _handleChangeSchemeVariant,
                child: Text(Intl.message('${schemeVariant.name}Scheme')),
              )
            else
              FilledButton(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _removablePrimaryColor = null),
                child: Text(appLocalizations.cancel),
              ),
            if (_removablePrimaryColor == null && !isDefault)
              IconButton.filledTonal(
                iconSize: 20,
                padding: const EdgeInsets.all(4),
                visualDensity: VisualDensity.compact,
                onPressed: _handleReset,
                icon: const Icon(Icons.replay),
              ),
          ],
          space: 8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (_, constraints) {
              final columns = _calcColumns(constraints.maxWidth);
              final itemSize =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final color in primaryColors)
                    SizedBox(
                      width: itemSize,
                      height: itemSize,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          EffectGestureDetector(
                            onLongPress: () =>
                                setState(() => _removablePrimaryColor = color),
                            child: ColorSchemeBox(
                              isSelected: color == primaryColor,
                              primaryColor: color != null ? Color(color) : null,
                              onPressed: () {
                                setState(() => _removablePrimaryColor = null);
                                ref
                                    .read(themeSettingProvider.notifier)
                                    .updateState(
                                      (s) => s.copyWith(primaryColor: color),
                                    );
                              },
                            ),
                          ),
                          if (_removablePrimaryColor != null &&
                              _removablePrimaryColor == color)
                            Positioned.fill(
                              child: IconButton.filledTonal(
                                onPressed: _handleDel,
                                padding: const EdgeInsets.all(12),
                                iconSize: 30,
                                icon: Icon(
                                  Icons.delete,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_removablePrimaryColor == null)
                    SizedBox(
                      width: itemSize,
                      height: itemSize,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: IconButton.filledTonal(
                          onPressed: _handleAdd,
                          iconSize: 32,
                          icon: Icon(
                            Icons.add,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PureBlackItem extends ConsumerWidget {
  const _PureBlackItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pureBlack = ref.watch(
      themeSettingProvider.select((s) => s.pureBlack),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.contrast),
      horizontalTitleGap: 12,
      title: Text(
        appLocalizations.pureBlackMode,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
      delegate: SwitchDelegate(
        value: pureBlack,
        onChanged: (value) {
          ref.read(themeSettingProvider.notifier).updateState(
                (s) => s.copyWith(pureBlack: value),
              );
        },
      ),
    );
  }
}

class _TextScaleFactorItem extends ConsumerWidget {
  const _TextScaleFactorItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select((s) => s.textScale),
    );
    final label = '${(textScale.scale * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListItem.switchItem(
            leading: const Icon(Icons.text_fields),
            horizontalTitleGap: 12,
            title: Text(
              appLocalizations.textScale,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
            delegate: SwitchDelegate(
              value: textScale.enable,
              onChanged: (value) {
                ref.read(themeSettingProvider.notifier).updateState(
                      (s) => s.copyWith.textScale(enable: value),
                    );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 32,
            children: [
              Expanded(
                child: DisabledMask(
                  status: !textScale.enable,
                  child: ActivateBox(
                    active: textScale.enable,
                    child: SliderTheme(
                      data: _SliderDefaultsM3(context),
                      child: Slider(
                        padding: EdgeInsets.zero,
                        min: minTextScale,
                        max: maxTextScale,
                        value: textScale.scale,
                        onChanged: (value) {
                          ref.read(themeSettingProvider.notifier).updateState(
                                (s) => s.copyWith.textScale(scale: value),
                              );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(label, style: context.textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog();

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = ValueNotifier<ui.Color>(Colors.transparent);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.palette,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.value.toARGB32()),
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              width: 250,
              height: 250,
              child: Palette(controller: _controller),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, color, __) => PrimaryColorBox(
                primaryColor: color,
                child: FilledButton(
                  onPressed: () {},
                  child: Text(_controller.value.hex),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SliderDefaultsM3 extends SliderThemeData {
  _SliderDefaultsM3(BuildContext context)
      : _colors = Theme.of(context).colorScheme,
        _textTheme = Theme.of(context).textTheme,
        super(trackHeight: 16.0);

  final ColorScheme _colors;
  final TextTheme _textTheme;

  @override
  Color? get activeTrackColor => _colors.primary;

  @override
  Color? get inactiveTrackColor => _colors.secondaryContainer;

  @override
  Color? get secondaryActiveTrackColor =>
      _colors.primary.withValues(alpha: 0.54);

  @override
  Color? get disabledActiveTrackColor =>
      _colors.onSurface.withValues(alpha: 0.38);

  @override
  Color? get disabledInactiveTrackColor =>
      _colors.onSurface.withValues(alpha: 0.12);

  @override
  Color? get disabledSecondaryActiveTrackColor =>
      _colors.onSurface.withValues(alpha: 0.38);

  @override
  Color? get activeTickMarkColor => _colors.onPrimary;

  @override
  Color? get inactiveTickMarkColor => _colors.onSecondaryContainer;

  @override
  Color? get disabledActiveTickMarkColor => _colors.onInverseSurface;

  @override
  Color? get disabledInactiveTickMarkColor => _colors.onSurface;

  @override
  Color? get thumbColor => _colors.primary;

  @override
  Color? get disabledThumbColor => _colors.onSurface.withValues(alpha: 0.38);

  @override
  Color? get overlayColor => WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return _colors.primary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withValues(alpha: 0.1);
        }
        return Colors.transparent;
      });

  @override
  TextStyle? get valueIndicatorTextStyle =>
      _textTheme.labelLarge!.copyWith(color: _colors.onInverseSurface);

  @override
  Color? get valueIndicatorColor => _colors.inverseSurface;

  @override
  SliderComponentShape? get valueIndicatorShape =>
      const RoundedRectSliderValueIndicatorShape();

  @override
  SliderComponentShape? get thumbShape => const HandleThumbShape();

  @override
  SliderTrackShape? get trackShape => const GappedSliderTrackShape();

  @override
  SliderComponentShape? get overlayShape => const RoundSliderOverlayShape();

  @override
  SliderTickMarkShape? get tickMarkShape =>
      const RoundSliderTickMarkShape(tickMarkRadius: 4.0 / 2);

  @override
  WidgetStateProperty<Size?>? get thumbSize =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return const Size(2.0, 44.0);
        }
        return const Size(4.0, 44.0);
      });

  @override
  double? get trackGap => 6.0;
}
