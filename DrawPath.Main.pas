unit DrawPath.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Direct2D, D2D1, System.Generics.Collections, HGM.Button,
  Vcl.StdCtrls, Vcl.Menus, HGM.Controls.PanelExt;

type
  T2DCanvasAdv = class helper for TDirect2DCanvas
    procedure Ellipse(Pt: TPoint; Size: Word); overload;
    procedure MoveTo(Pt: TPoint); overload;
    procedure LineTo(Pt: TPoint); overload;
    procedure RoundRect(Rt: TRect; Rnd: Word); overload;
  end;

  TDrawData = class
    Target: TDirect2DCanvas;
    FieldRect: TRect;
    constructor Create(ATarget: TDirect2DCanvas; AFieldRect: TRect);
  end;

  TLine = record
  private
    function GetDistance: Double;
  public
    UID: Integer;
    PointA: TPoint;
    PointB: TPoint;
    property Distance: Double read GetDistance;
    class function Create(A, B: TPoint): TLine; static;
  end;

  TLines = class(TList<TLine>)
    function DeleteWithUID(UID: Integer): Boolean;
    function GetLine(UID: Integer; var Line: TLine): Boolean;
  end;

  TInputMode = (imLine, imSetCenter);

  TFormMain = class(TForm)
    PanelLeft: TPanel;
    DrawPanel: TDrawPanel;
    TimerDraw: TTimer;
    ButtonFlatClear: TButtonFlat;
    Panel1: TPanel;
    LabelCoord: TLabel;
    LabelCursor: TLabel;
    ButtonFlatSetCenter: TButtonFlat;
    PopupMenuLine: TPopupMenu;
    MenuItemLineDelete: TMenuItem;
    LabelLineUnderMouse: TLabel;
    btnCoordLines: TButtonFlat;
    Label1: TLabel;
    Label2: TLabel;
    procedure DrawPanelPaint(Sender: TObject);
    procedure TimerDrawTimer(Sender: TObject);
    procedure DrawPanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormCreate(Sender: TObject);
    procedure DrawPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ButtonFlatClearClick(Sender: TObject);
    procedure ButtonFlatSetCenterClick(Sender: TObject);
    procedure MenuItemLineDeleteClick(Sender: TObject);
    procedure DrawPanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure btnCoordLinesClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FDrawCurrent: Boolean;
    FCurentLineStart: TPoint;
    FCurPos: TPoint;
    FFieldPos: TPoint;
    FLines: TLines;
    FInputMode: TInputMode;
    FOffsetCoord: TPoint;
    FLineUnderMouseUID: Integer;
    FCoordsVisible: Boolean;
    function AbsolutePoint(Pt: TPoint): TPoint; overload;
    function AbsolutePoint(Pt: TPoint; Offset: TPoint): TPoint; overload;
    function DisplayFieldPos(Pt: TPoint): TPoint;
    procedure DrawField(DrawData: TDrawData);
    procedure DrawCoords(DrawData: TDrawData);
    procedure DrawCursor(DrawData: TDrawData);
    procedure DrawLines(DrawData: TDrawData);
    procedure DrawCurrentLine(DrawData: TDrawData);
    procedure UpdateInfo;
    procedure SetInputMode(const Value: TInputMode);
    procedure SetLineUnderMouseUID(const Value: Integer);
    procedure DrawLineUnderMouseDate(DrawData: TDrawData);
    procedure SetCoordsVisible(const Value: Boolean);
  public
    procedure Clear;
    procedure SetCenter;
    property LineUnderMouseUID: Integer read FLineUnderMouseUID write SetLineUnderMouseUID;
    property InputMode: TInputMode read FInputMode write SetInputMode;
    property CoordsVisible: Boolean read FCoordsVisible write SetCoordsVisible;
  end;

const
  GridDIV = 40;

var
  FormMain: TFormMain;
  GUID: Integer = 0;

function Rect(Pt: TPoint; W, H: Word): TRect; overload;

implementation

uses
  Math;

{$R *.dfm}

function IndexInList(const Index: Integer; ListCount: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index <= ListCount - 1) and (ListCount > 0);
end;

function GetUID: Integer;
begin
  Inc(GUID);
  Result := GUID;
end;

function Rect(Pt: TPoint; W, H: Word): TRect;
begin
  Result := Rect(0, 0, W, H);
  Result.Offset(Pt);
end;

function CalcDistance(A, B: TPoint): Double;
begin
  Result := Sqrt(Sqr(A.X - B.X) + Sqr(B.Y - A.Y));
end;

function TFormMain.AbsolutePoint(Pt: TPoint): TPoint;
begin
  Result.X := Pt.X * GridDIV;
  Result.Y := Pt.Y * GridDIV;
end;

