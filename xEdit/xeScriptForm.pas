{******************************************************************************

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain
  one at https://mozilla.org/MPL/2.0/.

*******************************************************************************}

unit xeScriptForm;

{$I xeDefines.inc}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, IOUtils, StrUtils, ShellAPI, IniFiles,
  Vcl.ComCtrls, Vcl.FileCtrl, System.UITypes, Generics.Collections,
  SynEdit, SynMemo, SynEditKeyCmds, SynEditTypes, xeMainForm,
  SynHighlighterPas, VirtualTrees, Buttons, wbInterface;

const
  sNewScript = '<new script>';
  sNewScriptName = '_newscript_';
  sScriptExt = '.pas';

  cEditorSchemeAuto          = 'Auto';
  cEditorSchemeDelphiClassic = 'Delphi Classic';
  cEditorSchemeVisualStudio  = 'Visual Studio';
  cEditorSchemeSolarizedLight = 'Solarized Light';
  cEditorSchemeVSCodeDark    = 'VS Code Dark';
  cEditorSchemeMonokai       = 'Monokai';
  cEditorSchemeOneDark       = 'One Dark';

  cEditorSchemesSystem: array[0..0] of string = (
    cEditorSchemeAuto
  );
  cEditorSchemesLight: array[0..2] of string = (
    cEditorSchemeDelphiClassic,
    cEditorSchemeVisualStudio,
    cEditorSchemeSolarizedLight
  );
  cEditorSchemesDark: array[0..2] of string = (
    cEditorSchemeVSCodeDark,
    cEditorSchemeMonokai,
    cEditorSchemeOneDark
  );

type
  TScriptNodeData = record
    Name: string;
    RelativePath: string;
    BasePath: string;
    IsFolder: Boolean;
    IsRoot: Boolean;
  end;
  PScriptNodeData = ^TScriptNodeData;

  TEditorColorScheme = record
    Background   : TColor;
    Text         : TColor;
    Keyword      : TColor;
    KeywordStyle : TFontStyles;
    Comment      : TColor;
    CommentStyle : TFontStyles;
    Str          : TColor;
    Number       : TColor;
    Directive    : TColor;
    DirectiveStyle: TFontStyles;
    AsmColor     : TColor;
  end;

  TApplyScriptEvent = procedure(const aScriptName, aScript: string;
    const aExtraPaths, aExpandedNodes: string; aRefByMode: Boolean) of object;

  TfrmScript = class(TForm)
    pnlLeft: TPanel;
    edFilter: TEdit;
    vstScripts: TVirtualStringTree;
    splLeft: TSplitter;
    pnlBottom: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    dlgSave: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edFilterChange(Sender: TObject);
    procedure edFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure vstScriptsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstScriptsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vstScriptsFocusChanged(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex);
    procedure vstScriptsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure vstScriptsDblClick(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    Editor: TSynMemo;
    Highlighter: TSynPasSyn;
    FUpdatingTree: Boolean;
    FCurrentBasePath: string;
    FCurrentRelPath: string;
    SaveOverride: string;
    FApplying: Boolean;
    FExtraPaths: TStringList;
    FExpandedNodes: TStringList;
    pmuTree: TPopupMenu;
    mniNewScript: TMenuItem;
    mniAddFolder: TMenuItem;
    mniRemoveFolder: TMenuItem;
    pnlEditor: TPanel;
    pnlToolbar: TPanel;
    btnToolSave: TSpeedButton;
    btnToolReset: TSpeedButton;
    btnToolInsertRef: TSpeedButton;
    pmuInsertRef: TPopupMenu;
    pmuEditor: TPopupMenu;
    mniEditorInsertRef: TMenuItem;
    FInsertRefCodes: TStringList;
    pnlStatusBar: TPanel;
    lblCaret: TLabel;
    lblModified: TLabel;
    lblInsMode: TLabel;
    procedure btnSaveClick(Sender: TObject);
    procedure EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure btnToolResetClick(Sender: TObject);
    procedure UpdateToolbarState;
    procedure UpdateCaretPos;
    function EnsureFolderNode(aRootNode: PVirtualNode; const FolderPath: string; FolderNodes: TDictionary<string, PVirtualNode>): PVirtualNode;
    function FirstScriptNode: PVirtualNode;
    function GetNodeBasePath(Node: PVirtualNode): string;
    function Indent(aText: string; aPrefix: string): string;
    function Dedent(aText: string; aPrefix: string): string;
    procedure DoScriptSelectionChange;
    procedure pmuTreePopup(Sender: TObject);
    procedure mniNewScriptClick(Sender: TObject);
    procedure mniAddFolderClick(Sender: TObject);
    procedure mniRemoveFolderClick(Sender: TObject);
    procedure vstScriptsGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle;
      var HintText: string);
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    function GetNodeKey(Node: PVirtualNode): string;
    procedure SaveExpandedStates;
    procedure RestoreExpandedStates;
    procedure SaveSettings;
    procedure DoApplyAndClose;
    procedure btnToolInsertRefClick(Sender: TObject);
    procedure pmuInsertRefItemClick(Sender: TObject);
    function BuildNavRefCode(aElement: IwbElement): string;
    procedure BuildViewRefPopup(aElement: IwbElement; const aPopupPos: TPoint; const aNavCode: string);
    function GetSignatureStr(aElement: IwbElement): string;
    function GetRelativePath(aElement: IwbElement; aMainRec: IwbMainRecord): string;
    procedure GoToErrorLine;
    procedure CreateToolbar;
    procedure CreateStatusBar;
    procedure CreateEditor;
    procedure CreateTreeContextMenu;
    procedure LoadScriptFromFile(const AFilePath: string);
  public
    Path: string;
    LastUsedScript: string;
    Script: string;
    ExtraPathsStr: string;
    ExpandedNodesStr: string;
    RefByMode: Boolean;
    Settings: TMemIniFile;
    ErrorLine: Integer;
    ErrorUnitName: string;
    ErrorMessage: string;
    OnApplyScript: TApplyScriptEvent;
    procedure ReadScriptsList;
    procedure SetColorScheme(const AScheme: string);
  end;

var
  frmScript: TfrmScript;

implementation

{$R *.dfm}


procedure TfrmScript.mniNewScriptClick(Sender: TObject);
var
  TargetRoot: string;
