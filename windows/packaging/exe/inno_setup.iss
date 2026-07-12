[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma2
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern dynamic
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}
UninstallDisplayIcon={uninstallexe}
ChangesAssociations=yes
// Update mode settings
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

[Code]
const
  SHCNE_ASSOCCHANGED = $08000000;
  SHCNF_IDLIST = $0000;

var
  IsUpgrade: Boolean;
  PreviousVersion: String;

procedure SHChangeNotify(wEventId: Integer; uFlags: Integer; dwItem1: Integer; dwItem2: Integer); external 'SHChangeNotify@shell32.dll stdcall';

// Terminate all application processes gracefully, then forcefully if needed
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['MihoX.exe', 'MihoXCore.exe', 'MihoXHelperService.exe'];

  // First try graceful shutdown
  for i := 0 to GetArrayLength(Processes) - 1 do
  begin
    Exec('taskkill.exe', '/im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  
  // Wait for processes to terminate gracefully
  Sleep(1000);

  // Force kill any remaining processes
  for i := 0 to GetArrayLength(Processes) - 1 do
  begin
    Exec('taskkill.exe', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
  
  // Allow time for cleanup
  Sleep(1000);
end;

// Check if the application is already installed on the system
function IsAppInstalled(): Boolean;
var
  UninstallKey: String;
begin
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{APP_ID}}_is1';
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, UninstallKey) or 
            RegKeyExists(HKEY_CURRENT_USER, UninstallKey);
end;

// Determine if this is an upgrade installation
function IsUpgradeInstallation(): Boolean;
begin
  Result := IsUpgrade;
end;

// Retrieve the currently installed version from registry
function GetInstalledVersion(): String;
var
  UninstallKey: String;
  Version: String;
begin
  Result := '';
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{{APP_ID}}_is1';
  
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'DisplayVersion', Version) then
    Result := Version
  else if RegQueryStringValue(HKEY_CURRENT_USER, UninstallKey, 'DisplayVersion', Version) then
    Result := Version;
end;

// Initialize setup: check for existing installation and prepare for upgrade
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Check if app is already installed
  IsUpgrade := IsAppInstalled();
  if IsUpgrade then
    PreviousVersion := GetInstalledVersion();
  
  // Stop service if running
  Exec('sc.exe', 'stop "MihoXHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  
  // Kill all processes
  KillProcesses();
  
  Result := True;
end;

// Customize the wizard interface based on upgrade status
procedure InitializeWizard();
begin
  if IsUpgrade then
  begin
    WizardForm.Caption := '{{DISPLAY_NAME}} - Update';
    if PreviousVersion <> '' then
      WizardForm.WelcomeLabel2.Caption := 
        'Current version ' + PreviousVersion + ' was detected.' + #13#10 + #13#10 +
        'The setup will install version {{APP_VERSION}}.' + #13#10 + #13#10 +
        'Click Next to continue the update, or Cancel to exit.'
    else
      WizardForm.WelcomeLabel2.Caption := 
        'An installed version of the application was detected.' + #13#10 + #13#10 +
        'The setup will install version {{APP_VERSION}}.' + #13#10 + #13#10 +
        'Click Next to continue the update, or Cancel to exit.';
  end;
end;

// Update the ready memo to display installation summary
function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  if IsUpgrade then
  begin
    Result := 'Update' + NewLine;
    if PreviousVersion <> '' then
      Result := Result + 'Current version: ' + PreviousVersion + NewLine;
    Result := Result + 'New version: {{APP_VERSION}}' + NewLine + NewLine;
  end
  else
    Result := 'Fresh Installation' + NewLine + NewLine;
    
  if MemoDirInfo <> '' then
    Result := Result + MemoDirInfo + NewLine + NewLine;
  if MemoGroupInfo <> '' then
    Result := Result + MemoGroupInfo + NewLine + NewLine;
  if MemoTasksInfo <> '' then
    Result := Result + MemoTasksInfo + NewLine;
end;

// Post-install cleanup and service startup
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Refresh icon cache and file associations
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
    Sleep(500);
    // Ensure helper service is started after install/upgrade
    try
      Exec('sc.exe', 'start "MihoXHelperService"', '', SW_HIDE, ewNoWait, ResultCode);
    except
    end;
  end;
end;

// Handle uninstallation cleanup steps
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  case CurUninstallStep of
    usUninstall:
    begin
      // Stop service first
      Exec('sc.exe', 'stop "MihoXHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
      
      // Kill all application processes
      KillProcesses();
      
      // Delete the Windows service
      Exec('sc.exe', 'delete "MihoXHelperService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(500);
    end;
    
    usPostUninstall:
    begin
      if DirExists(ExpandConstant('{userappdata}\org.remtrik\mihox')) then
      begin
        if MsgBox('Delete application user data?', mbConfirmation, MB_YESNO) = IDYES then
        begin
          DelTree(ExpandConstant('{userappdata}\org.remtrik\mihox'), True, True, True);
        end;
      end;
    end;
  end;
end;
[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce; Check: not IsUpgradeInstallation
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
// NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent