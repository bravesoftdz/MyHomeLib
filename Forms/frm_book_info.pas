
{******************************************************************************}
{                                                                              }
{                                 MyHomeLib                                    }
{                                                                              }
{                                Version 0.9                                   }
{                                20.08.2008                                    }
{                    Copyright (c) Aleksey Penkov  alex.penkov@gmail.com       }
{                                                                              }
{******************************************************************************}


unit frm_book_info;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, xmldom, XMLIntf, msxmldom, XMLDoc, ExtCtrls, RzPanel, RzButton,
  StdCtrls, RzLabel, RzEdit, ComCtrls, RzTabs;

type
  TfrmBookDetails = class(TForm)
    RzPageControl1: TRzPageControl;
    TabSheet1: TRzTabSheet;
    TabSheet2: TRzTabSheet;
    mmShort: TMemo;
    Img: TImage;
    mmInfo: TMemo;
    mmReview: TMemo;
    RzPanel1: TRzPanel;
    RzBitBtn1: TRzBitBtn;
    btnClearReview: TRzBitBtn;
    btnLoadReview: TRzBitBtn;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RzBitBtn1Click(Sender: TObject);
    procedure mmReviewChange(Sender: TObject);
    procedure btnLoadReviewClick(Sender: TObject);
    procedure btnClearReviewClick(Sender: TObject);
  private
    { Private declarations }
    FLibID : integer;

    FReviewChanged : boolean;
    function GetReview: string;
    procedure Setreview(const Value: string);

  public
    procedure AllowOnlineReview(ID: integer);

    procedure ShowBookInfo(FS: TMemoryStream);
    property Review: string read GetReview write Setreview;
    property ReviewChanged: boolean read FReviewChanged;
    { Public declarations }
  end;

var
  frmBookDetails: TfrmBookDetails;

implementation

uses
  FictionBook_21,
  unit_globals,
  unit_Settings,
  unit_MHLHelpers,
  unit_ReviewParser;

{$R *.dfm}

procedure TfrmBookDetails.AllowOnlineReview(ID: integer);
begin
  FLibID := ID;

  btnLoadReview.Visible := True;
  btnClearReview.Visible := True;
end;

procedure TfrmBookDetails.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if key=27 then Close;
end;

function TfrmBookDetails.GetReview: string;
begin
  Result := mmReview.Lines.Text;
end;

procedure TfrmBookDetails.mmReviewChange(Sender: TObject);
begin
  FReviewChanged := True;
end;

procedure TfrmBookDetails.RzBitBtn1Click(Sender: TObject);
begin
  Close;
end;

procedure TfrmBookDetails.btnClearReviewClick(Sender: TObject);
begin
  mmReview.Clear;
  FReviewChanged := True;
end;

procedure TfrmBookDetails.btnLoadReviewClick(Sender: TObject);
const
  URL = 'http://lib.rus.ec/b/%d/';
var
  reviewParser : TReviewParser;
  review : TStringList;
begin
  reviewParser := TReviewParser.Create;
  review := TStringList.Create;
  Screen.Cursor := crHourGlass;
  try
    reviewParser.Parse(Format(url,[FLibID]), review);
    mmReview.Lines.AddStrings(review);
  finally
    review.Free;
    reviewParser.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmBookDetails.Setreview(const Value: string);
begin
  mmReview.Lines.Text := Value;
end;

procedure TfrmBookDetails.ShowBookInfo(FS: TMemoryStream);
var
  book:IXMLFictionBook;
  i,p:integer;
  S,outStr:string;
  F:TextFile;
  CoverID:String;
  CoverFile: string;
begin
  FReviewChanged := False;

  Img.Picture.Bitmap.Canvas.FrameRect(Img.ClientRect);
  mmInfo.Lines.Clear;
  mmShort.Lines.Clear;
  try

    book:=LoadFictionbook(FS);

    CoverID:=book.Description.TitleInfo.Coverpage.XML;
    p:=pos('"#',CoverID);
    Delete(CoverId,1,p+1);
    p:=pos('"',CoverID);
    CoverID:=Copy(CoverID,1,p-1);
    CoverFile := IntToStr(Random(99999)) + CoverID;
    for i:=0 to book.Binary.Count-1 do
    begin
      if Book.Binary.Items[i].Id=CoverID then
      begin
        S:=Book.Binary.Items[i].Text;
        outStr:=DecodeBase64(S);
        AssignFile(F,Settings.TempPath + CoverFile);
        Rewrite(F);
        Write(F,outStr);
        CloseFile(F);
      end;
    end;

    with Book.Description.Titleinfo do
    begin
      mmInfo.Lines.Add('Description:');
      if Author.Count>0 then
        mmInfo.Lines.Add(Author[0].Lastname.Text+' '+Author[0].Firstname.Text);
      mmInfo.Lines.Add(Booktitle.Text);
      if Genre.Count>0 then mmInfo.Lines.Add('����: '+Genre[0]);;
      if Sequence.Count>0 then
      begin
        mmInfo.Lines.Add('�����: '+Sequence[0].Name);
//        mmInfo.Lines.Add('�����: '+IntToStr(Sequence[0].Number));
      end;

     if Annotation.HasChildNodes then
          for I := 0 to Annotation.ChildNodes.Count - 1 do
            mmShort.Lines.Add(Annotation.ChildNodes[i].Text);

      mmInfo.Lines.Add('PublishInfo:');
      mmInfo.Lines.Add('��������: '+Book.Description.Publishinfo.Publisher.Text);
      mmInfo.Lines.Add('�����: '+Book.Description.Publishinfo.City.Text);
      mmInfo.Lines.Add('���: '+Book.Description.Publishinfo.Year);
      mmInfo.Lines.Add('ISBN: '+Book.Description.Publishinfo.Isbn.Text);
      mmInfo.Lines.Add('DocumentInfo (OCR):');
      mmInfo.Lines.Add('������: ');
      for I := 0 to Book.Description.Documentinfo.Author.Count - 1 do
        with Book.Description.Documentinfo.Author.Items[i] do
            mmInfo.Lines.Add(Firstname.Text + ' ' +Lastname.Text + '(' + NickName.Text + ')');
      mmInfo.Lines.Add('���������: '+Book.Description.Documentinfo.Programused.Text);
      mmInfo.Lines.Add('����: '+Book.Description.Documentinfo.Date.Text);
      mmInfo.Lines.Add('ID: '+Book.Description.Documentinfo.ID);
      mmInfo.Lines.Add('Version: '+Book.Description.Documentinfo.Version);
      mmInfo.Lines.Add('History: '+Book.Description.Documentinfo.History.P.OnlyText);
    end;
    Img.Picture.LoadFromFile(Settings.TempPath + CoverFile);
  except
  end;
end;


end.