begin
  TargetRoot := GetNodeBasePath(vstScripts.GetNodeAt(vstScripts.ScreenToClient(pmuTree.PopupPoint)));
  if TargetRoot = '' then
    TargetRoot := Path;

  if Editor.Modified and (Editor.Text.Trim <> '') then
    if MessageDlg('The current script has been modified. Do you want to save it before creating a new script?',
                  mtConfirmation, mbYesNo, 0) = mrYes then
      btnSaveClick(Self);

  FUpdatingTree := True;
  try
    vstScripts.ClearSelection;
    vstScripts.FocusedNode := nil;
  finally
    FUpdatingTree := False;
  end;

  FCurrentBasePath := TargetRoot;
  FCurrentRelPath := '';
  SaveOverride := sNewScript;
  Editor.Lines.Clear;
  LoadScriptFromFile(Path + sNewScriptName + sScriptExt);
  Editor.SetFocus;
  UpdateCaretPos;
end;

procedure TfrmScript.mniAddFolderClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := '';
  if SelectDirectory('Select scripts folder', '', Dir) then begin
    Dir := IncludeTrailingPathDelimiter(Dir);
    if FExtraPaths.IndexOf(Dir) < 0 then begin
      FExtraPaths.Add(Dir);
      ReadScriptsList;
    end;
  end;
end;

procedure TfrmScript.mniRemoveFolderClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
  idx: Integer;
begin
  Node := vstScripts.GetNodeAt(vstScripts.ScreenToClient(pmuTree.PopupPoint));
  if not Assigned(Node) then Exit;
  Data := vstScripts.GetNodeData(Node);
  if not Data^.IsRoot then Exit;
  idx := FExtraPaths.IndexOf(Data^.BasePath);
  if idx < 0 then Exit;
  FExtraPaths.Delete(idx);
  ReadScriptsList;
end;

