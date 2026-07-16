import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/dialog.dart';
import 'package:mihox/widgets/input.dart';
import 'package:mihox/widgets/list.dart';

class BackupAndRecovery extends ConsumerWidget {
  const BackupAndRecovery({super.key});

  Future<void> _backupOnLocal(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    final res = await commonScaffoldState?.loadingRun<bool>(
      () async {
        final backupData = await globalState.appController.backupData();
        final value = await picker.saveFile(
          utils.getBackupFileName(),
          Uint8List.fromList(backupData),
        );
        if (value == null) return false;
        return true;
      },
      title: appLocalizations.backup,
    );
    if (res != true) return;
    await globalState.showMessage(
      title: appLocalizations.backup,
      message: TextSpan(text: appLocalizations.backupSuccess),
    );
  }

  Future<void> _recoveryOnLocal(
    BuildContext context,
    RecoveryOption recoveryOption,
  ) async {
    final file = await picker.pickerFile();
    final data = file?.readAsBytes();
    if (data == null || !context.mounted) return;
    final commonScaffoldState = context.commonScaffoldState;
    final res = await commonScaffoldState?.loadingRun<bool>(
      () async {
        await globalState.appController.recoveryData(
          List<int>.from(await data),
          recoveryOption,
        );
        return true;
      },
      title: appLocalizations.recovery,
    );
    if (res != true) return;
    await globalState.showMessage(
      title: appLocalizations.recovery,
      message: TextSpan(text: appLocalizations.recoverySuccess),
    );
  }

  Future<void> _handleRecoveryOnLocal(BuildContext context) async {
    final recoveryOption = await globalState.showCommonDialog<RecoveryOption>(
      child: const RecoveryOptionsDialog(),
    );
    if (recoveryOption == null || !context.mounted) return;
    await _recoveryOnLocal(context, recoveryOption);
  }


  Future<void> _handleUpdateRecoveryStrategy(WidgetRef ref) async {
    final recoveryStrategy = ref.read(appSettingProvider.select(
      (state) => state.recoveryStrategy,
    ));
    final res = await globalState.showCommonDialog(
      child: OptionsDialog<RecoveryStrategy>(
        title: appLocalizations.recoveryStrategy,
        options: RecoveryStrategy.values,
        textBuilder: (mode) => Intl.message(
          "recoveryStrategy_${mode.name}",
        ),
        value: recoveryStrategy,
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            recoveryStrategy: res,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
      children: [
        ListHeader(title: appLocalizations.local),
        ListItem(
          onTap: () {
            _backupOnLocal(context);
          },
          title: Text(appLocalizations.backup),
          subtitle: Text(appLocalizations.localBackupDesc),
        ),
        ListItem(
          onTap: () {
            _handleRecoveryOnLocal(context);
          },
          title: Text(appLocalizations.recovery),
          subtitle: Text(appLocalizations.localRecoveryDesc),
        ),
        ListHeader(title: appLocalizations.options),
        Consumer(builder: (_, ref, __) {
          final recoveryStrategy = ref.watch(appSettingProvider.select(
            (state) => state.recoveryStrategy,
          ));
          return ListItem(
            onTap: () {
              _handleUpdateRecoveryStrategy(ref);
            },
            title: Text(appLocalizations.recoveryStrategy),
            trailing: FilledButton(
              onPressed: () {
                _handleUpdateRecoveryStrategy(ref);
              },
              child: Text(
                Intl.message("recoveryStrategy_${recoveryStrategy.name}"),
              ),
            ),
          );
        }),
      ],
    );
}

class RecoveryOptionsDialog extends StatefulWidget {
  const RecoveryOptionsDialog({super.key});

  @override
  State<RecoveryOptionsDialog> createState() => _RecoveryOptionsDialogState();
}

class _RecoveryOptionsDialogState extends State<RecoveryOptionsDialog> {
  void _handleOnTab(RecoveryOption? value) {
    if (value == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.recovery,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 16,
        ),
        child: Wrap(
          children: [
            ListItem(
              onTap: () {
                _handleOnTab(RecoveryOption.onlyProfiles);
              },
              title: Text(appLocalizations.recoveryProfiles),
            ),
            ListItem(
              onTap: () {
                _handleOnTab(RecoveryOption.all);
              },
              title: Text(appLocalizations.recoveryAll),
            )
          ],
        ),
      );
}
