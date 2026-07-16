import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:mihox/common/common.dart';
import 'package:mihox/enum/enum.dart';
import 'package:path/path.dart';
import 'package:win32_registry/win32_registry.dart';

class Windows {
  factory Windows() {
    _instance ??= Windows._internal();
    return _instance!;
  }

  Windows._internal();
  static Windows? _instance;

  static final _shell32 = DynamicLibrary.open('shell32.dll');
  static final _uxtheme = DynamicLibrary.open('uxtheme.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _getProcAddress = _kernel32.lookupFunction<
      IntPtr Function(IntPtr hModule, Pointer<Utf8> lpProcName),
      int Function(int hModule, Pointer<Utf8> lpProcName)>('GetProcAddress');

  static final _getModuleHandleW = _kernel32.lookupFunction<
      IntPtr Function(Pointer<Utf16> lpModuleName),
      int Function(Pointer<Utf16> lpModuleName)>('GetModuleHandleW');

  static final _shellExecuteW = _shell32.lookupFunction<
      Int32 Function(
          Pointer<Utf16> hwnd,
          Pointer<Utf16> lpOperation,
          Pointer<Utf16> lpFile,
          Pointer<Utf16> lpParameters,
          Pointer<Utf16> lpDirectory,
          Int32 nShowCmd),
      int Function(
          Pointer<Utf16> hwnd,
          Pointer<Utf16> lpOperation,
          Pointer<Utf16> lpFile,
          Pointer<Utf16> lpParameters,
          Pointer<Utf16> lpDirectory,
          int nShowCmd)>('ShellExecuteW');

  static final _setWindowTheme = _uxtheme.lookupFunction<
      Int32 Function(IntPtr hwnd, Pointer<Utf16> pszSubAppName,
          Pointer<Utf16> pszSubIdList),
      int Function(int hwnd, Pointer<Utf16> pszSubAppName,
          Pointer<Utf16> pszSubIdList)>('SetWindowTheme');

  int Function(int)? _lookupIntFn(int moduleHandle, int ordinal) {
    final ptr =
        _getProcAddress(moduleHandle, Pointer<Utf8>.fromAddress(ordinal));
    if (ptr == 0) return null;
    return Pointer<NativeFunction<Int32 Function(Int32)>>.fromAddress(ptr)
        .asFunction<int Function(int)>();
  }

  void Function()? _lookupVoidFn(int moduleHandle, int ordinal) {
    final ptr =
        _getProcAddress(moduleHandle, Pointer<Utf8>.fromAddress(ordinal));
    if (ptr == 0) return null;
    return Pointer<NativeFunction<Void Function()>>.fromAddress(ptr)
        .asFunction<void Function()>();
  }

  bool isDarkMode() {
    final key = CURRENT_USER.open(r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize');
    final value = key.getInt('AppsUseLightTheme');
    return value == 0; // 0 means "not light mode" i.e. dark
  }

  void enableDarkModeForApp() {
    try {
      if (!isDarkMode()) return;

      try {
        final moduleName = 'uxtheme.dll'.toNativeUtf16();
        final uxthemeHandle = _getModuleHandleW(moduleName);
        calloc.free(moduleName);
        if (uxthemeHandle == 0) return;

        final setPreferredAppMode = _lookupIntFn(uxthemeHandle, 135);
        if (setPreferredAppMode != null) {
          setPreferredAppMode(1);
        } else {
          _lookupIntFn(uxthemeHandle, 133)?.call(1);
        }

        _lookupVoidFn(uxthemeHandle, 136)?.call();
      } catch (e) {}
    } catch (e) {}
  }

  void applyDarkModeToMenu(int hwnd) {
    if (hwnd == 0) return;

    final themeName =
        isDarkMode() ? 'DarkMode_Explorer'.toNativeUtf16() : nullptr;
    try {
      _setWindowTheme(hwnd, themeName, nullptr);
    } catch (_) {
    } finally {
      if (themeName != nullptr) calloc.free(themeName);
    }
  }

  bool runas(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    final result = _shellExecuteW(
      nullptr,
      operationPtr,
      commandPtr,
      argumentsPtr,
      nullptr,
      1,
    );

    calloc
      ..free(commandPtr)
      ..free(argumentsPtr)
      ..free(operationPtr);

    commonPrint.log("windows runas: $command $arguments resultCode:$result");
    return result >= 42;
  }

  Future<void> _killProcess(int port) async {
    final result = await Process.run('netstat', ['-ano']);
    final lines = result.stdout.toString().trim().split('\n');
    for (final line in lines) {
      if (!line.contains(":$port") || !line.contains("LISTENING")) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      final pid = int.tryParse(parts.last);
      if (pid != null) {
        await Process.run('taskkill', ['/PID', pid.toString(), '/F']);
      }
    }
  }

  Future<bool> _runScCommand(String action) async {
    final result = await Process.run('sc', [action, appHelperService]);
    return result.exitCode == 0;
  }

  Future<WindowsHelperServiceStatus> checkService() async {
    // final qcResult = await Process.run('sc', ['qc', appHelperService]);
    // final qcOutput = qcResult.stdout.toString();
    // if (qcResult.exitCode != 0 || !qcOutput.contains(appPath.helperPath)) {
    //   return WindowsHelperServiceStatus.none;
    // }
    final result = await Process.run('sc', ['query', appHelperService]);
    if (result.exitCode != 0) return WindowsHelperServiceStatus.none;

    final output = result.stdout.toString();
    return (output.contains("RUNNING") && await request.pingHelper())
        ? WindowsHelperServiceStatus.running
        : WindowsHelperServiceStatus.presence;
  }

  /// Install the helper service (requires UAC elevation).
  /// This should only be called when the service is not installed.
  /// After installation, sets security descriptor to allow non-admin users
  /// to start/stop the service without UAC.
  Future<bool> installService() async {
    final status = await checkService();
    if (status == WindowsHelperServiceStatus.running) return true;

    await _killProcess(helperPort);

    final command = [
      "/c",
      if (status == WindowsHelperServiceStatus.presence) ...[
        "sc",
        "delete",
        appHelperService,
        "&&",
      ],
      "sc",
      "create",
      appHelperService,
      'binPath= "${appPath.helperPath}"',
      'start= auto',
      "&&",
      "sc",
      "start",
      appHelperService,
    ].join(" ");

    final res = runas("cmd.exe", command);
    await Future.delayed(const Duration(milliseconds: 300));
    return res;
  }

  /// Try to start an existing service without UAC.
  /// Returns true if the service was started successfully or is already running.
  /// Returns false if the service is not installed or failed to start.
  Future<bool> tryStartExistingService() async {
    final status = await checkService();
    if (status == WindowsHelperServiceStatus.running) return true;
    if (status == WindowsHelperServiceStatus.none) return false;

    // Service exists but not running - try to start it without elevation
    if (!await _runScCommand('start')) return false;

    //return _waitForHelperReady();
    // Wait for service to fully start
    await Future.delayed(const Duration(milliseconds: 500));
    // Verify it's actually running and responding
    return (await checkService()) == WindowsHelperServiceStatus.running;
  }

  /// Register the service - will request UAC only if service is not installed.
  /// If the service is already installed, it will try to start it without UAC.
  Future<bool> registerService() async {
    // First, try to start existing service without UAC
    if (await tryStartExistingService()) {
      return true;
    }

    // Service not installed or couldn't start - need to install with UAC
    return installService();
  }

  Future<bool> startService() async {
    final status = await checkService();
    if (status == WindowsHelperServiceStatus.running) return true;
    if (status == WindowsHelperServiceStatus.none) return false;

    if (!await _runScCommand('start')) return false;

    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> stopService() async {
    final status = await checkService();
    if (status == WindowsHelperServiceStatus.none) return true;
    if (!await _runScCommand('stop')) return false;

    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<bool> registerTask(String appName) async {
    final taskXml = '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Triggers>
    <LogonTrigger/>
  </Triggers>
  <Settings>
    <MultipleInstancesPolicy>Parallel</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>"${Platform.resolvedExecutable}"</Command>
    </Exec>
  </Actions>
</Task>''';
    final taskPath = join(await appPath.tempPath, "task.xml");
    final file = File(taskPath);

    try {
      await file.create(recursive: true);
      await file.writeAsBytes(taskXml.encodeUtf16LeWithBom, flush: true);
      return runas('schtasks', '/Create /TN "$appName" /XML "$taskPath" /F');
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }
}

final windows = Platform.isWindows ? Windows() : null;
