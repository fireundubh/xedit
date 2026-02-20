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
  Dialogs, StdCtrls, ExtCtrls, IOUtils, StrUtils, Vcl.ComCtrls, System.UITypes,
  Generics.Collections,
  SynEdit, SynMemo, SynEditKeyCmds, xeMainForm, SynHighlighterPas,
  VirtualTrees;

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
    IsFolder: Boolean;
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

  TfrmScript = class(TForm)
    pnlLeft: TPanel;
    edFilter: TEdit;
    vstScripts: TVirtualStringTree;
    splLeft: TSplitter;
    pnlBottom: TPanel;
    btnNewScript: TButton;
    btnSave: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    pnlStatus: TPanel;
    lblPosition: TLabel;
    dlgSave: TSaveDialog;
    procedure FormCreate(Sender: TObject);
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
    procedure btnSaveClick(Sender: TObject);
    procedure btnNewScriptClick(Sender: TObject);
    procedure EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
  private
    Editor: TSynMemo;
    Highlighter: TSynPasSyn;
    FUpdatingTree: Boolean;
    FCurrentRelPath: string;
    SaveOverride: string;
    function EnsureFolderNode(const FolderPath: string; FolderNodes: TDictionary<string, PVirtualNode>): PVirtualNode;
    function FirstScriptNode: PVirtualNode;
    function Indent(aText: string; aPrefix: string): string;
    function Dedent(aText: string; aPrefix: string): string;
    procedure DoScriptSelectionChange;
  public
    Path: string;
    LastUsedScript: string;
    Script: string;
    procedure UpdateCaretPos;
    procedure ReadScriptsList;
    procedure SetColorScheme(const AScheme: string);
  end;

var
  frmScript: TfrmScript;

implementation

{$R *.dfm}

uses
  wbInterface;

