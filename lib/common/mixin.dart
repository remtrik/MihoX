import 'package:flutter/material.dart';
import 'package:mihox/models/models.dart';
import 'package:riverpod/riverpod.dart';

import 'context.dart';

mixin AutoDisposeNotifierMixin<T> on AutoDisposeNotifier<T> {
  set value(T value) {
    state = value;
  }

  @override
  bool updateShouldNotify(previous, next) {
    final res = super.updateShouldNotify(previous, next);
    if (res) {
      onUpdate(next);
    }
    return res;
  }

  void onUpdate(T value) {}
}

mixin PageMixin<T extends StatefulWidget> on State<T> {
  void onPageShow() {
    initPageState();
  }

  void initPageState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.commonScaffoldState
        ?..actions = actions
        ..floatingActionButton = floatingActionButton
        ..onKeywordsUpdate = onKeywordsUpdate
        ..updateSearchState(
          (_) => onSearch != null ? AppBarSearchState(onSearch: onSearch!) : null,
        );
    });
  }
  
  void onPageHidden() {}

  List<Widget> get actions => [];

  Widget? get floatingActionButton => null;

  Function(String)? get onSearch => null;

  Function(List<String>)? get onKeywordsUpdate => null;
}
