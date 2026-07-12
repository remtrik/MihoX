import 'package:mihox/common/app_localizations.dart';

extension DateTimeExtension on DateTime {
  bool get isBeforeNow => isBefore(DateTime.now());

  bool isBeforeSecure(DateTime? dateTime) => dateTime != null;

  String get lastUpdateTimeDesc {
    final difference = DateTime.now().difference(this);

    final units = <(int, String)>[
      (difference.inDays ~/ 365, appLocalizations.years),
      (difference.inDays ~/ 30, appLocalizations.months),
      (difference.inDays, appLocalizations.days),
      (difference.inHours, appLocalizations.hours),
      (difference.inMinutes, appLocalizations.minutes),
    ];

    for (final (value, unit) in units) {
      if (value >= 1) return "$value $unit${appLocalizations.ago}";
    }
    return appLocalizations.just;
  }

  String get show => toIso8601String().substring(0, 10);
}
