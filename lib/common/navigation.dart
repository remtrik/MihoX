import 'package:flutter/material.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/views/views.dart';

class Navigation {
  factory Navigation() => _instance ??= Navigation._internal();

  Navigation._internal();
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) =>
      [
        const NavigationItem(
          keep: false,
          icon: Icon(Icons.home_rounded),
          label: PageLabel.dashboard,
          view: DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
        ),
        NavigationItem(
          icon: const Icon(Icons.travel_explore_rounded),
          label: PageLabel.proxies,
          view: const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
          modes: hasProxies
              ? const [NavigationItemMode.mobile, NavigationItemMode.desktop]
              : const [],
        ),
        const NavigationItem(
          icon: Icon(Icons.account_circle_rounded),
          label: PageLabel.profiles,
          view: ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
        ),
        const NavigationItem(
          icon: Icon(Icons.swap_horiz_rounded),
          label: PageLabel.connections,
          description: "connectionsDesc",
          view: ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
          modes: [NavigationItemMode.desktop, NavigationItemMode.more],
        ),
        const NavigationItem(
          icon: Icon(Icons.storage),
          label: PageLabel.resources,
          description: "resourcesDesc",
          view: ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
          modes: [NavigationItemMode.more],
        ),
        NavigationItem(
          icon: const Icon(Icons.adb),
          label: PageLabel.logs,
          description: "logsDesc",
          view: const LogsView(key: GlobalObjectKey(PageLabel.logs)),
          modes: openLogs
              ? const [NavigationItemMode.desktop, NavigationItemMode.more]
              : const [],
        ),
        const NavigationItem(
          icon: Icon(Icons.settings_rounded),
          label: PageLabel.tools,
          view: ToolsView(key: GlobalObjectKey(PageLabel.tools)),
          modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
        ),
      ];
}

final navigation = Navigation();
