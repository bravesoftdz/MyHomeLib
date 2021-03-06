﻿(* *****************************************************************************
  *
  * MyHomeLib
  *
  * Copyright (C) 2008-2010 Aleksey Penkov
  *
  * Author(s)           Nick Rymanov (nrymanov@gmail.com)
  *                     Aleksey Penkov  alex.penkov@gmail.com
  * Created             12.02.2010
  * Description
  *
  * $Id$
  *
  * History
  * NickR 02.03.2010    Код переформатирован
  * NickR 02.09.2010    INPX больше не распаковывается на диск для обработки. Вся работа происходит в памяти.
  *
  ****************************************************************************** *)

unit unit_ImportInpxThread;

interface

uses
  Windows,
  unit_WorkerThread,
  unit_CollectionWorkerThread,
  unit_Globals,
  unit_Interfaces;

type
  TFields = (
    flNone,
    flAuthor,
    flTitle,
    flSeries,
    flSerNo,
    flGenre,
    flLibID,
    flInsideNo,
    flFile,
    flFolder,
    flExt,
    flSize,
    flLang,
    flDate,
    flCode,
    flDeleted,
    flRate,
    flURI,
    flLibRate,
    flKeyWords
  );

  TFieldDescr = record
    Code: string;
    FType: TFields;
  end;

  TImportInpxThreadBase = class(TCollectionWorker)
  protected
    FGenresType: TGenresType;

    FFields: array of TFields;
    FUseStoredFolder: Boolean;

  protected
    procedure GetFields(const StructureInfo: string);
    procedure ParseData(const input: string; const OnlineCollection: Boolean; var R: TBookRecord);
    procedure Import(const INPXFileName: string; CheckFiles: Boolean; BookCollection: IBookCollection);
  end;

  TImportInpxThread = class(TImportInpxThreadBase)
  protected
    FInpxFileName: string;

  protected
    procedure WorkFunction; override;

  public
    constructor Create(const CollectionID: Integer; const INPXFileName: string; GenresType: TGenresType);
  end;

implementation

uses
  Classes,
  SysUtils,
  IOUtils,
  jclCompression,
  unit_MHLArchiveHelpers,
  unit_Consts,
  unit_Helpers,
  unit_Errors,
  dm_user;

resourcestring
  rstrProcessingFile = 'Обрабатываем файл %s';
  rstrAddedBooks = 'Добавлено %u книг';
  rstrErrorInpStructure = 'Ошибка структуры inp. Файл %s, Строка %u ';
  rstrDBErrorInp = 'Ошибка базы данных при импорте книги. Файл %s, Строка %u ';
  rstrUpdatingDB = 'Обновление базы данных. Пожалуйста, подождите ... ';
  rstrInvalidFormat = 'Неверный формат файла INPX!';

const
  FieldsDescr: array [1 .. 20] of TFieldDescr = (
    (Code: 'AUTHOR';   FType: flAuthor),
    (Code: 'TITLE';    FType: flTitle),
    (Code: 'SERIES';   FType: flSeries),
    (Code: 'SERNO';    FType: flSerNo),
    (Code: 'GENRE';    FType: flGenre),
    (Code: 'LIBID';    FType: flLibID),
    (Code: 'INSNO';    FType: flInsideNo),
    (Code: 'FILE';     FType: flFile),
    (Code: 'FOLDER';   FType: flFolder),
    (Code: 'EXT';      FType: flExt),
    (Code: 'SIZE';     FType: flSize),
    (Code: 'LANG';     FType: flLang),
    (Code: 'DATE';     FType: flDate),
    (Code: 'CODE';     FType: flCode),
    (Code: 'DEL';      FType: flDeleted),
    (Code: 'RATE';     FType: flRate),
    (Code: 'URI';      FType: flURI),
    (Code: 'LIBRATE';  FType: flLibRate),
    (Code: 'KEYWORDS'; FType: flKeyWords),
    (Code: 'URL';      FType: flURI)
  );

  DEFAULTSTRUCTURE = 'AUTHOR;GENRE;TITLE;SERIES;SERNO;FILE;SIZE;LIBID;DEL;EXT;DATE;LANG;LIBRATE;KEYWORDS';

{ TImportInpxThread }

function ExtractStrings(Content: PChar; const Separator: Char; Strings: TStrings): Integer;
var
  Head, Tail: PChar;
  EOS: Boolean;
  Item: string;
