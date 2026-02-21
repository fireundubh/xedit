object frmScript: TfrmScript
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  Caption = 'Apply Script'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsStayOnTop
  KeyPreview = True
  Position = poMainFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  TextHeight = 13
  object splLeft: TSplitter
    Left = 220
    Top = 0
    Width = 5
    Height = 544
    Cursor = crVSplit
    ResizeStyle = rsUpdate
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 565
    Width = 900
    Height = 35
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object btnOK: TButton
      Left = 738
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'OK'
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 819
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 220
    Height = 544
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object edFilter: TEdit
      Left = 0
      Top = 0
      Width = 220
      Height = 21
      Align = alTop
      TabOrder = 0
      TextHint = 'Search scripts...'
      OnChange = edFilterChange
      OnKeyDown = edFilterKeyDown
    end
    object vstScripts: TVirtualStringTree
      Left = 0
      Top = 21
      Width = 220
      Height = 523
      Align = alClient
      Header.AutoSizeIndex = 0
      Header.MainColumn = -1
      Header.Options = []
      TabOrder = 1
      TreeOptions.MiscOptions = [toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning]
      TreeOptions.SelectionOptions = [toFullRowSelect]
      OnDblClick = vstScriptsDblClick
      OnFocusChanged = vstScriptsFocusChanged
      OnFreeNode = vstScriptsFreeNode
      OnGetText = vstScriptsGetText
      OnKeyDown = vstScriptsKeyDown
      Columns = <>
    end
  end
  object dlgSave: TSaveDialog
    DefaultExt = 'pas'
    Filter = 'Pascal files (*.pas)|*.pas'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofNoChangeDir, ofEnableSizing]
    OptionsEx = [ofExNoPlacesBar]
    Title = 'Save script'
    Left = 600
    Top = 48
  end
end
