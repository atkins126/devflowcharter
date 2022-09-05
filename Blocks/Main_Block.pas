{
   Copyright (C) 2006 The devFlowcharter project.
   The initial author of this file is Michal Domagala.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
}



unit Main_Block;

interface

uses
   WinApi.Windows, WinApi.Messages, Vcl.Graphics, Vcl.ComCtrls, System.Classes,
   Base_Block, OmniXML, Interfaces, Types, BlockTabSheet;

type

   TMainBlock = class(TGroupBlock, IWinControl)
      private
         FPage: TBlockTabSheet;
         FLabelRect: TRect;
         FHandle: HDC;
         procedure DrawStartEllipse;
         procedure DrawStopEllipse;
         function GetMaxBounds: TPoint;
      public
         UserFunction: TObject;
         constructor Create(APage: TBlockTabSheet; const ABlockParms: TBlockParms); overload;
         constructor Create(APage: TBlockTabSheet; const ATopLeft: TPoint); overload;
         procedure SaveInXML(ATag: IXMLElement); override;
         procedure ExportToGraphic(AGraphic: TGraphic); override;
         procedure SetWidth(AMinX: integer); override;
         procedure SetZOrder(AValue: integer);
         procedure DrawLabel;
         function ExportToXMLFile(const AFile: string): TError; override;
         function GetExportFileName: string; override;
         function GenerateTree(AParentNode: TTreeNode): TTreeNode; override;
         function GetFromXML(ATag: IXMLElement): TError; override;
         function GetHandle: THandle;
         function GetZOrder: integer;
         function IsBoldDesc: boolean; override;
         function Remove(ANode: TTreeNodeWithFriend = nil): boolean; override;
         function GenerateCode(ALines: TStringList; const ALangId: string; ADeep: integer; AFromLine: integer = LAST_LINE): integer; override;
      protected
         FZOrder: integer;
         FStartLabel,
         FStopLabel: string;
         procedure MyOnResize(Sender: TObject);
         procedure MyOnMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
         procedure Paint; override;
         procedure WMWindowPosChanging(var Msg: TWMWindowPosChanging); message WM_WINDOWPOSCHANGING;
         procedure SetPage(APage: TBlockTabSheet); override;
         procedure OnWindowPosChanged(x, y: integer); override;
         function GetFunctionLabel(var ARect: TRect): string;
         function GetDefaultWidth: integer;
         function GetPage: TBlockTabSheet; override;
         function GetUndoObject: TObject; override;
   end;

const
   MAIN_BLOCK_DEF_WIDTH = 100;
   MAIN_BLOCK_DEF_HEIGHT = 101;

implementation

uses
   Vcl.Forms, System.SysUtils, System.StrUtils, Infrastructure, XMLProcessor, DeclareList,
   Navigator_Form, Return_Block, LangDefinition, UserFunction, Comment, Constants;

constructor TMainBlock.Create(APage: TBlockTabSheet; const ABlockParms: TBlockParms);
begin

   FPage := APage;

   inherited Create(nil, ABlockParms, shpEllipse, taLeftJustify);

   FStartLabel := i18Manager.GetString('CaptionStart');
   FStopLabel := i18Manager.GetString('CaptionStop');

   var defWidth := GetDefaultWidth;
   var defWidthHalf := defWidth div 2;
   if defWidth > Width then
   begin
      Width := defWidth;
      Branch.Hook.X := defWidthHalf;
      BottomHook := defWidthHalf;
      TopHook.X := defWidthHalf;
   end
   else
   begin
      BottomHook := ABlockParms.bh;
      TopHook.X := ABlockParms.br.X;
   end;

   FInitParms.Width := defWidth;
   FInitParms.Height := MAIN_BLOCK_DEF_HEIGHT;
   FInitParms.BottomHook := defWidthHalf;
   FInitParms.BranchPoint.X := defWidthHalf;
   FInitParms.BottomPoint.X := -60000;
   FInitParms.P2X := 0;
   FInitParms.HeightAffix := 42;

   BottomPoint.X := FInitParms.BottomPoint.X;
   TopHook.Y := TInfra.Scaled(30);
   FZOrder := -1;
   Constraints.MinWidth := FInitParms.Width;
   Constraints.MinHeight := FInitParms.Height;
   OnResize := MyOnResize;
   FLabelRect := TRect.Empty;
   FHandle := Canvas.Handle;
   FStatement.Free;
   FStatement := nil;
end;

