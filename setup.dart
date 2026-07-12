// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

enum Target {
  windows,
  linux,
  android,
}

extension TargetExt on Target {
  String get os => name;

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = ".so";
        break;
      case Target.windows:
        extensionName = ".dll";
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = ".exe";
        break;
      default:
        extensionName = "";
        break;
    }
    return extensionName;
  }
}

enum Mode { core, lib }

enum Arch { amd64, arm64, arm }

class BuildItem {
  BuildItem({
    required this.target,
    this.arch,
    this.archName,
  });
  Target target;
  Arch? arch;
  String? archName;

  @override
  String toString() =>
      'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
}

class Build {
  static List<BuildItem> get buildItems => [
        BuildItem(
          target: Target.linux,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm,
          archName: 'armeabi-v7a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm64,
          archName: 'arm64-v8a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.amd64,
          archName: 'x86_64',
        ),
      ];

  static String get appName => "MihoX";

  static String get coreName => "MihoXCore";

  static String get libName => "libmihomo";

  static String get outDir => join(current, libName);

  static String get _coreDir => join(current, "core");

  static String get _servicesDir => join(current, "services", "helper");

  static String get distPath => join(current, "dist");

  static String _getCc(BuildItem buildItem) {
    final environment = Platform.environment;
    if (buildItem.target == Target.android) {
      final ndk = environment["ANDROID_NDK"] ?? environment["ANDROID_NDK_HOME"];
      if (ndk == null || ndk.isEmpty) {
        throw "ANDROID_NDK or ANDROID_NDK_HOME environment variable is not set. Please set it to your Android NDK path.";
      }
      final prebuiltDir =
          Directory(join(ndk, "toolchains", "llvm", "prebuilt"));
      if (!prebuiltDir.existsSync()) {
        throw "Android NDK path is invalid: ${prebuiltDir.path}";
      }
      final prebuiltDirList =
          prebuiltDir.listSync().whereType<Directory>().toList();
      if (prebuiltDirList.isEmpty) {
        throw "No prebuilt directories found under ${prebuiltDir.path}.";
      }
      final hostDir = _selectAndroidNdkHostDir(prebuiltDirList);
      final map = {
        "armeabi-v7a": "armv7a-linux-androideabi21-clang",
        "arm64-v8a": "aarch64-linux-android21-clang",
        "x86": "i686-linux-androideabi21-clang",
        "x86_64": "x86_64-linux-android21-clang"
      };
      final compiler = map[buildItem.archName];
      if (compiler == null) {
        throw "Unsupported Android archName: ${buildItem.archName}";
      }

      return join(
        hostDir.path,
        "bin",
        compiler,
      );
    }
    return "gcc";
  }

  static Directory _selectAndroidNdkHostDir(List<Directory> dirs) {
    final hostNames = dirs.map((dir) => basename(dir.path)).toList();
    final preferred = <String>[
      if (Platform.isWindows) "windows-x86_64",
      if (Platform.isLinux) "linux-x86_64",
    ];

    for (final name in preferred) {
      for (final dir in dirs) {
        if (basename(dir.path) == name) {
          return dir;
        }
      }
    }

    if (dirs.length == 1) {
      return dirs.first;
    }

    throw "Unable to determine Android NDK prebuilt host directory. Found: $hostNames";
  }

