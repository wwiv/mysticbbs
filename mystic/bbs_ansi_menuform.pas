Unit bbs_Ansi_MenuForm;

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  bbs_ansi_MenuInput;

Const
  FormMaxItems = 50;

Const
  YesNoStr : Array[False..True] of String[03] = ('No', 'Yes');

Type
  FormItemType = (
    ItemNone,
    ItemString,
    ItemBoolean,
    ItemByte,
    ItemWord,
    ItemLong,
    ItemToggle,
    ItemPath,
    ItemChar,
    ItemAttr,
    ItemFlags,
    ItemDate,
    ItemPass,
    ItemPipe,
    ItemCaps,
    ItemBits
  );

  FormItemPTR = ^FormItemRec;
  FormItemRec = Record
    HotKey    : Char;
    Desc      : String[60];
    Help      : String[120];
    DescX     : Byte;
    DescY     : Byte;
    DescSize  : Byte;
    FieldX    : Byte;
    FieldY    : Byte;
    FieldSize : Byte;
    ItemType  : FormItemType;
    MaxSize   : Byte;
    MinNum    : LongInt;
    MaxNum    : LongInt;
    S         : ^String;
    O         : ^Boolean;
    B         : ^Byte;
    W         : ^Word;
    L         : ^LongInt;
    C         : ^Char;
    F         : ^TMenuFormFlagsRec;
    Toggle    :  String[68];
  End;

  TAnsiMenuFormHelpProc = Procedure (Item: FormItemRec);
  TAnsiMenuFormDrawProc = Procedure (Hi: Boolean);  // not functional
  TAnsiMenuFormDataProc = Procedure;                // not functional

  TAnsiMenuForm = Class
  Private
    Function  GetColorAttr    (C: Byte) : Byte;
    Function  DrawAccessFlags (Var Flags: TMenuFormFlagsRec) : String;
    Procedure EditAccessFlags (Var Flags: TMenuFormFlagsRec);
    Procedure AddBasic        (HK: Char; D: String; X, Y, FX, FY, DS, FS, MS: Byte; I: FormItemType; P: Pointer; H: String);
    Procedure BarON;
    Procedure BarOFF          (RecPos: Word);
    Procedure FieldWrite      (RecPos : Word);
    Procedure EditOption;
  Public
    Input        : TAnsiMenuInput;
    HelpProc     : TAnsiMenuFormHelpProc;
    DrawProc     : TAnsiMenuFormDrawProc;
    DataProc     : TAnsiMenuFormDataProc;
    ItemData     : Array[1..FormMaxItems] of FormItemPTR;
    Items        : Word;
    ItemPos      : Word;
    Changed      : Boolean;
    ExitOnFirst  : Boolean;
    ExitOnLast   : Boolean;
    WasHiExit    : Boolean;
    WasFirstExit : Boolean;
    WasLastExit  : Boolean;
    LoExitChars  : String[30];
    HiExitChars  : String[30];
    HelpX        : Byte;
    HelpY        : Byte;
    HelpSize     : Byte;
    HelpColor    : Byte;
    cLo          : Byte;
    cHi          : Byte;
    cData        : Byte;
    cLoKey       : Byte;
    cHiKey       : Byte;
    cField1      : Byte;
    cField2      : Byte;

    Constructor Create;
    Destructor  Destroy; Override;

    Procedure   Clear;
    Procedure   AddNone (HK: Char; D: String; X, Y, DS: Byte; H: String);
    Procedure   AddStr  (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
    Procedure   AddPipe (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
    Procedure   AddPath (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
    Procedure   AddPass (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
    Procedure   AddBol  (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; P: Pointer; H: String);
    Procedure   AddByte (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: Byte; P: Pointer; H: String);
    Procedure   AddWord (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: Word; P: Pointer; H: String);
    Procedure   AddLong (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: LongInt; P: Pointer; H: String);
    Procedure   AddTog  (HK: Char; D: String; X, Y, FX, FY, DS, FS, MN, MX: Byte; TG: String; P: Pointer; H: String);
    Procedure   AddChar (HK: Char; D: String; X, Y, FX, FY, DS, MN, MX: Byte; P: Pointer; H: String);
    Procedure   AddAttr (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
    Procedure   AddFlag (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
    Procedure   AddDate (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
    Procedure   AddCaps (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
    Procedure   AddBits (HK: Char; D: String; X, Y, FX, FY, DS: Byte; Flag: LongInt; P: Pointer; H: String);
    Function    Execute : Char;
  End;

Implementation

Uses
  m_FileIO,
  m_Strings,
  bbs_Core,
  bbs_Ansi_MenuBox;

Constructor TAnsiMenuForm.Create;
Begin
  Inherited Create;

  Input        := TAnsiMenuInput.Create;
  HelpProc     := NIL;
  DrawProc     := NIL;
  DataProc     := NIL;
  cLo          := 0  + 7 * 16;
  cHi          := 11 + 1 * 16;
  cData        := 1  + 7 * 16;
  cLoKey       := 15 + 7 * 16;
  cHiKey       := 15 + 1 * 16;
  cField1      := 15 + 1 * 16;
  cField2      := 7  + 1 * 16;
  HelpX        := 5;
  HelpY        := 24;
  HelpColor    := 15;
  HelpSize     := 75;
  WasHiExit    := False;
  WasFirstExit := False;
  ExitOnFirst  := False;
  WasLastExit  := False;
  ExitOnLast   := False;

  Clear;
End;

Destructor TAnsiMenuForm.Destroy;
Begin
  Clear;

  Input.Free;

  Inherited Destroy;
End;

Procedure TAnsiMenuForm.Clear;
Var
  Count : Word;
Begin
  For Count := 1 to Items Do
    Dispose(ItemData[Count]);

  Items   := 0;
  ItemPos := 1;
  Changed := False;
End;

Function TAnsiMenuForm.DrawAccessFlags (Var Flags: TMenuFormFlagsRec) : String;
Var
  Str : String;
  Ch  : Char;
Begin
  Str := '';

  For Ch := 'A' to 'Z' Do
    If Ord(Ch) - 64 in Flags Then Str := Str + Ch Else Str := Str + '-';

  Result := Str;
End;

Procedure TAnsiMenuForm.EditAccessFlags (Var Flags: TMenuFormFlagsRec);
Var
  Box : TAnsiMenuBox;
  Ch  : Char;
Begin
  Box := TAnsiMenuBox.Create;

  Box.Open (25, 11, 56, 14);

  WriteXY (28, 13, 113, 'A-Z to toggle, ESC to Quit');

  Repeat
    WriteXY (28, 12, 112, DrawAccessFlags(Flags));

    Ch := UpCase(Session.io.GetKey);

    Case Ch of
      #27 : Break;
      'A'..
      'Z' : Begin
              If Ord(Ch) - 64 in Flags Then
                Flags := Flags - [Ord(Ch) - 64]
              Else
                Flags := Flags + [Ord(Ch) - 64];

              Changed := True;
            End;
    End;
  Until False;

  Box.Close;
  Box.Free;
End;

Function TAnsiMenuForm.GetColorAttr (C: Byte) : Byte;
Var
  FG  : Byte;
  BG  : Byte;
  Box : TAnsiMenuBox;
  A   : Byte;
  B   : Byte;
  Ch  : Char;
Begin
  FG := C AND $F;
  BG := (C SHR 4) AND 7;

  Box := TAnsiMenuBox.Create;

  Box.Header  := ' Select color ';

  Box.Open (30, 7, 51, 18);

  Repeat
    For A := 0 to 9 Do
      WriteXY (31, 8 + A, Box.BoxAttr, '                    ');

    For A := 0 to 7 Do
      For B := 0 to 15 Do
        WriteXY (33 + B, 9 + A, B + A * 16, '�');

    WriteXY (37, 18, FG + BG * 16, ' Sample ');

    WriteXYPipe (31 + FG,  8 + BG, 15, 5, '�|23���|08�');
    WriteXYPipe (31 + FG,  9 + BG, 15, 5, '�|23   |08�');
    WriteXYPipe (31 + FG, 10 + BG, 15, 5, '|23�|08���|08�');
    WriteXY (33 + FG,  9 + BG, FG + BG * 16, '�');

    Ch := Session.io.GetKey;

    If Session.io.IsArrow Then Begin
      Case Ch of
        #72 : If BG > 0 Then Dec(BG);
        #75 : If FG > 0 Then Dec(FG);
        #77 : If FG < 15 Then Inc(FG);
        #80 : If BG < 7 Then Inc(BG);
      End;
    End Else
      Case Ch of
        #13 : Begin
                GetColorAttr := FG + BG * 16;
                Break;
              End;
        #27 : Begin
                GetColorAttr := C;
                Break;
              End;
      End;
  Until False;

  Box.Close;
  Box.Free;
End;

Procedure TAnsiMenuForm.AddBasic (HK: Char; D: String; X, Y, FX, FY, DS, FS, MS: Byte; I: FormItemType; P: Pointer; H: String);
Begin
  Inc (Items);

  New (ItemData[Items]);

  With ItemData[Items]^ Do Begin
    HotKey    := HK;
    Desc      := D;
    DescX     := X;
    DescY     := Y;
    DescSize  := DS;
    Help      := H;
    ItemType  := I;
    FieldSize := FS;
    MaxSize   := MS;
    FieldX    := FX;
    FieldY    := FY;

    Case ItemType of
      ItemCaps,
      ItemPipe,
      ItemPass,
      ItemDate,
      ItemPath,
      ItemString  : S := P;
      ItemBoolean : O := P;
      ItemAttr,
      ItemToggle,
      ItemByte    : B := P;
      ItemWord    : W := P;
      ItemBits,
      ItemLong    : L := P;
      ItemChar    : C := P;
      ItemFlags   : F := P;
    End;
  End;
End;

Procedure TAnsiMenuForm.AddNone (HK: Char; D: String; X, Y, DS: Byte; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, 0, 0, DS, 0, 0, ItemNone, NIL, H);
End;

Procedure TAnsiMenuForm.AddChar (HK: Char; D: String; X, Y, FX, FY, DS, MN, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, 1, 1, ItemChar, P, H);

  ItemData[Items]^.MinNum := MN;
  ItemData[Items]^.MaxNum := MX;
End;

Procedure TAnsiMenuForm.AddStr (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemString, P, H);
End;

Procedure TAnsiMenuForm.AddPipe (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemPipe, P, H);
End;

Procedure TAnsiMenuForm.AddCaps (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemCaps, P, H);
End;

Procedure TAnsiMenuForm.AddPass (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemPass, P, H);
End;

Procedure TAnsiMenuForm.AddPath (HK: Char; D: String; X, Y, FX, FY, DS, FS, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemPath, P, H);
End;

Procedure TAnsiMenuForm.AddBol  (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, 3, ItemBoolean, P, H);
End;

Procedure TAnsiMenuForm.AddBits (HK: Char; D: String; X, Y, FX, FY, DS: Byte; Flag: LongInt; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, 3, 3, ItemBits, P, H);

  ItemData[Items]^.MaxNum := Flag;
End;

Procedure TAnsiMenuForm.AddByte (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, Length(strI2S(MX)), ItemByte, P, H);

  ItemData[Items]^.MinNum := MN;
  ItemData[Items]^.MaxNum := MX;
End;

Procedure TAnsiMenuForm.AddWord (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: Word; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, Length(strI2S(MX)), ItemWord, P, H);

  ItemData[Items]^.MinNum := MN;
  ItemData[Items]^.MaxNum := MX;
End;

Procedure TAnsiMenuForm.AddLong (HK: Char; D: String; X, Y, FX, FY, DS, FS: Byte; MN, MX: LongInt; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, Length(strI2S(MX)), ItemLong, P, H);

  ItemData[Items]^.MinNum := MN;
  ItemData[Items]^.MaxNum := MX;
End;

Procedure TAnsiMenuForm.AddTog (HK: Char; D: String; X, Y, FX, FY, DS, FS, MN, MX: Byte; TG: String; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, FS, MX, ItemToggle, P, H);

  ItemData[Items]^.Toggle := TG;
  ItemData[Items]^.MinNum := MN;
End;

Procedure TAnsiMenuForm.AddAttr (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, 8, 8, ItemAttr, P, H);
End;

Procedure TAnsiMenuForm.AddFlag (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, 26, 26, ItemFlags, P, H);
End;

Procedure TAnsiMenuForm.AddDate (HK: Char; D: String; X, Y, FX, FY, DS: Byte; P: Pointer; H: String);
Begin
  If Items = FormMaxItems Then Exit;

  AddBasic (HK, D, X, Y, FX, FY, DS, 8, 8, ItemDate, P, H);
End;

Procedure TAnsiMenuForm.BarON;
Var
  A : Byte;
Begin
  If ItemPos = 0 Then Exit;

  WriteXY (ItemData[ItemPos]^.DescX, ItemData[ItemPos]^.DescY, cHi, strPadR(ItemData[ItemPos]^.Desc, ItemData[ItemPos]^.DescSize, ' '));

  A := Pos(ItemData[ItemPos]^.HotKey, strUpper(ItemData[ItemPos]^.Desc));

  If A > 0 Then
    WriteXY (ItemData[ItemPos]^.DescX + A - 1, ItemData[ItemPos]^.DescY, cHiKey, ItemData[ItemPos]^.Desc[A]);

  If HelpSize > 0 Then
    If Assigned(HelpProc) Then
      HelpProc(ItemData[ItemPos]^)
    Else
      WriteXYPipe (HelpX, HelpY, HelpColor, HelpSize, ItemData[ItemPos]^.Help);
End;

Procedure TAnsiMenuForm.BarOFF (RecPos: Word);
Var
  A : Byte;
Begin
  If RecPos = 0 Then Exit;

  With ItemData[RecPos]^ Do Begin
    WriteXY (DescX, DescY, cLo, strPadR(Desc, DescSize, ' '));

    A := Pos(HotKey, strUpper(Desc));

    If A > 0 Then
      WriteXY (DescX + A - 1, DescY, cLoKey, Desc[A]);
  End;
End;

Procedure TAnsiMenuForm.FieldWrite (RecPos : Word);
Begin
  // This could be changed to case itemtype and save display into string
  // variable.  Then we would only require a single Screen.WriteXY function.
  // It would be a tiny bit slower (obviously, not really noticable) but
  // would reduce code size.

  With ItemData[RecPos]^ Do Begin
    Case ItemType of
      ItemPass    : WriteXY (FieldX, FieldY, cData, strPadR(strRep('*', Length(S^)), FieldSize, ' '));
      ItemCaps,
      ItemDate,
      ItemPath,
      ItemString  : WriteXY (FieldX, FieldY, cData, strPadR(S^, FieldSize, ' '));
      ItemBoolean : WriteXY (FieldX, FieldY, cData, strPadR(YesNoStr[O^], FieldSize, ' '));
      ItemByte    : WriteXY (FieldX, FieldY, cData, strPadR(strI2S(B^), FieldSize, ' '));
      ItemWord    : WriteXY (FieldX, FieldY, cData, strPadR(strI2S(W^), FieldSize, ' '));
      ItemLong    : WriteXY (FieldX, FieldY, cData, strPadR(strI2S(L^), FieldSize, ' '));
      ItemToggle  : WriteXY (FieldX, FieldY, cData, StrPadR(strWordGet(B^ + 1 - MinNum, Toggle, ' '), FieldSize, ' '));
      ItemChar    : WriteXY (FieldX, FieldY, cData, C^);
      ItemAttr    : WriteXY (FieldX, FieldY, B^, ' Sample ');
      ItemFlags   : WriteXY (FieldX, FieldY, cData, DrawAccessFlags(F^));
      ItemPipe    : WriteXYPipe (FieldX, FieldY, 7, FieldSize, S^);
      ItemBits    : WriteXY (FieldX, FieldY, cData, strPadR(YesNoStr[L^ AND MaxNum <> 0], FieldSize, ' '));
    End;
  End;
End;

Procedure TAnsiMenuForm.EditOption;
Var
  TempStr  : String;
  TempByte : Byte;
  TempLong : LongInt;
Begin
  With ItemData[ItemPos]^ Do
    Case ItemType of
      ItemPass,
      ItemCaps    : S^ := Input.GetStr(FieldX, FieldY, FieldSize, MaxSize, 2, S^);
      ItemDate    : S^ := Input.GetStr(FieldX, FieldY, FieldSize, MaxSize, 3, S^);
      ItemPipe,
      ItemString  : S^ := Input.GetStr(FieldX, FieldY, FieldSize, MaxSize, 1, S^);
      ItemBoolean : Begin
                      O^      := Not O^;
                      Changed := True;
                    End;
      ItemByte    : B^ := Byte(Input.GetNum(FieldX, FieldY, FieldSize, MaxSize, MinNum, MaxNum, B^));
      ItemWord    : W^ := Word(Input.GetNum(FieldX, FieldY, FieldSize, MaxSize, MinNum, MaxNum, W^));
      ItemLong    : L^ := LongInt(Input.GetNum(FieldX, FieldY, FieldSize, MaxSize, MinNum, MaxNum, L^));
      ItemToggle  : Begin
                      If B^ < MaxSize Then Inc(B^) Else B^ := MinNum;
                      Changed := True;
                    End;
      ItemPath    : S^ := DirSlash(Input.GetStr(FieldX, FieldY, FieldSize, MaxSize, 1, S^));
      ItemChar    : Begin
                      TempStr := Input.GetStr(FieldX, FieldY, FieldSize, MaxSize, 1, C^);
                      Changed := TempStr[1] <> C^;
                      C^      := TempStr[1];
                    End;
      ItemAttr    : Begin
                      TempByte := GetColorAttr(B^);
                      Changed  := TempByte <> B^;
                      B^       := TempByte;
                    End;
      ItemFlags   : EditAccessFlags(F^);
      ItemBits    : Begin
                      Changed  := True;
                      TempLong := L^;
                      TempLong := TempLong XOR MaxNum;
                      L^       := TempLong;
                    End;
    End;

  FieldWrite (ItemPos);

  Changed := Changed or Input.Changed;
End;

Function TAnsiMenuForm.Execute : Char;
Var
  Count   : Word;
  Ch      : Char;
  NewPos  : Word;
  NewXPos : Word;
Begin
  Session.io.AllowArrow := True;

  WasHiExit := False;

  Input.Attr     := cField1;
  Input.FillAttr := cField2;

  For Count := 1 to Items Do Begin
    BarOFF(Count);
    FieldWrite(Count);
  End;

  BarON;

  Repeat
    Changed := Changed or Input.Changed;

    Ch := UpCase(Session.io.GetKey);

    If Session.io.IsArrow Then Begin
      If Pos(Ch, HiExitChars) > 0 Then Begin
        WasHiExit := True;
        Result    := Ch;
        Break;
      End;

      Case Ch of
        #72 : If ItemPos > 1 Then Begin
                BarOFF(ItemPos);
                Dec(ItemPos);
                BarON;
              End Else
              If ExitOnFirst Then Begin
                WasFirstExit := True;
                Result := Ch;
                Break;
              End;
        #75 : Begin
                NewPos  := 0;
                NewXPos := 0;

                For Count := 1 to Items Do
                  If (ItemData[Count]^.DescY = ItemData[ItemPos]^.DescY) and
                     (ItemData[Count]^.DescX < ItemData[ItemPos]^.DescX) and
                     (ItemData[Count]^.DescX > NewXPos) Then Begin
                        NewXPos := ItemData[Count]^.DescX;
                        NewPos  := Count;
                      End;

                If NewPos > 0 Then Begin
                  BarOFF(ItemPos);
                  ItemPos := NewPos;
                  BarON;
                End;
              End;
        #77 : Begin
                NewPos  := 0;
                NewXPos := 80;

                For Count := 1 to Items Do
                  If (ItemData[Count]^.DescY = ItemData[ItemPos]^.DescY) and
                     (ItemData[Count]^.DescX > ItemData[ItemPos]^.DescX) and
                     (ItemData[Count]^.DescX < NewXPos) Then Begin
                        NewXPos := ItemData[Count]^.DescX;
                        NewPos  := Count;
                  End;

                If NewPos > 0 Then Begin
                  BarOFF(ItemPos);
                  ItemPos := NewPos;
                  BarON;
                End;
              End;
        #80 : If ItemPos < Items Then Begin
                BarOFF(ItemPos);
                Inc(ItemPos);
                BarON;
              End Else
              If ExitOnLast Then Begin
                WasLastExit := True;
                Result      := Ch;
                Break;
              End;
      End;
    End Else Begin
      Case Ch of
        #13 : If ItemPos > 0 Then
                If ItemData[ItemPos]^.ItemType = ItemNone Then Begin
                  Result := ItemData[ItemPos]^.HotKey;
                  Break;
                End Else
                  EditOption;
        #27 : Begin
                Result := #27;
                Break;
              End;
      Else
        If Pos(Ch, LoExitChars) > 0 Then Begin
          Result := Ch;
          Break;
        End;
      End;

      For Count := 1 to Items Do
        If ItemData[Count]^.HotKey = Ch Then Begin
          BarOFF(ItemPos);
          ItemPos := Count;
          BarON;

          If ItemData[ItemPos]^.ItemType = ItemNone Then Begin
            Execute := ItemData[ItemPos]^.HotKey;
            BarOFF(ItemPos);
            Exit;
          End Else
            EditOption;
        End;
    End;
  Until False;

  BarOFF(ItemPos);
End;

End.