object Form1: TForm1
  Left = 380
  Top = 174
  Width = 617
  Height = 579
  Caption = 'Flashutility for 16F145[x] with CDC 512bytes Bootloader'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  OnActivate = FormActivate
  PixelsPerInch = 96
  TextHeight = 16
  object Label1: TLabel
    Left = 408
    Top = 63
    Width = 82
    Height = 20
    Caption = 'MAXPROG'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object ProgressBar1: TGauge
    Left = 136
    Top = 56
    Width = 265
    Height = 33
    BackColor = clMenu
    Color = clBlack
    ForeColor = clLime
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentColor = False
    ParentFont = False
    Progress = 0
  end
  object Memo1: TMemo
    Left = 8
    Top = 96
    Width = 585
    Height = 201
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -17
    Font.Name = 'Courier Std'
    Font.Style = [fsBold]
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Flashandreset: TButton
    Left = 136
    Top = 8
    Width = 137
    Height = 41
    Caption = 'Flash and Reset'
    TabOrder = 1
    OnClick = FlashandresetClick
  end
  object Closeapp: TButton
    Left = 520
    Top = 8
    Width = 73
    Height = 41
    Caption = 'Close'
    TabOrder = 2
    OnClick = CloseappClick
  end
  object LoadHexfile: TButton
    Left = 8
    Top = 8
    Width = 121
    Height = 41
    Caption = 'Load HEX file'
    TabOrder = 3
    OnClick = LoadHexfileClick
  end
  object Memo2: TMemo
    Left = 8
    Top = 304
    Width = 585
    Height = 217
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 4
  end
  object GETfirmwareversion: TButton
    Left = 408
    Top = 8
    Width = 89
    Height = 41
    Caption = 'Get Version'
    TabOrder = 5
    OnClick = GETfirmwareversionClick
  end
  object Resetonly: TButton
    Left = 312
    Top = 8
    Width = 89
    Height = 41
    Caption = 'Reset only'
    TabOrder = 6
    OnClick = ResetonlyClick
  end
  object MemoryModel: TComboBox
    Left = 504
    Top = 56
    Width = 89
    Height = 33
    Style = csDropDownList
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -20
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ItemHeight = 25
    ParentFont = False
    TabOrder = 7
    Items.Strings = (
      '1FFF'
      '1F80'
      '1F00')
  end
  object comcombobox1: TComboBox
    Left = 8
    Top = 56
    Width = 121
    Height = 32
    Style = csDropDownList
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ItemHeight = 24
    ParentFont = False
    TabOrder = 8
    Items.Strings = (
      'COM1'
      'COM2'
      'COM3'
      'COM4'
      'COM5'
      'COM6'
      'COM7'
      'COM8'
      'COM9')
  end
  object OpenDialog1: TOpenDialog
    Left = 280
    Top = 16
  end
end
