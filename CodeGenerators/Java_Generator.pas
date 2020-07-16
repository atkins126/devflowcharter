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



{ This unit contains stuff to support Java code generation }

unit Java_Generator;

interface

implementation

uses
   System.Classes, System.SysUtils, System.StrUtils, Vcl.Graphics, Vcl.ComCtrls,
   System.Character, SynHighlighterJava, DeclareList, ApplicationCommon, UserDataType,
   UserFunction, LangDefinition, ParserHelper, CommonTypes;

const
   JAVA_STRING_DELIM = #34;
   JAVA_CHAR_DELIM   = #39;

var
   javaLang: TLangDefinition;
   FImportLines: TStringList;
   FListImpl,
   FMapImpl,
   FSetImpl,
   FDateFormatImpl,
   FQueueImpl,
   FDequeImpl,
   FReaderImpl,
   FWriterImpl,
   FInStreamImpl,
   FOutStreamImpl,
   FTemporalImpl,
   FNumberImpl: TStringList;
   JAVA_INT_TYPE,
   JAVA_INTEGER_TYPE,
   JAVA_LONG_TYPE,
   JAVA_LONG_OBJECT_TYPE,
   JAVA_FLOAT_TYPE,
   JAVA_FLOAT_OBJECT_TYPE,
   JAVA_DOUBLE_TYPE,
   JAVA_DOUBLE_OBJECT_TYPE,
   JAVA_CHAR_TYPE,
   JAVA_CHARACTER_TYPE,
   JAVA_BYTE_TYPE,
   JAVA_BYTE_OBJECT_TYPE,
   JAVA_STRING_TYPE,
   JAVA_LIST_TYPE,
   JAVA_SET_TYPE,
   JAVA_MAP_TYPE,
   JAVA_BOOLEAN_TYPE,
   JAVA_BOOLEAN_OBJECT_TYPE,
   JAVA_DATE_TYPE,
   JAVA_CALENDAR_TYPE,
   JAVA_LOCAL_DATETIME_TYPE,
   JAVA_LOCAL_DATE_TYPE,
   JAVA_LOCAL_TIME_TYPE,
   JAVA_INSTANT_TYPE,
   JAVA_DURATION_TYPE,
   JAVA_PERIOD_TYPE,
   JAVA_DATETIME_FORMATTER,
   JAVA_BIGDECIMAL_TYPE,
   JAVA_BIGINTEGER_TYPE,
   JAVA_PATTERN_TYPE: integer;
   JAVA_PRIMITIVE_TYPES: array of integer;

function GetObjectType(AType: integer): integer;
begin
   result := UNKNOWN_TYPE;
   if AType <> UNKNOWN_TYPE then
   begin
      if AType = JAVA_INT_TYPE then
         result := JAVA_INTEGER_TYPE
      else if AType = JAVA_DOUBLE_TYPE then
         result := JAVA_DOUBLE_OBJECT_TYPE
      else if AType = JAVA_LONG_TYPE then
         result := JAVA_LONG_OBJECT_TYPE
      else if AType = JAVA_FLOAT_TYPE then
         result := JAVA_FLOAT_OBJECT_TYPE
      else if AType = JAVA_CHAR_TYPE then
         result := JAVA_CHARACTER_TYPE
      else if AType = JAVA_BOOLEAN_TYPE then
         result := JAVA_BOOLEAN_OBJECT_TYPE
      else if AType = JAVA_BYTE_TYPE then
         result := JAVA_BYTE_OBJECT_TYPE;
   end;
end;

function IsPrimitiveType(AType: integer): boolean;
var
   i: integer;
begin
   result := false;
   if AType <> UNKNOWN_TYPE then
   begin
      for i := 0 to High(JAVA_PRIMITIVE_TYPES) do
      begin
         if JAVA_PRIMITIVE_TYPES[i] = AType then
            Exit(true);
      end;
   end;
end;

procedure AddLibImport(const ALib: string);
var
   importLib: string;
begin
   if (FImportLines <> nil) and not ALib.IsEmpty then
   begin
      importLib := Format(javaLang.LibEntry, [ALib]);
      if (importLib <> '') and (FImportLines.IndexOf(importLib) = -1) then
         FImportLines.AddObject(importLib, TInfra.GetLibObject);
   end;
end;

function CheckForDataType(const AType: string): boolean;
var
   varList: TVarDeclareList;
   constList: TConstDeclareList;
   i: integer;
   typeStr: string;
   dataType: TUserDataType;
   field: TField;
   func: TUserFunction;
   param: TParameter;
begin

   result := false;

   // search in instance variables
   varList := GProject.GlobalVars;
   if varList <> nil then
   begin
      for i := 1 to varList.sgList.RowCount-2 do
      begin
         typeStr := varList.sgList.Cells[VAR_TYPE_COL, i];
         if typeStr = AType then
            Exit(true);
      end;
   end;

   // search in instance constants
   constList := GProject.GlobalConsts;
   if constList <> nil then
   begin
      for i := 1 to constList.sgList.RowCount-2 do
      begin
         typeStr := TParserHelper.GetTypeAsString(TParserHelper.GetConstType(constList.sgList.Cells[CONST_NAME_COL, i]));
         if typeStr = AType then
            Exit(true);
      end;
   end;

   // search in data types
   for dataType in GProject.GetUserDataTypes do
   begin
      if not dataType.GetName.IsEmpty then
      begin
         for field in dataType.GetFields do
         begin
            if field.cbType.Enabled and (field.cbType.Text = AType) then
               Exit(true);
         end;
      end;
   end;

   // search in functions
   for func in GProject.GetUserFunctions do
   begin
      if (func.Header <> nil) and not func.GetName.IsEmpty then
      begin
         if func.Header.cbType.Text = AType then
            Exit(true);
         varList := func.Header.LocalVars;
         if varList <> nil then
         begin
            for i := 1 to varList.sgList.RowCount-2 do
            begin
               typeStr := varList.sgList.Cells[VAR_TYPE_COL, i];
               if typeStr = AType then
                  Exit(true);
            end;
         end;
         for param in func.Header.GetParameters do
         begin
            if param.cbType.Text = AType then
               Exit(true);
         end;
      end;
   end;
