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
  SynEdit, SynMemo, SynEditKeyCmds, xeMainForm, SynHighlighterPas;

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

  TComboBox = class(StdCtrls.TComboBox)
  protected {private}
    FOnBeforeWheel: TNotifyEvent;
    FOnAfterWheel: TNotifyEvent;
  protected
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;

    property OnBeforeWheel: TNotifyEvent read FOnBeforeWheel write FOnBeforeWheel;
    property OnAfterWheel: TNotifyEvent read FOnAfterWheel write FOnAfterWheel;
  end;

  TfrmScript = class(TForm)
    pnlTop: TPanel;
    cmbScripts: TComboBox;
    pnlBottom: TPanel;
    btnCancel: TButton;
    btnOK: TButton;
    pnlStatus: TPanel;
    lblPosition: TLabel;
    btnSave: TButton;
    dlgSave: TSaveDialog;
    chkScriptsSubDir: TCheckBox;
    edFilter: TEdit;
    lblScript: TLabel;
    lblFilter: TLabel;
    procedure FormShow(Sender: TObject);
    procedure cmbScriptsChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnSaveClick(Sender: TObject);
    procedure EditorKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure chkScriptsSubDirClick(Sender: TObject);
    procedure edFilterChange(Sender: TObject);
    procedure cmbScriptsSelect(Sender: TObject);
    procedure cmbScriptsEnter(Sender: TObject);
    procedure cmbScriptsExit(Sender: TObject);
    procedure cmbScriptsCloseUp(Sender: TObject);
    procedure cmbScriptsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure cmbScriptsDropDown(Sender: TObject);
    procedure cmbScriptsBeforeWheel(Sender: TObject);
    procedure cmbScriptsAfterWheel(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorKeyPress(Sender: TObject; var Key: Char);
  private
    Editor: TSynMemo;
    Highlighter : TSynPasSyn;
    ScriptSelectionChanged : Boolean;
    LastCloseUp : UInt64;
    SelectionOnDropDown: string;
    ScriptSelectionChangedOnDropDown : Boolean;
    SelectionOnEnter: string;
    SaveOverride: string;
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

procedure TfrmScript.btnSaveClick(Sender: TObject);
var
  s, s2: string;
  i: integer;
begin
  if cmbScripts.ItemIndex = -1 then
    Exit;

  s := SaveOverride;
  if s = '' then
    s := cmbScripts.Items[cmbScripts.ItemIndex];

  if s = sNewScript then begin
    dlgSave.InitialDir := Path;
    if dlgSave.Execute then begin
      s := dlgSave.FileName;
      s2 := ChangeFileExt(ExtractFileName(s), '');
      i := cmbScripts.Items.IndexOf(s2);
      if i = -1 then begin
        cmbScripts.Items.Add(s2);
        cmbScripts.ItemIndex := Pred(cmbScripts.Items.Count);
      end else
        cmbScripts.ItemIndex := i;
      SaveOverride := s2;
    end else
      Exit;
  end else
    s := Path + s + sScriptExt;

  with TStringList.Create do try
    Text := Editor.Lines.Text.Replace(#9, #32#32);
    CopyFile(PChar(s), PChar(s + '.backup.' + FormatDateTime('yyyy_mm_dd_hh_nn_ss', Now)), True);
    SaveToFile(s);
    lblPosition.Caption := Format('Saved: %s', [ExtractFileName(s)]);
    ScriptSelectionChanged := False;
    Editor.Modified := False;
  finally
    Free;
  end;
end;

procedure TfrmScript.cmbScriptsAfterWheel(Sender: TObject);
begin
  if not (cmbScripts.Focused or cmbScripts.DroppedDown) then begin
    if SelectionOnEnter <> cmbScripts.Text then
      ScriptSelectionChanged := True;
    if ScriptSelectionChanged then
      DoScriptSelectionChange;
  end;
end;

procedure TfrmScript.cmbScriptsBeforeWheel(Sender: TObject);
begin
  if not (cmbScripts.Focused or cmbScripts.DroppedDown) then begin
    ScriptSelectionChanged := False;
    SelectionOnEnter := cmbScripts.Text;
  end;
end;

procedure TfrmScript.cmbScriptsChange(Sender: TObject);
begin
  ScriptSelectionChanged := True;
end;

procedure TfrmScript.cmbScriptsCloseUp(Sender: TObject);
begin
  if ScriptSelectionChanged then
    DoScriptSelectionChange
  else
    LastCloseUp := GetTickCount64;
end;

procedure TfrmScript.cmbScriptsDropDown(Sender: TObject);
begin
  SelectionOnDropDown := cmbScripts.Text;
  ScriptSelectionChangedOnDropDown := ScriptSelectionChanged;
end;

procedure TfrmScript.cmbScriptsEnter(Sender: TObject);
begin
  ScriptSelectionChanged := False;
  SelectionOnEnter := cmbScripts.Text;
end;

procedure TfrmScript.cmbScriptsExit(Sender: TObject);
begin
  if ScriptSelectionChanged then
    DoScriptSelectionChange;
end;

procedure TfrmScript.cmbScriptsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN: begin
      Key := 0;
      if ScriptSelectionChanged then
        DoScriptSelectionChange
      else
        Editor.SetFocus;
    end;
  end;
end;

procedure TfrmScript.cmbScriptsSelect(Sender: TObject);
begin
  ScriptSelectionChanged := True;
  if (GetTickCount64 - LastCloseUp) < 50 then
    DoScriptSelectionChange;
end;

procedure TfrmScript.DoScriptSelectionChange;
var
  s: string;
begin
  ScriptSelectionChanged := False;
  if cmbScripts.ItemIndex = -1 then
    Exit;

  s := cmbScripts.Items[cmbScripts.ItemIndex];

  if Editor.Modified and (string(Editor.Text).Trim <> '') then
    if MessageDlg('The previous script ("' + SaveOverride + '") has been modified. Do you want to save it before loading the new script?', mtConfirmation,mbYesNo, 0) = mrYes then
      btnSaveClick(Self);

  SaveOverride := s;
  if s = sNewScript then
    s := sNewScriptName;

  Editor.Lines.Clear;

  with TStringList.Create do try
    try
      LoadFromFile(Path + s + sScriptExt);
    except end;
    Editor.Lines.Text := Text.Replace(#9, #32#32);
    Editor.Modified := False;
    if not edFilter.Focused then
      Editor.SetFocus;
    UpdateCaretPos;
  finally
    Free;
  end;
  ScriptSelectionChanged := False;
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
    VK_RETURN: begin
      Key := 0;
      cmbScripts.SetFocus;
      cmbScripts.DroppedDown := True;
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

procedure TfrmScript.chkScriptsSubDirClick(Sender: TObject);
begin
  if Self.Active then begin
    ReadScriptsList;
    cmbScripts.SetFocus;
  end;
end;

procedure TfrmScript.ReadScriptsList;
var
  sl1, sl2: TStringList;
  f, sname: string;
  so: TSearchOption;
  i : Integer;
  s : string;
  CurrentSelection: string;
begin
  CurrentSelection := cmbScripts.Text;

  sl1 := TStringList.Create;
  sl2 := TStringList.Create;
  try
    if chkScriptsSubDir.Checked then
      so := TSearchOption.soAllDirectories
    else
      so := TSearchOption.soTopDirectoryOnly;
    for f in TDirectory.GetFiles(Path, '*' + sScriptExt, so) do begin
      sname := ChangeFileExt(Copy(f, Length(Path) + 1, Length(f)), '');
      if SameText(sNewScriptName, sname) then Continue;
      if Pos('\', sname) <> 0 then
        sl1.Add(sname)
      else
        sl2.Add(sname);
    end;
    sl1.Sort;
    sl2.Sort;
    sl1.AddStrings(sl2);
    sl1.Insert(0, sNewScript);
    s := edFilter.Text;
    s := s.ToLower.Trim;
    if s <> '' then
      for i := Pred(sl1.Count) downto 0 do
        if not sl1[i].ToLower.Contains(s) then
          sl1.Delete(i);
    cmbScripts.Items.Assign(sl1);
  finally
    sl1.Free;
    sl2.Free;
  end;

  if CurrentSelection = '' then begin
    CurrentSelection := LastUsedScript;
    ScriptSelectionChanged := True;
  end;

  i := cmbScripts.Items.IndexOf(CurrentSelection);
  if i = -1 then begin
    i := 0;
    ScriptSelectionChanged := True;
  end;
  cmbScripts.ItemIndex := i;

  if ScriptSelectionChanged then
    DoScriptSelectionChange;
end;

procedure TfrmScript.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if ModalResult = mrOk then begin
    if Editor.Modified then
      if MessageDlg('The script has been modified. Do you want to save it?', mtConfirmation,mbYesNo, 0) = mrYes then
        btnSaveClick(Sender);
    Script := Editor.Lines.Text;
    LastUsedScript := cmbScripts.Items[cmbScripts.ItemIndex];
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
  cmbScripts.OnBeforeWheel := cmbScriptsBeforeWheel;
  cmbScripts.OnAfterWheel := cmbScriptsAfterWheel;

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
var
  i: Integer;
begin
  if Key = VK_ESCAPE then
    if edFilter.Focused then begin
      edFilter.Text := '';
      edFilterChange(Sender);
    end else if cmbScripts.Focused then begin
      if not cmbScripts.DroppedDown then begin
        i := cmbScripts.Items.IndexOf(SelectionOnEnter);
        if i < 0 then
          i := 0;
        if cmbScripts.ItemIndex <> i then begin
          cmbScripts.ItemIndex := i;
          ScriptSelectionChanged := False;
        end;
      end else
        if SelectionOnDropDown <> cmbScripts.Text then begin
          i := cmbScripts.Items.IndexOf(SelectionOnDropDown);
          if i >= 0 then begin
            cmbScripts.ItemIndex := i;
            ScriptSelectionChanged := ScriptSelectionChangedOnDropDown;
          end;
        end;
    end else
      ModalResult := mrCancel;
end;

procedure TfrmScript.FormShow(Sender: TObject);
begin
  ScriptSelectionChanged := True;
  ReadScriptsList;
end;

{ TComboBox }

procedure TComboBox.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if Assigned(FOnBeforeWheel) then
    FOnBeforeWheel(Self);
  inherited;
  if Assigned(FOnAfterWheel) then
    FOnAfterWheel(Self);
end;

end.
