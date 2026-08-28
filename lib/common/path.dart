import 'dart:async';
import 'dart:io';

import 'package:mihox/common/common.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppPath {
  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    getApplicationSupportDirectory()
        .then((value) {
          dataDir.complete(value);
        })
        .catchError((e) {
          dataDir.completeError(e);
        });
    getTemporaryDirectory()
        .then((value) {
          tempDir.complete(value);
        })
        .catchError((e) {
          tempDir.completeError(e);
        });
    if (!Platform.isAndroid) {
      getDownloadsDirectory()
          .then((value) {
            downloadDir.complete(value);
          })
          .catchError((e) {
            downloadDir.completeError(e);
          });
    } else {
      getApplicationSupportDirectory()
          .then((value) {
            downloadDir.complete(Directory('${value.parent.path}/Download'));
          })
          .catchError((e) {
            downloadDir.completeError(e);
          });
    }
  }
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  late String appDirPath;

  String get executableExtension => Platform.isWindows ? ".exe" : "";

  String get executableDirPath => dirname(Platform.resolvedExecutable);

  String get corePath =>
      join(executableDirPath, "MihoXCore$executableExtension");

  String get corePendingPath => '$corePath.pending';

  /// Allow-list consumed by the Windows helper service; lives next to the
  /// helper exe so per-machine installs keep it admin-writable only.
  String get allowedCoreHashPath =>
      join(executableDirPath, "allowed_core.sha256");

  String get helperPath =>
      join(executableDirPath, "$appHelperService$executableExtension");

  Future<String> get downloadDirPath async => (await downloadDir.future).path;

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get lockFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, "MihoX.lock");
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory.path, "shared_preferences.json");
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, profilesDirectoryName);
  }

  Future<String> getProfilePath(String id) async {
    final directory = await profilesPath;
    return join(directory, "$id.yaml");
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(directory, "providers", id);
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(directory, "providers", id, type, url.toMd5());
  }

  Future<String> get tempPath async => (await tempDir.future).path;
}

final appPath = AppPath();