function TFormMain.AbsolutePoint(Pt, Offset: TPoint): TPoint;
begin
  Result := AbsolutePoint(Pt);
  Result.Offset(Offset);
end;

procedure TFormMain.btnCoordLinesClick(Sender: TObject);
begin
  CoordsVisible := not CoordsVisible;
end;

procedure TFormMain.ButtonFlatClearClick(Sender: TObject);
begin
  Clear;
end;

procedure TFormMain.ButtonFlatSetCenterClick(Sender: TObject);
begin
  SetCenter;
end;

procedure TFormMain.Clear;
begin
  FLines.Clear;
end;

function TFormMain.DisplayFieldPos(Pt: TPoint): TPoint;
begin
  Result := Point(Pt.X - FOffsetCoord.X, Pt.Y - FOffsetCoord.Y);
end;

procedure TFormMain.DrawLineUnderMouseDate(DrawData: TDrawData);
var
  W: Integer;
  Plate: TPoint;
  Str: string;
  Rt: TRect;
  Line: TLine;
begin
  if not FLines.GetLine(FLineUnderMouseUID, Line) then
    Exit;
  with DrawData.Target do
  begin
    Pen.Color := $20FFAD4A;
    Brush.Color := $20FFBE6E;
    Brush.Style := bsSolid;
    Pen.Width := 1;

    Str := 'Длина ' + Line.Distance.ToString(ffFixed, 6, 2) + ' ед.';
    W := TextWidth(Str) + 4;
    Plate := AbsolutePoint(FFieldPos);
    Plate.Offset(10, -10);
    Rt := Rect(Plate, W, 20);
    RoundRect(Rt, 5);
    Rt.Offset(2, 2);
    Font.Color := clWhite;
    TextRect(Rt, Str, []);

    Brush.Style := bsClear;
    Font.Color := $00433D31;
    Plate := AbsolutePoint(Line.PointA);
    Plate.Offset(5, 5);
    Str := 'A';
    TextOut(Plate.X, Plate.Y, Str);

    Plate := AbsolutePoint(Line.PointB);
    Str := 'B';
    Plate.Offset(5, 5);
    TextOut(Plate.X, Plate.Y, Str);
  end;
end;

procedure TFormMain.DrawCurrentLine(DrawData: TDrawData);
var
  W: Integer;
  Plate: TPoint;
  Str: string;
  Rt: TRect;
begin
  if not FDrawCurrent then
    Exit;
  with DrawData.Target do
  begin
    Pen.Color := $0069A9F1;
    Brush.Color := Pen.Color;
    Brush.Style := bsSolid;
    Pen.Width := 2;
    MoveTo(AbsolutePoint(FCurentLineStart));
    LineTo(AbsolutePoint(FFieldPos));
    Ellipse(AbsolutePoint(FCurentLineStart, Point(-5, -5)), 10);
    Ellipse(AbsolutePoint(FFieldPos, Point(-5, -5)), 10);
    Str := CalcDistance(FCurentLineStart, FFieldPos).ToString(ffFixed, 6, 2) + ' ед.';
    W := TextWidth(Str) + 4;
    Plate := AbsolutePoint(FFieldPos);
    Plate.Offset(10, -10);
    Rt := Rect(Plate, W, 20);
    RoundRect(Rt, 5);
    Rt.Offset(2, 2);
    Font.Color := clWhite;
    TextRect(Rt, Str, []);
  end;
end;

procedure TFormMain.DrawCursor(DrawData: TDrawData);
var
  FCur: TPoint;
begin
  if FDrawCurrent then
    Exit;
  with DrawData.Target do
  begin
    case FInputMode of
      imLine:
        begin
          Brush.Style := bsSolid;
          Pen.Color := $0069A9F1;
          Brush.Color := Pen.Color;
        end;
      imSetCenter:
        begin
          Brush.Style := bsSolid;
          Pen.Color := $00FFC61C;
          Brush.Color := Pen.Color;
        end;
    end;
    FCur := AbsolutePoint(FFieldPos);
    FCur.Offset(-5, -5);
    Ellipse(FCur, 11);
  end;
end;

procedure TFormMain.DrawField(DrawData: TDrawData);
var
  i: Integer;
