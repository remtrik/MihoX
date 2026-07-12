import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';

class Utils {
  String decodeBase64(String value) {
    try {
      return utf8
          .decode(
            base64.decode(base64.normalize(value)),
          )
          .trim();
    } catch (_) {
      // not a base64
      return value.trim();
    }
  }

  Color? getDelayColor(int? delay) {
    if (delay == null) return null;
    if (delay < 0) return Colors.red;
    if (delay < 600) return Colors.green;
    return const Color(0xFFC57F0A);
  }

  String get id {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random();
    final randomStr =
        String.fromCharCodes(List.generate(8, (_) => random.nextInt(26) + 97));
    return "$timestamp$randomStr";
  }

  String getDateStringLast2(int value) {
    final valueRaw = "0$value";
    return valueRaw.substring(
      valueRaw.length - 2,
    );
  }

  String generateRandomString({int minLength = 10, int maxLength = 100}) {
    const latinChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();

    final length = minLength + random.nextInt(maxLength - minLength + 1);

    var result = '';
    for (var i = 0; i < length; i++) {
      if (random.nextBool()) {
        result +=
            String.fromCharCode(0x4E00 + random.nextInt(0x9FA5 - 0x4E00 + 1));
      } else {
        result += latinChars[random.nextInt(latinChars.length)];
      }
    }

    return result;
  }

