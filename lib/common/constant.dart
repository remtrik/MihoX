import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:mihox/models/models.dart';

const appName = "MihoX";
const appHelperService = "MihoXHelperService";
const coreName = "mihomo";
const browserUa =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const packageName = "org.remtrik.mihox";
final unixSocketPath = "/tmp/MihoXSocket_${Random.secure().nextInt(1 << 30)}.sock";
const helperPort = 47890;
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const mmdbFileName = "geoip.metadb";
const asnFileName = "ASN.mmdb";
const geoIpFileName = "GeoIP.dat";
const geoSiteFileName = "GeoSite.dat";
final double kHeaderHeight = system.isDesktop ? 40 : 0;
const profilesDirectoryName = "profiles";
const localhost = "127.0.0.1";
const mihomoConfigKey = "mihomo_config";
const configKey = "config";
const double dialogCommonWidth = 300;
const repository = "remtrik/MihoX";
const defaultExternalController = "127.0.0.1:9090";
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = "https://www.gstatic.com/generate_204";
final commonFilter = ImageFilter.blur(
  sigmaX: 2.5,
  sigmaY: 2.5,
  tileMode: TileMode.mirror,
);

const navigationItemListEquality = ListEquality<NavigationItem>();
const connectionListEquality = ListEquality<Connection>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

// const proxiesStoreKey = PageStorageKey<String>('proxies');
// const toolsStoreKey = PageStorageKey<String>('tools');
// const profilesStoreKey = PageStorageKey<String>('profiles');

const defaultPrimaryColor = 0xFF03A9F4;

double getWidgetHeight(num lines) => max(lines * 84 + (lines - 1) * 16, 0).ap;

const maxLength = 150;

const int defaultMixedPort = 7890;
const int defaultPort = 0;
const int minPortValue = 1024;
const int maxPortValue = 49151;
const int groupUpdateIntervalSeconds = 60;
const int autoUpdateProfilesIntervalMinutes = 20;
const int startupSubscriptionDelaySeconds = 1;
const int initTimeoutSeconds = 15;
const int getAndroidVpnOptionsTimeoutSeconds = 10;
const int startVpnTimeoutSeconds = 60;
const int stopVpnTimeoutSeconds = 20;
const int quickStartTimeoutSeconds = 60;
const int getCurrentProfileNameTimeoutSeconds = 10;
const int updateNotificationParamsTimeoutSeconds = 10;
const int saveParamsTimeoutSeconds = 15;
const int updateDnsTimeoutSeconds = 10;
const int getRunTimeTimeoutSeconds = 10;
const int updateConfigTimeoutMinutes = 2;
const int setupConfigTimeoutMinutes = 2;
const int updateGeoDataTimeoutSeconds = 100;
const int updateExternalProviderTimeoutMinutes = 1;
const int getProxiesTimeoutSeconds = 5;
const int asyncTestDelayTimeoutMs = 5000;
const int debounceDefaultMs = 300;
const int debounceCheckIpMs = 1200;
const int debounceManualCheckCooldownSeconds = 15;
const int debounceJustStartedDelayMs = 2000;
const int debounceSetTimeoutMs = 300;
const int syncVpnStateResumeDelayMs = 300;
const int crashRetryBaseMs = 1000;
const int crashRetryMaxRetries = 5;
const int crashRetryCooldownSeconds = 60;
const int tileWaitForCoreInitRetries = 30;
const int tileWaitForCoreInitDelayMs = 500;
const int maxLogFiles = 100;
const int defaultKeepAliveInterval = 30;
const int profilesColumnsDivisor = 320;
const int dashboardColumnsDivisor = 320;
const int dashboardColumnsMultiplier = 4;
const int dashboardMinColumns = 8;
const int proxiesColumnsDivisor = 300;
const int toastDurationMs = 300;
const int exportSuccessDelayMs = 300;
const int windowShowDelayMs = 300;
const int restartCoreTimeoutSeconds = 3;
const int handleExitTimeoutSeconds = 8;
const int handleRestartTimeoutSeconds = 3;
const int shutdownGracePeriodMs = 500;
const int clearPreferencesDelayMs = 500;
const double maxTextScaleFactor = 1.4;
const double minTextScaleFactor = 0.8;
const int maxMobileWidthPx = 600;
const int maxLaptopWidthPx = 840;
const int profilesColumnsMin = 1;
const int proxiesColumnsMin = 2;

const defaultPrimaryColors = [
  0xFF795548,
  defaultPrimaryColor,
  0xFFFFFF00,
  0XFFBBC9CC,
  0XFFABD397,
  0XFFD8C0C3,
  0XFF665390,
];

const scriptTemplate = """
const main = (config) => {
  return config;
}""";

const int setUiActiveTimeoutSeconds = 2;
const int shutdownTimeoutSeconds = 1;
const int healthCheckTimeoutSeconds = 30;
const int getConfigTimeoutMinutes = 2;