import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/state.dart';
import 'package:mihox/views/proxies/common.dart';
import 'package:mihox/widgets/widgets.dart';

class ProxyCard extends StatelessWidget {
  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });

  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  void _handleTestCurrentDelay() => proxyDelayTest(proxy, testUrl);

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;

    if (!isComputedSelected && !isSelector) {
      globalState.showNotifier(appLocalizations.notSelectedTip);
      return;
    }

    final currentProxyName = ref.read(getProxyNameProvider(groupName));
    final nextProxyName = isComputedSelected && currentProxyName == proxy.name ? '' : proxy.name;

    globalState.appController
      ..updateCurrentSelectedMap(groupName, nextProxyName)
      ..changeProxyDebounce(groupName, nextProxyName);
  }

  @override
  Widget build(BuildContext context) {
    final measure = globalState.measure;

    final delayWidget = _DelayWidget(
      proxy: proxy,
      testUrl: testUrl,
      onTest: _handleTestCurrentDelay,
    );

    return Stack(
      children: [
        Consumer(
          builder: (_, ref, child) {
            final selectedProxyName = ref.watch(getSelectedProxyNameProvider(groupName));
            return CommonCard(
              key: key,
              onPressed: () => _changeProxy(ref),
              isSelected: selectedProxyName == proxy.name,
              child: child!,
            );
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProxyNameRow(
                  proxy: proxy,
                  groupName: groupName,
                  groupType: groupType,
                  type: type,
                  delayWidget: delayWidget,
                  measure: measure,
                ),
                if (type != ProxyCardType.oneline) ...[
                  const SizedBox(height: 8),
                  if (type == ProxyCardType.expand) ...[
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: _ProxyDesc(proxy: proxy),
                    ),
                    const SizedBox(height: 6),
                    delayWidget,
                  ] else
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: _ProxyDesc(proxy: proxy)),
                          delayWidget,
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (groupType.isComputedSelected)
          Positioned(
            top: 0,
            right: 0,
            child: _ProxyComputedMark(
              groupName: groupName,
              proxy: proxy,
              cardType: type,
            ),
          ),
      ],
    );
  }
}

class _ProxyNameRow extends ConsumerWidget {
  const _ProxyNameRow({
    required this.proxy,
    required this.groupName,
    required this.groupType,
    required this.type,
    required this.delayWidget,
    required this.measure,
  });

  final Proxy proxy;
  final String groupName;
  final GroupType groupType;
  final ProxyCardType type;
  final Widget delayWidget;
  final Measure measure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = type == ProxyCardType.oneline &&
        groupType.isComputedSelected &&
        ref.watch(getProxyNameProvider(groupName)) == proxy.name;

    final maxLines = type == ProxyCardType.expand ? 2 : 1;

    final nameText = SizedBox(
      height: measure.bodyMediumHeight * maxLines,
      child: type == ProxyCardType.oneline
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: EmojiText(
                    proxy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                delayWidget,
              ],
            )
          : EmojiText(
              proxy.name,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium,
            ),
    );

    return Padding(
      padding: isSelected ? const EdgeInsets.only(right: 32) : EdgeInsets.zero,
      child: nameText,
    );
  }
}

class _DelayWidget extends StatelessWidget {
  const _DelayWidget({
    required this.proxy,
    required this.testUrl,
    required this.onTest,
  });

  final Proxy proxy;
  final String? testUrl;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final labelHeight = globalState.measure.labelMediumHeight;

    return SizedBox(
      height: labelHeight,
      child: Consumer(
        builder: (context, ref, _) {
          final delay = ref.watch(getDelayProvider(
            proxyName: proxy.name,
            testUrl: testUrl,
          ));

          if (delay == 0) {
            return SizedBox.square(
              dimension: labelHeight,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (delay == null) {
            return SizedBox.square(
              dimension: labelHeight,
              child: IconButton(
                icon: const Icon(Icons.bolt),
                iconSize: labelHeight,
                padding: EdgeInsets.zero,
                onPressed: onTest,
              ),
            );
          }

          return GestureDetector(
            onTap: onTest,
            child: Text(
              delay > 0 ? '$delay ms' : 'Timeout',
              style: context.textTheme.labelMedium?.copyWith(
                overflow: TextOverflow.ellipsis,
                color: utils.getDelayColor(delay),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProxyDesc extends ConsumerWidget {
  const _ProxyDesc({required this.proxy});

  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(getProxyDescProvider(proxy));
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textTheme.bodySmall?.color?.opacity80,
      ),
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {
  const _ProxyComputedMark({
    required this.groupName,
    required this.proxy,
    required this.cardType,
  });

  final String groupName;
  final Proxy proxy;
  final ProxyCardType cardType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(getProxyNameProvider(groupName));
    if (proxyName != proxy.name) return const SizedBox.shrink();

    final margin = cardType == ProxyCardType.oneline
        ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
        : const EdgeInsets.all(8);

    return Container(
      alignment: Alignment.topRight,
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: const SelectIcon(),
    );
  }
}