begin
  with DrawData.Target do
  begin
    Brush.Color := clWhite;
    Brush.Style := bsSolid;
    FillRect(DrawData.FieldRect);
    Pen.Color := $00F6F6F6;
    for i := 1 to DrawData.FieldRect.Width div (GridDIV div 2) do
    begin
      MoveTo(i * (GridDIV div 2), 0);
      LineTo(i * (GridDIV div 2), DrawData.FieldRect.Height);
    end;
    for i := 1 to DrawData.FieldRect.Height div (GridDIV div 2) do
    begin
      MoveTo(0, i * (GridDIV div 2));
      LineTo(DrawData.FieldRect.Width, i * (GridDIV div 2));
    end;
    Pen.Color := $00EDEDED;
    for i := 1 to DrawData.FieldRect.Width div GridDIV do
    begin
      MoveTo(i * GridDIV, 0);
      LineTo(i * GridDIV, DrawData.FieldRect.Height);
    end;
    for i := 1 to DrawData.FieldRect.Height div GridDIV do
    begin
      MoveTo(0, i * GridDIV);
      LineTo(DrawData.FieldRect.Width, i * GridDIV);
    end;
    Brush.Style := bsSolid;
    Pen.Color := $00C5C5C5;
    Brush.Color := Pen.Color;
    Ellipse(AbsolutePoint(FOffsetCoord, Point(-2, -2)), 5);
  end;
end;

procedure TFormMain.DrawCoords(DrawData: TDrawData);
var
  i: Integer;
begin
  with DrawData.Target do
  begin
    Pen.Color := $00C5C5C5;
    Brush.Color := Pen.Color;
    Pen.Width := 2;

    MoveTo(0, AbsolutePoint(FOffsetCoord).Y);
    LineTo(DrawData.FieldRect.Right, AbsolutePoint(FOffsetCoord).Y);

    MoveTo(AbsolutePoint(FOffsetCoord).X, 0);
    LineTo(AbsolutePoint(FOffsetCoord).X, DrawData.FieldRect.Bottom);
  end;
end;

procedure TFormMain.DrawLines(DrawData: TDrawData);
var
  i: Integer;
  x, y, x1, x2, y1, y2, dx, dy, dx1, dy1, L: Integer;
  S, Closet: Double;
  RT: TRect;
begin
  with DrawData.Target do
  begin
    Closet := 30;
    L := -1;
    Brush.Style := bsSolid;
    Pen.Width := 2;
    for i := 0 to FLines.Count - 1 do
    begin
      if FLines[i].UID = FLineUnderMouseUID then
        Pen.Color := $00FF92C4
      else
        Pen.Color := $0056E28E;

      Brush.Color := Pen.Color;
      MoveTo(AbsolutePoint(FLines[i].PointA));
      LineTo(AbsolutePoint(FLines[i].PointB));
      Ellipse(AbsolutePoint(FLines[i].PointA, Point(-5, -5)), 10);
      Ellipse(AbsolutePoint(FLines[i].PointB, Point(-5, -5)), 10);
     //Вычисление нахождения курсора на линии

     //Для начала проверим по простому, входит ли точка в прямоугольник
      RT := Rect(AbsolutePoint(FLines[i].PointA).x, AbsolutePoint(FLines[i].PointA).y, AbsolutePoint(FLines[i].PointB).x, AbsolutePoint(FLines[i].PointB).y);
      RT.NormalizeRect;
      RT.Inflate(3, 3);

      if RT.Contains(FCurPos) then
      begin
        x1 := AbsolutePoint(FLines[i].PointA).x;
        y1 := AbsolutePoint(FLines[i].PointA).y;

        x2 := AbsolutePoint(FLines[i].PointB).x;
        y2 := AbsolutePoint(FLines[i].PointB).y;

        x := FCurPos.X;
        y := FCurPos.Y;

        dx1 := x2 - x1;
        dy1 := y2 - y1;
        dx := x - x1;
        dy := y - y1;
        S := ABS(dx1 * dy - dx * dy1);
        if S <> 0 then
          S := SQRT(S);
        if (S < 25) and (S < Closet) then
        begin
          Closet := S;
          L := FLines[i].UID;
        end;
      end;
    end;
    FLineUnderMouseUID := L;
  end;
end;

procedure TFormMain.DrawPanelMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Pt: TPoint;
begin
  case FInputMode of
    imLine:
      begin
        if Button = mbLeft then
        begin
          if FDrawCurrent then
          begin
             //Если непрерывно, то не устанавливать False
             //FDrawCurrent:=False;
            if FCurentLineStart = FFieldPos then
              Exit;
            FLines.Add(TLine.Create(FCurentLineStart, FFieldPos));
            FCurentLineStart := FFieldPos;
          end
          else
          begin
            FDrawCurrent := True;
            FCurentLineStart := FFieldPos;
          end;
        end;
        if Button = mbRight then
        begin
          if FDrawCurrent then
            FDrawCurrent := False
          else
          begin
            if FLineUnderMouseUID <> -1 then
            begin
              Pt := Mouse.CursorPos;
              PopupMenuLine.Popup(Pt.X, Pt.Y);
            end;
          end;
        end;
      end;
    imSetCenter:
      begin
        if Button = mbLeft then
        begin
          FOffsetCoord := FFieldPos;
          InputMode := imLine;
        end;
        if Button = mbRight then
        begin
          InputMode := imLine;
        end;
      end;
  end;