end;

procedure Java_ExecuteBeforeGeneration;
begin
   FImportLines := nil;
end;

procedure Java_ExecuteAfterGeneration;
begin
   FImportLines := nil;
end;

procedure Java_LibSectionGenerator(ALines: TStringList);
var
   i: integer;
   libList: TStringList;
   typeName, libImport: string;
   pNativeType: PNativeDataType;
begin

   FImportLines := ALines;

   for i := 0 to High(javaLang.NativeDataTypes) do
   begin
      pNativeType := @javaLang.NativeDataTypes[i];
      if (pNativeType.Lib <> '') and CheckForDataType(pNativeType.Name) then
      begin
         libImport := pNativeType.Lib + '.' + pNativeType.Name;
         AddLibImport(libImport);
      end;
   end;

   libList := GProject.GetLibraryList;
   try
      for i := 0 to libList.Count-1 do
      begin
         typeName := '';
         if libList.Objects[i] is TTabSheet then
            typeName := TTabSheet(libList.Objects[i]).Caption;
         if not typeName.IsEmpty then
         begin
            libImport := libList.Strings[i] + '.' + typeName;
            AddLibImport(libImport);
         end;
      end;
   finally
      libList.Free;
   end;
end;

function GetImplementerLibImport(const ATypeName: string; const AContents: string): string;
var
   i: integer;
   implList: TStringList;
   name: string;
begin
   result := '';
   implList := nil;
   if ATypeName.EndsWith('List') then
      implList := FListImpl
   else if ATypeName.EndsWith('Map') then
      implList := FMapImpl
   else if ATypeName.EndsWith('Set') then
      implList := FSetImpl
   else if ATypeName.EndsWith('DateFormat') then
      implList := FDateFormatImpl
   else if ATypeName.EndsWith('Queue') then
      implList := FQueueImpl
   else if ATypeName.EndsWith('Deque') then
      implList := FDequeImpl
   else if ATypeName.EndsWith('Reader') then
      implList := FReaderImpl
   else if ATypeName.EndsWith('Writer') then
      implList := FWriterImpl
   else if ATypeName.EndsWith('InputStream') then
      implList := FInStreamImpl
   else if ATypeName.EndsWith('OutputStream') then
      implList := FOutStreamImpl
   else if ATypeName.EndsWith('Temporal') then
      implList := FTemporalImpl
   else if ATypeName.EndsWith('Number') then
      implList := FNumberImpl;
   if implList <> nil then
   begin
      for i := 0 to implList.Count-1 do
      begin
         name := implList.Names[i];
         if AContents.Contains(name) then
            Exit(implList.Values[name] + '.' + name);
      end;
   end;
end;

procedure Java_VarSectionGenerator(ALines: TStringList; AVarList: TVarDeclareList);
var
   i, p1, p2, a, b: integer;
   varType, varInit, varInit2, varVal, varGeneric, varGenericType, libImport, varAccess, varSize, varName: string;
   dims: TArray<string>;
   pNativeType: PNativeDataType;
   tokens: TArray<string>;
begin
   if AVarList <> nil then
   begin
      for i := 1 to AVarList.sgList.RowCount-2 do
      begin
         varName := AVarList.sgList.Cells[VAR_NAME_COL, i];
         varType :=  AVarList.sgList.Cells[VAR_TYPE_COL, i];
         varInit := AVarList.sgList.Cells[VAR_INIT_COL, i];
         varGeneric := '';
         varSize := '';
         varAccess := '';
         p1 := 0;
         p2 := 0;
         if not varInit.IsEmpty then
         begin
            if TParserHelper.IsGenericType(varType) then
            begin
               p1 := Pos('<', varInit);
               if p1 > 0 then
               begin
                  p2 := LastDelimiter('>', varInit);
                  if p2 > p1 then
                  begin
                     varGeneric := Copy(varInit, p1, p2-p1+1);
                     varGenericType := Copy(varInit, p1+1, p2-p1-1);
                     varGenericType := ReplaceStr(varGenericType, ' ', '');
                     tokens := varGenericType.Split([',']);
                     for b := 0 to High(tokens) do
                     begin
                       for a := 0 to High(javaLang.NativeDataTypes) do
                       begin
                          pNativeType := @javaLang.NativeDataTypes[a];
                          if (pNativeType.Lib <> '') and (pNativeType.Name = tokens[b]) then
                          begin
                             libImport := pNativeType.Lib + '.' + pNativeType.Name;
                             AddLibImport(libImport);
                             break;
                          end;
                       end;
                     end;
                  end;
               end;
            end;
            libImport := GetImplementerLibImport(varType, varInit);
            AddLibImport(libImport);
            if p2 > p1 then
               Delete(varInit, p1+1, p2-p1-1);      // make diamond operator
            varInit := ' = ' + varInit;
         end;
         p1 := AVarList.GetDimensionCount(varName);
         if p1 > 0 then
         begin
            varInit2 := '';
            dims := AVarList.GetDimensions(varName);
            if dims <> nil then
            begin
               for p2 := 0 to High(dims) do
               begin
                  varSize := varSize + Format(javaLang.VarEntryArraySize, [dims[p2]]);
                  varInit2 := varInit2 + '[' + dims[p2] + ']';
               end;
               if varInit.IsEmpty then
                  varInit := ' = new ' + varType + varInit2;
               if javaLang.VarEntryArraySizeStripCount > 0 then
                  SetLength(varSize, varSize.Length - javaLang.VarEntryArraySizeStripCount);
            end;
         end;
         if AVarList.IsGlobal then
            varAccess := AVarList.GetExternModifier(i);
         varVal := varAccess + varType + varGeneric + varSize + ' ' + varName + varInit + ';';
         ALines.AddObject(varVal, AVarList);
      end;
   end;
end;

