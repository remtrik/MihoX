import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/core.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/widgets.dart';

@immutable
class Contributor {
  const Contributor({
    this.avatar,
    required this.name,
    required this.link,
    this.clickable = true,
  });

  final String? avatar;
  final String name;
  final String link;
  final bool clickable;
}

@immutable
class ThanksPerson {
  const ThanksPerson({this.avatar, required this.name});

  final String? avatar;
  final String name;
}

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final scaffold = context.commonScaffoldState;
    if (scaffold?.mounted != true) return;
    final data = await scaffold?.loadingRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
    );
    if (!context.mounted) return;
    await globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildAvatarSection({
    required String title,
    required List<Contributor> contributors,
    double avatarSize = 56.0,
  }) => generateSection(
    separated: false,
    title: title,
    items: [
      ListItem(
        title: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final c in contributors)
              _PersonAvatar(
                avatar: c.avatar,
                name: c.name,
                size: avatarSize,
                onTap: c.clickable ? () => globalState.openUrl(c.link) : null,
              ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _buildGratitudeSection() {
    const people = [
      ThanksPerson(
        name: 'cool_coala',
        avatar: 'assets/images/avatars/cool_coala.jpg',
      ),
      ThanksPerson(name: 'arpic', avatar: 'assets/images/avatars/arpic.jpg'),
      ThanksPerson(name: 'legiz', avatar: 'assets/images/avatars/legiz.jpg'),
    ];
    return generateSection(
      separated: false,
      title: appLocalizations.gratitude,
      items: [
        ListItem(
          title: Row(
            children: [
              for (final p in people)
                SizedBox(
                  width: 70,
                  child: _PersonAvatar(
                    avatar: p.avatar,
                    name: p.name,
                    size: 36.0,
                    fontSize: 9.0,
                    maxNameLines: 2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) => generateSection(
    separated: false,
    title: appLocalizations.more,
    items: [
      ListItem(
        title: Text(appLocalizations.checkUpdate),
        trailing: const Icon(Icons.update),
        onTap: () => _checkUpdate(context),
      ),
      if (system.isDesktop) const _CoreUpdateItem(),
      ListItem(
        title: Text(appLocalizations.project),
        trailing: const Icon(Icons.insert_link),
        onTap: () => globalState.openUrl('https://github.com/$repository'),
      ),
      ListItem(
        title: Text(appLocalizations.originalRepository),
        trailing: const Icon(Icons.insert_link),
        onTap: () =>
            globalState.openUrl('https://github.com/pluralplay/FlClashX'),
      ),
      ListItem(
        title: Text(appLocalizations.core),
        trailing: const Icon(Icons.insert_link),
        onTap: () => globalState.openUrl(
          'https://github.com/MetaCubeX/mihomo/tree/Meta',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    const mainContributors = [
      Contributor(
        avatar: 'assets/images/avatars/remtrik.jpg',
        name: 'remtrik',
        link: 'https://github.com/remtrik',
      ),
      Contributor(
        avatar: 'assets/images/avatars/pluralplay.jpg',
        name: 'pluralplay',
        link: 'https://github.com/pluralplay',
      ),
      Contributor(
        avatar: 'assets/images/avatars/kastov.jpg',
        name: 'kastov',
        link: 'https://github.com/kastov',
      ),
    ];

    const thanksContributors = [
      Contributor(
        avatar: 'assets/images/avatars/x_kit_.jpg',
        name: 'x_kit_',
        link: 'https://github.com/this-xkit',
      ),
      Contributor(
        avatar: 'assets/images/avatars/katsukibtw.jpg',
        name: 'katsukibtw',
        link: 'https://github.com/katsukibtw',
      ),
    ];

    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 64,
                    height: 64,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName, style: textTheme.headlineSmall),
                    Text(
                      globalState.packageInfo.version,
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    const _CoreVersionWidget(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(appLocalizations.desc, style: textTheme.bodySmall),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildAvatarSection(
        title: appLocalizations.otherContributors,
        contributors: mainContributors,
      ),
      ..._buildAvatarSection(
        title: appLocalizations.thanks,
        contributors: thanksContributors,
        avatarSize: 48.0,
      ),
      ..._buildGratitudeSection(),
      ..._buildMoreSection(context),
    ];

    return Padding(
      padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
      child: generateListView(items),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.name,
    this.avatar,
    this.size = 56.0,
    this.fontSize,
    this.onTap,
    this.maxNameLines = 1,
  });

  final String? avatar;
  final String name;
  final double size;
  final double? fontSize;
  final VoidCallback? onTap;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedFontSize = fontSize ?? size * 0.25;
    final avatarFontSize = size * 0.46;

    final circle = CircleAvatar(
      radius: size / 2,
      foregroundImage: avatar != null
          ? AssetImage(avatar!) as ImageProvider
          : null,
      backgroundColor: avatar == null ? colorScheme.primaryContainer : null,
      child: avatar == null
          ? Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontFamily: 'Unbounded',
                fontSize: avatarFontSize,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: size, height: size, child: circle),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: maxNameLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Unbounded', fontSize: resolvedFontSize),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: column);
    }
    return column;
  }
}

class _CoreVersionWidget extends StatelessWidget {
  const _CoreVersionWidget();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        // Prefer the running instance — after a standalone core update it is
        // the only truthful source; the build-time constant covers a stopped
        // core.
        future: mihomoCore.getCoreVersion(),
        builder: (context, snapshot) {
          final live = snapshot.data;
          final coreVersion =
              live != null && live.isNotEmpty ? live : globalState.coreVersion;
          if (coreVersion == null || coreVersion.isEmpty) {
            return const SizedBox.shrink();
          }
          return Text(
            'Core: $coreVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        },
      );
}

class _CoreUpdateItem extends StatefulWidget {
  const _CoreUpdateItem();

  @override
  State<_CoreUpdateItem> createState() => _CoreUpdateItemState();
}

class _CoreUpdateItemState extends State<_CoreUpdateItem> {
  Map<String, dynamic>? _release;
  bool _busy = false;
  bool _downloading = false;
  double _progress = 0;
  String _error = '';
  bool _initialCheckDone = false;

  String get _coreAssetName {
    final arch = Platform.version.contains('arm64') ||
            Platform.version.contains('aarch64')
        ? 'arm64'
        : 'amd64';
    final platform = Platform.isWindows
        ? 'windows'
        : 'linux';
    final ext = Platform.isWindows ? '.exe' : '';
    return 'MihoXCore-$platform-$arch$ext';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialCheckDone) {
      _initialCheckDone = true;
      _check();
    }
  }

  Future<void> _check() async {
    try {
      final coreVersion = await mihomoCore.getCoreVersion();
      final currentVersion =
          coreVersion.isNotEmpty ? coreVersion : globalState.coreVersion ?? '';
      if (currentVersion.isEmpty) {
        return;
      }
      final release = await request.checkForCoreUpdate(currentVersion);
      if (mounted && release != null) {
        setState(() => _release = release);
      }
    } catch (_) {
      // The item only appears when an update is found; stay hidden on errors.
    }
  }

  Future<void> _download() async {
    if (_busy || _release == null) {
      return;
    }
    final assets = _release!['assets'] as List<dynamic>? ?? [];
    final name = _coreAssetName;
    final asset = assets
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String?) == name)
        .firstOrNull;
    if (asset == null) {
      setState(() => _error = '$name not found');
      return;
    }
    final url = asset['browser_download_url'] as String;
    setState(() {
      _busy = true;
      _downloading = true;
      _progress = 0;
      _error = '';
    });
    final error = await request.downloadCoreUpdate(
      url,
      appPath.corePendingPath,
      onProgress: (received, total) {
        if (!mounted || total <= 0) return;
        setState(() => _progress = received / total);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _downloading = false;
      if (error != null) {
        _error = error;
      }
    });
    if (error == null) {
      _showRestartDialog();
    }
  }

  void _showRestartDialog() {
    globalState.showCommonDialog(
      dismissible: false,
      child: CommonDialog(
        title: appLocalizations.coreUpdateSuccess,
        actions: [
          TextButton(
            onPressed: () {
              // Restart only the core, not the whole app. reStart applies the
              // pending binary (helper swap on Windows) and re-inits in place, so
              // the Dart run-state stays in sync — a full app restart
              // (handleRestart) left the UI thinking the core was stopped while it
              // was actually up and proxying.
              // Close the dialog + the About sheet and jump to the dashboard so the
              // restart happens on the main screen, not buried in settings.
              globalState.navigatorKey.currentState
                  ?.popUntil((route) => route.isFirst);
              globalState.appController.page = PageLabel.dashboard;
              globalState.appController.restartCore();
            },
            child: Text(appLocalizations.restart),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.primary;
    final tag = (release['tag_name'] as String).replaceFirst('core-', '');
    final subtitle = _error.isNotEmpty
        ? '${appLocalizations.coreUpdateFailed}: $_error'
        : _downloading
            ? appLocalizations.coreUpdateDownloading
            : tag;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListItem(
          title: Text(
            appLocalizations.coreUpdateAvailable,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          onTap: _download,
          trailing: Icon(Icons.system_update, color: color),
        ),
        if (_downloading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
            ),
          ),
      ],
    );
  }
}