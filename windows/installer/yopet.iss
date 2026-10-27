; Local testing only. Never deletes account data or Docker volumes.
#ifndef SourceDir
  #error SourceDir must point to an extracted, verified Release directory
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef OutputName
  #define OutputName "yopet-local-setup"
#endif
#define AppVersion GetFileVersion(SourceDir + "\yopet.exe")

[Setup]
AppId={{D2DF61BE-978B-4C83-949C-84D89A41987E}
AppName=Yopet Local Test
AppVersion={#AppVersion}
AppPublisher=Yopet
DefaultDirName={localappdata}\Programs\YopetLocal
DefaultGroupName=Yopet Local Test
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\yopet.exe
CloseApplications=yes
RestartApplications=no
SetupIconFile=..\runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Yopet Local Test"; Filename: "{app}\yopet.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Yopet Local Test"; Filename: "{app}\yopet.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\yopet.exe"; Description: "Launch Yopet (local Docker backend required)"; Flags: nowait postinstall skipifsilent unchecked