procedure Java_UserDataTypesSectionGenerator(ALines: TStringList);
var
   name, line, fieldSize, fieldName, fieldType, funcStrU, typeAccess, indent: string;
   dataType: TUserDataType;
   field: TField;
   i: integer;
begin
   i := 0;
   for dataType in GProject.GetUserDataTypes do
   begin
      name := dataType.GetName;
      if not name.IsEmpty then
      begin
         indent := GSettings.IndentSpaces;
         typeAccess := dataType.GetExternModifier;
         if dataType.Kind = dtRecord then
         begin
            if i > 0 then
               ALines.AddObject('', dataType);
            line := typeAccess + 'class ' + name + ' {';
            ALines.AddObject(line, dataType);
            if dataType.FieldCount > 0 then
            begin
               ALines.AddObject('', dataType);
               i := ALines.Count;
               ALines.AddObject('', dataType);
               for field in dataType.GetFields do
               begin
                  fieldSize := javaLang.GetArraySizes(field.edtSize);
                  fieldName := Trim(field.edtName.Text);
                  fieldType := field.cbType.Text;
                  line := indent + 'private ' + fieldType + fieldSize + ' ' + fieldName + ';';
                  ALines.InsertObject(i, line, dataType);
                  funcStrU := fieldName;
                  if not funcStrU.IsEmpty then
                     funcStrU[1] := funcStrU[1].ToUpper;
                  line := indent + 'public ' + fieldType + fieldSize + ' get' + funcStrU + '() {';
                  ALines.AddObject(line, dataType);
                  line := indent + indent + 'return ' + fieldName + ';';
                  ALines.AddObject(line, dataType);
                  ALines.AddObject(indent + '}', dataType);
                  line := indent + 'public void set' + funcStrU + '(' + fieldType + fieldSize + ' ' + fieldName + ') {';
                  ALines.AddObject(line, dataType);
                  line := indent + indent + 'this.' + fieldName + ' = ' + fieldName + ';';
                  ALines.AddObject(line, dataType);
                  ALines.AddObject(indent + '}', dataType);
                  i := i + 1;
               end;
            end;
            ALines.AddObject('}', dataType);
            i := 1;
         end
         else if dataType.Kind = dtEnum then
         begin
            if i > 0 then
               ALines.AddObject('', dataType);
            line := typeAccess + 'enum ' + name + ' {';
            ALines.AddObject(line, dataType);
            if dataType.FieldCount > 0 then
            begin
               line := indent;
               for field in dataType.GetFields do
                  line := line + Trim(field.edtName.Text).ToUpper + ', ';
               SetLength(line, Length(line)-2);
               ALines.AddObject(line, dataType);
            end;
            ALines.AddObject('}', dataType);
            i := 1;
         end;
      end;
   end;
end;

function ProcessType(AType: integer): string;
var
   t: integer;
   libName: string;
begin
   result := '';
   if AType <> UNKNOWN_TYPE then
   begin
      t := GetObjectType(AType);
      if t <> UNKNOWN_TYPE then
         AType := t;
      result := TParserHelper.GetTypeAsString(AType);
      libName := TParserHelper.GetLibForType(result);
      if not libName.IsEmpty then
         AddLibImport(libName + '.' + result);
   end;
end;

function ContainsOneOf(const AString: string; const ASubStrings: array of string): boolean;
var
   i: integer;
begin
   for i := 0 to High(ASubStrings) do
   begin
      if AString.Contains(ASubStrings[i]) then
         Exit(true);
   end;
   result := false;
end;

function StartsWithOneOf(const AString: string; const AStartings: array of string): boolean;
var
   i: integer;
begin
   for i := 0 to High(AStartings) do
   begin
      if AString.StartsWith(AStartings[i]) then
         Exit(true);
   end;
   result := false;
end;

function EndsWithOneOf(const AString: string; const AEndings: array of string): boolean;
var
   i: integer;
begin
   for i := 0 to High(AEndings) do
   begin
      if AString.EndsWith(AEndings[i]) then
         Exit(true);
   end;
   result := false;
end;

function GetTypeForString(AType: integer; const AValue: string): integer;
begin
   result := AType;
   if ContainsOneOf(AValue, ['.toString(', '.toBinaryString(', '.toHexString(', '.toOctalString(', '.toUnsignedString(']) then
      result := JAVA_STRING_TYPE;
end;

function Java_GetConstantType(const AValue: string; var AGenericType: string): integer;
var
   i, len, a, ap, t1, t2, d: integer;
   i64: Int64;
   f: double;
   firstChar, lastChar: char;
   cValue, s, s1, s2: string;
   tokens: TArray<string>;