  String get uuidV4 {
    final random = Random();
    final bytes = List.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  String _formatHms(int hours, int minutes, int seconds) =>
      "${getDateStringLast2(hours)}:${getDateStringLast2(minutes)}:${getDateStringLast2(seconds)}";

  String getTimeDifference(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    return _formatHms(
      difference.inHours,
      difference.inMinutes,
      difference.inSeconds,
    );
  }

  String getTimeText(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final totalSeconds = (timeStamp / 1000).floor();

    const maxSeconds = 31 * 86400 + 23 * 3600 + 59 * 60 + 59;
    if (totalSeconds >= maxSeconds) return "Seriously?";

    final days = (totalSeconds / 86400).floor();
    final hours = ((totalSeconds % 86400) / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final hms = _formatHms(hours, minutes, seconds);

    return days == 0 ? hms : "${days}d $hms";
  }

  Locale? getLocaleForString(String? localString) {
    if (localString == null) return null;
    final parts = localString.split("_");
    return switch (parts.length) {
      1 => Locale(parts[0]),
      2 => Locale(parts[0], parts[1]),
      3 => Locale.fromSubtags(
          languageCode: parts[0],
          scriptCode: parts[1],
          countryCode: parts[2],
        ),
      _ => null,
    };
  }

  int sortByChar(String a, String b) {
    if (a.isEmpty && b.isEmpty) {
      return 0;
    }
    if (a.isEmpty) {
      return -1;
    }
    if (b.isEmpty) {
      return 1;
    }
    final charA = a[0];
    final charB = b[0];

    if (charA == charB) {
      return sortByChar(a.substring(1), b.substring(1));
    } else {
      return charA.compareToLower(charB);
    }
  }

  String getOverwriteLabel(String label) {
    final reg = RegExp(r'\((\d+)\)$');
    final matches = reg.allMatches(label);
    if (matches.isEmpty) return "$label(1)";

    final match = matches.last;
    final number = int.parse(match[1] ?? '0') + 1;
    return label.replaceFirst(reg, '($number)', label.length - 3 - 1);
  }

  String getTrayIconPath({
    required Brightness brightness,
    bool isRunning = false,
  }) {
    // When running - use colored icon
    if (isRunning) return "assets/images/icon.ico";

    // When stopped - use stop icons based on theme
    return switch (brightness) {
      Brightness.dark => "assets/images/icon_stop_white.ico",
      Brightness.light => "assets/images/icon_stop_black.ico",
    };
  }

  int compareVersions(String version1, String version2) {
    List<int> parts(String v) => v.split('+')[0].split('.').map(int.parse).toList();
    int build(String v) => v.contains('+') ? int.parse(v.split('+')[1]) : 0;

    final v1 = parts(version1);
    final v2 = parts(version2);
    for (var i = 0; i < 3; i++) {
      final a = i < v1.length ? v1[i] : 0;
      final b = i < v2.length ? v2[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return build(version1).compareTo(build(version2));
  }

  String getPinyin(String value) => value.isNotEmpty
      ? PinyinHelper.getFirstWordPinyin(value.substring(0, 1))
      : "";

  String? getFileNameForDisposition(String? disposition) {
    if (disposition == null) return null;
    final parameters = HeaderValue.parse(disposition).parameters;

    final encoded = parameters["filename*"];
    if (encoded != null) {
      final parts = encoded.split("''");
      if (parts.length >= 2) return Uri.decodeComponent(parts[1]);
    }

    return parameters["filename"];
  }

  FlutterView getScreen() =>
      WidgetsBinding.instance.platformDispatcher.views.first;

  List<String> parseReleaseBody(String? body) {
    if (body == null) return [];
    const pattern = r'- \s*(.*)';
    final regex = RegExp(pattern);
    return regex
        .allMatches(body)
        .map((match) => match.group(1) ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  ViewMode getViewMode(double viewWidth) {
    if (viewWidth <= maxMobileWidth) return ViewMode.mobile;
    if (viewWidth <= maxLaptopWidth) return ViewMode.laptop;
    return ViewMode.desktop;
  }

  int getProxiesColumns(double viewWidth, ProxiesLayout proxiesLayout) {
    final columns = max((viewWidth / 300).ceil(), 2);
    return switch (proxiesLayout) {
      ProxiesLayout.tight => columns + 1,
      ProxiesLayout.standard => columns,
      ProxiesLayout.loose => columns - 1,
    };
  }

  int getProfilesColumns(double viewWidth) => max((viewWidth / 320).floor(), 1);

  final _indexPrimary = [
    50,
    100,
    200,
    300,
    400,
    500,
    600,
    700,
    800,
    850,
    900,
  ];

  MaterialColor _createPrimarySwatch(Color color) {
    final swatch = <int, Color>{};
    final a = color.alpha8bit;
    final r = color.red8bit;
    final g = color.green8bit;
    final b = color.blue8bit;
    for (final strength in _indexPrimary) {
      final ds = 0.5 - strength / 1000;
      swatch[strength] = Color.fromARGB(
        a,
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      );
    }
    swatch[50] = swatch[50]!.lighten(18);
    swatch[100] = swatch[100]!.lighten(16);
    swatch[200] = swatch[200]!.lighten(14);
    swatch[300] = swatch[300]!.lighten(10);
    swatch[400] = swatch[400]!.lighten(6);
    swatch[700] = swatch[700]!.darken(2);
    swatch[800] = swatch[800]!.darken(3);
    swatch[900] = swatch[900]!.darken(4);
    return MaterialColor(color.value32bit, swatch);
  }

  List<Color> getMaterialColorShades(Color color) {
    final swatch = _createPrimarySwatch(color);
    return [
      for (final strength in _indexPrimary)
        if (swatch[strength] != null) swatch[strength]!,
    ];
  }

  String getBackupFileName() => "${appName}_backup_${DateTime.now().show}.zip";

  String get logFile => "${appName}_${DateTime.now().show}.log";

  int _prioritize(bool a, bool b) => a == b ? 0 : (a ? -1 : 1);

  Future<String?> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(includeLoopback: false)
      ..sort((a, b) {
        final wifi = _prioritize(a.isWifi, b.isWifi);
        return wifi != 0 ? wifi : _prioritize(a.includesIPv4, b.includesIPv4);
      });

    for (final interface in interfaces) {
      final addresses = interface.addresses;
      if (addresses.isEmpty) continue;
      addresses.sort((a, b) => _prioritize(a.isIPv4, b.isIPv4));
      return addresses.first.address;
    }
    return "";
  }

  SingleActivator controlSingleActivator(LogicalKeyboardKey trigger) {
    const control = true;
    return SingleActivator(
      trigger,
      control: control,
      meta: !control,
    );
  }

  FutureOr<T> handleWatch<T>(FutureOr<T> Function() function) async {
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      final res = await function();
      stopwatch.stop();
      commonPrint.log('耗时：${stopwatch.elapsedMilliseconds} ms');
      return res;
    }
    return await function();
  }
}

final utils = Utils();