  static String get tags => "with_gvisor,cmfa";

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print("run $name");
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      print(utf8.decode(data));
    });
    process.stderr.listen((data) {
      print(utf8.decode(data));
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0 && name != null) throw "$name error";
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw "File not exists";
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  static Future<String> extractCoreVersion() async {
    final versionFile = File(join("core", "constant", "version.go"));
    if (!versionFile.existsSync()) {
      throw "core/constant/version.go file not found";
    }
    final content = await versionFile.readAsString();
    final match = RegExp(r'Version\s*=\s*"([^"]+)"').firstMatch(content);
    if (match == null) {
      throw "Could not extract Version from core/constant/version.go";
    }
    return match.group(1)!;
  }

  static Future<void> syncCoreVersionDartFile() async {
    final v = await extractCoreVersion();
    final out = File(join(current, "lib", "core_version.dart"));
    await out.writeAsString(
      "// GENERATED by setup.dart from core/constant/version.go — do not edit by hand\n"
      "// ignore_for_file: constant_identifier_names\n"
      "\n"
      "/// Embedded mihomo version (see core/constant/version.go).\n"
      "const String kCoreVersionFromSource = '$v';\n",
    );
  }

  static Future<List<String>> buildCore({
    required Mode mode,
    required Target target,
    required String coreVersion,
    Arch? arch,
  }) async {
    final isLib = mode == Mode.lib;

    final items = buildItems
        .where(
          (element) =>
              element.target == target &&
              (arch == null ? true : element.arch == arch),
        )
        .toList();

    final corePaths = <String>[];

    final targetOutFilePath = join(outDir, target.name);
    final targetOutFile = File(targetOutFilePath);
    if (targetOutFile.existsSync()) {
      targetOutFile.deleteSync(recursive: true);
      Directory(targetOutFilePath).createSync(recursive: true);
    }

    for (final item in items) {
      final outFilePath = join(targetOutFilePath, item.archName);
      final file = File(outFilePath);
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
      }

      final fileName = isLib
          ? "$libName${item.target.dynamicLibExtensionName}"
          : "$coreName${item.target.executableExtensionName}";
      final realOutPath = join(outFilePath, fileName);
      corePaths.add(realOutPath);

      final env = <String, String>{};
      env["GOOS"] = item.target.os;
      if (item.arch != null) {
        env["GOARCH"] = item.arch!.name;
      }
      if (isLib) {
        env["CGO_ENABLED"] = "1";
        env["CC"] = _getCc(item);
        env["CFLAGS"] = "-O3 -Werror";
      } else {
        env["CGO_ENABLED"] = "0";
      }

      final execLines = [
        "go",
        "build",
        "-ldflags=-w -s -X github.com/metacubex/mihomo/constant.Version=$coreVersion",
        "-tags=$tags",
        if (isLib) "-buildmode=c-shared",
        "-o",
        realOutPath,
      ];
      await exec(
        execLines,
        name: "build core",
        environment: env,
        workingDirectory: _coreDir,
      );
      if (isLib && item.archName != null) {
        await adjustLibOut(
          targetOutFilePath: targetOutFilePath,
          outFilePath: outFilePath,
          archName: item.archName!,
        );
      }
    }

    return corePaths;
  }

  static Future<void> adjustLibOut({
    required String targetOutFilePath,
    required String outFilePath,
    required String archName,
  }) async {
    final includesPath = join(targetOutFilePath, "includes");
    final realOutPath = join(includesPath, archName);
    await Directory(realOutPath).create(recursive: true);
    final targetOutFiles = Directory(outFilePath).listSync();
    final coreFiles = Directory(_coreDir).listSync();
    for (final file in [...targetOutFiles, ...coreFiles]) {
      if (!file.path.endsWith('.h')) {
        continue;
      }
      final targetFilePath = join(realOutPath, basename(file.path));
      final realFile = File(file.path);
      await realFile.copy(targetFilePath);
      if (coreFiles.contains(file)) {
        continue;
      }
      await realFile.delete();
    }
  }

  static Future<void> buildHelper(Target target, String token,
      {Arch? arch}) async {
    final buildArgs = <String>[
      "cargo",
      "build",
      "--release",
      "--features",
      "windows-service",
    ];

    if (arch == Arch.arm64 && target == Target.windows) {
      buildArgs.addAll(["--target", "aarch64-pc-windows-msvc"]);
    }

    await exec(
      buildArgs,
      environment: {
        "TOKEN": token,
      },
      name: "build helper",
      workingDirectory: _servicesDir,
    );

    final String releasePath;
    if (arch == Arch.arm64 && target == Target.windows) {
      releasePath =
          join(_servicesDir, "target", "aarch64-pc-windows-msvc", "release");
    } else {
      releasePath = join(_servicesDir, "target", "release");
    }

    final outPath = join(
      releasePath,
      "helper${target.executableExtensionName}",
    );
    final targetPath = join(
      outDir,
      target.name,
      "MihoXHelperService${target.executableExtensionName}",
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) => command.split(" ");

  static Future<void> getDistributor() async {
    await exec(
      name: "activate fastforge",
      Build.getExecutable("dart pub global activate fastforge"),
    );
    return;
  }

  static void copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw "SourceFilePath not exists";
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print("File copied successfully!");
    } catch (e) {
      print("Failed to copy file: $e");
    }
  }
}

