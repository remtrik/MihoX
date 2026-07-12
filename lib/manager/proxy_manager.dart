import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/proxy.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/state.dart';

class ProxyManager extends ConsumerStatefulWidget {
  const ProxyManager({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _updateProxy(ProxyState proxyState) async {
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    if (isStart && systemProxy) {
      await proxy?.startProxy(port, proxyState.bassDomain);
    } else {
      await proxy?.stopProxy();
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      proxyStateProvider,
      (prev, next) {
        if (prev != next) {
          _updateProxy(next);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