procedure TfrmScript.pmuTreePopup(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  Node := vstScripts.GetNodeAt(vstScripts.ScreenToClient(pmuTree.PopupPoint));
  mniRemoveFolder.Visible := False;
  if Assigned(Node) then begin
    Data := vstScripts.GetNodeData(Node);
    if Data^.IsRoot and not SameText(Data^.BasePath, Path) then
      mniRemoveFolder.Visible := True;
  end;
end;

function TfrmScript.GetNodeBasePath(Node: PVirtualNode): string;
var
  Data: PScriptNodeData;
  N: PVirtualNode;
begin
  Result := '';
  N := Node;
  while Assigned(N) do begin
    Data := vstScripts.GetNodeData(N);
    if Data^.IsRoot then begin
      Result := Data^.BasePath;
      Exit;
    end;
    N := N.Parent;
    if N = vstScripts.RootNode then
      Break;
  end;
end;

procedure TfrmScript.btnSaveClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
  BasePath, s, s2: string;
  WasNewScript: Boolean;
begin
  WasNewScript := False;
  s := SaveOverride;
  BasePath := FCurrentBasePath;
  if BasePath = '' then
    BasePath := Path;

  if s = '' then begin
    Node := vstScripts.FocusedNode;
    if not Assigned(Node) then Exit;
    Data := vstScripts.GetNodeData(Node);
    if Data^.IsFolder or Data^.IsRoot or (Data^.RelativePath = '') then Exit;
    s := Data^.RelativePath;
    BasePath := Data^.BasePath;
  end;

  if s = sNewScript then begin
    WasNewScript := True;
    dlgSave.InitialDir := BasePath;
    if dlgSave.Execute then begin
      s2 := dlgSave.FileName;
      BasePath := IncludeTrailingPathDelimiter(ExtractFilePath(s2));
      s2 := ChangeFileExt(ExtractFileName(s2), '');
      s := BasePath + s2 + sScriptExt;
    end else
      Exit;
  end else
    s := BasePath + s + sScriptExt;

  with TStringList.Create do try
    Text := Editor.Lines.Text.Replace(#9, #32#32);
    CopyFile(PChar(s), PChar(s + '.backup.' + FormatDateTime('yyyy_mm_dd_hh_nn_ss', Now)), True);
    SaveToFile(s);
    Editor.Modified := False;
  finally
    Free;
  end;

  if WasNewScript then begin
    FCurrentBasePath := BasePath;
    FCurrentRelPath := s2;
    SaveOverride := '';
    ReadScriptsList;
  end;
end;

procedure TfrmScript.DoScriptSelectionChange;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
  NewRelPath, NewBasePath, OldRelPath: string;
begin
  Node := vstScripts.FocusedNode;
  if not Assigned(Node) then Exit;
  Data := vstScripts.GetNodeData(Node);
  if Data^.IsFolder or Data^.IsRoot then Exit;

  NewRelPath := Data^.RelativePath;
  NewBasePath := Data^.BasePath;
  if SameText(NewRelPath, FCurrentRelPath) and SameText(NewBasePath, FCurrentBasePath) then Exit;

  if Editor.Modified and (Editor.Text.Trim <> '') then begin
    OldRelPath := FCurrentRelPath;
    if MessageDlg('The previous script has been modified. Do you want to save it before loading the new script?',
                  mtConfirmation, mbYesNo, 0) = mrYes then
      btnSaveClick(Self);
    if FCurrentRelPath <> OldRelPath then
      Exit;
  end;

  FCurrentBasePath := NewBasePath;
  FCurrentRelPath := NewRelPath;
  SaveOverride := '';
  Editor.Lines.Clear;
  LoadScriptFromFile(NewBasePath + NewRelPath + sScriptExt);
  UpdateCaretPos;
end;

procedure TfrmScript.edFilterChange(Sender: TObject);
begin
  if Self.Active then
    ReadScriptsList;
end;

procedure TfrmScript.edFilterKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN, VK_DOWN: begin
      Key := 0;
      vstScripts.SetFocus;
    end;
  end;
end;

procedure TfrmScript.UpdateCaretPos;
begin
  lblCaret.Caption := Format('Line:%d Col:%d', [Editor.CaretY, Editor.CaretX]);
end;

function TfrmScript.Indent(aText: string; aPrefix: string): String;
begin
  var lines := TStringList.Create;
  try
    lines.Text := aText.TrimRight;

    for var i := 0 to Pred(lines.Count) do
      if lines[i].Trim.Length > 0 then
        lines[i] := aPrefix + lines[i];

    Result := lines.Text.TrimRight;
  finally
    lines.Free;
  end;
end;

function TfrmScript.Dedent(aText: string; aPrefix: string): String;
begin
  var lines := TStringList.Create;
  try
    lines.Text := aText.TrimRight;

    for var i := 0 to Pred(lines.Count) do
      if lines[i].Trim.Length > 0 then
        if lines[i].StartsWith(aPrefix) then
          lines[i] := StringReplace(lines[i], aPrefix, '', [])
        else
          lines[i] := lines[i].TrimLeft;

    Result := lines.Text.TrimRight;
  finally
    lines.Free;
  end;
end;

procedure TfrmScript.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_TAB: begin
      Key := 0;
      if Editor.SelLength > 0 then
        if Shift = [ssShift] then
          Editor.SelText := Dedent(Editor.SelText, '  ')
        else
          Editor.SelText := Indent(Editor.SelText, '  ')
      else
      begin
        SendMessage(Editor.Handle, WM_CHAR, Ord(' '), 0);
        SendMessage(Editor.Handle, WM_CHAR, Ord(' '), 0);
      end;
    end;
  end;
end;

procedure TfrmScript.EditorKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #9: begin
      Key := #0;
    end;
  end;
end;

procedure TfrmScript.EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  if Changes * [scAll, scCaretX, scCaretY] <> [] then
    UpdateCaretPos;
  if Changes * [scAll, scModified] <> [] then begin
    if Editor.Modified then
      lblModified.Caption := 'Modified'
    else
      lblModified.Caption := '';
    UpdateToolbarState;
  end;
  if Changes * [scAll, scInsertMode] <> [] then begin
    if Editor.InsertMode then
      lblInsMode.Caption := 'INS'
    else
      lblInsMode.Caption := 'OVR';
  end;
end;

procedure TfrmScript.UpdateToolbarState;
begin
  btnToolSave.Enabled := Editor.Modified;
  btnToolReset.Enabled := Editor.Modified;
end;

procedure TfrmScript.btnToolResetClick(Sender: TObject);
begin
  if not Editor.Modified then Exit;
  if SaveOverride = sNewScript then begin
    Editor.Lines.Clear;
    LoadScriptFromFile(Path + sNewScriptName + sScriptExt);
    Exit;
  end;
  if (FCurrentRelPath = '') or not FileExists(FCurrentBasePath + FCurrentRelPath + sScriptExt) then
    Exit;
  LoadScriptFromFile(FCurrentBasePath + FCurrentRelPath + sScriptExt);
end;

function TfrmScript.EnsureFolderNode(aRootNode: PVirtualNode; const FolderPath: string; FolderNodes: TDictionary<string, PVirtualNode>): PVirtualNode;
var
  ParentPath: string;
  ParentNode: PVirtualNode;
  Data: PScriptNodeData;
begin
  if FolderNodes.TryGetValue(FolderPath, Result) then Exit;

  ParentPath := ExtractFileDir(FolderPath);
  if ParentPath = '' then
    ParentNode := aRootNode
  else
    ParentNode := EnsureFolderNode(aRootNode, ParentPath, FolderNodes);

  Result := vstScripts.AddChild(ParentNode);
  Data := vstScripts.GetNodeData(Result);
  Data^.Name := ExtractFileName(FolderPath);
  Data^.RelativePath := '';
  Data^.IsFolder := True;
  FolderNodes.Add(FolderPath, Result);
end;

function TfrmScript.FirstScriptNode: PVirtualNode;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  Result := nil;
  Node := vstScripts.GetFirst;
  while Assigned(Node) do begin
    Data := vstScripts.GetNodeData(Node);
    if not Data^.IsFolder and not Data^.IsRoot then begin
      Result := Node;
      Exit;
    end;
    Node := vstScripts.GetNext(Node);
  end;
end;

procedure TfrmScript.ReadScriptsList;
var
  FolderNodes: TDictionary<string, PVirtualNode>;
  AllPaths: TStringList;
  Files: TArray<string>;
  f, sname, dirpart, leafname, BasePath: string;
  ScriptNode, SelectNode, RootNode: PVirtualNode;
  Data: PScriptNodeData;
  FilterText, TargetFullPath: string;
  i: Integer;
  HasChildren: Boolean;
begin
  Path := IncludeTrailingPathDelimiter(Path);

  TargetFullPath := '';
  SelectNode := vstScripts.FocusedNode;
  if Assigned(SelectNode) then begin
    Data := vstScripts.GetNodeData(SelectNode);
    if not Data^.IsFolder and not Data^.IsRoot then
      TargetFullPath := Data^.BasePath + Data^.RelativePath;
  end;
  if TargetFullPath = '' then
    TargetFullPath := LastUsedScript;

  SaveExpandedStates;

  FUpdatingTree := True;
  vstScripts.BeginUpdate;
  vstScripts.Clear;
  try
    FilterText := Trim(LowerCase(edFilter.Text));

    AllPaths := TStringList.Create;
    try
      AllPaths.Add(Path);
      for i := 0 to Pred(FExtraPaths.Count) do
        if AllPaths.IndexOf(FExtraPaths[i]) < 0 then
          AllPaths.Add(FExtraPaths[i]);

      for i := 0 to Pred(AllPaths.Count) do begin
        BasePath := IncludeTrailingPathDelimiter(AllPaths[i]);
        if not TDirectory.Exists(BasePath) then Continue;

        RootNode := vstScripts.AddChild(nil);
        Data := vstScripts.GetNodeData(RootNode);
        Data^.Name := ExtractFileName(ExcludeTrailingPathDelimiter(BasePath));
        Data^.BasePath := BasePath;
        Data^.IsFolder := False;
        Data^.IsRoot := True;

        FolderNodes := TDictionary<string, PVirtualNode>.Create;
        try
          Files := TDirectory.GetFiles(BasePath, '*' + sScriptExt, TSearchOption.soAllDirectories);
          TArray.Sort<string>(Files);
          for f in Files do begin
            sname := ChangeFileExt(Copy(f, Length(BasePath) + 1, MaxInt), '');
            if SameText(sNewScriptName, sname) then Continue;
            if (FilterText <> '') and not sname.ToLower.Contains(FilterText) then Continue;

            dirpart := ExtractFileDir(sname);
            leafname := ExtractFileName(sname);

            if dirpart <> '' then
              ScriptNode := vstScripts.AddChild(EnsureFolderNode(RootNode, dirpart, FolderNodes))
            else
              ScriptNode := vstScripts.AddChild(RootNode);

            Data := vstScripts.GetNodeData(ScriptNode);
            Data^.Name := leafname;
            Data^.RelativePath := sname;
            Data^.BasePath := BasePath;
            Data^.IsFolder := False;
            Data^.IsRoot := False;
          end;
        finally
          FolderNodes.Free;
        end;

      end;
    finally
      AllPaths.Free;
    end;

    // Bottom-up prune: remove folder/root nodes with no children
    var PruneNode := vstScripts.GetLast;
    while Assigned(PruneNode) do begin
      var PrevNode := vstScripts.GetPrevious(PruneNode);
      Data := vstScripts.GetNodeData(PruneNode);
      if (Data^.IsFolder or Data^.IsRoot) and
         not Assigned(vstScripts.GetFirstChild(PruneNode)) then
        vstScripts.DeleteNode(PruneNode);
      PruneNode := PrevNode;
    end;

    RestoreExpandedStates;
  finally
    vstScripts.EndUpdate;
  end;

  SelectNode := nil;
  if TargetFullPath <> '' then begin
    var Node := vstScripts.GetFirst;
    while Assigned(Node) do begin
      Data := vstScripts.GetNodeData(Node);
      if not Data^.IsFolder and not Data^.IsRoot and
         SameText(Data^.BasePath + Data^.RelativePath, TargetFullPath) then begin
        SelectNode := Node;
        Break;
      end;
      Node := vstScripts.GetNext(Node);
    end;
  end;
  if not Assigned(SelectNode) then
    SelectNode := FirstScriptNode;

  // Ensure ancestors of selected node are expanded so it's visible
  if Assigned(SelectNode) then begin
    var AncestorNode := SelectNode.Parent;
    while Assigned(AncestorNode) and (AncestorNode <> vstScripts.RootNode) do begin
      vstScripts.Expanded[AncestorNode] := True;
      AncestorNode := AncestorNode.Parent;
    end;
  end;

  vstScripts.FocusedNode := SelectNode;
  if Assigned(SelectNode) then begin
    vstScripts.Selected[SelectNode] := True;
    vstScripts.TopNode := SelectNode;
  end;

  FUpdatingTree := False;
  if Assigned(SelectNode) then
    DoScriptSelectionChange;
end;

procedure TfrmScript.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not FApplying then begin
    if Editor.Modified then
      if MessageDlg('The script has been modified. Do you want to save it?', mtConfirmation, mbYesNo, 0) = mrYes then
        btnSaveClick(Sender);
    SaveSettings;
    if Assigned(Settings) then begin
      Settings.WriteString('View', 'ScriptExtraPaths', ExtraPathsStr);
      Settings.WriteString('View', 'ScriptExpandedNodes', ExpandedNodesStr);
      Settings.UpdateFile;
    end;
  end;
  Action := caFree;
end;

procedure TfrmScript.SaveSettings;
begin
  ExtraPathsStr := String.Join(';', FExtraPaths.ToStringArray);
  SaveExpandedStates;
  ExpandedNodesStr := String.Join('|', FExpandedNodes.ToStringArray);
end;

procedure TfrmScript.DoApplyAndClose;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  FApplying := True;
  if Editor.Modified then
    if MessageDlg('The script has been modified. Do you want to save it?', mtConfirmation, mbYesNo, 0) = mrYes then
      btnSaveClick(Self);
  Script := Editor.Lines.Text;
  Node := vstScripts.FocusedNode;
  if Assigned(Node) then begin
    Data := vstScripts.GetNodeData(Node);
    if not Data^.IsFolder and not Data^.IsRoot then
      LastUsedScript := Data^.BasePath + Data^.RelativePath;
  end;
  SaveSettings;
  if Assigned(OnApplyScript) then
    OnApplyScript(LastUsedScript, Script, ExtraPathsStr, ExpandedNodesStr, RefByMode);
  Release;
end;

procedure TfrmScript.btnOKClick(Sender: TObject);
begin
  DoApplyAndClose;
end;

procedure TfrmScript.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmScript.SetColorScheme(const AScheme: string);
const
  // Light schemes
  csDelphiClassic: TEditorColorScheme = (
    Background: $00FFFFFF; Text: $00000000;
    Keyword: $00800000; KeywordStyle: [fsBold];
    Comment: $00008000; CommentStyle: [fsItalic];
    Str: $00000080; Number: $00800000;
    Directive: $00808000; DirectiveStyle: [fsItalic];
    AsmColor: $00800000
  );
  csVisualStudio: TEditorColorScheme = (
    Background: $00FFFFFF; Text: $00000000;
    Keyword: $00FF0000; KeywordStyle: [fsBold];
    Comment: $00008000; CommentStyle: [fsItalic];
    Str: $001515A3; Number: $00588609;
    Directive: $00DB00AF; DirectiveStyle: [fsItalic];
    AsmColor: $00FF0000
  );
  csSolarizedLight: TEditorColorScheme = (
    Background: $00E3F6FD; Text: $00837B65;
    Keyword: $00D28B26; KeywordStyle: [fsBold];
    Comment: $00A1A193; CommentStyle: [fsItalic];
    Str: $0098A12A; Number: $008236D3;
    Directive: $00164BCB; DirectiveStyle: [fsItalic];
    AsmColor: $00D28B26
  );
  // Dark schemes
  csVSCodeDark: TEditorColorScheme = (
    Background: $001E1E1E; Text: $00D4D4D4;
    Keyword: $00D69C56; KeywordStyle: [fsBold];
    Comment: $0055996A; CommentStyle: [fsItalic];
    Str: $007891CE; Number: $00A8CEB5;
    Directive: $00C086C5; DirectiveStyle: [fsItalic];
    AsmColor: $00D69C56
  );
  csMonokai: TEditorColorScheme = (
    Background: $00222827; Text: $00F2F8F8;
    Keyword: $007226F9; KeywordStyle: [fsBold];
    Comment: $005E7175; CommentStyle: [fsItalic];
    Str: $0074DBE6; Number: $00FF81AE;
    Directive: $002EE2A6; DirectiveStyle: [fsItalic];
    AsmColor: $00E8D966
  );
  csOneDark: TEditorColorScheme = (
    Background: $00342C28; Text: $00BFB2AB;
    Keyword: $00DD78C6; KeywordStyle: [fsBold];
    Comment: $0070635C; CommentStyle: [fsItalic];
    Str: $0079C398; Number: $00669AD1;
    Directive: $007BC0E5; DirectiveStyle: [fsItalic];
    AsmColor: $00EFAF61
  );
var
  Scheme: string;
  CS: TEditorColorScheme;
begin
  Scheme := AScheme;
  if Scheme = cEditorSchemeAuto then
    if wbDarkMode then
      Scheme := cEditorSchemeVSCodeDark
    else
      Scheme := cEditorSchemeDelphiClassic;

  if      Scheme = cEditorSchemeDelphiClassic  then CS := csDelphiClassic
  else if Scheme = cEditorSchemeVisualStudio   then CS := csVisualStudio
  else if Scheme = cEditorSchemeSolarizedLight then CS := csSolarizedLight
  else if Scheme = cEditorSchemeVSCodeDark     then CS := csVSCodeDark
  else if Scheme = cEditorSchemeMonokai        then CS := csMonokai
  else if Scheme = cEditorSchemeOneDark        then CS := csOneDark
  else Exit;

  Editor.Color := CS.Background;
  Editor.Font.Color := CS.Text;

  with Highlighter do begin
    KeyAttri.Style           := CS.KeywordStyle;
    KeyAttri.Foreground      := CS.Keyword;
    CommentAttri.Style       := CS.CommentStyle;
    CommentAttri.Foreground  := CS.Comment;
    StringAttri.Foreground   := CS.Str;
    CharAttri.Foreground     := CS.Str;
    NumberAttri.Foreground   := CS.Number;
    FloatAttri.Foreground    := CS.Number;
    HexAttri.Foreground      := CS.Number;
    DirectiveAttri.Style     := CS.DirectiveStyle;
    DirectiveAttri.Foreground := CS.Directive;
    AsmAttri.Foreground      := CS.AsmColor;
    IdentifierAttri.Foreground := clNone;
    SymbolAttri.Foreground     := clNone;
  end;

  Editor.Invalidate;
end;

procedure TfrmScript.FormCreate(Sender: TObject);
begin
  vstScripts.NodeDataSize := SizeOf(TScriptNodeData);

  FExtraPaths := TStringList.Create;
  FExpandedNodes := TStringList.Create;
  FExpandedNodes.Sorted := True;
  FInsertRefCodes := TStringList.Create;

  CreateTreeContextMenu;
  DragAcceptFiles(Self.Handle, True);

  pnlEditor := TPanel.Create(Self);
  pnlEditor.Parent := Self;
  pnlEditor.Align := alClient;
  pnlEditor.BevelOuter := bvNone;

  CreateToolbar;
  CreateStatusBar;
  CreateEditor;
end;

procedure TfrmScript.CreateTreeContextMenu;
var
  Sep: TMenuItem;
begin
  pmuTree := TPopupMenu.Create(Self);
  pmuTree.OnPopup := pmuTreePopup;

  mniNewScript := TMenuItem.Create(pmuTree);
  mniNewScript.Caption := 'New Script...';
  mniNewScript.OnClick := mniNewScriptClick;
  pmuTree.Items.Add(mniNewScript);

  Sep := TMenuItem.Create(pmuTree);
  Sep.Caption := '-';
  pmuTree.Items.Add(Sep);

  mniAddFolder := TMenuItem.Create(pmuTree);
  mniAddFolder.Caption := 'Add Folder...';
  mniAddFolder.OnClick := mniAddFolderClick;
  pmuTree.Items.Add(mniAddFolder);

  mniRemoveFolder := TMenuItem.Create(pmuTree);
  mniRemoveFolder.Caption := 'Remove Folder';
  mniRemoveFolder.OnClick := mniRemoveFolderClick;
  pmuTree.Items.Add(mniRemoveFolder);

  vstScripts.PopupMenu := pmuTree;
  vstScripts.HintMode := hmHint;
  vstScripts.ShowHint := True;
  vstScripts.OnGetHint := vstScriptsGetHint;
end;

procedure TfrmScript.CreateToolbar;
begin
  pnlToolbar := TPanel.Create(Self);
  pnlToolbar.Parent := pnlEditor;
  pnlToolbar.Align := alTop;
  pnlToolbar.Height := 26;
  pnlToolbar.BevelOuter := bvNone;

  btnToolSave := TSpeedButton.Create(Self);
  btnToolSave.Parent := pnlToolbar;
  btnToolSave.Left := 4;
  btnToolSave.Top := 1;
  btnToolSave.Width := 26;
  btnToolSave.Height := 24;
  btnToolSave.Caption := #$1F4BE;
  btnToolSave.Flat := True;
  btnToolSave.Enabled := False;
  btnToolSave.OnClick := btnSaveClick;

  btnToolReset := TSpeedButton.Create(Self);
  btnToolReset.Parent := pnlToolbar;
  btnToolReset.Left := 34;
  btnToolReset.Top := 1;
  btnToolReset.Width := 26;
  btnToolReset.Height := 24;
  btnToolReset.Caption := #$21A9;
  btnToolReset.Flat := True;
  btnToolReset.Enabled := False;
  btnToolReset.OnClick := btnToolResetClick;

  btnToolInsertRef := TSpeedButton.Create(Self);
  btnToolInsertRef.Parent := pnlToolbar;
  btnToolInsertRef.Left := 64;
  btnToolInsertRef.Top := 1;
  btnToolInsertRef.Width := 26;
  btnToolInsertRef.Height := 24;
  btnToolInsertRef.Caption := #$1F4CB;
  btnToolInsertRef.Flat := True;
  btnToolInsertRef.ShowHint := True;
  btnToolInsertRef.Hint := 'Insert Reference (Ctrl+I)';
  btnToolInsertRef.OnClick := btnToolInsertRefClick;

  pmuInsertRef := TPopupMenu.Create(Self);
end;

procedure TfrmScript.CreateStatusBar;
begin
  pnlStatusBar := TPanel.Create(Self);
  pnlStatusBar.Parent := pnlEditor;
  pnlStatusBar.Align := alBottom;
  pnlStatusBar.Height := 21;
  pnlStatusBar.BevelOuter := bvLowered;

  lblCaret := TLabel.Create(Self);
  lblCaret.Parent := pnlStatusBar;
  lblCaret.Left := 8;
  lblCaret.Top := 4;
  lblCaret.Width := 120;
  lblCaret.AutoSize := False;
  lblCaret.Caption := 'Line:1 Col:1';

  lblModified := TLabel.Create(Self);
  lblModified.Parent := pnlStatusBar;
  lblModified.Left := 140;
  lblModified.Top := 4;
  lblModified.Width := 80;
  lblModified.AutoSize := False;
  lblModified.Caption := '';

  lblInsMode := TLabel.Create(Self);
  lblInsMode.Parent := pnlStatusBar;
  lblInsMode.Align := alRight;
  lblInsMode.Width := 40;
  lblInsMode.Alignment := taRightJustify;
  lblInsMode.Layout := tlCenter;
  lblInsMode.Caption := 'INS';
end;

procedure TfrmScript.CreateEditor;
begin
  Editor := TSynMemo.Create(Self);
  Editor.Parent := pnlEditor;
  Editor.Align := alClient;
  Editor.Font.Name := 'Courier New';
  Editor.Font.Height := -11;
  Editor.ParentFont := False;
  Editor.ScrollBars := ssBoth;
  Editor.TabOrder := 3;
  Editor.WantTabs := True;
  Editor.WordWrap := False;
  Editor.OnKeyDown := EditorKeyDown;
  Editor.OnKeyPress := EditorKeyPress;
  Editor.OnStatusChange := EditorStatusChange;

  Highlighter := TSynPasSyn.Create(Self);
  Editor.Highlighter := Highlighter;
  SetColorScheme(cEditorSchemeAuto);
  if frmMain.MonospaceFontName <> '' then
    Editor.Font.Name := frmMain.MonospaceFontName;

  Editor.Gutter.ShowLineNumbers := True;
  Editor.Gutter.AutoSize := True;
  Editor.Gutter.Visible := False;
  Editor.Gutter.Visible := True;

  pmuEditor := TPopupMenu.Create(Self);
  mniEditorInsertRef := TMenuItem.Create(pmuEditor);
  mniEditorInsertRef.Caption := 'Insert Reference';
  mniEditorInsertRef.ShortCut := ShortCut(Ord('I'), [ssCtrl]);
  mniEditorInsertRef.OnClick := btnToolInsertRefClick;
  pmuEditor.Items.Add(mniEditorInsertRef);
  Editor.PopupMenu := pmuEditor;
end;

procedure TfrmScript.LoadScriptFromFile(const AFilePath: string);
begin
  with TStringList.Create do try
    try
      LoadFromFile(AFilePath);
    except
      on E: Exception do begin
        lblModified.Caption := 'Load error: ' + E.Message;
        Exit;
      end;
    end;
    Editor.Lines.Text := Text.Replace(#9, #32#32);
    Editor.Modified := False;
  finally
    Free;
  end;
end;

procedure TfrmScript.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FInsertRefCodes);
  FreeAndNil(FExpandedNodes);
  FreeAndNil(FExtraPaths);
end;

procedure TfrmScript.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('S')) and (Shift = [ssCtrl]) then begin
    Key := 0;
    if Editor.Modified then btnSaveClick(Self);
  end else if (Key = Ord('I')) and (Shift = [ssCtrl]) then begin
    Key := 0;
    btnToolInsertRefClick(Self);
  end else if Key = VK_ESCAPE then
    if edFilter.Focused then begin
      edFilter.Text := '';
      edFilterChange(Sender);
    end else
      Close;
end;

procedure TfrmScript.GoToErrorLine;
begin
  Editor.CaretXY := BufferCoord(1, ErrorLine);
  Editor.EnsureCursorPosVisible;
  lblModified.Caption := ErrorMessage;
  frmMain.ScriptLastErrorLine := -1;
  frmMain.ScriptLastErrorUnitName := '';
  frmMain.ScriptLastErrorMessage := '';
  ErrorLine := -1;
  ErrorUnitName := '';
  ErrorMessage := '';
end;

procedure TfrmScript.FormShow(Sender: TObject);
var
  Parts: TArray<string>;
  s: string;
begin
  FExtraPaths.Clear;
  if ExtraPathsStr <> '' then begin
    Parts := ExtraPathsStr.Split([';']);
    for s in Parts do
      if s.Trim <> '' then
        FExtraPaths.Add(IncludeTrailingPathDelimiter(s.Trim));
  end;
  FExpandedNodes.Clear;
  if ExpandedNodesStr <> '' then begin
    Parts := ExpandedNodesStr.Split(['|']);
    for s in Parts do
      if s <> '' then
        FExpandedNodes.Add(s);
  end;
  ReadScriptsList;
  if ErrorLine > 0 then
    GoToErrorLine;
end;

procedure TfrmScript.vstScriptsDblClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  Node := vstScripts.FocusedNode;
  if Assigned(Node) then begin
    Data := vstScripts.GetNodeData(Node);
    if not Data^.IsFolder and not Data^.IsRoot then
      Editor.SetFocus;
  end;
end;

procedure TfrmScript.vstScriptsFocusChanged(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex);
begin
  if FUpdatingTree or not Assigned(Node) then Exit;
  DoScriptSelectionChange;
end;

procedure TfrmScript.vstScriptsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  Data: PScriptNodeData;
begin
  Data := Sender.GetNodeData(Node);
  Finalize(Data^);
end;

procedure TfrmScript.vstScriptsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  Data: PScriptNodeData;
begin
  if TextType <> ttNormal then Exit;
  Data := Sender.GetNodeData(Node);
  CellText := Data^.Name;
end;

procedure TfrmScript.vstScriptsGetHint(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex;
  var LineBreakStyle: TVTTooltipLineBreakStyle; var HintText: string);
var
  Data: PScriptNodeData;
begin
  Data := Sender.GetNodeData(Node);
  if Data^.IsRoot then
    HintText := ExcludeTrailingPathDelimiter(Data^.BasePath)
  else if not Data^.IsFolder and (Data^.RelativePath <> '') then
    HintText := Data^.BasePath + Data^.RelativePath + sScriptExt
  else
    HintText := '';
end;

function TfrmScript.GetNodeKey(Node: PVirtualNode): string;
var
  Data: PScriptNodeData;
  N: PVirtualNode;
  Parts: string;
begin
  Data := vstScripts.GetNodeData(Node);
  if Data^.IsRoot then begin
    Result := Data^.BasePath;
    Exit;
  end;
  // Build path from folder names up to root
  Parts := Data^.Name;
  N := Node.Parent;
  while Assigned(N) and (N <> vstScripts.RootNode) do begin
    Data := vstScripts.GetNodeData(N);
    if Data^.IsRoot then begin
      Result := Data^.BasePath + '::' + Parts;
      Exit;
    end;
    Parts := Data^.Name + '\' + Parts;
    N := N.Parent;
  end;
  Result := Parts;
end;

procedure TfrmScript.SaveExpandedStates;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  FExpandedNodes.Clear;
  Node := vstScripts.GetFirst;
  while Assigned(Node) do begin
    Data := vstScripts.GetNodeData(Node);
    if (Data^.IsRoot or Data^.IsFolder) and vstScripts.Expanded[Node] then
      FExpandedNodes.Add(GetNodeKey(Node));
    Node := vstScripts.GetNext(Node);
  end;
end;

procedure TfrmScript.RestoreExpandedStates;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  Node := vstScripts.GetFirst;
  while Assigned(Node) do begin
    Data := vstScripts.GetNodeData(Node);
    if (Data^.IsRoot or Data^.IsFolder) and
       (FExpandedNodes.IndexOf(GetNodeKey(Node)) >= 0) then
      vstScripts.Expanded[Node] := True;
    Node := vstScripts.GetNext(Node);
  end;
end;

procedure TfrmScript.WMDropFiles(var Msg: TWMDropFiles);
var
  i, Count: Integer;
  Buf: array[0..MAX_PATH] of Char;
  Dir: string;
  Changed: Boolean;
begin
  Changed := False;
  Count := DragQueryFile(Msg.Drop, $FFFFFFFF, nil, 0);
  try
    for i := 0 to Pred(Count) do begin
      DragQueryFile(Msg.Drop, i, Buf, MAX_PATH);
      Dir := Buf;
      if not TDirectory.Exists(Dir) then Continue;
      Dir := IncludeTrailingPathDelimiter(Dir);
      if SameText(Dir, Path) then Continue;
      if FExtraPaths.IndexOf(Dir) >= 0 then Continue;
      FExtraPaths.Add(Dir);
      Changed := True;
    end;
  finally
    DragFinish(Msg.Drop);
  end;
  if Changed then
    ReadScriptsList;
  Msg.Result := 0;
end;

procedure TfrmScript.vstScriptsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then begin
    Key := 0;
    Editor.SetFocus;
  end;
end;

function TfrmScript.GetSignatureStr(aElement: IwbElement): string;
var
  Rec: IwbRecord;
  HasSig: IwbHasSignature;
  Sig: TwbSignature;
begin
  Result := '';
  if Supports(aElement, IwbRecord, Rec) then
    Result := Rec.DisplaySignature
  else if Supports(aElement, IwbHasSignature, HasSig) then begin
    Sig := HasSig.Signature;
    Result := string(AnsiString(PAnsiChar(@Sig[0])));
    if Length(Result) <> 4 then
      Result := '';
  end;
end;

function TfrmScript.GetRelativePath(aElement: IwbElement; aMainRec: IwbMainRecord): string;
var
  ElemPath, OwnerPath: string;
  Parts: TArray<string>;
  i, DashPos: Integer;
begin
  Result := '';
  ElemPath := aElement.Path;
  OwnerPath := aMainRec.Path;
  if (Length(ElemPath) > Length(OwnerPath)) and
     SameText(Copy(ElemPath, 1, Length(OwnerPath)), OwnerPath) then begin
    Result := Copy(ElemPath, Length(OwnerPath) + 1, MaxInt);
    if Copy(Result, 1, 3) = ' \ ' then
      Delete(Result, 1, 3)
    else if (Result <> '') and (Result[1] = '\') then
      Delete(Result, 1, 1);
    Result := StringReplace(Result, ' \ ', '\', [rfReplaceAll]);
    // Strip verbose names from signature segments: "ACBS - Configuration" -> "ACBS"
    Parts := Result.Split(['\']);
    for i := 0 to High(Parts) do begin
      DashPos := Pos(' - ', Parts[i]);
      if (DashPos = 5) and (Length(Parts[i]) >= 4) then
        Parts[i] := Copy(Parts[i], 1, 4);
    end;
    Result := string.Join('\', Parts);
  end;
end;

function TfrmScript.BuildNavRefCode(aElement: IwbElement): string;
var
  FileElem: IwbFile;
  MainRec: IwbMainRecord;
  GroupRec: IwbGroupRecord;
  FormIDStr, EdID, FileName, RelPath: string;
begin
  Result := '';
  if Supports(aElement, IwbFile, FileElem) then
    Result := 'FileByName(''' + FileElem.FileName + ''')'
  else if Supports(aElement, IwbMainRecord, MainRec) then begin
    FormIDStr := '$' + MainRec.LoadOrderFormID.ToString;
    FileName := MainRec._File.FileName;
    EdID := MainRec.EditorID;
    Result := 'RecordByFormID(FileByName(''' + FileName + '''), ' + FormIDStr + ', True)';
    if EdID <> '' then
      Result := Result + ' // ' + EdID;
  end
  else if Supports(aElement, IwbGroupRecord, GroupRec) then begin
    if GroupRec.GroupType = 0 then begin
      FileName := aElement._File.FileName;
      Result := 'f := FileByName(''' + FileName + ''');' + sLineBreak +
                'g := GroupBySignature(f, ''' + GroupRec.GroupLabelSignature + ''');' + sLineBreak +
                'for i := 0 to Pred(ElementCount(g)) do begin' + sLineBreak +
                '  r := ElementByIndex(g, i);' + sLineBreak +
                '  // ...' + sLineBreak +
                'end;';
    end else begin
      MainRec := aElement.ContainingMainRecord;
      if Assigned(MainRec) then begin
        RelPath := GetRelativePath(aElement, MainRec);
        if RelPath <> '' then
          Result := 'ElementByPath(r, ''' + RelPath + ''')';
      end;
    end;
  end;
end;

procedure TfrmScript.BuildViewRefPopup(aElement: IwbElement; const aPopupPos: TPoint; const aNavCode: string);
var
  Templates: TwbTemplateElements;
  MainRec: IwbMainRecord;
  Container: IwbContainerBase;
  ValDef: IwbValueDef;
  Sig, RelPath, Accessor, Code: string;
  HasLinksTo, UseEdit, UseNative: Boolean;
  Sep: TMenuItem;
  i: Integer;

  procedure AddItem(const aCaption, aCode: string);
  var
    mni: TMenuItem;
  begin
    FInsertRefCodes.Add(aCode);
    mni := TMenuItem.Create(pmuInsertRef);
    mni.Caption := aCaption;
    mni.Tag := FInsertRefCodes.Count - 1;
    mni.OnClick := pmuInsertRefItemClick;
    pmuInsertRef.Items.Add(mni);
  end;

begin
  pmuInsertRef.Items.Clear;
  FInsertRefCodes.Clear;

  Templates := aElement.GetAssignTemplates(High(Integer));
  if Length(Templates) > 0 then begin
    for i := 0 to High(Templates) do begin
      Code := 'e := TemplateAssign(container, ''' + Templates[i].Name + ''');';
      if Supports(Templates[i], IwbContainerBase, Container) then begin
        var j: Integer;
        for j := 0 to Pred(Container.ElementCount) do
          Code := Code + sLineBreak + 'SetElementEditValues(e, ''' +
            Container.Elements[j].Name + ''', '''');';
      end;
      AddItem(Templates[i].Name, Code);
    end;
  end;

  Sig := GetSignatureStr(aElement);
  MainRec := aElement.ContainingMainRecord;
  if Assigned(MainRec) then begin
    RelPath := GetRelativePath(aElement, MainRec);
    if RelPath <> '' then begin
      HasLinksTo := Assigned(aElement.LinksTo);
      UseEdit := True;
      UseNative := True;
      ValDef := aElement.ValueDef;
      if Assigned(ValDef) then
        case ValDef.DefType of
          dtString, dtLString, dtLenString, dtGuid:
            UseNative := False;
          dtInteger, dtIntegerFormater, dtIntegerFormaterUnion, dtFlag, dtFloat:
            UseEdit := False;
        end;
      if pmuInsertRef.Items.Count > 0 then begin
        Sep := TMenuItem.Create(pmuInsertRef);
        Sep.Caption := '-';
        pmuInsertRef.Items.Add(Sep);
      end;
      if (Sig <> '') and (Pos('\', RelPath) = 0) then begin
        AddItem('Add', 'Add(r, ''' + Sig + ''', True)');
        AddItem('CopyByPath', 'CopyByPath(r, ''' + Sig + ''', sourceElement)');
        Accessor := 'ElementBySignature(r, ''' + Sig + ''')';
        AddItem('ElementBySignature', Accessor);
        if UseEdit then begin
          AddItem('GetEditValue', 'GetEditValue(' + Accessor + ')');
          AddItem('SetEditValue', 'SetEditValue(' + Accessor + ', value)');
        end;
        if UseNative then begin
          AddItem('GetNativeValue', 'GetNativeValue(' + Accessor + ')');
          AddItem('SetNativeValue', 'SetNativeValue(' + Accessor + ', value)');
        end;
        if HasLinksTo then
          AddItem('LinksTo', 'LinksTo(' + Accessor + ')');
      end else begin
        AddItem('Add', 'Add(r, ''' + RelPath + ''', True)');
        AddItem('CopyByPath', 'CopyByPath(r, ''' + RelPath + ''', sourceElement)');
        AddItem('ElementByPath', 'ElementByPath(r, ''' + RelPath + ''')');
        if UseEdit then begin
          AddItem('GetElementEditValues', 'GetElementEditValues(r, ''' + RelPath + ''')');
          AddItem('SetElementEditValues', 'SetElementEditValues(r, ''' + RelPath + ''', value)');
        end;
        if UseNative then begin
          AddItem('GetElementNativeValues', 'GetElementNativeValues(r, ''' + RelPath + ''')');
          AddItem('SetElementNativeValues', 'SetElementNativeValues(r, ''' + RelPath + ''', value)');
        end;
        if HasLinksTo then
          AddItem('LinksTo', 'LinksTo(ElementByPath(r, ''' + RelPath + '''))');
      end;
    end;
  end;

  if aNavCode <> '' then begin
    if pmuInsertRef.Items.Count > 0 then begin
      Sep := TMenuItem.Create(pmuInsertRef);
      Sep.Caption := '-';
      pmuInsertRef.Items.Add(Sep);
    end;
    AddItem('Nav Reference', aNavCode);
  end;

  if pmuInsertRef.Items.Count > 0 then
    pmuInsertRef.Popup(aPopupPos.X, aPopupPos.Y);
end;

procedure TfrmScript.btnToolInsertRefClick(Sender: TObject);
var
  ViewElem, NavElem: IwbElement;
  NavCode: string;
  Pt: TPoint;
begin
  ViewElem := frmMain.GetFocusedViewElementSafely;
  if Assigned(ViewElem) and
     (Supports(ViewElem, IwbFile) or
      Supports(ViewElem, IwbMainRecord) or
      Supports(ViewElem, IwbGroupRecord)) then
    ViewElem := nil;

  NavElem := frmMain.GetFocusedNavElementSafely;
  NavCode := '';
  if Assigned(NavElem) then
    NavCode := BuildNavRefCode(NavElem);

  if Assigned(ViewElem) then begin
    if Sender = btnToolInsertRef then begin
      Pt.X := 0;
      Pt.Y := btnToolInsertRef.Height;
      Pt := btnToolInsertRef.ClientToScreen(Pt);
    end else
      Pt := Mouse.CursorPos;
    BuildViewRefPopup(ViewElem, Pt, NavCode);
    Exit;
  end;

  if NavCode <> '' then begin
    Editor.SelText := NavCode;
    Editor.SetFocus;
    Exit;
  end;

  MessageDlg('No element selected in the main window.', mtInformation, [mbOK], 0);
end;

procedure TfrmScript.pmuInsertRefItemClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := TMenuItem(Sender).Tag;
  if (Idx >= 0) and (Idx < FInsertRefCodes.Count) then begin
    Editor.SelText := FInsertRefCodes[Idx];
    Editor.SetFocus;
  end;
end;

end.
