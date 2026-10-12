#define MyAppName "CDA Inventory"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Chennai Drone Academy"
#define MyAppExeName "cda_inventory.exe"

[Setup]
AppId={{6F2C8E1A-7B4D-4F9C-9D31-5A8E2C6B7410}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

SetupIconFile=E:\FlutterWorkspace\CDA_INVENTORY\windows\runner\resources\app_icon.ico

DefaultDirName={autopf}\CDA Inventory
DefaultGroupName=CDA Inventory

OutputDir=E:\FlutterWorkspace\CDA_INVENTORY\installer
OutputBaseFilename=CDA_Inventory_Setup

Compression=lzma
SolidCompression=yes

WizardStyle=modern

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

PrivilegesRequired=admin

UninstallDisplayName=CDA Inventory

[Files]
Source: "E:\FlutterWorkspace\CDA_INVENTORY\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\CDA Inventory"; \
    Filename: "{app}\cda_inventory.exe"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\CDA Inventory"; \
    Filename: "{app}\cda_inventory.exe"; \
    WorkingDir: "{app}"; \
    Tasks: desktopicon

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\cda_inventory.exe"; \
    Description: "Launch CDA Inventory"; \
    Flags: nowait postinstall skipifsilent
    