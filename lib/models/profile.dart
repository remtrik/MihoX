// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/mihomo/core.dart';
import 'package:mihox/utils/device_info_service.dart';

import 'mihomo_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final list = info.split(";");
    final map = <String, int?>{};
    for (final i in list) {
      final keyValue = i.trim().split("=");
      map[keyValue[0]] = int.tryParse(keyValue[1]);
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
    @Default({}) Map<String, String> providerHeaders,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) =>
      Profile(
        label: label,
        url: url,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autoUpdateDuration: defaultUpdateDuration,
      );
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    final profilePath = await appPath.getProfilePath(id);
    return File(profilePath).existsSync();
  }

  Future<File> getFile() async {
    final path = await appPath.getProfilePath(id);
    final file = File(path);
    final isExists = file.existsSync();
    if (!isExists) {
      file.createSync(recursive: true);
    }
    return file;
  }

  Future<int> get profileLastModified async {
    final file = await getFile();
    return (file.lastModifiedSync()).microsecondsSinceEpoch;
  }

  Future<Profile> update({bool shouldSendHeaders = true}) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      throw Exception("Invalid URL");
    }

    switch (uri.scheme.toLowerCase()) {
      case 'http':
      case 'https':
        break;
      default:
        throw Exception("Raw ${uri.scheme}:// links are not yet supported");
    }

    final headers = <String, dynamic>{};

    if (shouldSendHeaders) {
      final deviceInfoService = DeviceInfoService();
      final details = await deviceInfoService.getDeviceDetails();

      if (details.hwid != null) headers['x-hwid'] = details.hwid;
      if (details.os != null) headers['x-device-os'] = details.os;
      if (details.osVersion != null) headers['x-ver-os'] = details.osVersion;
      if (details.model != null) headers['x-device-model'] = details.model;
    }

    final response = await request.getFileResponseForUrl(
      url,
      headers: headers.isNotEmpty ? headers : null,
    );

    final disposition = response.headers.value("content-disposition");
    final userinfo = response.headers.value('subscription-userinfo');

    final responseData = response.data;
    if (responseData == null) {
      throw Exception("Failed to get profile data from response.");
    }

    final providerHeaders = <String, String>{};

    final headersToCollect = [
      'announce',
      'support-url',
      'profile-title',
      'profile-update-interval',
      'x-hwid-limit',
    ];

    for (final headerName in headersToCollect) {
      final value = response.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        providerHeaders[headerName] = value;
      }
    }

    for (final entry in response.headers.map.entries) {
      var name = entry.key.toLowerCase();
      final values = entry.value;

      if (values.isEmpty) continue;

      if (name.startsWith('flclashx-')) {
        name = 'mihox-${name.substring('flclashx-'.length)}';
      }

      if (name.startsWith('mihox-')) {
        providerHeaders[name] = values.first;
      }
    }

    Duration? durationFromHeader;
    final updateIntervalHeader = providerHeaders['profile-update-interval'];
    if (updateIntervalHeader != null) {
      final hours = int.tryParse(updateIntervalHeader);
      if (hours != null && hours > 0) {
        durationFromHeader = Duration(hours: hours);
      }
    }

    var profileNameHeader = providerHeaders['profile-title'];
    if (profileNameHeader == null || profileNameHeader.isEmpty) {
      profileNameHeader = utils.getFileNameForDisposition(disposition) ?? id;
    } else if (profileNameHeader.startsWith('base64:')) {
      profileNameHeader = utils.decodeBase64(profileNameHeader.substring(7));
    }

    return copyWith(
      label: label ?? profileNameHeader,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      autoUpdateDuration: durationFromHeader ?? autoUpdateDuration,
      providerHeaders: providerHeaders,
    ).saveFile(responseData);
  }

  Future<Profile> saveFile(Uint8List bytes) async {
    final message = await mihomoCore.validateConfig(utf8.decode(bytes));
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    await file.writeAsBytes(bytes);
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<Profile> saveFileWithString(String value) async {
    final message = await mihomoCore.validateConfig(value);
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    await file.writeAsString(value);
    return copyWith(lastUpdateDate: DateTime.now());
  }
}
