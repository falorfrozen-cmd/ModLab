#ifndef ModLabVersion
  #error ModLabVersion is required.
#endif
#ifndef PayloadDir
  #error PayloadDir is required.
#endif
#ifndef OutputDir
  #error OutputDir is required.
#endif

[Setup]
AppId=ModLab.MinecraftDungeonsII
AppName=ModLab
AppVersion={#ModLabVersion}
AppPublisher=falorfrozen-cmd
AppPublisherURL=https://github.com/falorfrozen-cmd/ModLab
AppSupportURL=https://discord.gg/q6aexZZSAf
AppCopyright=Copyright (c) 2026 falorfrozen-cmd
DefaultDirName={tmp}
CreateAppDir=no
Uninstallable=no
CreateUninstallRegKey=no
DisableProgramGroupPage=yes
DisableWelcomePage=no
DisableDirPage=yes
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
SetupArchitecture=x64
OutputDir={#OutputDir}
OutputBaseFilename=ModLab-Setup-{#ModLabVersion}
Compression=lzma2
SolidCompression=no
Encryption=no
CloseApplications=no
RestartApplications=no
DisableReadyPage=no
DisableFinishedPage=no
VersionInfoVersion=0.1.0.0
InfoBeforeFile={#PayloadDir}\NOTICES.txt

[Files]
Source: "{#PayloadDir}\ModLabWorker.exe"; Flags: dontcopy
Source: "{#PayloadDir}\ModLab.manifest.json"; Flags: dontcopy
Source: "{#PayloadDir}\ModLabLoader_P.pak"; Flags: dontcopy
Source: "{#PayloadDir}\ModLabLoader_P.ucas"; Flags: dontcopy
Source: "{#PayloadDir}\ModLabLoader_P.utoc"; Flags: dontcopy
Source: "{#PayloadDir}\QoLSuite_P.pak"; Flags: dontcopy
Source: "{#PayloadDir}\QoLSuite_P.ucas"; Flags: dontcopy
Source: "{#PayloadDir}\QoLSuite_P.utoc"; Flags: dontcopy
Source: "{#PayloadDir}\ModLab.html"; Flags: dontcopy
Source: "{#PayloadDir}\BerserkerBuffs.png"; Flags: dontcopy

[Code]
var
  ActionPage: TInputOptionWizardPage;
  GamePage: TInputDirWizardPage;
  Libraries: TNewComboBox;
  ChangingFiles: Boolean;

function SelectedOperation: String;
begin
  if ActionPage.SelectedValueIndex = 1 then Result := 'Restore'
  else Result := 'Install';
end;

procedure LibraryChanged(Sender: TObject);
begin
  if Libraries.ItemIndex >= 0 then GamePage.Values[0] := Libraries.Items[Libraries.ItemIndex];
end;

procedure InitializeWizard;
var
  ResultCode, I: Integer;
  Games: TArrayOfString;
  Requested: String;
begin
  ActionPage := CreateInputOptionPage(wpInfoBefore, 'ModLab',
    'Choose what you want to do.',
    'Install the complete suite or restore the installation you had before ModLab.'#13#10 +
    'Requires Minecraft Dungeons II Steam build 25754144 / game 1.1.2.0. Close the game first.', True, False);
  ActionPage.Add('Install / Update ModLab');
  ActionPage.Add('Remove / Restore previous installation');
  Requested := ExpandConstant('{param:OPERATION|Install}');
  if Requested = 'Restore' then ActionPage.SelectedValueIndex := 1
  else if Requested = 'Install' then ActionPage.SelectedValueIndex := 0
  else RaiseException('Unknown ModLab operation.');
  GamePage := CreateInputDirPage(ActionPage.ID, 'Minecraft Dungeons II',
    'Select the installed game folder.',
    'Choose the folder containing Dungeons. Setup preserves character saves and other mods.'#13#10 +
    'Original packages are backed up to ModLabBackups outside the mounted Paks folder.', False, '');
  GamePage.Add('Game folder:');
  Libraries := TNewComboBox.Create(WizardForm);
  Libraries.Parent := GamePage.Surface;
  Libraries.Left := GamePage.Edits[0].Left;
  Libraries.Top := GamePage.Edits[0].Top + ScaleY(65);
  Libraries.Width := GamePage.SurfaceWidth;
  Libraries.Style := csDropDownList;
  Libraries.OnChange := @LibraryChanged;
  ExtractTemporaryFile('ModLabWorker.exe');
  if Exec(ExpandConstant('{tmp}\ModLabWorker.exe'), '--discover', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
     (ResultCode = 0) and LoadStringsFromFile(ExpandConstant('{tmp}\ModLab-games.txt'), Games) then
    for I := 0 to GetArrayLength(Games) - 1 do
      if Games[I] <> '' then Libraries.Items.Add(Games[I]);
  if Libraries.Items.Count > 0 then begin
    Libraries.ItemIndex := 0;
    GamePage.Values[0] := Libraries.Items[0];
  end;
  Requested := ExpandConstant('{param:GAME|}');
  if Requested <> '' then GamePage.Values[0] := Requested;
  Libraries.Visible := Libraries.Items.Count > 1;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then begin
    if SelectedOperation = 'Restore' then
      WizardForm.FinishedLabel.Caption := 'ModLab was removed. Your previous installation has been restored.'
    else
      WizardForm.FinishedLabel.Caption := 'ModLab is installed. Start Minecraft Dungeons II through Steam and press F10.'#13#10#13#10 +
        'Keep this Setup and the game''s ModLabBackups folder for future removal or updates.';
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = GamePage.ID then begin
    Result := FileExists(AddBackslash(GamePage.Values[0]) + 'Dungeons\Content\Paks\global.utoc') and
      FileExists(AddBackslash(GamePage.Values[0]) + 'Dungeons\Binaries\Win64\Dungeons-Win64-Shipping.exe');
    if not Result then begin
      Log('Select the game root containing Dungeons.');
      if not WizardSilent then MsgBox('Select the game root folder containing Dungeons.', mbError, MB_OK);
    end;
  end;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := 'Operation: ' + SelectedOperation + NewLine +
    'Game folder: ' + GamePage.Values[0] + NewLine + NewLine +
    'Eight verified runtime files. Original packages are backed up before changes.' + NewLine +
    'No PowerShell script, download, background service or save editing.';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ExitCode, I: Integer;
  Lines: TArrayOfString;
  Args: String;
begin
  Result := '';
  ExtractTemporaryFiles('*');
  DeleteFile(ExpandConstant('{tmp}\ModLab-result.txt'));
  Args := SelectedOperation + ' "' + RemoveBackslashUnlessRoot(GamePage.Values[0]) + '"';
  ChangingFiles := True;
  try
    if not Exec(ExpandConstant('{tmp}\ModLabWorker.exe'), Args, '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
      Result := 'Cannot start the verified installation worker: ' + SysErrorMessage(ExitCode)
    else if ExitCode <> 0 then Result := 'ModLab could not complete the operation. No successful installation was reported.';
    if LoadStringsFromFile(ExpandConstant('{tmp}\ModLab-result.txt'), Lines) then begin
      for I := 0 to GetArrayLength(Lines) - 1 do Log(Lines[I]);
      if (Result <> '') and (GetArrayLength(Lines) > 1) then Result := Lines[1];
      if (Result = '') and ((GetArrayLength(Lines) < 2) or (Lines[0] <> 'OK')) then
        Result := 'The worker returned an invalid completion record.';
    end else if Result = '' then Result := 'The installation worker returned no result.';
  finally
    ChangingFiles := False;
  end;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if ChangingFiles then Cancel := False;
end;