constructor TMainBlock.Create(APage: TBlockTabSheet; const ATopLeft: TPoint);
begin
   var blockParms := TBlockParms.New(blMain,
                                 ATopLeft.X,
                                 ATopLeft.Y,
                                 MAIN_BLOCK_DEF_WIDTH,
                                 MAIN_BLOCK_DEF_HEIGHT,
                                 MAIN_BLOCK_DEF_WIDTH div 2,
                                 MAIN_BLOCK_DEF_HEIGHT-42,
                                 MAIN_BLOCK_DEF_WIDTH div 2);
   Create(APage, blockParms);
end;

procedure TMainBlock.SetPage(APage: TBlockTabSheet);
begin
   if FPage <> APage then
   begin
      var unPin := Expanded and (PinComments > 0);
      try
         for var comment in GetPinComments do
             comment.Page := APage;
      finally
         if unPin then
            UnPinComments;
      end;
      FPage := APage;
      Parent := APage.Box;
      if UserFunction <> nil then
      begin
         var header := TUserFunction(UserFunction).Header;
         if header <> nil then
            header.SetPageCombo(APage.Caption);
      end;
   end;
end;

function TMainBlock.GetPage: TBlockTabSheet;
begin
   result := FPage;
end;

function TMainBlock.GetDefaultWidth: integer;
begin
   var R := GetEllipseTextRect(0, 0, FStartLabel);
   result := R.Width;
   R := GetEllipseTextRect(0, 0, FStopLabel);
   var w := R.Width;
   if w > result then
      result := w;
   result := result + 40;
end;

procedure TMainBlock.SetZOrder(AValue: integer);
begin
   FZOrder := FPage.PageIndex * 100 + AValue;
end;

function TMainBlock.GetZOrder: integer;
begin
   result := FZOrder;
end;

function TMainBlock.GetHandle: THandle;
begin
   result := 0;
   if Visible then
      result := Handle;
end;

function TMainBlock.GetMaxBounds: TPoint;
begin
   result := TPoint.Zero;
   if Visible then
   begin
      result := BoundsRect.BottomRight;
      if Expanded then
      begin
         for var comment in GetComments do
         begin
            if comment.Visible then
            begin
               var pnt := comment.BoundsRect.BottomRight;
               if pnt.X > result.X then
                  result.X := pnt.X;
               if pnt.Y > result.Y then
                  result.Y := pnt.Y;
            end;
         end;
      end;
      result := result + Point(MARGIN_X, MARGIN_Y);
   end;
end;

procedure TMainBlock.ExportToGraphic(AGraphic: TGraphic);
var
   bitmap: TBitmap;
   pnt: TPoint;
   comment: TComment;
   bStyle: TBorderStyle;
   selStart: integer;
   pdi: boolean;
begin
   DeSelect;
   if AGraphic is TBitmap then
      bitmap := TBitmap(AGraphic)
   else
      bitmap := TBitmap.Create;
   pnt := GetMaxBounds;
   pnt.X := pnt.X - Left - MARGIN_X + 1;
   pnt.Y := pnt.Y - Top - MARGIN_Y + 1;
   bitmap.Width := pnt.X;
   bitmap.Height := pnt.Y;
   pdi := FPage.DrawI;
   FPage.DrawI := false;
   bitmap.Canvas.Lock;
   try
      PaintTo(bitmap.Canvas, 1, 1);
      if Expanded then
      begin
         for comment in GetComments do
         begin
            if comment.Visible then
            begin
               bStyle := comment.BorderStyle;
               selStart := comment.SelStart;
               comment.BorderStyle := bsNone;
               comment.PaintTo(bitmap.Canvas, comment.Left-Left, comment.Top-Top);
               comment.BorderStyle := bStyle;
               comment.SelStart := selStart;
            end;
         end;
      end;
   finally
      bitmap.Canvas.Unlock;
      FPage.DrawI := pdi;
   end;
   if AGraphic <> bitmap then
   begin
      AGraphic.Assign(bitmap);
      bitmap.Free;
   end;
end;

procedure TMainBlock.Paint;
var
   fontColor: TColor;
   lLabel: string;
   R: TRect;
   fontStyles: TFontStyles;
