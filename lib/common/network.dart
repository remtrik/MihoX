import 'dart:io';

extension NetworkInterfaceExt on NetworkInterface {
  bool get isWifi {
    final nameLowCase = name.toLowerCase();
    return nameLowCase.contains('wlan') ||
        nameLowCase.contains('wi-fi') ||
        nameLowCase == 'en0' ||
        nameLowCase == 'eth0';
  }

  bool get includesIPv4 => addresses.any((addr) => addr.isIPv4);
}

extension InternetAddressExt on InternetAddress {
  bool get isIPv4 => type == InternetAddressType.IPv4;
}
