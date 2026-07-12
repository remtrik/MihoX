import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/l10n/l10n.dart';
import 'package:mihox/manager/hotkey_manager.dart';
import 'package:mihox/manager/manager.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/plugins/app.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/state.dart';

import 'controller.dart';
import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) =>
      ref.read(genColorSchemeProvider(brightness));

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      windows?.enableDarkModeForApp();
    }

    _autoUpdateGroupTask();
    _autoUpdateProfilesTask();
    globalState.appController = AppController(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        globalState.appController = AppController(currentContext, ref);
      }
      await globalState.appController.init();
      globalState.appController.initLink();
      await app?.initShortcuts();
    });
  }

  void _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer = Timer(const Duration(milliseconds: 20000), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        globalState.appController.updateGroupsDebounce();
        _autoUpdateGroupTask();
      });
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await globalState.appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(
            child: ProxyManager(child: child),
          ),
        ),
      );
    }
    return AndroidManager(child: TileManager(child: child));
  }

  Widget _buildState(Widget child) => AppStateManager(
        child: MihomoManager(
          child: ConnectivityManager(
            onConnectivityChanged: (results) async {
              if (!results.contains(ConnectivityResult.vpn)) {
                mihomoCore.closeConnections();
              }
              await globalState.appController.updateLocalIp();
              globalState.appController.addCheckIpNumDebounce();
            },
            child: child,
          ),
        ),
      );

  Widget _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(child: child);
    }
    return VpnManager(child: child);
  }

  Widget _buildApp(Widget child) => MessageManager(
        child: ThemeManager(child: child),
      );

  @override
  Widget build(BuildContext context) => _buildPlatformState(
        _buildState(
          Consumer(
            builder: (_, ref, child) {
              final locale =
                  ref.watch(appSettingProvider.select((state) => state.locale));
              final themeProps = ref.watch(themeSettingProvider);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: globalState.navigatorKey,
                checkerboardRasterCacheImages: false,
                checkerboardOffscreenLayers: false,
                showPerformanceOverlay: false,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate
                ],
                builder: (_, child) {
                  final Widget app = AppEnvManager(
                    child: _buildPlatformApp(
                      _buildApp(child!),
                    ),
                  );

                  return app;
                },
                scrollBehavior: BaseScrollBehavior(),
                title: appName,
                locale: utils.getLocaleForString(locale),
                supportedLocales: AppLocalizations.delegate.supportedLocales,
                themeMode: themeProps.themeMode,
                theme: ThemeData(
                  useMaterial3: true,
                  pageTransitionsTheme: _pageTransitionsTheme,
                  colorScheme: _getAppColorScheme(
                    brightness: Brightness.light,
                    primaryColor: themeProps.primaryColor,
                  ),
                  // Reduce animation duration for snappier feel
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  pageTransitionsTheme: _pageTransitionsTheme,
                  colorScheme: _getAppColorScheme(
                    brightness: Brightness.dark,
                    primaryColor: themeProps.primaryColor,
                  ).toPureBlack(isPureBlack: themeProps.pureBlack),
                  // Reduce animation duration for snappier feel
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                ),
                home: child,
              );
            },
            child: const HomePage(),
          ),
        ),
      );

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateProfilesTaskTimer?.cancel();
    await mihomoCore.destroy();
    await globalState.appController.savePreferences();
    await globalState.appController.handleExit();
    super.dispose();
  }
}
