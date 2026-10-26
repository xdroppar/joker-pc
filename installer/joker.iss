; Joker for Windows: the setup wizard. Built by publish.ps1, which passes the build folder and version:
;   ISCC /DBuild=C:\tmp\joker-playsheet-build8 /DTag=pc-2026-10-26-0005 /DVersion=2026.10.26.5 installer\joker.iss
; Installs per user (no admin prompt) into %LOCALAPPDATA%\Programs\Joker, with Start Menu and desktop shortcuts to
; JokerLauncher.exe (which keeps the game up to date) and an entry in Settings > Apps for uninstalling.

#ifndef Build
  #error Pass /DBuild=<folder holding Joker.exe>
#endif
#ifndef Tag
  #define Tag "dev"
#endif
#ifndef Version
  #define Version "0.0.0.0"
#endif

[Setup]
AppId={{8C1B6E2A-4F7D-4A2B-9E57-3D0A6C91F4B2}
AppName=Joker
AppVersion={#Version}
AppVerName=Joker
AppPublisher=Joker
AppPublisherURL=https://xdroppar.github.io/joker-pc/
AppSupportURL=https://poker-penu.onrender.com/support
VersionInfoVersion={#Version}
VersionInfoProductName=Joker
VersionInfoDescription=Joker Setup
DefaultDirName={localappdata}\Programs\Joker
DefaultGroupName=Joker
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
WizardImageFile=..\art\wizard-100.bmp,..\art\wizard-125.bmp,..\art\wizard-150.bmp,..\art\wizard-200.bmp
WizardSmallImageFile=..\art\small-100.bmp,..\art\small-125.bmp,..\art\small-150.bmp,..\art\small-200.bmp
SetupIconFile=..\art\joker.ico
UninstallDisplayIcon={app}\JokerLauncher.exe
UninstallDisplayName=Joker
OutputDir=..\out
OutputBaseFilename=JokerSetup
Compression=lzma2/fast
SolidCompression=no
CloseApplications=force
RestartApplications=no

[Messages]
WelcomeLabel2=This will install Joker on your computer.%n%nPull up a chair: real tables, real players, and a dealer who deals every card.

[Tasks]
Name: "desktopicon"; Description: "Put a Joker shortcut on the desktop"; GroupDescription: "Shortcuts:"

[InstallDelete]
; The first PowerShell installer left these behind.
Type: files; Name: "{app}\Joker-Launch.ps1"
Type: files; Name: "{userdesktop}\Joker.lnk"
Type: files; Name: "{userprograms}\Joker.lnk"

[Files]
Source: "{#Build}\*"; DestDir: "{app}"; Excludes: "*_BackUpThisFolder_ButDontShipItWithYourGame"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\out\JokerLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Joker"; Filename: "{app}\JokerLauncher.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall Joker"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Joker"; Filename: "{app}\JokerLauncher.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Joker.exe"; WorkingDir: "{app}"; Description: "Play Joker now"; Flags: nowait postinstall skipifsilent
; An update from the launcher (/SILENT /LAUNCH=1): the launcher has exited so its file could be replaced; start the game.
Filename: "{app}\Joker.exe"; WorkingDir: "{app}"; Flags: nowait; Check: LaunchRequested

[UninstallDelete]
Type: files; Name: "{app}\version.txt"

[Code]
function LaunchRequested: Boolean;
begin
  Result := ExpandConstant('{param:LAUNCH|0}') = '1';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  { The launcher compares this with the newest release to know when to offer an update. }
  if CurStep = ssPostInstall then
    SaveStringToFile(ExpandConstant('{app}\version.txt'), '{#Tag}', False);
end;
