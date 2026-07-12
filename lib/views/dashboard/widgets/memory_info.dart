import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/models/common.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

final _memoryInfoStateNotifier = ValueNotifier<TrafficValue>(
  const TrafficValue(value: 0),
);

class _MemoryMonitor {
  _MemoryMonitor._();
  static final instance = _MemoryMonitor._();

  static const _interval = Duration(seconds: 2);

  int _refCount = 0;
  Timer? _timer;
  bool _ticking = false;

  void attach() {
    _refCount++;
    if (_refCount == 1) {
      _tick();
    }
  }

  void detach() {
    _refCount = _refCount > 0 ? _refCount - 1 : 0;
    if (_refCount == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _tick() async {
    if (_refCount == 0 || _ticking) return;
    _ticking = true;
    try {
      final rss = ProcessInfo.currentRss;
      final value =
          mihomoLib != null ? rss : await mihomoCore.getMemory() + rss;
      if (_refCount > 0) {
        _memoryInfoStateNotifier.value = TrafficValue(value: value);
      }
    } finally {
      _ticking = false;
      if (_refCount > 0) {
        _timer = Timer(_interval, _tick);
      }
    }
  }
}

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> {
  @override
  void initState() {
    super.initState();
    _MemoryMonitor.instance.attach();
  }

  @override
  void dispose() {
    _MemoryMonitor.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            iconData: Icons.memory,
            label: appLocalizations.memoryInfo,
          ),
          onPressed: mihomoCore.requestGc,
          child: Padding(
            padding: baseInfoEdgeInsets.copyWith(
              top: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _memoryInfoStateNotifier,
                    builder: (_, trafficValue, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          trafficValue.showValue,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          trafficValue.showUnit,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
}