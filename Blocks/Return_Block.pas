{
   Copyright � 2007 Frost666, The devFlowcharter project.
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

unit Return_Block;

interface

uses
   Vcl.Graphics, System.Classes, Vcl.StdCtrls, Base_Block, CommonTypes;

type

   TReturnBlock = class(TBlock)
      public
         constructor Create(ABranch: TBranch); overload;
         constructor Create(ABranch: TBranch; const ABlockParms: TBlockParms); overload;
         function GenerateCode(ALines: TStringList; const ALangId: string; ADeep: integer; AFromLine: integer = LAST_LINE): integer; override;
         procedure ChangeColor(AColor: TColor); override;
         procedure UpdateEditor(AEdit: TCustomEdit); override;
         function GetDescTemplate(const ALangId: string): string; override;
      protected
         FReturnLabel: string;
         procedure Paint; override;
         procedure MyOnMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
         function GetDefaultWidth: integer;
   end;

implementation

uses
   Vcl.Controls, System.SysUtils, System.StrUtils, System.Types, System.UITypes,
   ApplicationCommon, Project, UserFunction, Main_Block, LangDefinition;

constructor TReturnBlock.Create(ABranch: TBranch; const ABlockParms: TBlockParms);
var
   defWidth: integer;
begin

   inherited Create(ABranch, ABlockParms);

   FReturnLabel := i18Manager.GetString('CaptionExit');

   defWidth := GetDefaultWidth;
   if defWidth > Width then
      Width := defWidth;

   FShape := shpEllipse;
   BottomHook := Width div 2;
   BottomPoint.X := BottomHook;
   BottomPoint.Y := 19;
   IPoint.X := BottomHook + 30;
   IPoint.Y := 30;
   TopHook.X := BottomHook;

   FStatement.SetBounds(BottomHook-26, 31, 52, 19);
   FStatement.Anchors := [akRight, akLeft, akTop];
   FStatement.Alignment := taCenter;
   FStatement.Color := GSettings.DesktopColor;
end;

constructor TReturnBlock.Create(ABranch: TBranch);
begin
   Create(ABranch, TBlockParms.New(blReturn, 0, 0, 140, 53));
end;

procedure TReturnBlock.Paint;
var
   fontStyles: TFontStyles;
   R: TRect;
begin
   inherited;
   fontStyles := Canvas.Font.Style;
   Canvas.Font.Style := [];
   R := DrawEllipsedText(BottomHook, 30, FReturnLabel);
   DrawBlockLabel(R.Left, R.Bottom, GInfra.CurrentLang.LabelReturn, true);
   Canvas.Font.Style := fontStyles;
   DrawI;
end;

function TReturnBlock.GetDefaultWidth: integer;
begin
   result := GetEllipseTextRect(0, 0, FReturnLabel).Width + 48;
end;

function TReturnBlock.GetDescTemplate(const ALangId: string): string;
var
   lang: TLangDefinition;
begin
   result := '';
   lang := GInfra.GetLangDefinition(ALangId);
   if lang <> nil then
      result := lang.ReturnDescTemplate;
end;

function TReturnBlock.GenerateCode(ALines: TStringList; const ALangId: string; ADeep: integer; AFromLine: integer = LAST_LINE): integer;
var
   indnt, expr: string;
   userFunction: TUserFunction;
   inFunc: boolean;
   tmpList: TStringList;
begin
   result := 0;
   if fsStrikeOut in Font.Style then
      exit;
   if ALangId = PASCAL_LANG_ID then
   begin
      indnt := DupeString(GSettings.IndentSpaces, ADeep);
      expr := Trim(FStatement.Text);
      inFunc := false;
      if not expr.IsEmpty then
      begin
         for userFunction in GProject.GetUserFunctions do
         begin
            inFunc := userFunction.Active and (userFunction.Body = FTopParentBlock) and (userFunction.Header <> nil) and (userFunction.Header.cbType.ItemIndex > 0);
            if inFunc then
               break;
         end;
      end;
      tmpList := TStringList.Create;
      try
         if inFunc then
            tmpList.AddObject(indnt + userFunction.Header.edtName.Text + ' ' + GInfra.GetLangDefinition(ALangId).AssignOperator + ' ' + expr + ';', Self);
         if not (((TMainBlock(FTopParentBlock).Branch.Count > 0) and (TMainBlock(FTopParentBlock).Branch.Last = Self)) and inFunc) then
            tmpList.AddObject(indnt + 'exit;', Self);
         TInfra.InsertLinesIntoList(ALines, tmpList, AFromLine);
         result := tmpList.Count;
      finally
         tmpList.Free;
      end;
   end
   else
      result := inherited GenerateCode(ALines, ALangId, ADeep, AFromLine);
end;

procedure TReturnBlock.UpdateEditor(AEdit: TCustomEdit);
var
   chLine: TChangeLine;
   list: TStringList;
begin
   if PerformEditorUpdate then
   begin
      chLine := TInfra.GetChangeLine(Self, FStatement);
      if chLine.Row <> ROW_NOT_FOUND then
      begin
         list := TStringList.Create;
         try
            GenerateCode(list, GInfra.CurrentLang.Name, 0);
            chLine.Text := TInfra.ExtractIndentString(chLine.Text) + list.Text;
         finally
            list.Free;
         end;
         if GSettings.UpdateEditor and not SkipUpdateEditor then
            TInfra.ChangeLine(chLine);
         TInfra.GetEditorForm.SetCaretPos(chLine);
      end;
   end;
end;

procedure TReturnBlock.ChangeColor(AColor: TColor);
begin
   inherited ChangeColor(AColor);
   FStatement.Color := AColor;
end;

procedure TReturnBlock.MyOnMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
   SelectBlock(Point(X, Y));
end;

end.
