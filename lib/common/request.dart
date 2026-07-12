import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/models/models.dart';
import 'package:mihox/state.dart';

class Request {
  Request() {
    _dio = Dio(
      BaseOptions(
        headers: {
          "User-Agent": browserUa,
        },
      ),
    );
    _mihomoDio = Dio();
    _mihomoDio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) {
        client.userAgent = globalState.ua;
        return MihoXHttpOverrides.handleFindProxy(uri);
      };
      return client;
    });
  }
  late final Dio _dio;
  late final Dio _mihomoDio;
  String? userAgent;

  Future<Response<Uint8List>> getFileResponseForUrl(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    final requestHeaders = {
      ...?headers,
      'User-Agent': globalState.ua,
    };

    return _dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: requestHeaders,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  Future<Response> getTextResponseForUrl(String url) async {
    final response = await _mihomoDio.get(
      url,
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    final response = await _dio.get(
      "https://api.github.com/repos/$repository/releases/latest",
      options: Options(
        responseType: ResponseType.json,
      ),
    );
    if (response.statusCode != 200) return null;
    final data = response.data as Map<String, dynamic>;
    final remoteVersion = (data['tag_name'] as String).replaceAll('v', '');
    final version = globalState.packageInfo.version;
    final hasUpdate = utils.compareVersions(remoteVersion, version) > 0;
    if (!hasUpdate) return null;
    return data;
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    "https://ipwho.is/": IpInfo.fromIpwhoIsJson,
    "https://api.ip.sb/geoip/": IpInfo.fromIpSbJson,
    "https://ipapi.co/json/": IpInfo.fromIpApiCoJson,
    "https://ipinfo.io/json/": IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
  final dio = Dio();
  final raceCancelToken = CancelToken();

  unawaited(cancelToken?.whenCancel.then((_) {
    if (!raceCancelToken.isCancelled) {
      raceCancelToken.cancel();
    }
  }));

  final completer = Completer<Result<IpInfo?>>();
  var pending = _ipInfoSources.length;
  final errors = <String>[];

  void recordFailure(String source, Object error) {
    errors.add('$source: $error');
    pending--;
    if (pending == 0 && !completer.isCompleted) {
      completer.complete(
        Result.error('All IP info sources failed:\n${errors.join('\n')}'),
      );
    }
  }

  for (final entry in _ipInfoSources.entries) {
    unawaited(() async {
      try {
        final res = await dio.get<Map<String, dynamic>>(
          entry.key,
          cancelToken: raceCancelToken,
          options: Options(
            responseType: ResponseType.json,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );

        if (completer.isCompleted) return;

        if (res.statusCode != HttpStatus.ok || res.data == null) {
          recordFailure(entry.key, 'HTTP ${res.statusCode}');
          return;
        }

        final ipInfo = entry.value(res.data!);
        if (!completer.isCompleted) {
          completer.complete(Result.success(ipInfo));
        }
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) {
          return;
        }
        if (!completer.isCompleted) {
          recordFailure(entry.key, e);
        }
      }
    }());
  }

  final result = await completer.future;
  if (!raceCancelToken.isCancelled) {
    raceCancelToken.cancel('IP lookup finished, cancelling remaining requests');
  }
  return result;
}

  Future<bool> pingHelper() async {
    try {
      final response = await _dio
          .get(
            "http://$localhost:$helperPort/ping",
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final homeDirPath = await appPath.homeDirPath;
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/start",
            data: json.encode({
              "path": appPath.corePath,
              "arg": arg,
              "home_dir": homeDirPath,
            }),
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/stop",
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));

      if (response.statusCode != HttpStatus.ok) return false;
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCoreVersion() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>(
            "http://$defaultExternalController/version",
            options: Options(
              responseType: ResponseType.json,
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != HttpStatus.ok) return null;
      return response.data;
    } catch (_) {
      return null;
    }
  }
}

final request = Request();
