﻿(* *****************************************************************************
  *
  * MyHomeLib
  *
  * Copyright (C) 2008-2010 Aleksey Penkov
  *
  * Authors Aleksey Penkov   alex.penkov@gmail.com
  *         Nick Rymanov     nrymanov@gmail.com
  * Created                  22.02.2010
  * Description              Форма редактирования свойств коллекции
  *
  * $Id$
  *
  * History
  *
  ****************************************************************************** *)

{
TODO -oNickR : возможно, стоит здесь задавать свойства обновления. сервер, названия файлов обновлений и периодичность обновлений
}

unit frm_bases;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Windows,
  Messages,
  System.UITypes,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  ExtCtrls,
  unit_StaticTip,
  unit_AutoCompleteEdit,
  ComCtrls,
  unit_Interfaces;

type
  TfrmBases = class(TForm)
    pcCollectionInfo: TPageControl;
    tsGeneralInfo: TTabSheet;
    tsConnectionInfo: TTabSheet;
    warningMessage: TMHLStaticTip;
    edDescription: TEdit;
    lblCollectionDescription: TLabel;
    lblCollectionRoot: TLabel;
    edCollectionRoot: TMHLAutoCompleteEdit;
    edCollectionFile: TMHLAutoCompleteEdit;
    edCollectionName: TEdit;
    lblCollectionFile: TLabel;
    lblCollectionName: TLabel;
    btnSelectRoot: TButton;
    lblUser: TLabel;
    edUser: TEdit;
    edPass: TEdit;
    lblPassword: TLabel;
    edURL: TEdit;
    lblURL: TLabel;
    lblScript: TLabel;
    mmScript: TMemo;
    pnButtons: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure edDBFolderButtonClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);

  private
    FSystemData: ISystemData;
    FCollection: IBookCollection;

  public
    procedure SetCollection(const SystemData: ISystemData; const Collection: IBookCollection);
  end;

var
  frmBases: TfrmBases;

implementation

uses
  SysUtils,
  Vcl.FileCtrl,
  unit_Helpers,
  unit_Consts,
  unit_Errors,
  unit_Globals,
  dm_user;

resourcestring
  rstrChooseDataFolder = 'Выберите папку для сохранения данных';

{$R *.dfm}

procedure TfrmBases.SetCollection(const SystemData: ISystemData; const Collection: IBookCollection);
begin
  Assert(Assigned(SystemData));
  Assert(Assigned(Collection));
  FSystemData := SystemData;
  FCollection := Collection;

  tsConnectionInfo.TabVisible := isOnlineCollection(FCollection.CollectionCode);

  edCollectionName.Text := FCollection.GetProperty(PROP_DISPLAYNAME);
  edCollectionFile.Text := FCollection.GetProperty(PROP_DATAFILE);
  edCollectionRoot.Text := FCollection.GetProperty(PROP_ROOTFOLDER);
  edDescription.Text := FCollection.GetProperty(PROP_NOTES);
  edURL.Text := FCollection.GetProperty(PROP_URL);
  edPass.Text := FCollection.GetProperty(PROP_LIBPASSWORD);
  edUser.Text := FCollection.GetProperty(PROP_LIBUSER);
  mmScript.Lines.Text := FCollection.GetProperty(PROP_CONNECTIONSCRIPT);
end;

procedure TfrmBases.edDBFolderButtonClick(Sender: TObject);
var
  AFolder: string;
begin
  AFolder := edCollectionRoot.Text;
  if SelectDirectory(rstrChooseDataFolder, AFolder, AFolder, [sdNewUI, sdNewFolder]) then
    edCollectionRoot.Text := AFolder;
end;

procedure TfrmBases.FormCreate(Sender: TObject);
begin
  warningMessage.Images := DMUser.SeverityImagesBig;
  warningMessage.ImageIndex := TDMUser.iiWarning;
end;

procedure TfrmBases.btnSaveClick(Sender: TObject);
var
  CollectionName: string;
  storedRoot: string;
  storedFileName: string;
begin
  //
  // Получим абсолютные пути. В качестве базового каталого используется DataPath. <--- Иделогическая ошибка!
  //
//  CollectionName := Trim(edCollectionName.Text);
//  storedRoot := Settings.ExpandCollectionRoot(Trim(edCollectionRoot.Text));
//  storedFileName := Settings.ExpandCollectionFileName(edCollectionFile.Text);

  // Абсолютные пути нахрен не нужны, приводят к куче пробелм и тупых вопросов!

  CollectionName := Trim(edCollectionName.Text);
  storedRoot := Trim(edCollectionRoot.Text);
  storedFileName := Trim(edCollectionFile.Text);


  if (CollectionName = '') or (storedFileName = '') or (storedRoot = '') then
  begin
    MessageDlg(rstrAllFieldsShouldBeFilled, mtError, [mbOk], 0);
    Exit;
  end;

  //
  // Проверим название коллекции
  //
  if FSystemData.HasCollectionWithProp(PROP_DISPLAYNAME, CollectionName, FCollection.CollectionID) then
  begin
    MessageDlg(Format(rstrCollectionAlreadyExists, [CollectionName]), mtError, [mbOk], 0);
    Exit;
  end;

  //
  // Проверим название и существование файла
  //
  if not FileExists(storedFileName) then
  begin
    MessageDlg(Format(rstrFileDoesntExists, [storedFileName]), mtError, [mbOk], 0);
    Exit;
  end;

  if FSystemData.HasCollectionWithProp(PROP_DATAFILE, storedFileName, FCollection.CollectionID) then
  begin
    MessageDlg(Format(rstrFileAlreadyExistsInDB, [storedFileName]), mtError, [mbOk], 0);
    Exit;
  end;

  FCollection.SetProperty(PROP_DISPLAYNAME, CollectionName);
  FCollection.SetProperty(PROP_ROOTFOLDER, storedRoot);
  FCollection.SetProperty(PROP_NOTES, Trim(edDescription.Text));
  FCollection.SetProperty(PROP_URL, edURL.Text);
  FCollection.SetProperty(PROP_LIBPASSWORD, edPass.Text);
  FCollection.SetProperty(PROP_LIBUSER, edUser.Text);
  FCollection.SetProperty(PROP_CONNECTIONSCRIPT, mmScript.Lines.Text);

  ModalResult := mrOk;
end;

end.

