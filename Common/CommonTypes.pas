{
   Copyright (C) 2011 The devFlowcharter project.
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



unit CommonTypes;

interface

uses
{$IFDEF USE_CODEFOLDING}
   SynEditCodeFolding,
{$ENDIF}
   System.Classes, Vcl.StdCtrls, Vcl.Forms, Vcl.Controls, Generics.Defaults,
   Vcl.ComCtrls, WinApi.Messages, System.Types, SynEditTypes, OmniXML;

const
   ID_INVALID = -1;

type

   TCustomCursor = (crNormal, crIfElse, crFor, crRepeat, crWhile, crInstr, crMultiInstr,
                    crIf, crFuncCall, crInput, crOutput, crCase, crReturn, crText, crFolder);

   TError = (errNone, errDeclare, errIO, errValidate, errConvert, errSyntax, errPrinter, errCompile, errImport, errGeneral);

   TBlockType = (blUnknown, blInstr, blMultiInstr, blInput, blOutput, blFuncCall, blWhile, blRepeat,
                 blIf, blIfElse, blFor, blCase, blMain, blComment, blReturn, blText, blFolder);

   TDataTypeKind = (tpInt, tpReal, tpString, tpBool, tpRecord, tpEnum, tpArray, tpPtr, tpOther);

   TUserDataTypeKind = (dtInt, dtRecord, dtArray, dtReal, dtOther, dtEnum);

   TArrowPosition = (arrMiddle, arrEnd);

   TColorShape = (shpNone, shpEllipse, shpParallel, shpDiamond, shpRectangle, shpRoadSign, shpRoutine, shpFolder);

   TImportMode = (impSelectTab, impSelectPopup, impAll);

   TCodeRange = record
      FirstRow,
      LastRow: integer;
      IsFolded: boolean;
      Lines: TStrings;
{$IFDEF USE_CODEFOLDING}
      FoldRange: TSynEditFoldRange;
{$ENDIF}
      class function New: TCodeRange; static;
   end;

   PNativeDataType = ^TNativeDataType;
   TNativeDataType = record
      Name: string;
      Kind: TDataTypeKind;
      OrigType: PNativeDataType;
      IsGeneric: boolean;
      Lib: string;
   end;

   PNativeFunction = ^TNativeFunction;
   TNativeFunction = record
      Name,
      Brackets,
      Hint,
      Caption,
      Lib: string;
      BracketsCursorPos: integer;
   end;

   TErrWarnCount = record
      ErrorCount,
      WarningCount: integer;
   end;

   TChangeLine = record
      Text: string;
      Row,
      Col: integer;
      EditCaretXY: TBufferCoord;
      CodeRange: TCodeRange;
      class function New: TChangeLine; static;
   end;

   TFocusInfo = record
      LineText,
      SelText: string;
      Line,
      RelativeLine,
      SelStart: integer;
      FocusEdit: TCustomEdit;
      FocusEditForm: TForm;
      FocusEditCallBack: procedure(AEdit: TCustomEdit) of object;
      ActiveControl: TWinControl;
      class function New: TFocusInfo; static;
   end;

   T3Strings = record
     S0, S1, S2: string;
     class function Extract(const AFrom: string): T3Strings; static;
   end;

   TBlockParms = record
      x, y, h, w, bh, bid, th, trh, flh: integer;
      br, br2: TPoint;
      bt: TBlockType;
      class function New(bt: TBlockType; x, y, w, h: integer; bid: integer = ID_INVALID): TBlockParms; overload; static;
      class function New(bt: TBlockType; x, y, w, h, brx, bry, bh: integer; bid: integer = ID_INVALID): TBlockParms; overload; static;
      class function New(bt: TBlockType; x, y, w, h, brx, bry, bh, th, br2x, br2y, trh, flh: integer; bid: integer = ID_INVALID): TBlockParms; overload; static;
      class function New(AFrom: IXMLElement): TBlockParms; overload; static;
   end;

   PTypesSet = ^TTypesSet;
   TTypesSet = set of 0..255;

   TComponentComparer = class(TComparer<TComponent>)
      FCompareType: integer;
      constructor Create(ACompareType: integer);
      function Compare(const L, R: TComponent): integer; override;
   end;

   TTreeNodeWithFriend = class(TTreeNode)
   public
      Friend: TTreeNodeWithFriend;
      Offset: integer;
   end;

   TNameEdit = class(TEdit)
       protected
          procedure WMKillFocus(var msg: TWMKillFocus); message WM_KILLFOCUS;
    end;

implementation

uses
   System.SysUtils, System.Rtti, CommonInterfaces, ApplicationCommon, XMLProcessor;

constructor TComponentComparer.Create(ACompareType: integer);
begin
   inherited Create;
   FCompareType := ACompareType;
end;

function TComponentComparer.Compare(const L, R: TComponent): integer;
var
   c1, c2: IGenericComparable;
begin
   if (L = nil) and (R = nil) then
      result := 0
   else if not Supports(L, IGenericComparable, c1) then
      result := -41893
   else if not Supports(R, IGenericComparable, c2) then
      result := 41893
   else
      result := c1.GetCompareValue(FCompareType) - c2.GetCompareValue(FCompareType);
end;

class function TCodeRange.New: TCodeRange;
begin
   result.IsFolded := false;
   result.FirstRow := ROW_NOT_FOUND;
   result.LastRow := ROW_NOT_FOUND;
   result.Lines := nil;
{$IFDEF USE_CODEFOLDING}
   result.FoldRange := nil;
{$ENDIF}
end;

class function TChangeLine.New: TChangeLine;
begin
   result.Text := '';
   result.Row := ROW_NOT_FOUND;
   result.Col := 0;
   result.EditCaretXY := BufferCoord(0, 0);
   result.CodeRange := TCodeRange.New;
end;

class function TFocusInfo.New: TFocusInfo;
begin
   result.Line := -1;
   result.RelativeLine := 0;
   result.SelStart := -1;
   result.SelText := '';
   result.LineText := '';
   result.FocusEdit := nil;
   result.FocusEditForm := nil;
   result.FocusEditCallBack := nil;
   result.ActiveControl := nil;
end;

class function T3Strings.Extract(const AFrom: string): T3Strings;
var
   i: integer;
   tokens: TArray<string>;
begin
   result.S0 := '';
   result.S1 := '';
   result.S2 := '';
   tokens := AFrom.Split(['|'], 3);
   i := Length(tokens);
   if i > 0 then
      result.S0 := tokens[0];
   if i > 1 then
      result.S1 := tokens[1];
   if i > 2 then
      result.S2 := tokens[2];
end;

class function TBlockParms.New(bt: TBlockType; x, y, w, h: integer; bid: integer = ID_INVALID): TBlockParms;
begin
   result.bt := bt;
   result.x := x;
   result.y := y;
   result.w := w;
   result.h := h;
   result.bid := bid;
   result.bh := 0;
   result.th := 0;
   result.trh := 0;
   result.flh := 0;
   result.br := TPoint.Zero;
   result.br2 := TPoint.Zero;
end;

class function TBlockParms.New(bt: TBlockType; x, y, w, h, brx, bry, bh: integer; bid: integer = ID_INVALID): TBlockParms;
begin
   result := New(bt, x, y, w, h, bid);
   result.br := Point(brx, bry);
   result.bh := bh;
end;

class function TBlockParms.New(bt: TBlockType; x, y, w, h, brx, bry, bh, th, br2x, br2y, trh, flh: integer; bid: integer = ID_INVALID): TBlockParms;
begin
   result := New(bt, x, y, w, h, brx, bry, bh, bid);
   result.th := th;
   result.br2 := Point(br2x, br2y);
   result.trh := trh;
   result.flh := flh;
end;

class function TBlockParms.New(AFrom: IXMLElement): TBlockParms;
var
   attr: string;
   at: integer;
   bt: TBlockType;
begin
   attr := AFrom.GetAttribute(BLOCK_TYPE_ATTR);
   at := StrToIntDef(attr, -1);
   if at = -1 then
      bt := TRttiEnumerationType.GetValue<TBlockType>(attr)
   else
      bt := TBlockType(at);
   with TXMLProcessor do
      result := New(bt,
                    GetInt(AFrom, 'x'),
                    GetInt(AFrom, 'y'),
                    GetInt(AFrom, 'w'),
                    GetInt(AFrom, 'h'),
                    GetInt(AFrom, 'brx'),
                    GetInt(AFrom, 'bry'),
                    GetInt(AFrom, 'bh'),
                    GetInt(AFrom, 'th'),
                    GetInt(AFrom, 'fbrx'),
                    GetInt(AFrom, 'fbry'),
                    GetInt(AFrom, 'trh'),
                    GetInt(AFrom, 'flh'),
                    GetInt(AFrom, ID_ATTR, ID_INVALID));
end;

procedure TNameEdit.WMKillFocus(var msg: TWMKillFocus);
begin
   inherited;
   Change;
end;

end.


