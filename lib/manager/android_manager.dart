import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/plugins/app.dart';
import 'package:mihox/providers/config.dart';

class AndroidManager extends ConsumerStatefulWidget {
  const AndroidManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.listenManual(appSettingProvider.select((state) => state.hidden),
        (prev, next) {
      app?.updateExcludeFromRecents(value: next);
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
