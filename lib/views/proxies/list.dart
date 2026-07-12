import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/app.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/providers/state.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

import 'card.dart';
import 'common.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _GroupBuildData {
  const _GroupBuildData(this.groups, this.proxiesLists, this.map);

  final List<Group> groups;
  final List<List<Proxy>> proxiesLists;
  final GroupNameProxiesMap map;
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState>(
    const ProxiesListHeaderSelectorState(offset: 0, currentIndex: 0),
  );
  final List<double> _headerOffset = [];

  int _lastGroupsVersion = 0;
  List<String> _lastGroupNames = [];

  final Map<String, _SortCacheEntry> _sortCache = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller
      ..removeListener(_adjustHeader)
      ..dispose();
    super.dispose();
  }

  void _adjustHeader() {
    final offset = _controller.offset;
    final index = _headerOffset.findInterval(offset);

    var headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (offset > startOffset && offset < endOffset) {
        headerOffset = offset - startOffset;
      }
    }
    headerOffset = max(headerOffset, 0);

    final current = _headerStateNotifier.value;
    if (current.currentIndex == index && current.offset == headerOffset) return;

    _headerStateNotifier.value = current.copyWith(
      currentIndex: index,
      offset: headerOffset,
    );
  }

  _GroupBuildData _resolveGroups(
    WidgetRef ref, {
    required List<String> groupNames,
    required String query,
  }) {
    final groups = <Group>[];
    final proxiesLists = <List<Proxy>>[];
    final groupNameProxiesMap = <String, List<Proxy>>{};

    for (final groupName in groupNames) {
      final group = ref.watch(
        groupsProvider.select((state) => state.getGroup(groupName)),
      );
      if (group == null) continue;

      final cached = _sortCache[groupName];
      final List<Proxy> sortedProxies;
      if (cached != null &&
          identical(cached.group, group) &&
          cached.query == query) {
        sortedProxies = cached.sorted;
      } else {
        sortedProxies = globalState.appController.getSortProxies(
          group.all
              .where((item) => item.name.toLowerCase().contains(query))
              .toList(),
          group.testUrl,
        );
        _sortCache[groupName] = _SortCacheEntry(group, query, sortedProxies);
      }

      groups.add(group);
      proxiesLists.add(sortedProxies);
      groupNameProxiesMap[groupName] = sortedProxies;
    }

    if (_sortCache.length != groupNames.length) {
      _sortCache.removeWhere((key, _) => !groupNames.contains(key));
    }

    return _GroupBuildData(groups, proxiesLists, groupNameProxiesMap);
  }

  Widget _buildGroupItem(
    int index,
    _GroupBuildData data, {
    required int columns,
    required ProxyCardType type,
  }) {
    final group = data.groups[index];
    final sortedProxies = data.proxiesLists[index];
    final groupName = group.name;

    final rows = sortedProxies
        .chunks(columns)
        .map<Widget>((proxies) => Row(
              children: proxies
                  .map<Widget>(
                    (proxy) => Flexible(
                      child: RepaintBoundary(
                        child: ProxyCard(
                          testUrl: group.testUrl,
                          type: type,
                          groupType: group.type,
                          key: ValueKey('$groupName.${proxy.name}'),
                          proxy: proxy,
                          groupName: groupName,
                        ),
                      ),
                    ),
                  )
                  .fill(
                    columns,
                    filler: (_) => const Flexible(child: SizedBox()),
                  )
                  .separated(const SizedBox(width: 8))
                  .toList(),
            ))
        .separated(SizedBox(height: type == ProxyCardType.oneline ? 4 : 8))
        .toList();

    return ProxyGroupCard(
      key: ValueKey(groupName),
      group: group,
      proxies: rows,
    );
  }

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(proxiesListSelectorStateProvider);
          final groupsVersion = ref.watch(versionProvider);

          ref.watch(themeSettingProvider.select((s) => s.textScale));

          final groupsChanged = _lastGroupsVersion != groupsVersion ||
              !listEquals(_lastGroupNames, state.groupNames);

          if (groupsChanged) {
            _lastGroupsVersion = groupsVersion;
            _lastGroupNames = state.groupNames;
          }

          if (state.groupNames.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.proxies),
            );
          }

          final data = _resolveGroups(
            ref,
            groupNames: state.groupNames,
            query: state.query,
          );

          return RepaintBoundary(
            child: CommonScrollBar(
              controller: _controller,
              child: ScrollConfiguration(
                behavior: HiddenBarScrollBehavior(),
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    controller: _controller,
                    itemCount: data.groups.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
                    itemBuilder: (_, index) => _buildGroupItem(
                      index,
                      data,
                      columns: state.columns,
                      type: state.proxyCardType,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _SortCacheEntry {
  const _SortCacheEntry(this.group, this.query, this.sorted);

  final Group group;
  final String query;
  final List<Proxy> sorted;
}

class ProxyGroupCard extends StatefulWidget {
  const ProxyGroupCard({
    super.key,
    required this.group,
    required this.proxies,
  });

  final Group group;
  final List<Widget> proxies;

  @override
  State<ProxyGroupCard> createState() => _ProxyGroupCardState();
}

class _ProxyGroupCardState extends State<ProxyGroupCard> {
  final _expansibleController = ExpansibleController();

  final _isLocked = ValueNotifier<bool>(false);

  bool? _syncedExpand;

  Map<String, String>? _iconMapCacheSource;
  List<MapEntry<RegExp?, String>> _iconMapCacheCompiled = const [];

  String get _icon => widget.group.icon;
  String get _groupName => widget.group.name;

  @override
  void dispose() {
    _expansibleController.dispose();
    _isLocked.dispose();
    super.dispose();
  }

  void _toggleExpansion(WidgetRef ref) {
    final currentUnfoldSet = ref.read(unfoldSetProvider);
    final unfoldSet = Set<String>.from(currentUnfoldSet);
    if (_expansibleController.isExpanded) {
      _expansibleController.collapse();
      unfoldSet.remove(_groupName);
    } else {
      _expansibleController.expand();
      unfoldSet.add(_groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(unfoldSet);
  }

  Future<void> _delayTest() async {
    if (_isLocked.value) return;
    _isLocked.value = true;
    try {
      await delayTest(widget.group.all, widget.group.testUrl);
    } finally {
      _isLocked.value = false;
    }
  }

  List<MapEntry<RegExp?, String>> _compiledMatchers(
      Map<String, String> iconMap) {
    if (identical(iconMap, _iconMapCacheSource)) {
      return _iconMapCacheCompiled;
    }
    final compiled = iconMap.entries.map((e) {
      RegExp? regex;
      try {
        regex = RegExp(e.key);
      } catch (_) {
        regex = null;
      }
      return MapEntry(regex, e.value);
    }).toList();
    _iconMapCacheSource = iconMap;
    _iconMapCacheCompiled = compiled;
    return compiled;
  }

  Widget _buildIcon() => Consumer(
        builder: (_, ref, __) {
          final iconStyle = ref.watch(
            proxiesStyleSettingProvider.select((s) => s.iconStyle),
          );

          if (iconStyle == ProxiesIconStyle.none) {
            return const SizedBox.shrink();
          }

          final resolvedIcon = ref.watch(
            proxiesStyleSettingProvider.select((s) {
              final matchers = _compiledMatchers(s.iconMap);
              for (final entry in matchers) {
                if (entry.key?.hasMatch(_groupName) ?? false) {
                  return entry.value;
                }
              }
              return _icon;
            }),
          );

          return Container(
            margin: const EdgeInsets.only(right: 16),
            child: CommonTargetIcon(src: resolvedIcon, size: 38),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Consumer(
      builder: (_, ref, __) {
        final shouldExpand = ref.watch(
          unfoldSetProvider.select((s) => s.contains(_groupName)),
        );

        if (_syncedExpand != shouldExpand) {
          _syncedExpand = shouldExpand;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (shouldExpand && !_expansibleController.isExpanded) {
              _expansibleController.expand();
            } else if (!shouldExpand && _expansibleController.isExpanded) {
              _expansibleController.collapse();
            }
          });
        }

        return RepaintBoundary(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Expansible(
              controller: _expansibleController,
              headerBuilder: (context, animation) {
                final isExpanded = animation.value > 0;
                return GestureDetector(
                  onTap: () => _toggleExpansion(ref),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow.opacity80,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              _buildIcon(),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _groupName,
                                      style: context.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Consumer(
                                      builder: (_, ref, __) {
                                        final proxyName = ref
                                            .watch(getSelectedProxyNameProvider(
                                                _groupName))
                                            .getSafeValue('');
                                        if (proxyName.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return EmojiText(
                                          proxyName,
                                          overflow: TextOverflow.ellipsis,
                                          style: context
                                              .textTheme.labelMedium?.toLight,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (isExpanded) ...[
                              ValueListenableBuilder(
                                valueListenable: _isLocked,
                                builder: (_, locked, __) => IconButton(
                                  onPressed: locked ? null : _delayTest,
                                  visualDensity: VisualDensity.standard,
                                  icon: const Icon(Icons.network_ping),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else
                              const SizedBox(width: 4),
                            IconButton.filledTonal(
                              onPressed: () => _toggleExpansion(ref),
                              icon: CommonExpandIcon(expand: isExpanded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              bodyBuilder: (context, animation) => RepaintBoundary(
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: animation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(children: widget.proxies),
                    ),
                  ),
                ),
              ),
              expansibleBuilder: (_, header, body, __) =>
                  Column(children: [header, body]),
            ),
          ),
        );
      },
    );
  }
}