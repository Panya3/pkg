; pkg — the hub's Windows installer script, compiled by Inno Setup (ISCC).
;
; What it installs is the published artifact itself, as it is: include\ (one
; include root per member) beside lib\ (one column per arch x config) beside
; the Install.bat that ships inside it. Nothing is renamed, merged or lifted
; out, so what a consumer gets from this setup.exe is byte-identical to what a
; consumer gets from unpacking the artifact — one hub, two ways in.
;
; One decision lines this script up with the rest of the hub: naming the hub
; in the user's environment is Install.bat's job, not the installer's. The
; last setup step runs it from the install folder; the uninstall step clears
; the stored value only when it points at the folder being removed, so a hub
; the user installed some other way is never touched.
;
; Per-user on purpose (docs/adr/0007): {localappdata}, no admin, no UAC —
; the same level Install.bat writes its environment at.

[Setup]
AppId={{7E6C6D8F-4B2A-4C0B-9A5E-3B6D1F0A5C42}
AppName=pkg
AppVersion={#pkgVersion}
AppPublisher=Panya3
DefaultDirName={localappdata}\pkg
DisableProgramGroupPage=yes
; The user may reinstall the hub somewhere else; the dir page is how.
DisableDirPage=no
OutputBaseFilename=pkg-setup-{#pkgVersion}
; Paths in this script are resolved from the script's own folder, so the
; compiled exe lands in the repository root — beside the artifact it wrapped,
; which is where the CI step looks for it.
OutputDir=..
; Per-user: the installer never elevates, and PrivilegesRequired=lowest is what
; makes {localappdata} the default without a UAC prompt.
PrivilegesRequired=lowest
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; The hub is a folder of headers and libraries, not a running program; files
; may sit open in an editor — replace them, do not fail the install.
CloseApplications=no
RestartApplications=no
UninstallDisplayName=pkg (library hub)

[Files]
; The whole artifact, as the publish job laid it out: include\, lib\ with all
; four columns, Install.bat at the root. recurse skips empty directories,
; which are not part of the contract — the consumer asserts on files.
; One line, not three: Inno reads a [Files] entry per line, and splitting the
; parameters across lines makes the first line an entry without a DestDir.
; ..\ because Source is resolved from this script's folder, not the working
; directory ISCC happened to be started in.
Source: "..\artifact\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs uninsrestartdelete

[Run]
; The one thing the artifact could not do for itself before someone pointed at
; it. runhidden, not postinstall: this is not an optional bonus step, it is the
; install's whole point, and the finish page reports it rather than offering
; it. No nowait - setup.exe returns only after the environment is written,
; which is what makes "installer finished" a fact instead of a race.
; skipifdoesntexist keeps a broken artifact from failing here instead of
; upstream, where the missing file is the diagnosable fact.
Filename: "{app}\Install.bat"; Flags: runhidden skipifdoesntexist; WorkingDir: "{app}"

[Code]
// True when the stored PKG_DIR (per-user environment — HKCU\Environment,
// where setx puts it) points inside the folder being uninstalled. Anything
// else — unset, another folder, a copy the user unpacked somewhere else — is
// not this install's value to clear, and stays.
function PkgDirPointsHere(): Boolean;
var
  StoredPath, InstallPath: String;
begin
  Result := False;
  if not RegQueryStringValue(HKCU, 'Environment', 'PKG_DIR', StoredPath) then
    Exit;
  StoredPath := Lowercase(RemoveBackslashUnlessRoot(StoredPath));
  InstallPath := Lowercase(RemoveBackslashUnlessRoot(ExpandConstant('{app}')));
  Result := (StoredPath = InstallPath) or
            (Pos(AddBackslash(InstallPath), StoredPath) = 1);
end;

// UninstallDelete removes files; PKG_DIR lives in the registry and must go the
// way it came — a deliberate delete, never a silent leftover pointing into a
// folder this uninstall is about to remove.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    if PkgDirPointsHere() then
      RegDeleteValue(HKCU, 'Environment', 'PKG_DIR');
end;