end;

procedure TFormMain.UpdateInfo;
var
  Line: TLine;
begin
  LabelCursor.Caption := Format('Курсор: %d:%d', [FCurPos.X, FCurPos.Y]);
  LabelCoord.Caption := Format('Позиция: %d:%d', [DisplayFieldPos(FFieldPos).x, DisplayFieldPos(FFieldPos).y]);
  if FLines.GetLine(FLineUnderMouseUID, Line) then
    LabelLineUnderMouse.Caption := Format('Прямая: A(%d:%d), B(%d:%d)', [DisplayFieldPos(Line.PointA).x, DisplayFieldPos(Line.PointA).y, DisplayFieldPos(Line.PointB).x, DisplayFieldPos(Line.PointB).y])
  else
    LabelLineUnderMouse.Caption := '';
end;

procedure TFormMain.DrawPanelMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  FCurPos := Point(X, Y);
  FFieldPos := Point(Round(FCurPos.X / GridDIV), Round(FCurPos.Y / GridDIV));

  UpdateInfo;
end;

procedure TFormMain.DrawPanelMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  case FInputMode of
    imLine:
      ;
    imSetCenter:
      ;
  end;
end;

procedure TFormMain.DrawPanelPaint(Sender: TObject);
var
  DData: TDrawData;
  Draw2D: TDirect2DCanvas;
begin
  Draw2D := TDirect2DCanvas.Create(DrawPanel.Canvas, DrawPanel.ClientRect);
  with Draw2D do
  begin
    DData := TDrawData.Create(Draw2D, DrawPanel.ClientRect);
    try
      BeginDraw;
      DrawField(DData);
      if FCoordsVisible then
        DrawCoords(DData);
      DrawLines(DData);
      DrawLineUnderMouseDate(DData);
      DrawCurrentLine(DData);
      DrawCursor(DData);
    finally
      DData.Free;
      EndDraw;
      Free;
    end;
  end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FLines := TLines.Create;
  FInputMode := imLine;
  FOffsetCoord := Point(0, 0);
  UpdateInfo;
end;

procedure TFormMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE:
     begin
       FDrawCurrent := False;
       InputMode := imLine;
     end;
  end;
end;

procedure TFormMain.MenuItemLineDeleteClick(Sender: TObject);
begin
  FLines.DeleteWithUID(FLineUnderMouseUID);
end;

procedure TFormMain.SetCenter;
begin
  InputMode := imSetCenter;
end;

procedure TFormMain.SetCoordsVisible(const Value: Boolean);
begin
  FCoordsVisible := Value;
  btnCoordLines.NotifyVisible := FCoordsVisible;
end;

procedure TFormMain.SetInputMode(const Value: TInputMode);
begin
  case FInputMode of  //Если вдруг что нужно проверить перед сменой
    imLine:
      ;
    imSetCenter:
      ;
  end;
  FInputMode := Value;
  DrawPanel.Repaint;
end;

procedure TFormMain.SetLineUnderMouseUID(const Value: Integer);
begin
  FLineUnderMouseUID := Value;
end;

procedure TFormMain.TimerDrawTimer(Sender: TObject);
begin
  DrawPanel.Repaint;
end;

{ TDrawData }

constructor TDrawData.Create(ATarget: TDirect2DCanvas; AFieldRect: TRect);
begin
  Target := ATarget;
  FieldRect := AFieldRect;
end;

{ T2DCanvasAdv }

procedure T2DCanvasAdv.Ellipse(Pt: TPoint; Size: Word);
var
  CRect: TRect;
begin
  CRect := Rect(0, 0, Size, Size);
  CRect.Offset(Pt);
  Ellipse(CRect);
end;

procedure T2DCanvasAdv.LineTo(Pt: TPoint);
begin
  LineTo(Pt.X, Pt.Y);
end;

procedure T2DCanvasAdv.MoveTo(Pt: TPoint);
begin
  MoveTo(Pt.X, Pt.Y);
end;

procedure T2DCanvasAdv.RoundRect(Rt: TRect; Rnd: Word);
begin
  RoundRect(Rt, Rnd, Rnd);
end;

{ TLine }

class function TLine.Create(A, B: TPoint): TLine;
begin
  Result.UID := GetUID;
  Result.PointA := A;
  Result.PointB := B;
end;

function TLine.GetDistance: Double;
begin
  Result := CalcDistance(PointA, PointB);
end;

{ TLines }

function TLines.DeleteWithUID(UID: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].UID = UID then
    begin
      Delete(i);
      Result := True;
      Break;
    end;
end;

function TLines.GetLine(UID: Integer; var Line: TLine): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].UID = UID then
    begin
      Line := Items[i];
      Result := True;
      Break;
    end;
end;

end.