class BuildCommand extends Command {
  BuildCommand({
    required this.target,
  }) {
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        "arch",
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption(
        "arch",
        help: 'The $name build archName',
      );
    }
    argParser
      ..addOption(
        "out",
        valueHelp: [
          if (target.same) "app",
          "core",
        ].join(','),
        help: 'The $name build arch',
      )
      ..addOption(
        "env",
        valueHelp: [
          "preview",
          "stable",
        ].join(','),
        help: 'The $name build env',
      );
  }
  Target target;

  @override
  String get description => "build $name application";

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  Future<void> _getLinuxDependencies(Arch arch) async {
    await Build.exec(
      Build.getExecutable("sudo apt update -y"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y ninja-build libgtk-3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y libayatana-appindicator3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt-get install -y libkeybinder-3.0-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y locate"),
    );
    if (arch == Arch.amd64) {
      await Build.exec(
        Build.getExecutable("sudo apt install -y rpm patchelf"),
      );
      await Build.exec(
        Build.getExecutable("sudo apt install -y libfuse2"),
      );

      final downloadName = arch == Arch.amd64 ? "x86_64" : "aarch64";
      await Build.exec(
        Build.getExecutable(
          "wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "chmod +x appimagetool",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "sudo mv appimagetool /usr/local/bin/",
        ),
      );
    }
  }

  Future<void> _buildDistributor({
    required Target target,
    required String targets,
    String args = '',
    required String env,
  }) async {
    await Build.getDistributor();
    final distributorCommand =
        "dart pub global run fastforge:main package --skip-clean --platform ${target.name} --targets $targets --flutter-build-args=verbose$args";
    await Build.exec(
      name: name,
      Build.getExecutable(distributorCommand),
    );
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final mode = target == Target.android ? Mode.lib : Mode.core;
    final String out = argResults?["out"] ?? (target.same ? "app" : "core");
    var archName = argResults?["arch"];
    final env = argResults?["env"] ?? "stable";

    if (archName == null && target != Target.android) {
      final sysArch = await systemArch;
      if (sysArch != null) {
        final archMap = {
          'x86_64': 'amd64',
          'AMD64': 'amd64',
          'arm64': 'arm64',
          'aarch64': 'arm64',
        };
        archName = archMap[sysArch] ?? sysArch;
      }
    }

    final currentArches =
        arches.where((element) => element.name == archName).toList();
    final arch = currentArches.isEmpty ? null : currentArches.first;

    if (arch == null && target != Target.android) {
      throw "Invalid arch parameter. Available: ${arches.map((e) => e.name).join(', ')}";
    }

    await Build.syncCoreVersionDartFile();
    final coreVersion = await Build.extractCoreVersion();

    final corePaths = await Build.buildCore(
      target: target,
      arch: arch,
      mode: mode,
      coreVersion: coreVersion,
    );
    switch (target) {
      case Target.windows:
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        await Build.buildHelper(target, token!, arch: arch);
        break;
      case Target.linux:
      case Target.android:
        break;
    }

    if (out != "app") {
      return;
    }

    switch (target) {
      case Target.windows:
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        await Build.buildHelper(target, token!, arch: arch);
        await _buildDistributor(
          target: target,
          targets: "exe,zip",
          args:
              " --build-dart-define=CORE_SHA256=$token --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        return;
      case Target.linux:
        final targetMap = {
          Arch.arm64: "linux-arm64",
          Arch.amd64: "linux-x64",
        };
        final targets = [
          "deb",
          if (arch == Arch.amd64) "appimage",
          if (arch == Arch.amd64) "rpm",
        ].join(",");
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        await _buildDistributor(
          target: target,
          targets: targets,
          args:
              " --build-target-platform $defaultTarget --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        return;
      case Target.android:
        const allTargets = "android-arm,android-arm64,android-x64";

        await _buildDistributor(
          target: target,
          targets: "apk",
          args:
              ",split-per-abi --build-target-platform $allTargets --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );

        await _buildDistributor(
          target: target,
          targets: "apk",
          args:
              " --build-target-platform $allTargets --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );

        return;
    }
  }
}

Future<void> main(args) async {
  CommandRunner("setup", "build Application")
    ..addCommand(BuildCommand(target: Target.android))
    ..addCommand(BuildCommand(target: Target.linux))
    ..addCommand(BuildCommand(target: Target.windows))
    // ignore: unawaited_futures
    ..run(args);
}