begin
   inherited;
   if Expanded then
   begin
      IPoint.X := Branch.Hook.X + 30;
      IPoint.Y := 35;
      fontStyles := Canvas.Font.Style;
      Canvas.Font.Style := [];
      Canvas.Brush.Style := bsClear;
      lLabel := GetFunctionLabel(R);
      if not lLabel.IsEmpty then
      begin
         fontColor := Canvas.Font.Color;
         Canvas.Font.Color := clNavy;
         DrawText(Canvas.Handle, PChar(lLabel), -1, R, 0);
         Canvas.Font.Color := fontColor;
         if Canvas.Handle = FHandle then
            FLabelRect := R;
      end
      else
         FLabelRect := TRect.Empty;
      DrawStartEllipse;
      if Branch.FindInstanceOf(TReturnBlock) = -1 then
         DrawStopEllipse;
      Canvas.Font.Style := fontStyles;
      DrawArrow(Point(Branch.Hook.X, TopHook.Y), Branch.Hook);
   end;
   DrawI;
end;

procedure TMainBlock.DrawStartEllipse;
begin
   DrawEllipsedText(Branch.Hook.X, TopHook.Y, FStartLabel);
end;

procedure TMainBlock.DrawStopEllipse;
var
   y: integer;
begin
   if Branch.Count = 0 then
      y := Branch.Hook.Y + 1
   else
      y := Branch.Last.BoundsRect.Bottom;
   y := y + GetEllipseTextRect(0, 0, FStopLabel).Height;
   DrawEllipsedText(BottomHook, y, FStopLabel);
end;

function TMainBlock.GetFunctionLabel(var ARect: TRect): string;
var
   lang: TLangDefinition;
   d: integer;
   header: TUserFunctionHeader;
begin
   result := '';
   ARect := Rect(Branch.Hook.X+75, 7, 0, 0);
   if GSettings.ShowFuncLabels and (UserFunction <> nil) and Expanded then
   begin
      lang := nil;
      header := TUserFunction(UserFunction).Header;
      if header <> nil then
      begin
         if Assigned(GInfra.CurrentLang.GetUserFuncDesc) then
            lang := GInfra.CurrentLang
         else if Assigned(GInfra.TemplateLang.GetUserFuncDesc) then
            lang := GInfra.TemplateLang;
         if lang <> nil then
            result := lang.GetUserFuncDesc(header, false, header.chkInclDescFlow.Checked);
      end
      else
      begin
         if Assigned(GInfra.CurrentLang.GetMainProgramDesc) then
            lang := GInfra.CurrentLang
         else if Assigned(GInfra.TemplateLang.GetMainProgramDesc) then
            lang := GInfra.TemplateLang;
         if lang <> nil then
            result := lang.GetMainProgramDesc;
      end;
   end;
   if not result.IsEmpty then
   begin
      DrawText(Canvas.Handle, PChar(result), -1, ARect, DT_CALCRECT);
      if (Branch.Count > 0) and (ARect.Bottom > Branch.First.Top-5) and (ARect.Left < Branch.First.BoundsRect.Right+5) then
      begin
         d := Branch.First.BoundsRect.Right + 5 - ARect.Left;
         ARect.Offset(d, 0);
      end;
   end;
end;

function TMainBlock.GetExportFileName: string;
begin
   if UserFunction <> nil then
      result := TUserFunction(UserFunction).GetName
   else
      result := inherited GetExportFileName;
end;

function TMainBlock.ExportToXMLFile(const AFile: string): TError;
begin
   if UserFunction <> nil then
      result := TXMLProcessor.ExportToXMLFile(TUserFunction(UserFunction).ExportToXMLTag, AFile)
   else
      result := inherited ExportToXMLFile(AFile);
end;

procedure TMainBlock.DrawLabel;
var
   R: TRect;
   lLabel: string;
   lColor: TColor;
begin
   lLabel := GetFunctionLabel(R);
   if not lLabel.IsEmpty then
   begin
      if not FLabelRect.IsEmpty then
      begin
         Canvas.Brush.Style := bsSolid;
         Canvas.Brush.Color := Color;
         Canvas.FillRect(FLabelRect);
      end;
      lColor := Canvas.Font.Color;
      Canvas.Font.Color := clNavy;
      DrawText(Canvas.Handle, PChar(lLabel), -1, R, 0);
      Canvas.Font.Color := lColor;
      FLabelRect := R;
   end;
end;

procedure TMainBlock.MyOnMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
   if Expanded then
      inherited MyOnMouseMove(Sender, Shift, X, Y)
   else
   begin
      var p := Point(X, Y);
      if IsAtSelectPos(p) then
         Select
      else
         DeSelect;
      SetCursor(p);
   end;
end;

procedure TMainBlock.MyOnResize(Sender: TObject);
begin
   FPage.Box.SetScrollbars;
   BringAllToFront;
   FPage.Box.Invalidate;
