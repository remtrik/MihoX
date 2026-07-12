import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';
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
  const ThanksPerson({
    this.avatar,
    required this.name,
  });

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
  }) =>
      generateSection(
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
                    onTap: c.clickable
                        ? () => globalState.openUrl(c.link)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      );

  List<Widget> _buildGratitudeSection() {
    const people = [
      ThanksPerson(name: 'cool_coala', avatar: 'assets/images/avatars/cool_coala.jpg'),
      ThanksPerson(name: 'arpic',      avatar: 'assets/images/avatars/arpic.jpg'),
      ThanksPerson(name: 'legiz',      avatar: 'assets/images/avatars/legiz.jpg'),
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
          ListItem(
            title: Text(appLocalizations.project),
            trailing: const Icon(Icons.insert_link),
            onTap: () => globalState.openUrl('https://github.com/$repository'),
          ),
          ListItem(
            title: Text(appLocalizations.originalRepository),
            trailing: const Icon(Icons.insert_link),
            onTap: () => globalState.openUrl('https://github.com/chen08209/MihoX'),
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
                    Text(globalState.packageInfo.version,
                        style: textTheme.labelLarge),
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
      foregroundImage:
          avatar != null ? AssetImage(avatar!) as ImageProvider : null,
      backgroundColor:
          avatar == null ? colorScheme.primaryContainer : null,
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
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: resolvedFontSize,
          ),
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
  Widget build(BuildContext context) {
    final coreVersion = globalState.coreVersion;
    if (coreVersion == null || coreVersion.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      'Core: $coreVersion',
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}