begin
  Result := 0;
  if (Content = nil) or (Content^ = #0) or (Strings = nil) then
    Exit;
  Tail := Content;

  Strings.BeginUpdate;
  try
    repeat
      Head := Tail;
      while not CharInSet(Tail^, [Separator, #0]) do
        Tail := StrNextChar(Tail);

      EOS := Tail^ = #0;
      if {(Head <> Tail) and} (Head^ <> #0) then
      begin
        SetString(Item, Head, Tail - Head);
        Strings.Add(Item);

        Inc(Result);
      end;
      Tail := StrNextChar(Tail);
    until EOS;
  finally
    Strings.EndUpdate;
  end;
end;

procedure TImportInpxThreadBase.ParseData(const input: string; const OnlineCollection: Boolean; var R: TBookRecord);
var
  p, i: Integer;
  slParams: TStringList;
  AuthorList: string;
  strLastName: string;
  strFirstName: string;
  strMidName: string;
  GenreList: string;
  s: string;
  mm, dd, yy: word;

  Max: Integer;

begin
  R.Clear;

  slParams := TStringList.Create;
  try
    ExtractStrings(PChar(input), INPX_FIELD_DELIMITER, slParams);

    // -- костыль
    if slParams.Count <= High(FFields) then
      Max := slParams.Count - 1
    else
      Max := High(FFields);
    // --

    for i := 0 to Max do
    begin
      case FFields[i] of
        flAuthor:
          begin // Список авторов
            AuthorList := slParams[i];
            p := PosChr(INPX_ITEM_DELIMITER, AuthorList);
            while p <> 0 do
            begin
              s := Copy(AuthorList, 1, p - 1);
              Delete(AuthorList, 1, p);

              p := PosChr(INPX_SUBITEM_DELIMITER, s);
              strLastName := Copy(s, 1, p - 1);
              Delete(s, 1, p);

              p := PosChr(INPX_SUBITEM_DELIMITER, s);
              strFirstName := Copy(s, 1, p - 1);
              Delete(s, 1, p);

              strMidName := s;

              TAuthorsHelper.Add(R.Authors, strLastName, strFirstName, strMidName);

              p := PosChr(INPX_ITEM_DELIMITER, AuthorList);
            end;
          end;

        flGenre:
          begin // Список жанров
            GenreList := slParams[i];
            p := PosChr(INPX_ITEM_DELIMITER, GenreList);
            while p <> 0 do
            begin
              if FGenresType = gtFb2 then
                TGenresHelper.Add(R.Genres, '', '', Copy(GenreList, 1, p - 1))
              else
                TGenresHelper.Add(R.Genres, Copy(GenreList, 1, p - 1), '', '');

              Delete(GenreList, 1, p);
              p := PosChr(INPX_ITEM_DELIMITER, GenreList);
            end;
          end;

        flTitle:
          R.Title := slParams[i]; // Название

        flSeries:
          R.Series := slParams[i]; // Серия

        flSerNo:
          R.SeqNumber := StrToIntDef(slParams[i], 0); // Номер внутри серии

        flFile:
          R.FileName := CheckSymbols(Trim(slParams[i])); // Имя файла

        flExt:
          R.FileExt := '.' + slParams[i]; // Тип

        flSize:
          R.Size := StrToIntDef(slParams[i], 0); // Размер

        flLibID: R.LibID := slParams[i]; // внутр. номер   ИСПОЛЬЗУЕТСЯ ВО ВСЕХ КОЛЛЕКЦИЯХ!

        flDeleted:
          begin
            if (slParams[i] = '1') then // удалена
              Include(R.BookProps, bpIsDeleted)
            else
              Exclude(R.BookProps, bpIsDeleted);
          end;

        flDate:
          begin // дата
            if slParams[i] <> '' then
            begin
              yy := StrToInt(Copy(slParams[i], 1, 4));
              mm := StrToInt(Copy(slParams[i], 6, 2));
              dd := StrToInt(Copy(slParams[i], 9, 2));
              R.Date := EncodeDate(yy, mm, dd);
            end
            else
              R.Date := EncodeDate(70, 01, 01);
          end;

        flInsideNo:
          R.InsideNo := StrToInt(slParams[i]); // номер в архиве

        flFolder:
          R.Folder := slParams[i]; // папка

        flLibRate:
          R.LibRate := StrToIntDef(slParams[i], 0); // внешний рейтинг

        flLang:
          R.Lang := slParams[i]; // язык

        flKeyWords:
          R.KeyWords := slParams[i]; // ключевые слова

        flURI:
          Assert(False, 'Not supported anymore');
          ///R.URI := slParams[i]; // ключевые слова
      end; // case, for
    end;

    R.Normalize;
  finally
    slParams.Free;
  end;
end;

procedure TImportInpxThreadBase.GetFields(const StructureInfo: string);
const
  del = ';';
var
  s: string;
  p, i: Integer;

  function FindType(const s: string): TFields;
  var
    F: TFieldDescr;
  begin
    for F in FieldsDescr do
      if F.Code = s then
      begin
        Result := F.FType;
        Exit;
      end;
    Result := flNone;
  end;

begin
  s := StructureInfo;

  // код
  SetLength(FFields, 0);
  i := 0;
  p := Pos(del, s);
  while p <> 0 do
  begin
    SetLength(FFields, i + 1);
    FFields[i] := FindType(Copy(s, 1, p - 1));
    Delete(s, 1, p);
    p := Pos(del, s);

    //
    // если среди полей есть Folder, то необходимо использовать это поле при создании BookRecord
    //
    FUseStoredFolder := FUseStoredFolder or (FFields[i] = flFolder);

    Inc(i);
  end;
end;

procedure TImportInpxThreadBase.Import(const INPXFileName: string; CheckFiles: Boolean; BookCollection: IBookCollection);
var
  CollectionRoot: string;
  BookList: TStringList;
  i: Integer;
  j: Integer;
  R: TBookRecord;
  filesProcessed: Integer;
  CurrentFile: string;
  IsOnline: Boolean;
  inpStream: TMemoryStream;
  header: TINPXHeader;
  numFiles: Integer;
  Zip: TJclZipDecompressArchive;
  ZipItem: TJclCompressionItem;
  collectionCode: Integer;

  procedure InpxProcessStructureInfo(const AZip: TJclZipDecompressArchive);
  var
    I: Integer;
    StructureInfoString: string;
    StructureInfoStream: TStringStream;
  begin
    Assert(AZip <> nil);

    StructureInfoString := '';

    AZip.ListFiles;
    if AZip.ItemCount > 0 then
      for I := 0 to AZip.ItemCount - 1 do
        if AZip.Items[I].PackedName = STRUCTUREINFO_FILENAME then
        begin
          StructureInfoStream := TStringStream.Create;
          try
            AZip.Items[I].OwnsStream := False;
            AZip.Items[I].Stream := StructureInfoStream;
            AZip.Items[I].Selected := True;
            AZip.ExtractSelected;

            StructureInfoString := StructureInfoStream.DataString;
          finally
            StructureInfoStream.Free;
            AZip.Items[I].Selected := False;
          end;
        end;

    if StructureInfoString = '' then
      StructureInfoString := DEFAULTSTRUCTURE;

    GetFields(StructureInfoString);
  end;

  procedure InpxProcessCollectionInfo(const AZip: TJclZipDecompressArchive;
    ABookCollection: IBookCollection);
  var
    I: Integer;
    CollectionInfoString: string;
    CollectionInfoStream: TStringStream;
  begin
    Assert(AZip <> nil);
    Assert(ABookCollection <> nil);

    CollectionInfoString := '';

    AZip.ListFiles;
    if AZip.ItemCount > 0 then
      for I := 0 to AZip.ItemCount - 1 do
        if AZip.Items[I].PackedName = COLLECTIONINFO_FILENAME then
        begin
          CollectionInfoStream := TStringStream.Create;
          try
            AZip.Items[I].OwnsStream := False;
            AZip.Items[I].Stream := CollectionInfoStream;
            AZip.Items[I].Selected := True;
            AZip.ExtractSelected;

            CollectionInfoString := CollectionInfoStream.DataString;
            header.ParseString(CollectionInfoString);
            ABookCollection.SetProperty(PROP_NOTES, header.Notes);
            ABookCollection.SetProperty(PROP_URL, header.URL);
            ABookCollection.SetProperty(PROP_CONNECTIONSCRIPT, header.Script);
          finally
            CollectionInfoStream.Free;
            AZip.Items[I].Selected := False;
          end;
        end;
  end;

  procedure InpxProcessVersionInfo(const AZip: TJclZipDecompressArchive;
    ABookCollection: IBookCollection);
  var
    I: Integer;
    VersionInfoString: string;
    VersionInfoStream: TStringStream;
  begin
    Assert(AZip <> nil);
    Assert(ABookCollection <> nil);

    VersionInfoString := '';

    AZip.ListFiles;
    if AZip.ItemCount > 0 then
      for I := 0 to AZip.ItemCount - 1 do
        if AZip.Items[I].PackedName = VERINFO_FILENAME then
        begin
          VersionInfoStream := TStringStream.Create;
          try
            AZip.Items[I].OwnsStream := False;
            AZip.Items[I].Stream := VersionInfoStream;
            AZip.Items[I].Selected := True;
            AZip.ExtractSelected;

            VersionInfoString := VersionInfoStream.DataString;
            VersionInfoString := Trim(VersionInfoString);
            BookCollection.SetProperty(PROP_DATAVERSION, StrToIntDef(VersionInfoString, UNVERSIONED_COLLECTION));
          finally
            VersionInfoStream.Free;
            AZip.Items[I].Selected := False;
          end;
        end;
  end;

begin
  filesProcessed := 0;
  i := 0;
  SetProgress(0);
  collectionCode := BookCollection.CollectionCode;

  IsOnline := isOnlineCollection(collectionCode);
  CollectionRoot := BookCollection.GetProperty(PROP_ROOTFOLDER);

  SetLength(FFields, 0);
  FUseStoredFolder := False;

  BookCollection.StartBatchUpdate;
  try
    Zip := TJclZipDecompressArchive.Create(INPXFileName);
    Zip.ListFiles;

    InpxProcessStructureInfo(Zip);

    numFiles := Zip.ItemCount;

    for I := 0 to Zip.ItemCount - 1 do
    begin
      ZipItem := Zip.Items[I];
      Assert(ZipItem <> nil);

      // Skip directories
      if ZipItem.Directory then
        Continue;

      CurrentFile:= String(Zip.Items[I].PackedName);

      // Skip non-inp files
      if not CurrentFile.EndsWith('.inp', True) then
        Continue;

      if not IsOnline and (CurrentFile = 'extra.inp') then
        Continue;

      Teletype(Format(rstrProcessingFile, [CurrentFile]), tsInfo);

      BookList := TStringList.Create;
      try
        inpStream := TMemoryStream.Create;
        try
          ZipItem.OwnsStream := False;
          ZipItem.Stream := inpStream;
          ZipItem.Selected := True;
          Zip.ExtractSelected;
          inpStream.Seek(0, soBeginning);
          BookList.LoadFromStream(inpStream, TEncoding.UTF8);
        finally
          FreeAndNil(inpStream);
          ZipItem.Selected := False;
        end;

        for j := 0 to BookList.Count - 1 do
        begin
          try
            ParseData(BookList[j], IsOnline, R);
            if IsOnline then
            begin

              if 0 = (CONTENT_NONFB and collectionCode) then
                R.Folder := R.GenerateLocation + FB2ZIP_EXTENSION;  // И\Иванов Иван\1234 Просто книга.fb2.zip
              // Сохраним отметку о существовании файла
              if FileExists(TPath.Combine(CollectionRoot, R.Folder)) then
                Include(R.BookProps, bpIsLocal)
              else
                Exclude(R.BookProps, bpIsLocal);
            end
            else
            begin
              Include(R.BookProps, bpIsLocal);
              if not FUseStoredFolder then
              begin
                // 98058-98693.inp -> 98058-98693.zip
                R.Folder := ChangeFileExt(CurrentFile, ZIP_EXTENSION);
                //
                R.InsideNo := j;
              end
            end;

            try
              if BookCollection.InsertBook(R, CheckFiles, False) <> 0 then
                Inc(filesProcessed);
            except
              on E: Exception do
                raise EDBError.Create(E.Message);
            end;

            if (filesProcessed mod ProcessedItemThreshold) = 0 then
            begin
              SetProgress(Round((i + j / BookList.Count) * 100 / numFiles));
              SetComment(Format(rstrAddedBooks, [filesProcessed]));

              if Canceled then
                Break;
            end;

          except
            on E: EConvertError do
              Teletype(Format(rstrErrorInpStructure, [CurrentFile, j]), tsError);
            on E: EDBError do
              Teletype(Format(rstrDBErrorInp, [CurrentFile, j]), tsError);
            on E: Exception do
              Teletype(E.Message, tsError);
          end;
        end;
      finally
        FreeAndNil(BookList);
      end;

      if Canceled then
        Break;

    end;

    Teletype(Format(rstrAddedBooks, [filesProcessed]), tsInfo);
    FProgressEngine.BeginOperation(-1, rstrUpdatingDB, '');

    //
    // Прочитать и установить свойства коллекции
    //
    InpxProcessCollectionInfo(Zip, BookCollection);

    InpxProcessVersionInfo(Zip, BookCollection);

    BookCollection.AfterBatchUpdate;
  finally
    FreeAndNil(Zip);
    FreeAndNil(inpStream);
    BookCollection.FinishBatchUpdate;
  end;
end;

constructor TImportInpxThread.Create(const CollectionID: Integer; const INPXFileName: string; GenresType: TGenresType);
begin
  inherited Create(CollectionID);
  FInpxFileName := INPXFileName;
  FGenresType := GenresType;
end;

procedure TImportInpxThread.WorkFunction;
begin
  Assert(Assigned(FCollection));

  FCollection.BeginBulkOperation;
  try
    Import(FInpxFileName, False, FCollection);
    FCollection.EndBulkOperation(True);
  except
    on E: Exception do
    begin
      Teletype(E.Message, tsError);
      FCollection.EndBulkOperation(False);
    end;
  end;
end;

end.
