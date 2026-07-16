import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mihox/common/archive.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/mihomo.dart';
import 'package:mihox/plugins/app.dart';
import 'package:mihox/providers/providers.dart';
import 'package:mihox/services/subscription_notification_service.dart';
import 'package:mihox/state.dart';
import 'package:mihox/widgets/dialog.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:path/path.dart' hide windows;
import 'package:shared_preferences/shared_preferences.dart';

import 'common/common.dart';
import 'models/models.dart';
import 'plugins/vpn.dart';
import 'views/profiles/override_profile.dart';

class AppController {
  AppController(this.context, WidgetRef ref) : _ref = ref;
  int? lastProfileModified;
  Timer? _profileUpdateTimer;
  //bool _isRestartingCore = false;
  final BuildContext context;
  final WidgetRef _ref;

  void setupMihomoConfigDebounce() {
    debouncer.call(FunctionTag.setupMihomoConfig, () async {
      await setupMihomoConfig();
    });
  }

  void updateMihomoConfigDebounce() {
    debouncer.call(FunctionTag.updateMihomoConfig, () async {
      await updateMihomoConfig();
    });
  }

  void updateGroupsDebounce() {
    debouncer.call(FunctionTag.updateGroups, updateGroups);
  }

  void addCheckIpNumDebounce() {
    debouncer.call(FunctionTag.addCheckIpNum, () {
      _ref.read(checkIpNumProvider.notifier).add();
    });
  }

