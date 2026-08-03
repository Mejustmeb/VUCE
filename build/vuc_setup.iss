; VUC v1.0.0 — Windows Installer (InnoSetup)
[Setup]
AppName=VUC — Vector Universal Compression
AppVersion=1.0.0
AppPublisher=Fractal Resonance Grand
DefaultDirName={pf}\VUC
DefaultGroupName=VUC
OutputDir=/Users/sickbastered/Desktop/VUC_Launch/build
OutputBaseFilename=VUC_Setup_v1.0.0
Compression=lzma2/max
SolidCompression=yes
Uninstallable=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "/Users/sickbastered/Desktop/VUC_Launch/vlzx"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "/Users/sickbastered/Desktop/VUC_Launch/website/VUCE.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "/Users/sickbastered/Desktop/VUC_Launch/LICENSE.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "/Users/sickbastered/Desktop/VUC_Launch/README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\VUC Compressor"; Filename: "{app}\bin\vlzx.exe"
Name: "{group}\VUC Manual"; Filename: "{app}\MANUAL.md"
Name: "{group}\Uninstall VUC"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\bin\vlzx.exe"; Description: "Verify installation"; Flags: postinstall nowait skipifsilent