end;

function TMainBlock.GenerateCode(ALines: TStringList; const ALangId: string; ADeep: integer; AFromLine: integer = LAST_LINE): integer;
var
   lName, template, ending: string;
   lang: TLangDefinition;
   progList, varList, tmpList: TStringList;
   vars: TVarDeclareList;
   header: TUserFunctionHeader;
begin
   tmpList := TStringList.Create;
   try
      if ALangId = TIBASIC_LANG_ID then
         GenerateNestedCode(tmpList, PRIMARY_BRANCH_IDX, ADeep+1, ALangId)
      else
      begin
         lang := GInfra.GetLangDefinition(ALangId);
         if lang <> nil then
         begin
            header := TInfra.GetFunctionHeader(Self);
            if header <> nil then
            begin
               vars := header.LocalVars;
               lName := header.GetName;
               template := GetBlockTemplate(ALangId);
            end
            else
            begin
               vars := GProject.GlobalVars;
               lName := GProject.Name;
               template := lang.MainFunctionTemplate;
            end;
            if not template.IsEmpty then
            begin
               progList := TStringList.Create;
               varList := TStringList.Create;
               try
                  progList.Text := ReplaceStr(template, PRIMARY_PLACEHOLDER, lName);
                  if header = nil then
                  begin
                     ending := '';
                     if not ((Branch.Count > 0) and (Branch.Last is TReturnBlock)) then
                        ending := lang.ProgramReturnTemplate;
                     TInfra.InsertTemplateLines(progList, '%s3', ending);
                  end;
                  if Assigned(GInfra.CurrentLang.VarSectionGenerator) then
                     GInfra.CurrentLang.VarSectionGenerator(varList, vars)
                  else if Assigned(GInfra.TemplateLang.VarSectionGenerator) then
                     GInfra.TemplateLang.VarSectionGenerator(varList, vars);
                  TInfra.InsertTemplateLines(progList, '%s2', varList);
                  GenerateTemplateSection(tmpList, progList, ALangId, ADeep);
               finally
                  varList.Free;
                  progList.Free;
               end;
            end;
         end;
      end;
      TInfra.InsertLinesIntoList(ALines, tmpList, AFromLine);
      result := tmpList.Count;
   finally
      tmpList.Free;
   end;
end;

procedure TMainBlock.SetWidth(AMinX: integer);
var
   minVal, val: integer;
   R: TRect;
begin
   if Expanded then
   begin
      minVal := Branch.GetMostRight + 30;
      if not GetFunctionLabel(R).IsEmpty then
         val := R.Right + 10
      else
         val := minVal;
      if val > minVal then
         minVal := val;
      if AMinX < minVal then
         Width := minVal
      else
         Width := AMinX + 5;
   end;
end;

function TMainBlock.GenerateTree(AParentNode: TTreeNode): TTreeNode;
begin
   result := AParentNode;
   for var block in Branch do
       block.GenerateTree(AParentNode);
end;

procedure TMainBlock.SaveInXML(ATag: IXMLElement);
begin
   inherited SaveInXML(ATag);
   if ATag <> nil then
   begin
      ATag.SetAttribute(Z_ORDER_ATTR, FZOrder.ToString);
      if not FPage.IsMain then
         ATag.SetAttribute(PAGE_CAPTION_ATTR, FPage.Caption);
   end;
end;

function TMainBlock.GetFromXML(ATag: IXMLElement): TError;
begin
   result := inherited GetFromXML(ATag);
   if ATag <> nil then
      FZOrder := TXMLProcessor.GetIntFromAttr(ATag, Z_ORDER_ATTR, -1);
end;

function TMainBlock.IsBoldDesc: boolean;
begin
   result := true;
end;

procedure TMainBlock.WMWindowPosChanging(var Msg: TWMWindowPosChanging);
begin
   MoveComments(Msg.WindowPos.x, Msg.WindowPos.y);
   inherited;
end;

procedure TMainBlock.OnWindowPosChanged(x, y: integer);
begin
// do nothing
end;

function TMainBlock.GetUndoObject: TObject;
begin
   result := UserFunction;
end;

function TMainBlock.Remove(ANode: TTreeNodeWithFriend = nil): boolean;
begin
   result := inherited Remove(ANode);
   if result and (UserFunction <> nil) then
   begin
      TUserFunction(UserFunction).Active := false;
      TInfra.UpdateCodeEditor;
   end;
end;

end.