  void applyProfileDebounce({
    bool silence = false,
  }) {
    debouncer.call(FunctionTag.applyProfile, (silence) {
      applyProfile(silence: silence);
    }, args: [silence]);
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, savePreferences);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy,
        (String groupName, String proxyName) async {
      await changeProxy(
        groupName: groupName,
        proxyName: proxyName,
      );
      await updateGroups();
      // Update cached server name for foreground notification
      _updateForegroundServerName(groupName, proxyName);
    }, args: [groupName, proxyName]);
  }

  /// Update cached server name in VPN plugin for foreground notification
  /// Also sends IPC message to service isolate to update selectedMap
  void _updateForegroundServerName(String groupName, String serverName) {
    vpn?.serverName = serverName;
    // Send IPC message to service isolate (Android only)
    mihomoLib?.sendIpcMessage({
      'action': 'updateForegroundServer',
      'groupName': groupName,
      'serverName': serverName,
    });
  }

  /// Initialize foreground notification cache with current profile and server
  void initForegroundCache() {
    final profile = globalState.config.currentProfile;
    if (profile == null) return;

    final profileName = profile.label ?? profile.id;

    // Decode service name from header
    var serviceName = "";
    final svc = profile.providerHeaders['mihox-servicename'];
    if (svc != null && svc.isNotEmpty) {
      serviceName = utils.decodeBase64(svc);
    }

    vpn?.updateProfileInfo(
      profileName: profileName,
      serviceName: serviceName,
    );

    // Get current server name from selectedMap
    final groupName = profile.providerHeaders['mihox-serverinfo'];
    if (groupName != null && groupName.isNotEmpty) {
      final serverName =
          profile.selectedMap[utils.decodeBase64(groupName)] ?? "";
      vpn?.serverName = serverName;
    }
  }

  /*Future<void> restartCore() async {
    if (_isRestartingCore) {
      return;
    }
    _isRestartingCore = true;
    try {
      commonPrint.log("restart core");
      await mihomoService?.reStart();
      await _initCore();
      if (_ref.read(runTimeProvider.notifier).isStart) {
        await globalState.handleStart();
      }
    } finally {
      _isRestartingCore = false;
    }
  }*/

  Future<void> restartCore() async {
    commonPrint.log("restart core");
    await mihomoService?.reStart();
    await _initCore();
    if (_ref.read(runTimeProvider.notifier).isStart) {
      await globalState.handleStart();
    }
  }

  Future<void> updateStatus(bool isStart) async {

    if (isStart) {
      // Initialize foreground notification cache before starting
      initForegroundCache();
      await globalState.handleStart([
        updateRunTime,
        updateTraffic,
      ]);
      final currentLastModified =
          await _ref.read(currentProfileProvider)?.profileLastModified;
      if (currentLastModified == null || lastProfileModified == null) {
        addCheckIpNumDebounce();
        return;
      }
      if (currentLastModified <= (lastProfileModified ?? 0)) {
        addCheckIpNumDebounce();
        return;
      }
      applyProfileDebounce();
    } else {
      await globalState.handleStop();
      mihomoCore.resetTraffic();
      _ref.read(trafficsProvider.notifier).clear();
      _ref.read(totalTrafficProvider.notifier).value = Traffic();
      _ref.read(runTimeProvider.notifier).value = null;
      addCheckIpNumDebounce();
    }
  }

  void updateRunTime() {
    final startTime = globalState.startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      _ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      _ref.read(runTimeProvider.notifier).value = null;
    }
  }

  Future<void> updateTraffic() async {
    final traffic = await mihomoCore.getTraffic();
    _ref.read(trafficsProvider.notifier).addTraffic(traffic);
    _ref.read(totalTrafficProvider.notifier).value =
        await mihomoCore.getTotalTraffic();
  }

  Future<void> addProfile(Profile profile) async {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (_ref.read(currentProfileIdProvider) != null) return;
    _ref.read(currentProfileIdProvider.notifier).value = profile.id;
    applyProfileDebounce(silence: true);
  }

  Future<void> deleteProfile(String id) async {
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
    await clearEffect(id);
    if (globalState.config.currentProfileId == id) {
      final profiles = globalState.config.profiles;
      final currentProfileId = _ref.read(currentProfileIdProvider.notifier);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        currentProfileId.value = updateId;
      } else {
        currentProfileId.value = null;
        await updateStatus(false);
      }
    }
  }

  Future<void> updateProviders() async {
    _ref.read(providersProvider.notifier).value =
        await mihomoCore.getExternalProviders();
  }

  Future<void> updateLocalIp() async {
    _ref.read(localIpProvider.notifier).value = null;
    await Future.delayed(commonDuration);
    _ref.read(localIpProvider.notifier).value = await utils.getLocalIpAddress();
  }

  void applySubscriptionSettings(Set<String>? settings) {
    try {
      final currentSettings = _ref.read(appSettingProvider);
      if (currentSettings.overrideProviderSettings) {
        commonPrint.log(
            "Override provider settings enabled - ignoring subscription settings");
        return;
      }

      // If settings is null (header removed), reset to defaults (false)
      final effectiveSettings = settings ?? {};

      _ref
          .read(appSettingProvider.notifier)
          .updateState((state) => state.copyWith(
                minimizeOnExit: effectiveSettings.contains('minimize'),
                autoLaunch: effectiveSettings.contains('autorun'),
                silentLaunch: effectiveSettings.contains('shadowstart'),
                autoRun: effectiveSettings.contains('autostart'),
                autoCheckUpdate: effectiveSettings.contains('autoupdate'),
              ));
    } catch (e) {
      commonPrint.log("applySubscriptionSettings failed: $e");
    }
  }

  void _applyAllHeaderSettings(Profile profile, {required bool isNewProfile}) {
    final headers = profile.providerHeaders;
    if (headers.isEmpty) return;

    final customBehavior = headers['mihox-custom'];

    final shouldApply = switch (customBehavior) {
      'add' => isNewProfile,
      'update' => true,
      _ => false,
    };

    if (!shouldApply) return;

    _applyProviderSettings(headers);
    _applyThemeColor(headers);
    _applyCustomViewSettings(profile);
  }

  void _applyProviderSettings(Map<String, String> headers) {
    try {
      final currentSettings = _ref.read(appSettingProvider);
      if (currentSettings.overrideProviderSettings) {
        commonPrint.log(
            "Override provider settings enabled - ignoring provider settings");
        return;
      }

      final settingsHeader = headers['mihox-settings'];
      if (settingsHeader != null) {
        final settings = settingsHeader
            .split(',')
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet();
        applySubscriptionSettings(settings);
      }
    } catch (e) {
      commonPrint.log("Failed to apply provider settings: $e");
    }
  }

  void _applyThemeColor(Map<String, String> headers) {
    try {
      final hexHeader = headers['mihox-hex'];
      if (hexHeader != null && hexHeader.isNotEmpty) {
        _applyThemeColorFromHex(hexHeader);
      }
    } catch (e) {
      commonPrint.log("Failed to apply theme color: $e");
    }
  }

  void _applyThemeColorFromHex(String hexHeader) {
    try {
      final parts = hexHeader.split(':');
      final hexString = parts[0].trim().replaceAll('#', '');
      final variantName = parts.length > 1 ? parts[1].trim() : null;

      // Check for pureblack flag in any position after color
      var enablePureBlack = false;
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i].trim().toLowerCase();
        if (part == 'pureblack') {
          enablePureBlack = true;
          break;
        }
      }

      if (hexString.length != 6 && hexString.length != 8) {
        commonPrint.log('Invalid hex color length: $hexString');
        return;
      }

      final colorValue = int.parse(
        hexString.length == 6 ? 'FF$hexString' : hexString,
        radix: 16,
      );

      commonPrint
          .log('Applying theme from mihox-hex: #${hexString.toUpperCase()}'
              '${variantName != null ? ', variant=$variantName' : ''}'
              '${enablePureBlack ? ', pureBlack=true' : ''}');

      _ref.read(themeSettingProvider.notifier).updateState((state) {
        final updatedColors = [...state.primaryColors];
        if (!updatedColors.contains(colorValue)) {
          updatedColors.add(colorValue);
        }

        DynamicSchemeVariant? newVariant;
        if (variantName != null && variantName.toLowerCase() != 'pureblack') {
          try {
            newVariant = DynamicSchemeVariant.values.firstWhere(
              (v) => v.name.toLowerCase() == variantName.toLowerCase(),
            );
            commonPrint.log('Using scheme variant: ${newVariant.name}');
          } catch (e) {
            commonPrint.log(
                'Unknown variant: $variantName, using current: ${state.schemeVariant.name}');
          }
        }

        commonPrint.log(
            'Theme updated: primaryColor=#${colorValue.toRadixString(16).toUpperCase()}'
            '${enablePureBlack ? ', pureBlack=true' : ''}');

        return state.copyWith(
          primaryColor: colorValue,
          primaryColors: updatedColors,
          schemeVariant: newVariant ?? state.schemeVariant,
          pureBlack: enablePureBlack,
        );
      });

      savePreferencesDebounce();

      commonPrint.log('Theme applied successfully');
    } catch (e) {
      commonPrint.log('Failed to parse hex color from header: $hexHeader - $e');
    }
  }

  Future<void> updateProfile(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldSend = prefs.getBool('sendDeviceHeaders') ?? true;
    final newProfile = await profile.update(
      shouldSendHeaders: shouldSend,
    );

    final headers = newProfile.providerHeaders;
    if (headers.isNotEmpty) {
      _applyAllHeaderSettings(newProfile, isNewProfile: false);
    }

    final showHwidLimit = headers['x-hwid-limit']?.toLowerCase() == 'true';
    final announceText = headers['announce'];
    if (showHwidLimit && announceText != null && announceText.isNotEmpty) {
      _showHwidLimitNotice(announceText, headers['support-url']);
    }

    _ref
        .read(profilesProvider.notifier)
        .setProfile(newProfile.copyWith(isUpdating: false));

    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
      unawaited(_updateGeoFilesAfterProfileUpdate().catchError((e) {
        commonPrint.log("Error updating geo files: $e");
      }));
    }

    // Check subscription expiration and show notification if needed
    unawaited(SubscriptionNotificationService.checkAndNotify(newProfile)
        .catchError((e) {
      commonPrint.log("Error checking subscription: $e");
    }));
  }

  void _showHwidLimitNotice(String encodedText, String? supportUrl) {
    String? announceText;
    var textToDecode = encodedText;

    if (encodedText.startsWith('base64:')) {
      textToDecode = encodedText.substring(7);
    }

    announceText = utils.decodeBase64(textToDecode);

    if (announceText.isNotEmpty) {
      final actions = <Widget>[];

      if (supportUrl != null && supportUrl.isNotEmpty) {
        actions.add(
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              globalState.openUrl(supportUrl);
            },
            child: Text(appLocalizations.support),
          ),
        );
      }

      actions.add(
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      );

      globalState.showCommonDialog(
        child: CommonDialog(
          title: appLocalizations.tip,
          actions: actions,
          child: Container(
            width: 300,
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: SelectableText(
                announceText,
                style: const TextStyle(
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<Map<String, String>?> _getRemoteFileMetadata(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final metadata = <String, String>{};

      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        metadata['etag'] = etag;
      }

      final lastModified = response.headers['last-modified'];
      if (lastModified != null && lastModified.isNotEmpty) {
        metadata['last-modified'] = lastModified;
      }

      final contentLength = response.headers['content-length'];
      if (contentLength != null && contentLength.isNotEmpty) {
        metadata['content-length'] = contentLength;
      }

      return metadata.isEmpty ? null : metadata;
    } catch (e) {
      commonPrint.log("Failed to get remote file metadata for $url: $e");
      return null;
    }
  }

  String _getMetadataKey(String profileId, String key) =>
      'geo_metadata_${profileId}_$key';

  Future<Map<String, String>?> _getSavedMetadata(
      String profileId, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _getMetadataKey(profileId, key);
      final jsonString = prefs.getString(storageKey);
      if (jsonString == null) return null;
      return Map<String, String>.from(json.decode(jsonString));
    } catch (e) {
      commonPrint.log("Failed to get saved metadata for $key: $e");
      return null;
    }
  }

  Future<void> _saveMetadata(
      String profileId, String key, Map<String, String> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _getMetadataKey(profileId, key);
      await prefs.setString(storageKey, json.encode(metadata));
    } catch (e) {
      commonPrint.log("Failed to save metadata for $key: $e");
    }
  }

  bool _hasMetadataChanged(
      Map<String, String>? oldMeta, Map<String, String>? newMeta) {
    if (oldMeta == null || newMeta == null) return true;

    if (newMeta['etag'] != null && oldMeta['etag'] != null) {
      return newMeta['etag'] != oldMeta['etag'];
    }

    if (newMeta['last-modified'] != null && oldMeta['last-modified'] != null) {
      return newMeta['last-modified'] != oldMeta['last-modified'];
    }

    if (newMeta['content-length'] != null &&
        oldMeta['content-length'] != null) {
      return newMeta['content-length'] != oldMeta['content-length'];
    }

    return true;
  }

  Future<void> _updateGeoFilesAfterProfileUpdate(
      {bool forceUpdate = false}) async {
    try {
      final currentProfileId = _ref.read(currentProfileIdProvider);
      if (currentProfileId == null) return;

      final profileConfig =
          await globalState.getProfileConfig(currentProfileId);

      final geodataMode = profileConfig["geodata-mode"];
      if (geodataMode != true) {
        commonPrint.log(
            "Geodata updates are disabled by profile (geodata-mode != true)");
        return;
      }

      final geoXUrl = profileConfig["geox-url"];

      if (geoXUrl == null || geoXUrl is! Map) {
        commonPrint.log("No geox-url found in profile config");
        return;
      }

      final geoFiles = [
        {'type': 'GeoIp', 'name': geoIpFileName, 'key': 'geoip'},
        {'type': 'MMDB', 'name': mmdbFileName, 'key': 'mmdb'},
        {'type': 'GeoSite', 'name': geoSiteFileName, 'key': 'geosite'},
        {'type': 'ASN', 'name': asnFileName, 'key': 'asn'},
      ];

      // Counters for logging purposes (values used in log messages via increment)
      // ignore: unused_local_variable
      var updatedCount = 0;
      // ignore: unused_local_variable
      var skippedCount = 0;

      for (final geoFile in geoFiles) {
        final geoType = geoFile['type']!;
        final fileName = geoFile['name']!;
        final key = geoFile['key']!;

        final url = geoXUrl[key];
        if (url == null || url is! String || url.isEmpty) {
          commonPrint.log("No URL for $fileName, skipping");
          continue;
        }

        try {
          final remoteMetadata = await _getRemoteFileMetadata(url);
          if (remoteMetadata == null) {
            commonPrint.log("Failed to get metadata for $fileName from $url");
            continue;
          }

          final savedMetadata = await _getSavedMetadata(currentProfileId, key);

          if (!forceUpdate &&
              !_hasMetadataChanged(savedMetadata, remoteMetadata)) {
            commonPrint.log(
                "$fileName is up to date for profile $currentProfileId, skipping download");
            skippedCount++;
            continue;
          }

          final reason = forceUpdate ? "force update" : "metadata changed";
          commonPrint.log(
              "$fileName needs update for profile $currentProfileId ($reason), downloading from $url...");
          final result = await mihomoCore.updateGeoData(
            UpdateGeoDataParams(geoType: geoType, geoName: fileName),
          );

          if (result.isNotEmpty) {
            commonPrint.log("Failed to update $fileName: $result");
            continue;
          }

          await _saveMetadata(currentProfileId, key, remoteMetadata);
          commonPrint.log(
              "$fileName was successfully updated for profile $currentProfileId from $url");
          updatedCount++;
        } catch (e) {
          commonPrint.log("Failed to update $fileName: $e");
        }
      }
    } catch (e) {
      commonPrint.log("Failed to update geo files after profile update: $e");
    }
  }

  void setProfile(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
  }

  void setProfileAndAutoApply(Profile profile) {
    _ref.read(profilesProvider.notifier).setProfile(profile);
    if (profile.id == _ref.read(currentProfileIdProvider)) {
      applyProfileDebounce(silence: true);
    }
  }

  set profiles(List<Profile> value) {
    _ref.read(profilesProvider.notifier).value = value;
  }

  void addLog(Log log) {
    _ref.read(logsProvider).add(log);
  }

  void updateOrAddHotKeyAction(HotKeyAction hotKeyAction) {
    final actions = List.of(_ref.read(hotKeyActionsProvider));

    final index = actions.indexWhere(
      (item) => item.action == hotKeyAction.action,
    );

    if (index == -1) {
      actions.add(hotKeyAction);
    } else {
      actions[index] = hotKeyAction;
    }

    _ref.read(hotKeyActionsProvider.notifier).value = actions;
  }

  List<Group> getCurrentGroups() =>
      _ref.read(currentGroupsStateProvider.select((state) => state.value));

  String getRealTestUrl(String? url) => _ref.read(getRealTestUrlProvider(url));

  int getProxiesColumns() => _ref.read(getProxiesColumnsProvider);

  int addSortNum() => _ref.read(sortNumProvider.notifier).add();

  String? getCurrentGroupName() {
    final currentGroupName = _ref.read(currentProfileProvider.select(
      (state) => state?.currentGroupName,
    ));
    return currentGroupName;
  }

  ProxyCardState getProxyCardState(proxyName) =>
      _ref.read(getProxyCardStateProvider(proxyName));

  String? getSelectedProxyName(groupName) =>
      _ref.read(getSelectedProxyNameProvider(groupName));

  void updateCurrentGroupName(String groupName) {
    final profile = _ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) {
      return;
    }
    setProfile(
      profile.copyWith(currentGroupName: groupName),
    );
  }

  Future<void> updateMihomoConfig() async {
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    await commonScaffoldState?.loadingRun(() async {
      await _updateMihomoConfig();
    });
  }

  Future<void> _updateMihomoConfig() async {
    final updateParams = _ref.read(updateParamsProvider);
    final res = await _requestAdmin(updateParams.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    final message = await mihomoCore.updateConfig(
      updateParams.copyWith.tun(
        enable: realTunEnable,
      ),
    );
    if (message.isNotEmpty) throw message;
  }

  Future<Result<bool>> _requestAdmin(bool enableTun) async {
    final realTunEnable = _ref.read(realTunEnableProvider);
    var finalEnableTun = enableTun;
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          _ref.read(realTunEnableProvider.notifier).value = finalEnableTun;
          await restartCore();
          return Result.error("");
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          finalEnableTun = false;
          break;
      }
    }
    _ref.read(realTunEnableProvider.notifier).value = finalEnableTun;
    return Result.success(finalEnableTun);
  }

  Future<void> setupMihomoConfig() async {
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    await commonScaffoldState?.loadingRun(() async {
      await _setupMihomoConfig();
    });
  }

  Future<void> _setupMihomoConfig() async {
    await _ref.read(currentProfileProvider)?.checkAndUpdate();
    var patchConfig = _ref.read(patchMihomoConfigProvider);

    // Sync network settings from provider config if not overriding
    final appSetting = _ref.read(appSettingProvider);
    if (!appSetting.overrideNetworkSettings) {
      final syncedConfig =
          await globalState.syncNetworkSettingsFromProvider(patchConfig);
      // Always update provider when using provider settings to ensure UI reflects config
      _ref
          .read(patchMihomoConfigProvider.notifier)
          .updateState((state) => syncedConfig);
      patchConfig = syncedConfig;
    }

    // mihox-androidsecure header: on Android, when the current profile
    // declares "androidsecure: true", force mixedPort=0 on the Dart-side
    // MihomoConfig so that all downstream providers (coreStateProvider,
    // proxyStateProvider, http.handleFindProxy) observe the disabled inbound
    // and behave consistently with patchRawConfig's forced override. Applied
    // after syncFromProvider so it overrides both user and provider values.
    if (Platform.isAndroid) {
      final profile = _ref.read(currentProfileProvider);
      final secure = profile?.providerHeaders['mihox-androidsecure']
              ?.trim()
              .toLowerCase() ==
          'true';
      if (secure && patchConfig.mixedPort != 0) {
        patchConfig = patchConfig.copyWith(mixedPort: 0);
        _ref
            .read(patchMihomoConfigProvider.notifier)
            .updateState((state) => state.copyWith(mixedPort: 0));
      }
    }

    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) {
      return;
    }
    final realTunEnable = _ref.read(realTunEnableProvider);
    final realPatchConfig = patchConfig.copyWith.tun(enable: realTunEnable);
    final params = await globalState.getSetupParams(
      pathConfig: realPatchConfig,
    );
    final message = await mihomoCore.setupConfig(params);
    lastProfileModified = await _ref.read(
      currentProfileProvider.select(
        (state) => state?.profileLastModified,
      ),
    );
    if (message.isNotEmpty) {
      throw message;
    }
  }

  Future _applyProfile() async {
    mihomoCore.requestGc();
    await setupMihomoConfig();
    await updateGroups();
    await updateProviders();
  }

  Future applyProfile({bool silence = false}) async {
    if (silence) {
      await _applyProfile();
    } else {
      final commonScaffoldState = globalState.homeScaffoldKey.currentState;
      if (commonScaffoldState?.mounted != true) return;
      await commonScaffoldState?.loadingRun(() async {
        await _applyProfile();
      });
    }
    addCheckIpNumDebounce();
  }

  void handleChangeProfile() {
    _ref.read(delayDataSourceProvider.notifier).value = {};

    final currentProfileId = _ref.read(currentProfileIdProvider);
    if (currentProfileId != null) {
      final profiles = _ref.read(profilesProvider);
      final currentProfile = profiles.firstWhere(
        (p) => p.id == currentProfileId,
        orElse: () => profiles.first,
      );

      if (currentProfile.providerHeaders.isNotEmpty) {
        _applyAllHeaderSettings(currentProfile, isNewProfile: false);
      }
    }

    applyProfile();
    _ref.read(logsProvider.notifier).value = FixedList(500);
    _ref.read(requestsProvider.notifier).value = FixedList(500);
    globalState.cacheHeightMap = {};
    globalState.cacheScrollPosition = {};

    if (currentProfileId != null) {
      _updateGeoFilesAfterProfileUpdate(forceUpdate: true).catchError((e) {
        commonPrint.log("Error updating geo files on profile change: $e");
      });
    }
  }

  set brightness(Brightness value) {
    _ref.read(appBrightnessProvider.notifier).value = value;
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(
            profile.autoUpdateDuration,
          )
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString());
      }
    }
  }

  /// Updates subscription info for the current profile on app startup.
  /// This ensures the subscription info is always up-to-date when the app launches.
  Future<void> _updateCurrentProfileSubscription() async {
    try {
      final currentProfileId = _ref.read(currentProfileIdProvider);
      commonPrint.log(
          "_updateCurrentProfileSubscription: currentProfileId = $currentProfileId");
      if (currentProfileId == null) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: No current profile selected, skipping");
        return;
      }

      final profiles = _ref.read(profilesProvider);
      commonPrint.log(
          "_updateCurrentProfileSubscription: profiles count = ${profiles.length}");

      final currentProfile =
          profiles.where((p) => p.id == currentProfileId).firstOrNull;
      if (currentProfile == null) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: Profile not found in list, skipping");
        return;
      }

      if (currentProfile.type == ProfileType.file) {
        commonPrint.log(
            "_updateCurrentProfileSubscription: Profile is file type, skipping");
        return;
      }

      commonPrint.log(
          "Updating subscription info for current profile '${currentProfile.label}' on startup...");
      if (currentProfile.autoUpdate) {
        await updateProfile(currentProfile);
        commonPrint.log("Subscription info updated successfully");
      } else {
        commonPrint.log(
            "Auto-update disabled for current profile, skipping startup update");
      }
    } catch (e, stackTrace) {
      commonPrint
        ..log("Failed to update subscription info on startup: $e")
        ..log("Stack trace: $stackTrace");
    }
  }

  Future<void> updateGroups() async {
    try {
      final newGroups = await retry(
        task: () async => mihomoCore.getProxiesGroups(),
        retryIf: (res) => res.isEmpty,
      );

      if (newGroups.isNotEmpty) {
        _ref.read(groupsProvider.notifier).value = newGroups;
        _ref.read(versionProvider.notifier).value =
            _ref.read(versionProvider) + 1;
      } else {
        commonPrint
            .log("updateGroups: received empty groups, keeping old state");
      }
    } catch (e) {
      commonPrint.log("updateGroups error: $e, keeping old groups");
    }
  }

  Future<void> updateProfiles() async {
    for (final profile in _ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) {
        continue;
      }
      await updateProfile(profile);
    }
  }

  Future<void> savePreferences() async {
    commonPrint.log("save preferences");
    await preferences.saveConfig(globalState.config);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    await mihomoCore.changeProxy(
      ChangeProxyParams(
        groupName: groupName,
        proxyName: proxyName,
      ),
    );
    if (_ref.read(appSettingProvider).closeConnections) {
      mihomoCore.closeConnections();
    }
    addCheckIpNumDebounce();
  }

  Future<void> handleBackOrExit() async {
    if (_ref.read(backBlockProvider)) {
      return;
    }
    if (_ref.read(appSettingProvider).minimizeOnExit) {
      if (system.isDesktop) {
        savePreferencesDebounce();
      }
      await system.back();
    } else {
      await handleExit();
    }
  }

  void backBlock() {
    _ref.read(backBlockProvider.notifier).value = true;
  }

  void unBackBlock() {
    _ref.read(backBlockProvider.notifier).value = false;
  }

  Future<void> handleExit() async {
    _profileUpdateTimer?.cancel();
    Future.delayed(commonDuration, system.exit);
    try {
      await savePreferences();
      await proxy?.stopProxy();
      await mihomoCore.shutdown();
      await mihomoService?.destroy();
      if (Platform.isWindows) {
        //await windows?.stopService();
      }
    } finally {
      await system.exit();
    }
  }

  Future<void> handleRestart() async {
    commonPrint.log("Starting application restart...");

    if (Platform.isLinux || Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      commonPrint.log("Launching new process: $executablePath");

      try {
        await Process.start(
          executablePath,
          [],
          mode: ProcessStartMode.detached,
        );
        commonPrint.log("New process started, exiting old process...");
      } catch (e) {
        commonPrint.log("Failed to start new process: $e");
        return;
      }
    }

    await system.exit();
  }

  Future handleClear() async {
    try {
      // Stop proxy/VPN first
      await globalState.handleStop();
      commonPrint.log("stopped proxy/VPN");

      // Stop core
      await mihomoCore.shutdown();
      commonPrint.log("shutdown core");

      // Wait a bit for all file handles to close
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear preferences
      await preferences.clearPreferences();
      commonPrint.log("cleared preferences");

      // Get paths
      final homePath = await appPath.homeDirPath;
      final profilesPath = await appPath.profilesPath;

      // Delete profiles directory
      final profilesDir = Directory(profilesPath);
      if (profilesDir.existsSync()) {
        try {
          profilesDir.deleteSync(recursive: true);
          commonPrint.log("deleted profiles directory");
        } catch (e) {
          commonPrint.log("failed to delete profiles directory: $e");
        }
      }

      // Delete cache and temporary files
      final filesToDelete = [
        'cache.db',
        'libCachedImageData.json',
        'MihoX.lock',
      ];

      for (final fileName in filesToDelete) {
        final file = File(join(homePath, fileName));
        if (file.existsSync()) {
          try {
            file.deleteSync();
            commonPrint.log("deleted $fileName");
          } catch (e) {
            commonPrint.log("failed to delete $fileName: $e");
          }
        }
      }

      // Reset config
      globalState.config = const Config(
        themeProps: defaultThemeProps,
      );

      commonPrint.log("handleClear completed");

      // Close file logger to release file handles (MUST be last step)
      await fileLogger.dispose();
    } catch (e) {
      commonPrint.log("handleClear error: $e");
      await fileLogger.dispose();
      rethrow;
    }
  }

  Future<void> autoCheckUpdate() async {
    if (!_ref.read(appSettingProvider).autoCheckUpdate) return;
    final res = await request.checkForUpdate();
    await checkUpdateResultHandle(data: res);
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool handleError = false,
  }) async {
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final textTheme = context.textTheme;
      final res = await globalState.showMessage(
        title: appLocalizations.discoverNewVersion,
        message: TextSpan(
          text: "$tagName \n",
          style: textTheme.headlineSmall,
          children: [
            TextSpan(
              text: "\n",
              style: textTheme.bodyMedium,
            ),
            for (final submit in submits)
              TextSpan(
                text: "- $submit \n",
                style: textTheme.bodyMedium,
              ),
          ],
        ),
        confirmText: appLocalizations.goDownload,
      );
      if (res != true) {
        return;
      }
      UrlOpener.instance.open("https://github.com/$repository/releases/latest");
    } else if (handleError) {
      await globalState.showMessage(
        title: appLocalizations.checkUpdate,
        message: TextSpan(
          text: appLocalizations.checkUpdateError,
        ),
      );
    }
  }

  Future<void> _handlePreference() async {
    if (await preferences.isInit) {
      return;
    }
    final res = await globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.cacheCorrupt),
    );
    if (res == true) {
      final file = File(await appPath.sharedPreferencesPath);
      final isExists = file.existsSync();
      if (isExists) {
        file.deleteSync();
      }
    }
    await handleExit();
  }

  Future<void> _initCore() async {
    final isInit = await mihomoCore.isInit;
    if (!isInit) {
      await mihomoCore.init();
      await mihomoCore.setState(
        globalState.getCoreState(),
      );
    }
    await applyProfile();
  }

  Future<void> init() async {
    FlutterError.onError = (details) {
      commonPrint.log(details.stack.toString());
    };
    await updateTray(true);
    await _initCore();
    await _initStatus();
    await autoLaunch?.updateStatus(
      isAutoLaunch: _ref.read(appSettingProvider).autoLaunch,
    );
    // Delay subscription update to ensure network is ready after app initialization
    Future.delayed(
        const Duration(seconds: 1), _updateCurrentProfileSubscription);
    await autoUpdateProfiles();
    await autoCheckUpdate();
    if (!_ref.read(appSettingProvider).silentLaunch) {
      await window?.show();
    } else {
      await window?.hide();
    }

    await _handlePreference();
    _ref.read(initProvider.notifier).value = true;
  }

  Future<void> _initStatus() async {
    if (Platform.isAndroid) {
      await globalState.updateStartTime();
    }
    final status = globalState.isStart == true
        ? true
        : _ref.read(appSettingProvider).autoRun;

    await updateStatus(status);
    if (!status) {
      addCheckIpNumDebounce();
    }
  }

  void setDelay(Delay delay) {
    _ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  set page(PageLabel value) {
    _ref.read(currentPageLabelProvider.notifier).value = value;
  }

  void toProfiles() {
    page = PageLabel.profiles;
  }

  void initLink() {
    linkManager.initAppLinksListen(
      (url) async {
        final res = await globalState.showMessage(
          title: "${appLocalizations.add} ${appLocalizations.profile}",
          message: TextSpan(
            children: [
              TextSpan(text: appLocalizations.doYouWantToPass),
              TextSpan(
                text: " $url",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );

        if (res != true) {
          return;
        }
        await addProfileFormURL(url);
      },
    );
  }

  Future<void> addProfileFormURL(String url) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    page = PageLabel.dashboard;
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;

    try {
      final profile = await commonScaffoldState?.loadingRun<Profile>(
        () async {
          final prefs = await SharedPreferences.getInstance();
          final shouldSend = prefs.getBool('sendDeviceHeaders') ?? true;
          return Profile.normal(url: url).update(shouldSendHeaders: shouldSend);
        },
        title: "${appLocalizations.add}${appLocalizations.profile}",
      );

      if (profile != null) {
        _applyAllHeaderSettings(profile, isNewProfile: true);

        final headers = profile.providerHeaders;
        final showHwidLimit = headers['x-hwid-limit']?.toLowerCase() == 'true';
        final announceText = headers['announce'];
        if (showHwidLimit && announceText != null && announceText.isNotEmpty) {
          _showHwidLimitNotice(announceText, headers['support-url']);
        }

        await addProfile(profile);
      }
    } catch (err) {
      commonPrint.log('Add Profile Failed: $err');
      unawaited(
          globalState.showMessage(message: TextSpan(text: err.toString())));
    }
  }

  Future<Null> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    final bytes = await platformFile?.readAsBytes();
    if (bytes == null) {
      return null;
    }
    if (!context.mounted) return;
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    page = PageLabel.dashboard;
    final commonScaffoldState = globalState.homeScaffoldKey.currentState;
    if (commonScaffoldState?.mounted != true) return;
    final profile = await commonScaffoldState?.loadingRun<Profile?>(
      () async {
        await Future.delayed(const Duration(milliseconds: 300));
        return Profile.normal(label: platformFile?.name).saveFile(bytes);
      },
      title: "${appLocalizations.add}${appLocalizations.profile}",
    );
    if (profile != null) {
      await addProfile(profile);
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    await addProfileFormURL(url);
  }

  void updateViewSize(Size size) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ref.read(viewSizeProvider.notifier).value = size;
    });
  }

  void setProvider(ExternalProvider? provider) {
    _ref.read(providersProvider.notifier).setProvider(provider);
  }

  List<Proxy> _sortOfName(List<Proxy> proxies) => List.of(proxies)
    ..sort(
      (a, b) => utils.sortByChar(
        utils.getPinyin(a.name),
        utils.getPinyin(b.name),
      ),
    );

  List<Proxy> _sortOfDelay({
    required List<Proxy> proxies,
    String? testUrl,
  }) =>
      List.of(proxies)
        ..sort(
          (a, b) {
            final aDelay = _ref.read(getDelayProvider(
              proxyName: a.name,
              testUrl: testUrl,
            ));
            final bDelay = _ref.read(
              getDelayProvider(
                proxyName: b.name,
                testUrl: testUrl,
              ),
            );
            if (aDelay == null && bDelay == null) {
              return 0;
            }
            if (aDelay == null || aDelay == -1) {
              return 1;
            }
            if (bDelay == null || bDelay == -1) {
              return -1;
            }
            return aDelay.compareTo(bDelay);
          },
        );

  List<Proxy> getSortProxies(List<Proxy> proxies, [String? url]) =>
      switch (_ref.read(proxiesStyleSettingProvider).sortType) {
        ProxiesSortType.none => proxies,
        ProxiesSortType.delay => _sortOfDelay(
            proxies: proxies,
            testUrl: url,
          ),
        ProxiesSortType.name => _sortOfName(proxies),
      };

  Future<Null> clearEffect(String profileId) async {
    final profilePath = await appPath.getProfilePath(profileId);
    final providersDirPath = await appPath.getProvidersDirPath(profileId);
    return Isolate.run(() async {
      final profileFile = File(profilePath);
      final isExists = profileFile.existsSync();
      if (isExists) {
        unawaited(profileFile.delete(recursive: true));
      }
      final providersFileDir = File(providersDirPath);
      final providersFileIsExists = providersFileDir.existsSync();
      if (providersFileIsExists) {
        unawaited(providersFileDir.delete(recursive: true));
      }
    });
  }

  void updateTun() {
    _ref.read(patchMihomoConfigProvider.notifier).updateState(
          (state) => state.copyWith.tun(enable: !state.tun.enable),
        );
  }

  void updateSystemProxy() {
    _ref.read(networkSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            systemProxy: !state.systemProxy,
          ),
        );
  }

  void _applyCustomViewSettings(Profile profile) {
    final headers = profile.providerHeaders;

    final dashboardLayout = headers['mihox-widgets'];
    if (dashboardLayout != null && dashboardLayout.isNotEmpty) {
      final newLayout = DashboardWidgetParser.parseLayout(dashboardLayout);
      if (newLayout.isNotEmpty) {
        _ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(dashboardWidgets: newLayout),
            );
      }
    }

    final proxiesView = headers['mihox-view'];
    if (proxiesView != null && proxiesView.isNotEmpty) {
      _ref
          .read(proxiesStyleSettingProvider.notifier)
          .updateState((currentState) {
        var newState = currentState;
        final settings = proxiesView.split(';');
        for (final setting in settings) {
          final parts = setting.split(':');
          if (parts.length == 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts[1].trim().toLowerCase();
            switch (key) {
              case 'type':
                switch (value) {
                  case 'list':
                    newState = newState.copyWith(type: ProxiesType.list);
                    break;
                  case 'tab':
                    newState = newState.copyWith(type: ProxiesType.tab);
                    break;
                }
                break;
              case 'sort':
                switch (value) {
                  case 'none':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.none);
                    break;
                  case 'delay':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.delay);
                    break;
                  case 'name':
                    newState =
                        newState.copyWith(sortType: ProxiesSortType.name);
                    break;
                }
                break;
              case 'layout':
                switch (value) {
                  case 'loose':
                    newState = newState.copyWith(layout: ProxiesLayout.loose);
                    break;
                  case 'standard':
                    newState =
                        newState.copyWith(layout: ProxiesLayout.standard);
                    break;
                  case 'tight':
                    newState = newState.copyWith(layout: ProxiesLayout.tight);
                    break;
                }
                break;
              case 'icon':
                switch (value) {
                  case 'standard':
                  case 'icon':
                    newState =
                        newState.copyWith(iconStyle: ProxiesIconStyle.icon);
                    break;
                  case 'none':
                    newState =
                        newState.copyWith(iconStyle: ProxiesIconStyle.none);
                    break;
                }
                break;
              case 'card':
                switch (value) {
                  case 'expand':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.expand);
                    break;
                  case 'shrink':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.shrink);
                    break;
                  case 'min':
                    newState = newState.copyWith(cardType: ProxyCardType.min);
                    break;
                  case 'oneline':
                    newState =
                        newState.copyWith(cardType: ProxyCardType.oneline);
                    break;
                }
                break;
            }
          }
        }
        return newState;
      });
    }
  }

  Future<List<Package>> getPackages() async {
    if (_ref.read(isMobileViewProvider)) {
      await Future.delayed(commonDuration);
    }
    if (_ref.read(packagesProvider).isEmpty) {
      _ref.read(packagesProvider.notifier).value =
          await app?.getPackages() ?? [];
    }
    return _ref.read(packagesProvider);
  }

  void updateStart() {
    updateStatus(!_ref.read(runTimeProvider.notifier).isStart);
  }

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(
        currentProfile.selectedMap,
      )..[groupName] = proxyName;
      _ref.read(profilesProvider.notifier).setProfile(
            currentProfile.copyWith(
              selectedMap: selectedMap,
            ),
          );
    }
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      return;
    }
    _ref.read(profilesProvider.notifier).setProfile(
          currentProfile.copyWith(
            unfoldSet: value,
          ),
        );
  }

  void changeMode(Mode mode) {
    _ref.read(patchMihomoConfigProvider.notifier).updateState(
          (state) => state.copyWith(mode: mode),
        );
    if (mode == Mode.global) {
      updateCurrentGroupName(GroupName.GLOBAL.name);
    }
    addCheckIpNumDebounce();
  }

  void updateAutoLaunch() {
    _ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(
            autoLaunch: !state.autoLaunch,
          ),
        );
  }

  void updateTheme(ThemeProps themeProps) {
    _ref.read(themeSettingProvider.notifier).updateState((_) => themeProps);
  }

  Future<void> updateVisible() async {
    final visible = await window?.isVisible;
    if (visible != null && !visible) {
      await window?.show();
    } else {
      await window?.hide();
    }
  }

  void updateMode() {
    _ref.read(patchMihomoConfigProvider.notifier).updateState(
      (state) {
        final index = Mode.values.indexWhere((item) => item == state.mode);
        if (index == -1) {
          return null;
        }
        final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
        return state.copyWith(
          mode: Mode.values[nextIndex],
        );
      },
    );
  }

  Future<void> handleAddOrUpdate(WidgetRef ref, [Rule? rule]) async {
    final res = await globalState.showCommonDialog<Rule>(
      child: AddRuleDialog(
        rule: rule,
        snippet: ref.read(
          profileOverrideStateProvider.select(
            (state) => state.snippet!,
          ),
        ),
      ),
    );
    if (res == null) {
      return;
    }
    ref.read(profileOverrideStateProvider.notifier).updateState(
      (state) {
        final model = state.copyWith.overrideData!(
          rule: state.overrideData!.rule.updateRules(
            (rules) {
              final index = rules.indexWhere((item) => item.id == res.id);
              if (index == -1) {
                return List.from([res, ...rules]);
              }
              return List.from(rules)..[index] = res;
            },
          ),
        );
        return model;
      },
    );
  }

  Future<bool> exportLogs() async {
    final logsRaw = _ref.read(logsProvider).list.map(
          (item) => item.toString(),
        );
    final data = await Isolate.run<List<int>>(() async {
      final logsRawString = logsRaw.join("\n");
      return utf8.encode(logsRawString);
    });
    return await picker.saveFile(
          utils.logFile,
          Uint8List.fromList(data),
        ) !=
        null;
  }

  Future<List<int>> backupData() async {
    final homeDirPath = await appPath.homeDirPath;
    final profilesPath = await appPath.profilesPath;
    final configJson = globalState.config.toJson();
    return Isolate.run<List<int>>(() async {
      final archive = Archive()
        ..addJson("config.json", configJson)
        ..addDirectoryToArchive(profilesPath, homeDirPath);
      final zipEncoder = ZipEncoder();
      return zipEncoder.encode(archive);
    });
  }

  Future<void> updateTray([bool focus = false]) async {
    await tray.update(
      trayState: _ref.read(trayStateProvider),
    );
  }

  Future<void> recoveryData(
    List<int> data,
    RecoveryOption recoveryOption,
  ) async {
    final archive = await Isolate.run<Archive>(() {
      final zipDecoder = ZipDecoder();
      return zipDecoder.decodeBytes(data);
    });
    final homeDirPath = await appPath.homeDirPath;
    final configs =
        archive.files.where((item) => item.name.endsWith(".json")).toList();
    final profiles =
        archive.files.where((item) => !item.name.endsWith(".json"));
    final configIndex =
        configs.indexWhere((config) => config.name == "config.json");
    if (configIndex == -1) throw "invalid backup file";
    final configFile = configs[configIndex];
    var tempConfig = Config.compatibleFromJson(
      json.decode(
        utf8.decode(configFile.content),
      ),
    );
    for (final profile in profiles) {
      if (!profile.isFile) continue;
      final filePath = join(homeDirPath, profile.name);
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(profile.content);
    }
    final mihomoConfigIndex =
        configs.indexWhere((config) => config.name == "mihomoConfig.json");
    if (mihomoConfigIndex != -1) {
      final mihomoConfigFile = configs[mihomoConfigIndex];
      tempConfig = tempConfig.copyWith(
        patchMihomoConfig: MihomoConfig.fromJson(
          json.decode(
            utf8.decode(
              mihomoConfigFile.content,
            ),
          ),
        ),
      );
    }
    _recovery(
      tempConfig,
      recoveryOption,
    );
  }

  void _recovery(Config config, RecoveryOption recoveryOption) {
    final recoveryStrategy = _ref.read(appSettingProvider.select(
      (state) => state.recoveryStrategy,
    ));
    final profiles = config.profiles;
    if (recoveryStrategy == RecoveryStrategy.override) {
      _ref.read(profilesProvider.notifier).value = profiles;
    } else {
      for (final profile in profiles) {
        _ref.read(profilesProvider.notifier).setProfile(
              profile,
            );
      }
    }
    final onlyProfiles = recoveryOption == RecoveryOption.onlyProfiles;
    if (!onlyProfiles) {
      _ref.read(patchMihomoConfigProvider.notifier).value =
          config.patchMihomoConfig;
      _ref.read(appSettingProvider.notifier).value = config.appSetting;
      _ref.read(currentProfileIdProvider.notifier).value =
          config.currentProfileId;
      _ref.read(themeSettingProvider.notifier).value = config.themeProps;
      _ref.read(windowSettingProvider.notifier).value = config.windowProps;
      _ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      _ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyle;
      _ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      _ref.read(networkSettingProvider.notifier).value = config.networkProps;
      _ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
      _ref.read(scriptStateProvider.notifier).value = config.scriptProps;
    }
    final currentProfile = _ref.read(currentProfileProvider);
    if (currentProfile == null) {
      _ref.read(currentProfileIdProvider.notifier).value = profiles.first.id;
    }
    savePreferencesDebounce();
  }
}