begin
   result := UNKNOWN_TYPE;
   AGenericType := '';
   len := AValue.Length;
   if len > 0 then
   begin
      firstChar := AValue[1];
      lastChar := AValue[len];
      if firstChar = '$' then
         Exit;
      if not TryStrToInt(AValue, i) then
      begin
         if len = 1 then
            Exit;
         if not TryStrToFloat(AValue, f) then
         begin
            if firstChar = JAVA_STRING_DELIM then
            begin
               if AValue.EndsWith(JAVA_STRING_DELIM + '.length()') then
                  result := JAVA_INT_TYPE
               else if lastChar = JAVA_STRING_DELIM then
                  result := JAVA_STRING_TYPE
               else
                  Exit;
            end
            else if AValue.StartsWith('new String(' + JAVA_STRING_DELIM) and AValue.EndsWith(JAVA_STRING_DELIM + ')') and (AValue.Length > 13) then
               result := JAVA_STRING_TYPE
            else if StartsWithOneOf(AValue, ['String.valueOf(', 'String.join(', 'String.format(']) and (lastChar = ')') then
               result := JAVA_STRING_TYPE
            else if (len > 2) and (firstChar = JAVA_CHAR_DELIM) and (lastChar = JAVA_CHAR_DELIM) then
            begin
               cValue := Copy(AValue, 2, len-2);
               i := cValue.Length;
               if cValue[1] = '\' then
               begin
                  if (i = 2) and (LastDelimiter('0btnfr"\'#39, cValue) = 2) then
                     result := JAVA_CHAR_TYPE
                  else if (i = 6) and ((cValue[2] = 'u') or (cValue[2] = 'U')) then
                  begin
                     for a := 3 to 6 do
                     begin
                        if not CharInSet(cValue[a], ['0'..'9', 'a'..'f', 'A'..'F']) then
                           Exit;
                     end;
                     result := JAVA_CHAR_TYPE;
                  end;
               end
               else if i = 1 then
                  result := JAVA_CHAR_TYPE;
            end
            else if AValue = 'new Date()' then
               result := JAVA_DATE_TYPE
            else if AValue = 'Calendar.getInstance()' then
               result := JAVA_CALENDAR_TYPE
            else if (AValue = 'LocalDateTime.now()') or AValue.StartsWith('LocalDateTime.of(') then
               result := JAVA_LOCAL_DATETIME_TYPE
            else if (AValue = 'LocalDate.now()') or AValue.StartsWith('LocalDate.of(') then
               result := JAVA_LOCAL_DATE_TYPE
            else if (AValue = 'LocalTime.now()') or AValue.StartsWith('LocalTime.of(') then
               result := JAVA_LOCAL_TIME_TYPE
            else if AValue.StartsWith('Duration.') then
            begin
               if EndsWithOneOf(AValue, ['.toDays()', '.toHours()', '.toMillis()', '.toMinutes()', '.toNanos()']) then
                  result := JAVA_LONG_TYPE
               else if AValue.EndsWith('.toString()') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_DURATION_TYPE;
               if result <> JAVA_DURATION_TYPE then
                  AddLibImport(TParserHelper.GetLibForType('Duration', 'java.time') + '.Duration');
            end
            else if AValue.StartsWith('Period.') then
            begin
               if EndsWithOneOf(AValue, ['.getDays()', '.getMonths()', '.getYears()']) then
                  result := JAVA_INT_TYPE
               else if AValue.EndsWith('.toString()') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_PERIOD_TYPE;
               if result <> JAVA_PERIOD_TYPE then
                  AddLibImport(TParserHelper.GetLibForType('Period', 'java.time') + '.Period');
            end
            else if AValue.StartsWith('Instant.') then
            begin
               if AValue.EndsWith('.getNano()') then
                  result := JAVA_INT_TYPE
               else if AValue.EndsWith('.toEpochMilli()') then
                  result := JAVA_LONG_TYPE
               else if AValue.EndsWith('.toString()') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_INSTANT_TYPE;
               if result <> JAVA_INSTANT_TYPE then
                  AddLibImport(TParserHelper.GetLibForType('Instant', 'java.time') + '.Instant');
            end
            else if AValue = 'null' then
               result := JAVA_STRING_TYPE
            else if MatchStr(AValue, ['true', 'false']) then
               result := JAVA_BOOLEAN_TYPE
            else if StartsWithOneOf(AValue, ['new Boolean(', 'Boolean.']) then
            begin
               if ContainsOneOf(AValue, ['.booleanValue()', '.parseBoolean(']) then
                  result := JAVA_BOOLEAN_TYPE
               else if AValue.Contains('.toString(') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_BOOLEAN_OBJECT_TYPE;
            end
            else if StartsWithOneOf(AValue, ['new BigDecimal(', 'BigDecimal.']) then
            begin
               if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else if AValue.Contains('.intValue()') then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else if EndsWithOneOf(AValue, ['.toString()', '.toPlainString()']) then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_BIGDECIMAL_TYPE;
               if result <> JAVA_BIGDECIMAL_TYPE then
                  AddLibImport(TParserHelper.GetLibForType('BigDecimal', 'java.math') + '.BigDecimal');
            end
            else if StartsWithOneOf(AValue, ['new BigInteger(', 'BigInteger.']) then
            begin
               if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else if AValue.Contains('.intValue()') then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else if AValue.Contains('.toString(') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_BIGINTEGER_TYPE;
               if result <> JAVA_BIGINTEGER_TYPE then
                  AddLibImport(TParserHelper.GetLibForType('BigInteger', 'java.math') + '.BigInteger');
            end
            else if StartsWithOneOf(AValue, ['new Integer(', 'Integer.']) then
            begin
               if ContainsOneOf(AValue, ['.intValue()', '.parseInt(', '.SIZE', '.BYTES', '.MAX_VALUE', '.MIN_VALUE']) then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else
                  result := GetTypeForString(JAVA_INTEGER_TYPE, AValue);
            end
            else if StartsWithOneOf(AValue, ['new Byte(', 'Byte.']) then
            begin
               if ContainsOneOf(AValue, ['.byteValue()', '.parseByte(']) then
                  result := JAVA_BYTE_TYPE
               else if AValue.Contains('.intValue()') then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else if AValue.Contains('.toString(') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_BYTE_OBJECT_TYPE;
            end
            else if StartsWithOneOf(AValue, ['new Long(', 'Long.']) then
            begin
               if ContainsOneOf(AValue, ['.longValue()', '.parseLong(', '.MAX_VALUE', '.MIN_VALUE']) then
                  result := JAVA_LONG_TYPE
               else if ContainsOneOf(AValue, ['.intValue()', '.SIZE', '.BYTES']) then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else
                  result := GetTypeForString(JAVA_LONG_OBJECT_TYPE, AValue);
            end
            else if StartsWithOneOf(AValue, ['new Double(', 'Double.']) then
            begin
               if ContainsOneOf(AValue, ['.doubleValue()', '.parseDouble(', '.MIN_VALUE', '.MAX_VALUE', '.NaN', '.NEGATIVE_INFINITY', '.POSITIVE_INFINITY']) then
                  result := JAVA_DOUBLE_TYPE
               else if ContainsOneOf(AValue, ['.intValue()', '.SIZE', '.BYTES', '.MIN_EXPONENT', '.MAX_EXPONENT']) then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else if AValue.Contains('.floatValue()') then
                  result := JAVA_FLOAT_TYPE
               else
                  result := GetTypeForString(JAVA_DOUBLE_OBJECT_TYPE, AValue);
            end
            else if StartsWithOneOf(AValue, ['new Float(', 'Float.']) then
            begin
               if ContainsOneOf(AValue, ['.floatValue()', '.parseFloat(', '.MIN_VALUE', '.MAX_VALUE', '.NaN', '.NEGATIVE_INFINITY', '.POSITIVE_INFINITY']) then
                  result := JAVA_FLOAT_TYPE
               else if AValue.Contains('.doubleValue()') then
                  result := JAVA_DOUBLE_TYPE
               else if ContainsOneOf(AValue, ['.intValue()', '.SIZE', '.BYTES', '.MIN_EXPONENT', '.MAX_EXPONENT']) then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.longValue()') then
                  result := JAVA_LONG_TYPE
               else
                  result := GetTypeForString(JAVA_FLOAT_OBJECT_TYPE, AValue);
            end
            else if StartsWithOneOf(AValue, ['new Character(', 'Character.']) then
            begin
               if ContainsOneOf(AValue, ['.charValue()', '.toLowerCase(', '.toUpperCase(', '.reverseBytes(', '.toTitleCase(']) then
                  result := JAVA_CHAR_TYPE
               else if ContainsOneOf( AValue, ['.digit(', '.codePoint']) then
                  result := JAVA_INT_TYPE
               else if AValue.Contains('.toString(') then
                  result := JAVA_STRING_TYPE
               else
                  result := JAVA_CHARACTER_TYPE;
            end
            else if AValue.StartsWith('Collections.') then
            begin
              AddLibImport('java.util.Collections');
              cValue := Copy(AValue, 13);
              if MatchStr(cValue, ['EMPTY_LIST', 'emptyList()']) then
                 result := JAVA_LIST_TYPE
              else if MatchStr(cValue, ['EMPTY_SET', 'emptySet()']) then
                 result := JAVA_SET_TYPE
              else if MatchStr(cValue, ['EMPTY_MAP', 'emptyMap()']) then
                 result := JAVA_MAP_TYPE
              else if lastChar = ')' then
              begin
                 if StartsWithOneOf(cValue, ['unmodifiableList(', 'synchronizedList(']) then
                    result := JAVA_LIST_TYPE
                 else if cValue.StartsWith('singletonList(') then
                 begin
                    cValue := Copy(cValue, 15, cValue.Length-15);
                    result := Java_GetConstantType(cValue.Trim, s);
                    AGenericType := ProcessType(result);
                    result := JAVA_LIST_TYPE
                 end
                 else if cValue.StartsWith('nCopies(') then
                 begin
                    cValue := Copy(cValue, 9, cValue.Length-9);
                    tokens := cValue.Split([',']);
                    if (Length(tokens) <> 2) or not TryStrToInt(tokens[0].Trim, t1) then
                       Exit;
                    result := Java_GetConstantType(tokens[1].Trim, s);
                    AGenericType := ProcessType(result);
                    result := JAVA_LIST_TYPE
                 end
                 else if StartsWithOneOf(cValue, ['unmodifiableSet(', 'synchronizedSet(']) then
                    result := JAVA_SET_TYPE
                 else if cValue.StartsWith('singleton(') then
                 begin
                    cValue := Copy(cValue, 11, cValue.Length-11);
                    result := Java_GetConstantType(cValue.Trim, s);
                    AGenericType := ProcessType(result);
                    result := JAVA_SET_TYPE
                 end
                 else if StartsWithOneOf(cValue, ['unmodifiableMap(', 'synchronizedMap(']) then
                    result := JAVA_MAP_TYPE
                 else if cValue.StartsWith('singletonMap(') then
                 begin
                    cValue := Copy(cValue, 14, cValue.Length-14);
                    tokens := cValue.Split([',']);
                    if Length(tokens) <> 2 then
                       Exit;
                    t1 := Java_GetConstantType(tokens[0].Trim, s);
                    t2 := Java_GetConstantType(tokens[1].Trim, s);
                    s1 := ProcessType(t1);
                    s2 := ProcessType(t2);
                    if (s1 <> '') and (s2 <> '') then
                       AGenericType := s1 + ', ' + s2;
                    result := JAVA_MAP_TYPE;
                 end;
              end;
            end
            else if AValue.StartsWith('Arrays.asList(') and (lastChar = ')') then
            begin
               t1 := UNKNOWN_TYPE;
               cValue := Copy(AValue, 15, len-15);
               if cValue.StartsWith('new ') and cValue.EndsWith('}') then
               begin
                  s := Copy(cValue, 5);
                  s := ReplaceStr(s, ' ', '');
                  i := Pos('[', s);
                  if (i = 0) or (s[i+1] <> ']') or (s[i+2] <> '{') then
                     Exit;
                  s := Copy(s, 1, i-1);
                  t1 := TParserHelper.GetType(s);
                  if t1 = UNKNOWN_TYPE then
                     Exit;
                  i := Pos('{', cValue);
                  cValue := Copy(cValue, i+1, cValue.Length-i-1);
               end;
               tokens := cValue.Split([',']);
               a := t1;
               for i := 0 to High(tokens) do
               begin
                  a := Java_GetConstantType(tokens[i].Trim, s);
                  if ((t1 <> UNKNOWN_TYPE) and (a <> t1)) or ((i > 0) and (a <> ap)) or (a = UNKNOWN_TYPE) then
                     Exit;
                  ap := a;
               end;
               result := a;
               AGenericType := ProcessType(result);
               AddLibImport('java.util.Arrays');
               result := JAVA_LIST_TYPE;
            end
            else if AValue.StartsWith('new ') then
            begin
               if lastChar = '}' then
               begin
                  cValue := Copy(AValue, 5);
                  cValue := ReplaceStr(cValue, ' ', '');
                  i := Pos('[', cValue);
                  if i = 0 then
                     Exit;
                  s := Copy(cValue, 1, i-1);
                  t1 := TParserHelper.GetType(s);
                  if t1 = UNKNOWN_TYPE then
                     Exit;
                  d := 0;
                  cValue := Copy(cValue, i);
                  while cValue[1] = '[' do
                  begin
                     if cValue[2] <> ']' then
                        Exit;
                     d := d + 1;
                     cValue := Copy(cValue, 3);
                  end;
                  if cValue[1] <> '{' then
                     Exit;
                  ProcessType(t1);
                  t1 := TParserHelper.EncodeArrayType(t1, d);
                  cValue := Copy(AValue, Pos('{', AValue));
                  t2 := Java_GetConstantType(cValue, s);
                  if t1 <> t2 then
                     Exit;
                  result := t1;
               end
               else if lastChar = ')' then
               begin
                  i := Pos('(', AValue);
                  if i = 0 then
                     Exit;
                  cValue := Trim(Copy(AValue, 5, i-5));
                  t1 := TParserHelper.GetType(cValue);
                  if IsPrimitiveType(t1) or MatchText(cValue, ['String', 'Pattern']) then
                     Exit;
                  ProcessType(t1);
                  result := t1;
               end;
            end
            else if AValue.StartsWith('DateTimeFormatter.') then
            begin
               cValue := Copy(AValue, 19, len-18);
               if cValue.StartsWith('ofPattern(') and (lastChar = ')') then
               begin
                  cValue := Copy(cValue, 11, cValue.Length-11);
                  t1 := Java_GetConstantType(cValue, s);
                  if t1 <> JAVA_STRING_TYPE then
                     Exit;
               end;
               AddLibImport(TParserHelper.GetLibForType('DateTimeFormatter', 'java.time.format') + '.DateTimeFormatter');
               result := JAVA_DATETIME_FORMATTER;
            end
            else if AValue.StartsWith('Pattern.compile(') and (lastChar = ')') then
            begin
               cValue := Copy(AValue, 17, len-17);
               t1 := Java_GetConstantType(cValue, s);
               if t1 <> JAVA_STRING_TYPE then
                  Exit;
               AddLibImport(TParserHelper.GetLibForType('Pattern', 'java.util.regex') + '.Pattern');
               result := JAVA_PATTERN_TYPE;
            end
            else if (AValue[1] = '{') and (lastChar = '}') then
            begin
               t1 := 0;
               t2 := 0;
               for i := 1 to AValue.Length do
               begin
                  if AValue[i] = '{' then
                     t1 := t1 + 1
                  else if AValue[i] = '}' then
                     t2 := t2 + 1;
               end;
               if t1 <> t2 then
                  Exit;
               cValue := ReplaceStr(AValue, ' ', '');
               d := 0;
               while cValue[d+1] = '{' do
                  d := d + 1;
               cValue := ReplaceStr(AValue, '{', '');
               cValue := ReplaceStr(cValue, '}', '');
               a := result;
               tokens := cValue.Split([',']);
               for i := 0 to High(tokens) do
               begin
                  a := Java_GetConstantType(tokens[i].Trim, s);
                  if ((i > 0) and (a <> ap)) or (a = UNKNOWN_TYPE) then
                     Exit;
                  ap := a;
               end;
               ProcessType(a);
               result := TParserHelper.EncodeArrayType(a, d);
            end
            else if AValue.Contains('System.currentTimeMillis()') then
               result := JAVA_LONG_TYPE
            else if ContainsOneOf(AValue, ['Math.E', 'Math.PI']) then
               result := JAVA_DOUBLE_TYPE
            else if TryStrToInt64(AValue, i64) then
               result := JAVA_LONG_TYPE
            else if AValue.Contains('_') and firstChar.IsDigit and CharInSet(lastChar, ['0'..'9', 'l', 'L', 'd', 'D', 'f', 'F']) then
               result := Java_GetConstantType(ReplaceText(AValue, '_', ''), s)
            else
            begin
               cValue := Copy(AValue, 1, len-1);
               case lastChar of
                  'l', 'L':
                  if TryStrToInt64(cValue, i64) then
                     result := JAVA_LONG_TYPE;
                  'd', 'D':
                  if TryStrToFloat(cValue, f) then
                     result := JAVA_DOUBLE_TYPE;
                  'f', 'F':
                  if TryStrToFloat(cValue, f) then
                     result := JAVA_FLOAT_TYPE;
               end;
            end;
         end
         else
            result := JAVA_DOUBLE_TYPE;
      end
      else
         result := JAVA_INT_TYPE;
   end;
end;

procedure Java_SetHLighterAttrs;
var
   hlighter: TSynJavaSyn;
   bkgColor: TColor;
begin
   if (javaLang <> nil) and (javaLang.HighLighter is TSynJavaSyn) then
   begin
      bkgColor := GSettings.EditorBkgColor;
      hlighter := TSynJavaSyn(javaLang.HighLighter);
      hlighter.StringAttri.Foreground     := GSettings.EditorStringColor;
      hlighter.StringAttri.Background     := bkgColor;
      hlighter.NumberAttri.Foreground     := GSettings.EditorNumberColor;
      hlighter.NumberAttri.Background     := bkgColor;
      hlighter.CommentAttri.Foreground    := GSettings.EditorCommentColor;
      hlighter.CommentAttri.Background    := bkgColor;
      hlighter.KeyAttri.Foreground        := GSettings.EditorKeywordColor;
      hlighter.KeyAttri.Background        := bkgColor;
      hlighter.IdentifierAttri.Foreground := GSettings.EditorIdentColor;
      hlighter.IdentifierAttri.Background := bkgColor;
      hlighter.DocumentAttri.Foreground   := GSettings.EditorDocumentColor;
      hlighter.DocumentAttri.Background   := bkgColor;
   end;
end;


initialization

   JAVA_INT_TYPE            := TParserHelper.GetType('int', JAVA_LANG_ID);
   JAVA_INTEGER_TYPE        := TParserHelper.GetType('Integer', JAVA_LANG_ID);
   JAVA_LONG_TYPE           := TParserHelper.GetType('long', JAVA_LANG_ID);
   JAVA_LONG_OBJECT_TYPE    := TParserHelper.GetType('Long', JAVA_LANG_ID);
   JAVA_FLOAT_TYPE          := TParserHelper.GetType('float', JAVA_LANG_ID);
   JAVA_FLOAT_OBJECT_TYPE   := TParserHelper.GetType('Float', JAVA_LANG_ID);
   JAVA_BYTE_TYPE           := TParserHelper.GetType('byte', JAVA_LANG_ID);
   JAVA_BYTE_OBJECT_TYPE    := TParserHelper.GetType('Byte', JAVA_LANG_ID);
   JAVA_DOUBLE_TYPE         := TParserHelper.GetType('double', JAVA_LANG_ID);
   JAVA_DOUBLE_OBJECT_TYPE  := TParserHelper.GetType('Double', JAVA_LANG_ID);
   JAVA_CHAR_TYPE           := TParserHelper.GetType('char', JAVA_LANG_ID);
   JAVA_CHARACTER_TYPE      := TParserHelper.GetType('Character', JAVA_LANG_ID);
   JAVA_STRING_TYPE         := TParserHelper.GetType('String', JAVA_LANG_ID);
   JAVA_LIST_TYPE           := TParserHelper.GetType('List', JAVA_LANG_ID);
   JAVA_SET_TYPE            := TParserHelper.GetType('Set', JAVA_LANG_ID);
   JAVA_MAP_TYPE            := TParserHelper.GetType('Map', JAVA_LANG_ID);
   JAVA_BOOLEAN_TYPE        := TParserHelper.GetType('boolean', JAVA_LANG_ID);
   JAVA_BOOLEAN_OBJECT_TYPE := TParserHelper.GetType('Boolean', JAVA_LANG_ID);
   JAVA_DATE_TYPE           := TParserHelper.GetType('Date', JAVA_LANG_ID);
   JAVA_CALENDAR_TYPE       := TParserHelper.GetType('Calendar', JAVA_LANG_ID);
   JAVA_LOCAL_DATETIME_TYPE := TParserHelper.GetType('LocalDateTime', JAVA_LANG_ID);
   JAVA_LOCAL_DATE_TYPE     := TParserHelper.GetType('LocalDate', JAVA_LANG_ID);
   JAVA_LOCAL_TIME_TYPE     := TParserHelper.GetType('LocalTime', JAVA_LANG_ID);
   JAVA_INSTANT_TYPE        := TParserHelper.GetType('Instant', JAVA_LANG_ID);
   JAVA_DURATION_TYPE       := TParserHelper.GetType('Duration', JAVA_LANG_ID);
   JAVA_PERIOD_TYPE         := TParserHelper.GetType('Period', JAVA_LANG_ID);
   JAVA_DATETIME_FORMATTER  := TParserHelper.GetType('DateTimeFormatter', JAVA_LANG_ID);
   JAVA_BIGDECIMAL_TYPE     := TParserHelper.GetType('BigDecimal', JAVA_LANG_ID);
   JAVA_BIGINTEGER_TYPE     := TParserHelper.GetType('BigInteger', JAVA_LANG_ID);
   JAVA_PATTERN_TYPE        := TParserHelper.GetType('Pattern', JAVA_LANG_ID);

   JAVA_PRIMITIVE_TYPES := [JAVA_INT_TYPE, JAVA_LONG_TYPE, JAVA_FLOAT_TYPE, JAVA_DOUBLE_TYPE,
                            JAVA_CHAR_TYPE, JAVA_BOOLEAN_TYPE, JAVA_BYTE_TYPE];

   javaLang := GInfra.GetLangDefinition(JAVA_LANG_ID);
   if javaLang <> nil then
   begin
      javaLang.ExecuteBeforeGeneration :=  Java_ExecuteBeforeGeneration;
      javaLang.ExecuteAfterGeneration :=  Java_ExecuteAfterGeneration;
      javaLang.LibSectionGenerator := Java_LibSectionGenerator;
      javaLang.VarSectionGenerator := Java_VarSectionGenerator;
      javaLang.UserDataTypesSectionGenerator := Java_UserDataTypesSectionGenerator;
      javaLang.GetConstantType := Java_GetConstantType;
      javaLang.SetHLighterAttrs := Java_SetHLighterAttrs;
   end;

   FListImpl := TStringList.Create;
   FListImpl.AddPair('CopyOnWriteArrayList', 'java.util.concurrent');
   FListImpl.AddPair('ArrayList', 'java.util');
   FListImpl.AddPair('LinkedList', 'java.util');
   FListImpl.AddPair('Stack', 'java.util');
   FListImpl.AddPair('Vector', 'java.util');

   FMapImpl := TStringList.Create;
   FMapImpl.AddPair('ConcurrentHashMap', 'java.util.concurrent');
   FMapImpl.AddPair('ConcurrentSkipListMap', 'java.util.concurrent');
   FMapImpl.AddPair('EnumMap', 'java.util');
   FMapImpl.AddPair('WeakHashMap', 'java.util');
   FMapImpl.AddPair('LinkedHashMap', 'java.util');
   FMapImpl.AddPair('HashMap', 'java.util');
   FMapImpl.AddPair('Hashtable', 'java.util');
   FMapImpl.AddPair('Properties', 'java.util');
   FMapImpl.AddPair('TreeMap', 'java.util');

   FSetImpl := TStringList.Create;
   FSetImpl.AddPair('ConcurrentSkipListSet', 'java.util.concurrent');
   FSetImpl.AddPair('CopyOnWriteArraySet', 'java.util.concurrent');
   FSetImpl.AddPair('EnumSet', 'java.util');
   FSetImpl.AddPair('LinkedHashSet', 'java.util');
   FSetImpl.AddPair('HashSet', 'java.util');
   FSetImpl.AddPair('TreeSet', 'java.util');

   FDateFormatImpl := TStringList.Create;
   FDateFormatImpl.AddPair('SimpleDateFormat', 'java.text');

   FQueueImpl := TStringList.Create;
   FQueueImpl.AddPair('ArrayBlockingQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('ArrayDeque', 'java.util');
   FQueueImpl.AddPair('ConcurrentLinkedDeque', 'java.util.concurrent');
   FQueueImpl.AddPair('ConcurrentLinkedQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('DelayQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('LinkedBlockingDeque', 'java.util.concurrent');
   FQueueImpl.AddPair('LinkedBlockingQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('LinkedList', 'java.util');
   FQueueImpl.AddPair('LinkedTransferQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('PriorityBlockingQueue', 'java.util.concurrent');
   FQueueImpl.AddPair('PriorityQueue', 'java.util');
   FQueueImpl.AddPair('SynchronousQueue', 'java.util.concurrent');

   FDequeImpl := TStringList.Create;
   FDequeImpl.AddPair('ArrayDeque', 'java.util');
   FDequeImpl.AddPair('ConcurrentLinkedDeque', 'java.util.concurrent');
   FDequeImpl.AddPair('LinkedBlockingDeque', 'java.util.concurrent');
   FDequeImpl.AddPair('LinkedList', 'java.util');

   FReaderImpl := TStringList.Create;
   FReaderImpl.AddPair('BufferedReader', 'java.io');
   FReaderImpl.AddPair('CharArrayReader', 'java.io');
   FReaderImpl.AddPair('InputStreamReader', 'java.io');
   FReaderImpl.AddPair('PipedReader', 'java.io');
   FReaderImpl.AddPair('StringReader', 'java.io');

   FWriterImpl := TStringList.Create;
   FWriterImpl.AddPair('BufferedWriter', 'java.io');
   FWriterImpl.AddPair('CharArrayWriter', 'java.io');
   FWriterImpl.AddPair('OutputStreamWriter', 'java.io');
   FWriterImpl.AddPair('PipedWriter', 'java.io');
   FWriterImpl.AddPair('PrintWriter', 'java.io');
   FWriterImpl.AddPair('StringWriter', 'java.io');

   FInStreamImpl := TStringList.Create;
   FInStreamImpl.AddPair('AudioInputStream', 'javax.sound.sampled');
   FInStreamImpl.AddPair('ByteArrayInputStream', 'java.io');
   FInStreamImpl.AddPair('FileInputStream', 'java.io');
   FInStreamImpl.AddPair('FilterInputStream', 'java.io');
   FInStreamImpl.AddPair('ObjectInputStream', 'java.io');
   FInStreamImpl.AddPair('PipedInputStream', 'java.io');
   FInStreamImpl.AddPair('SequenceInputStream', 'java.io');
   FInStreamImpl.AddPair('BufferedInputStream', 'java.io');
   FInStreamImpl.AddPair('CheckedInputStream', 'java.util.zip');
   FInStreamImpl.AddPair('CipherInputStream', 'javax.crypto');
   FInStreamImpl.AddPair('DataInputStream', 'java.io');
   FInStreamImpl.AddPair('DeflaterInputStream', 'java.util.zip');
   FInStreamImpl.AddPair('InflaterInputStream', 'java.util.zip');
   FInStreamImpl.AddPair('DigestInputStream', 'java.security');
   FInStreamImpl.AddPair('PushbackInputStream', 'java.io');

   FOutStreamImpl := TStringList.Create;
   FOutStreamImpl.AddPair('ByteArrayOutputStream', 'java.io');
   FOutStreamImpl.AddPair('FileOutputStream', 'java.io');
   FOutStreamImpl.AddPair('FilterOutputStream', 'java.io');
   FOutStreamImpl.AddPair('ObjectOutputStream', 'java.io');
   FOutStreamImpl.AddPair('PipedOutputStream', 'java.io');
   FOutStreamImpl.AddPair('BufferedOutputStream', 'java.io');
   FOutStreamImpl.AddPair('CipherOutputStream', 'javax.crypto');
   FOutStreamImpl.AddPair('DataOutputStream', 'java.io');
   FOutStreamImpl.AddPair('InflaterOutputStream', 'java.util.zip');
   FOutStreamImpl.AddPair('DeflaterOutputStream', 'java.util.zip');
   FOutStreamImpl.AddPair('DigestOutputStream', 'java.security');
   FOutStreamImpl.AddPair('PrintStream', 'java.io');

   FTemporalImpl := TStringList.Create;
   FTemporalImpl.AddPair('Instant', 'java.time');
   FTemporalImpl.AddPair('LocalDateTime', 'java.time');
   FTemporalImpl.AddPair('LocalDate', 'java.time');
   FTemporalImpl.AddPair('LocalTime', 'java.time');
   FTemporalImpl.AddPair('OffsetDateTime', 'java.time');
   FTemporalImpl.AddPair('OffsetTime', 'java.time');
   FTemporalImpl.AddPair('ZonedDateTime', 'java.time');

   FNumberImpl := TStringList.Create;
   FNumberImpl.AddPair('AtomicInteger', 'java.util.concurrent.atomic');
   FNumberImpl.AddPair('AtomicLong', 'java.util.concurrent.atomic');
   FNumberImpl.AddPair('BigDecimal', 'java.math');
   FNumberImpl.AddPair('BigInteger', 'java.math');
   FNumberImpl.AddPair('DoubleAccumulator', 'java.util.concurrent.atomic');
   FNumberImpl.AddPair('DoubleAdder', 'java.util.concurrent.atomic');
   FNumberImpl.AddPair('LongAccumulator', 'java.util.concurrent.atomic');
   FNumberImpl.AddPair('LongAdder', 'java.util.concurrent.atomic');

finalization

   FListImpl.Free;
   FMapImpl.Free;
   FSetImpl.Free;
   FDateFormatImpl.Free;
   FQueueImpl.Free;
   FDequeImpl.Free;
   FReaderImpl.Free;
   FWriterImpl.Free;
   FInStreamImpl.Free;
   FOutStreamImpl.Free;
   FTemporalImpl.Free;
   FNumberImpl.Free;
   JAVA_PRIMITIVE_TYPES := nil;

end.