procedure TfrmScript.btnNewScriptClick(Sender: TObject);
begin
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

  FCurrentRelPath := '';
  SaveOverride := sNewScript;
  Editor.Lines.Clear;
  with TStringList.Create do try
    try
      LoadFromFile(Path + sNewScriptName + sScriptExt);
    except end;
    Editor.Lines.Text := Text.Replace(#9, #32#32);
  finally
    Free;
  end;
  Editor.Modified := False;
  Editor.SetFocus;
  UpdateCaretPos;
end;

procedure TfrmScript.btnSaveClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
  s, s2: string;
  WasNewScript: Boolean;
begin
  WasNewScript := False;
  s := SaveOverride;
  if s = '' then begin
    Node := vstScripts.FocusedNode;
    if not Assigned(Node) then Exit;
    Data := vstScripts.GetNodeData(Node);
    if Data^.IsFolder or (Data^.RelativePath = '') then Exit;
    s := Data^.RelativePath;
  end;

  if s = sNewScript then begin
    WasNewScript := True;
    dlgSave.InitialDir := Path;
    if dlgSave.Execute then begin
      s2 := dlgSave.FileName;
      if s2.StartsWith(Path, True) then
        s2 := ChangeFileExt(Copy(s2, Length(Path) + 1, MaxInt), '')
      else
        s2 := ChangeFileExt(ExtractFileName(s2), '');
      s := Path + s2 + sScriptExt;
    end else
      Exit;
  end else
    s := Path + s + sScriptExt;

  with TStringList.Create do try
    Text := Editor.Lines.Text.Replace(#9, #32#32);
    CopyFile(PChar(s), PChar(s + '.backup.' + FormatDateTime('yyyy_mm_dd_hh_nn_ss', Now)), True);
    SaveToFile(s);
    lblPosition.Caption := Format('Saved: %s', [ExtractFileName(s)]);
    Editor.Modified := False;
  finally
    Free;
  end;

  if WasNewScript then begin
    FCurrentRelPath := s2;
    SaveOverride := '';
    ReadScriptsList;
  end;
end;

procedure TfrmScript.DoScriptSelectionChange;
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
  NewRelPath, OldRelPath: string;
begin
  Node := vstScripts.FocusedNode;
  if not Assigned(Node) then Exit;
  Data := vstScripts.GetNodeData(Node);
  if Data^.IsFolder then Exit;

  NewRelPath := Data^.RelativePath;
  if SameText(NewRelPath, FCurrentRelPath) then Exit;

  if Editor.Modified and (Editor.Text.Trim <> '') then begin
    OldRelPath := FCurrentRelPath;
    if MessageDlg('The previous script has been modified. Do you want to save it before loading the new script?',
                  mtConfirmation, mbYesNo, 0) = mrYes then
      btnSaveClick(Self);
    if FCurrentRelPath <> OldRelPath then
      Exit;
  end;

  FCurrentRelPath := NewRelPath;
  SaveOverride := '';
  Editor.Lines.Clear;
  with TStringList.Create do try
    try
      LoadFromFile(Path + NewRelPath + sScriptExt);
    except end;
    Editor.Lines.Text := Text.Replace(#9, #32#32);
    Editor.Modified := False;
    UpdateCaretPos;
  finally
    Free;
  end;
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
  lblPosition.Caption := Format('Line:%d Col:%d', [Editor.CaretY, Editor.CaretX]);
end;

procedure TfrmScript.EditorMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  UpdateCaretPos;
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

procedure TfrmScript.EditorKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  UpdateCaretPos;
end;

function TfrmScript.EnsureFolderNode(const FolderPath: string; FolderNodes: TDictionary<string, PVirtualNode>): PVirtualNode;
var
  ParentPath: string;
  ParentNode: PVirtualNode;
  Data: PScriptNodeData;
begin
  if FolderNodes.TryGetValue(FolderPath, Result) then Exit;

  ParentPath := ExtractFileDir(FolderPath);
  if ParentPath = '' then
    ParentNode := nil
  else
    ParentNode := EnsureFolderNode(ParentPath, FolderNodes);

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
    if not Data^.IsFolder then begin
      Result := Node;
      Exit;
    end;
    Node := vstScripts.GetNext(Node);
  end;
end;

procedure TfrmScript.ReadScriptsList;
var
  FolderNodes: TDictionary<string, PVirtualNode>;
  Files: TArray<string>;
  f, sname, dirpart, leafname: string;
  ScriptNode, SelectNode: PVirtualNode;
  Data: PScriptNodeData;
  FilterText, TargetRelPath: string;
begin
  Path := IncludeTrailingPathDelimiter(Path);

  TargetRelPath := '';
  SelectNode := vstScripts.FocusedNode;
  if Assigned(SelectNode) then begin
    Data := vstScripts.GetNodeData(SelectNode);
    if not Data^.IsFolder then
      TargetRelPath := Data^.RelativePath;
  end;
  if TargetRelPath = '' then
    TargetRelPath := LastUsedScript;

  FUpdatingTree := True;
  vstScripts.BeginUpdate;
  vstScripts.Clear;
  FolderNodes := TDictionary<string, PVirtualNode>.Create;
  try
    FilterText := edFilter.Text;
    FilterText := FilterText.Trim.ToLower;
    if TDirectory.Exists(Path) then begin
      Files := TDirectory.GetFiles(Path, '*' + sScriptExt, TSearchOption.soAllDirectories);
      TArray.Sort<string>(Files);
      for f in Files do begin
        sname := ChangeFileExt(Copy(f, Length(Path) + 1, MaxInt), '');
        if SameText(sNewScriptName, sname) then Continue;
        if (FilterText <> '') and not sname.ToLower.Contains(FilterText) then Continue;

        dirpart := ExtractFileDir(sname);
        leafname := ExtractFileName(sname);

        if dirpart <> '' then
          ScriptNode := vstScripts.AddChild(EnsureFolderNode(dirpart, FolderNodes))
        else
          ScriptNode := vstScripts.AddChild(nil);

        Data := vstScripts.GetNodeData(ScriptNode);
        Data^.Name := leafname;
        Data^.RelativePath := sname;
        Data^.IsFolder := False;
      end;
    end;
    vstScripts.FullExpand;
  finally
    FolderNodes.Free;
    vstScripts.EndUpdate;
  end;

  SelectNode := nil;
  if TargetRelPath <> '' then begin
    var Node := vstScripts.GetFirst;
    while Assigned(Node) do begin
      Data := vstScripts.GetNodeData(Node);
      if not Data^.IsFolder and SameText(Data^.RelativePath, TargetRelPath) then begin
        SelectNode := Node;
        Break;
      end;
      Node := vstScripts.GetNext(Node);
    end;
  end;
  if not Assigned(SelectNode) then
    SelectNode := FirstScriptNode;

  vstScripts.FocusedNode := SelectNode;
  if Assigned(SelectNode) then begin
    vstScripts.Selected[SelectNode] := True;
    vstScripts.ScrollIntoView(SelectNode, False);
  end;

  FUpdatingTree := False;
  if Assigned(SelectNode) then
    DoScriptSelectionChange;
end;

procedure TfrmScript.FormClose(Sender: TObject; var Action: TCloseAction);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  if ModalResult = mrOk then begin
    if Editor.Modified then
      if MessageDlg('The script has been modified. Do you want to save it?', mtConfirmation, mbYesNo, 0) = mrYes then
        btnSaveClick(Sender);
    Script := Editor.Lines.Text;
    Node := vstScripts.FocusedNode;
    if Assigned(Node) then begin
      Data := vstScripts.GetNodeData(Node);
      if not Data^.IsFolder then
        LastUsedScript := Data^.RelativePath;
    end;
  end;
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

  Editor := TSynMemo.Create(Self);
  Editor.Parent := Self;
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
  Editor.OnKeyUp := EditorKeyUp;
  Editor.OnMouseUp := EditorMouseUp;

  Highlighter := TSynPasSyn.Create(Self);
  Editor.Highlighter := Highlighter;
  SetColorScheme(cEditorSchemeAuto);
  if frmMain.MonospaceFontName <> '' then
    Editor.Font.Name := frmMain.MonospaceFontName;

  Editor.Gutter.ShowLineNumbers := True;
  Editor.Gutter.AutoSize := True;
  Editor.Gutter.Visible := False;
  Editor.Gutter.Visible := True;
end;

procedure TfrmScript.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    if edFilter.Focused then begin
      edFilter.Text := '';
      edFilterChange(Sender);
    end else
      ModalResult := mrCancel;
end;

procedure TfrmScript.FormShow(Sender: TObject);
begin
  ReadScriptsList;
end;

procedure TfrmScript.vstScriptsDblClick(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PScriptNodeData;
begin
  Node := vstScripts.FocusedNode;
  if Assigned(Node) then begin
    Data := vstScripts.GetNodeData(Node);
    if not Data^.IsFolder then
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

procedure TfrmScript.vstScriptsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then begin
    Key := 0;
    Editor.SetFocus;
  end;
end;

end.
