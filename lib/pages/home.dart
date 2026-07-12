import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (_, ref, child) {
            final viewMode = ref.watch(
              homeStateProvider.select((s) => s.viewMode),
            );
            final navigationItems = ref.watch(
              homeStateProvider.select((s) => s.navigationItems),
            );
            final pageLabel = ref.watch(
              homeStateProvider.select((s) => s.pageLabel),
            );

            final rawIndex =
                navigationItems.indexWhere((e) => e.label == pageLabel);
            assert(
              rawIndex != -1,
              'pageLabel "$pageLabel" not found in navigationItems',
            );
            final currentIndex = rawIndex == -1 ? 0 : rawIndex;

            final navigationBar = CommonNavigationBar(
              viewMode: viewMode,
              navigationItems: navigationItems,
              currentIndex: currentIndex,
            );

            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              title: Intl.message(pageLabel.name),
              sideNavigationBar:
                  viewMode != ViewMode.mobile ? navigationBar : null,
              body: child!,
              bottomNavigationBar:
                  viewMode == ViewMode.mobile ? navigationBar : null,
            );
          },
          child: const _HomePageView(),
        ),
      );
}

class _HomePageView extends ConsumerStatefulWidget {
  const _HomePageView();

  @override
  ConsumerState<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentPageIndex,
      keepPage: true,
    );

    ref
      ..listenManual(currentPageLabelProvider, (prev, next) {
        if (prev != next) _animateToLabel(next);
      })
      ..listenManual(currentNavigationsStateProvider, (prev, next) {
        if (prev?.value.length != next.value.length) {
          _jumpToCurrentLabel();
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _currentPageIndex {
    final items = ref.read(currentNavigationsStateProvider).value;
    final label = globalState.appState.pageLabel;
    final index = items.indexWhere((item) => item.label == label);
    assert(index != -1, 'pageLabel "$label" not found in navigationItems');
    return index == -1 ? 0 : index;
  }

  int _indexOfLabel(PageLabel label) {
    final items = ref.read(currentNavigationsStateProvider).value;
    return items.indexWhere((item) => item.label == label);
  }

  Future<void> _animateToLabel(PageLabel label) async {
    if (!mounted) return;
    final index = _indexOfLabel(label);
    if (index == -1) return;

    final animate = ref.read(appSettingProvider).isAnimateToPage &&
        ref.read(isMobileViewProvider);

    if (animate) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _jumpToCurrentLabel() {
    final label = globalState.appState.pageLabel;
    final index = _indexOfLabel(label);
    if (index != -1) _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final navigationItems = ref.watch(currentNavigationsStateProvider).value;
    final currentLabel = ref.watch(currentPageLabelProvider);

    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: navigationItems.length,
      itemBuilder: (_, index) {
        final item = navigationItems[index];
        return ExcludeFocus(
          excluding: item.label != currentLabel,
          child: KeepScope(
            keep: item.keep,
            key: Key(item.label.name),
            child: item.view,
          ),
        );
      },
    );
  }
}

class CommonNavigationBar extends ConsumerWidget {
  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  void _onDestinationSelected(int index) {
    globalState.appController.page = navigationItems[index].label;
  }

  List<Widget> _destinations(BuildContext context) => navigationItems
      .map((e) => NavigationDestination(
            icon: e.icon,
            label: Intl.message(e.label.name),
          ))
      .toList();

  List<NavigationRailDestination> _railDestinations() => navigationItems
      .map((e) => NavigationRailDestination(
            icon: e.icon,
            label: Text(Intl.message(e.label.name)),
          ))
      .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewMode == ViewMode.mobile) {
      return NavigationBarTheme(
        data: _NavigationBarDefaultsM3(context),
        child: NavigationBar(
          destinations: _destinations(context),
          onDestinationSelected: _onDestinationSelected,
          selectedIndex: currentIndex,
        ),
      );
    }

    final showLabel = ref.watch(
      appSettingProvider.select((s) => s.showLabel),
    );
    final colorScheme = context.colorScheme;
    final labelStyle =
        context.textTheme.labelLarge!.copyWith(color: colorScheme.onSurface);

    return Material(
      color: colorScheme.surfaceContainer,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: colorScheme.surfaceContainer,
                    selectedIconTheme: IconThemeData(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    selectedLabelTextStyle: labelStyle,
                    unselectedLabelTextStyle: labelStyle,
                    destinations: _railDestinations(),
                    onDestinationSelected: _onDestinationSelected,
                    extended: false,
                    selectedIndex: currentIndex,
                    labelType: showLabel
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          IconButton(
            onPressed: () {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(showLabel: !state.showLabel),
                  );
            },
            icon: const Icon(Icons.menu),
            tooltip: 'Toggle labels',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(BuildContext context)
      : _colors = Theme.of(context).colorScheme,
        _textTheme = Theme.of(context).textTheme,
        super(
          height: 80.0,
          elevation: 3.0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        );

  final ColorScheme _colors;
  final TextTheme _textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme =>
      WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24.0,
            color: states.contains(WidgetState.disabled)
                ? _colors.onSurfaceVariant.opacity38
                : states.contains(WidgetState.selected)
                    ? _colors.onSecondaryContainer
                    : _colors.onSurfaceVariant,
          ));

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle =>
      WidgetStateProperty.resolveWith((states) => _textTheme.labelMedium!.apply(
            overflow: TextOverflow.ellipsis,
            color: states.contains(WidgetState.disabled)
                ? _colors.onSurfaceVariant.opacity38
                : states.contains(WidgetState.selected)
                    ? _colors.onSurface
                    : _colors.onSurfaceVariant,
          ));
}

class HomeBackScope extends StatelessWidget {
  const HomeBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return child;

    return CommonPopScope(
      onPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          await globalState.appController.handleBackOrExit();
        }
        return false;
      },
      child: child,
    );
  }
}
