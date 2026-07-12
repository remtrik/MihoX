import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/providers/config.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';
import 'package:path/path.dart';

class _AppSettingSwitchItem extends ConsumerWidget {
  const _AppSettingSwitchItem({
    required this.title,
    required this.subtitle,
    required this.select,
    required this.update,
    this.requiresOverride = false,
  });

  final String title;
  final String subtitle;
  final bool Function(AppSettingProps) select;
  final AppSettingProps Function(AppSettingProps, {required bool value}) update;
  final bool requiresOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(appSettingProvider.select(select));
    final isEnabled = !requiresOverride ||
        ref.watch(
          appSettingProvider.select((s) => s.overrideProviderSettings),
        );

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(title),
        subtitle: Text(subtitle),
        delegate: SwitchDelegate(
          value: value,
          onChanged: isEnabled
              ? (v) => ref
                  .read(appSettingProvider.notifier)
                  .updateState((s) => update(s, value: v))
              : null,
        ),
      ),
    );
  }
}

class OverrideProviderSettingsItem extends ConsumerWidget {
  const OverrideProviderSettingsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((s) => s.overrideProviderSettings),
    );
    final colorScheme = context.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.switchItem(
          title: Text(appLocalizations.overrideProviderSettings),
          subtitle: Text(appLocalizations.overrideProviderSettingsDesc),
          delegate: SwitchDelegate(
            value: overrideProviderSettings,
            onChanged: (value) {
              ref.read(appSettingProvider.notifier).updateState(
                    (s) => s.copyWith(overrideProviderSettings: value),
                  );
            },
          ),
        ),
        if (!overrideProviderSettings)
          ColoredBox(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appLocalizations.managedByProvider,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class MinimizeItem extends StatelessWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.minimizeOnExit,
        subtitle: appLocalizations.minimizeOnExitDesc,
        select: (s) => s.minimizeOnExit,
        update: (s, {required value}) => s.copyWith(minimizeOnExit: value),
        requiresOverride: true,
      );
}

class AutoLaunchItem extends StatelessWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.autoLaunch,
        subtitle: appLocalizations.autoLaunchDesc,
        select: (s) => s.autoLaunch,
        update: (s, {required value}) => s.copyWith(autoLaunch: value),
        requiresOverride: true,
      );
}

class SilentLaunchItem extends StatelessWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.silentLaunch,
        subtitle: appLocalizations.silentLaunchDesc,
        select: (s) => s.silentLaunch,
        update: (s, {required value}) => s.copyWith(silentLaunch: value),
        requiresOverride: true,
      );
}

class AutoRunItem extends StatelessWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.autoRun,
        subtitle: appLocalizations.autoRunDesc,
        select: (s) => s.autoRun,
        update: (s, {required value}) => s.copyWith(autoRun: value),
        requiresOverride: true,
      );
}

class AutoCheckUpdateItem extends StatelessWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.autoCheckUpdate,
        subtitle: appLocalizations.autoCheckUpdateDesc,
        select: (s) => s.autoCheckUpdate,
        update: (s, {required value}) => s.copyWith(autoCheckUpdate: value),
        requiresOverride: true,
      );
}

class CloseConnectionsItem extends StatelessWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.autoCloseConnections,
        subtitle: appLocalizations.autoCloseConnectionsDesc,
        select: (s) => s.closeConnections,
        update: (s, {required value}) => s.copyWith(closeConnections: value),
      );
}

class UsageItem extends StatelessWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.onlyStatisticsProxy,
        subtitle: appLocalizations.onlyStatisticsProxyDesc,
        select: (s) => s.onlyStatisticsProxy,
        update: (s, {required value}) => s.copyWith(onlyStatisticsProxy: value),
      );
}

class HiddenItem extends StatelessWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.exclude,
        subtitle: appLocalizations.excludeDesc,
        select: (s) => s.hidden,
        update: (s, {required value}) => s.copyWith(hidden: value),
      );
}

class AnimateTabItem extends StatelessWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.tabAnimation,
        subtitle: appLocalizations.tabAnimationDesc,
        select: (s) => s.isAnimateToPage,
        update: (s, {required value}) => s.copyWith(isAnimateToPage: value),
      );
}

class OpenLogsItem extends StatelessWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context) => _AppSettingSwitchItem(
        title: appLocalizations.logcat,
        subtitle: appLocalizations.logcatDesc,
        select: (s) => s.openLogs,
        update: (s, {required value}) => s.copyWith(openLogs: value),
      );
}

class OpenLogsFolderItem extends ConsumerWidget {
  const OpenLogsFolderItem({super.key});

  Future<void> _openLogsFolder() async {
    try {
      final homePath = await appPath.homeDirPath;
      final logsPath = join(homePath, 'logs');
      final logsDir = Directory(logsPath);

      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }

      final ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run('explorer', [logsPath]);
      } else if (Platform.isLinux) {
        result = await Process.run('xdg-open', [logsPath]);
      } else {
        return;
      }

      if (result.exitCode != 0) {
        commonPrint.log(
          'Failed to open logs folder (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (e) {
      commonPrint.log('Failed to open logs folder: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(appLocalizations.openLogsFolder),
        leading: const Icon(Icons.folder_open),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _openLogsFolder,
      );
}

class ResetAppItem extends ConsumerWidget {
  const ResetAppItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return ListItem(
      title: Text(
        appLocalizations.clearData,
        style: TextStyle(
          color: colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: Icon(Icons.delete_forever, color: colorScheme.error),
      onTap: () async {
        final res = await globalState.showMessage(
          title: appLocalizations.clearData,
          message: TextSpan(
            text: appLocalizations.clearDataTip,
            style: TextStyle(color: colorScheme.onSurface),
          ),
        );
        if (res != true) return;
        await globalState.appController.handleClear();
        await system.exit();
      },
    );
  }
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      const OverrideProviderSettingsItem(),
      const MinimizeItem(),
      if (system.isDesktop) ...[
        const AutoLaunchItem(),
        const SilentLaunchItem(),
      ],
      const AutoRunItem(),
      if (Platform.isAndroid) const HiddenItem(),
      const AnimateTabItem(),
      const OpenLogsItem(),
      const CloseConnectionsItem(),
      const AutoCheckUpdateItem(),
      if (system.isDesktop)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: OpenLogsFolderItem(),
        ),
      Padding(
        padding: EdgeInsets.only(top: system.isDesktop ? 0 : 16),
        child: const ResetAppItem(),
      ),
    ];

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, index) => items[index],
    );
  }
}