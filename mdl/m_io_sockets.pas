Unit m_io_Sockets;

{$I M_OPS.PAS}

Interface

Uses
  {$IFDEF OS2}
    WinSock,
  {$ENDIF}
  {$IFDEF WIN32}
    Windows,
    Winsock2,
  {$ENDIF}
  {$IFDEF UNIX}
    BaseUnix,
    cNetDB,
  {$ENDIF}
  Sockets,
  m_DateTime,
  m_Strings,
  m_io_Base;

Type
  TIOSocket = Class(TIOBase)
    FSocketHandle  : LongInt;
    FPort          : LongInt;
    FPeerName      : String;
    FPeerIP        : String;
    FHostIP        : String;
    FInBuf         : TIOBuffer;
    FInBufPos      : LongInt;
    FInBufEnd      : LongInt;
    FOutBuf        : TIOBuffer;
    FOutBufPos     : LongInt;
    FTelnetState   : Byte;
    FTelnetReply   : Array[1..14] of Char;
    FTelnetCmd     : Char;
    FTelnetSubCmd  : Char;
    FTelnetLen     : Byte;
    FTelnetEcho    : Boolean;
    FTelnetSubData : String;
    FTelnetClient  : Boolean;
    FTelnetServer  : Boolean;
    FDisconnect    : Boolean;

    Constructor Create;         Override;
    Destructor  Destroy;        Override;
    Procedure   Disconnect;
    Function    DataWaiting     : Boolean; Override;
    Function    WriteBuf        (Var Buf; Len: LongInt) : LongInt; Override;
    Procedure   BufFlush;       Override;
    Procedure   BufWriteChar    (Ch: Char); Override;
    Procedure   BufWriteStr     (Str: String); Override;
    Function    WriteLine       (Str: String) : LongInt; Override;
    Function    WriteStr        (Str: String) : LongInt; Override;
    Function    WriteFile       (Str: String) : Boolean;
    Function    WriteBufEscaped (Var Buf: TIOBuffer; Var Len: LongInt) : LongInt;
    Procedure   TelnetInBuffer  (Var Buf: TIOBuffer; Var Len: LongInt);
    Function    ReadBuf         (Var Buf; Len: LongInt) : LongInt; Override;
    Function    ReadLine        (Var Str: String) : LongInt; Override;
    Function    SetBlocking     (Block: Boolean): LongInt;
    Function    WaitForData     (TimeOut: LongInt) : LongInt; Override;
    Function    Connect         (Address: String; Port: Word) : Boolean;
    Function    ResolveAddress  (Host: String) : LongInt;
    Procedure   WaitInit        (Port: Word);
    Function    WaitConnection  : TIOSocket;

    Function    PeekChar        (Num: Byte) : Char; Override;
    Function    ReadChar        : Char; Override;
    Function    WriteChar       (Ch: Char) : LongInt;

    Property SocketHandle : LongInt READ FSocketHandle WRITE FSocketHandle;
    Property PeerPort     : LongInt READ FPort         WRITE FPort;
    Property PeerName     : String  READ FPeerName     WRITE FPeerName;
    Property PeerIP       : String  READ FPeerIP       WRITE FPeerIP;
    Property HostIP       : String  READ FHostIP       WRITE FHostIP;
  End;

Implementation

{.$DEFINE SOCKETLOG}

{ TELNET NEGOTIATION CONSTANTS }

Const
  Telnet_IAC      = #255;
  Telnet_DONT     = #254;
  Telnet_DO       = #253;
  Telnet_WONT     = #252;
  Telnet_WILL     = #251;
  Telnet_SB       = #250;
  Telnet_BINARY   = #000;
  Telnet_ECHO     = #001;
  Telnet_SE       = #240;
  Telnet_TERM     = #24;
  Telnet_SGA      = #003;
  Telnet_WINSIZE  = #31;
  Telnet_SPEED    = #32;
  Telnet_FLOW     = #33;
  Telnet_LINEMODE = #34;

  FPSENDOPT     = 0;
  FPRECVOPT     = 0;

{$IFDEF SOCKETLOG}
Function sCmd (C: Char) : String;
Begin
  Case C of
    Telnet_IAC      : Result := ' IAC ';
    Telnet_DONT     : Result := ' DONT ';
    Telnet_DO       : Result := ' DO ';
    Telnet_WONT     : Result := ' WONT ';
    Telnet_WILL     : Result := ' WILL ';
    Telnet_SB       : Result := ' SB ';
    Telnet_BINARY   : Result := ' BINARY ';
    Telnet_ECHO     : Result := ' ECHO ';
    Telnet_SE       : Result := ' SE ';
    Telnet_TERM     : Result := ' TERM ';
    Telnet_SGA      : Result := ' SGA ';
    Telnet_WINSIZE  : Result := ' WINSIZE ';
    Telnet_SPEED    : Result := ' SPEED ';
    Telnet_FLOW     : Result := ' FLOW ';
    Telnet_LINEMODE : Result := ' LINEMODE ';
  Else
    Result := ' UNKNOWN ' + strI2S(Ord(C)) + ' ';
  End;
End;

Procedure sLog (S: String);
Var
  T : Text;
Begin
  Assign (T, 'socket.log');
  Append (T);

  If IoResult <> 0 Then ReWrite(T);

  WriteLn(T, S);

  Close(T);
End;
{$ENDIF}

Constructor TIOSocket.Create;
Begin
  Inherited Create;

  FSocketHandle := -1;
  FPort         := 0;
  FPeerName     := 'Unknown';
  FPeerIP       := FPeerName;
  FInBufPos     := 0;
  FInBufEnd     := 0;
  FOutBufPos    := 0;
  FTelnetState  := 0;
  FTelnetEcho   := True;
  FTelnetClient := False;
  FTelnetServer := False;
  FDisconnect   := True;
  FHostIP       := '';
End;

Destructor TIOSocket.Destroy;
Begin
  If FDisconnect Then Disconnect;

  Inherited Destroy;
End;

Procedure TIOSocket.Disconnect;
Begin
  If FSocketHandle <> -1 Then Begin
    fpShutdown(FSocketHandle, 2);
    CloseSocket(FSocketHandle);

    FSocketHandle := -1;
  End;
End;

Function TIOSocket.DataWaiting : Boolean;
Begin
  Result := (FInBufPos < FInBufEnd) or (WaitForData(0) > 0);
End;

Function TIOSocket.WriteBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Buf, Len, FPSENDOPT);

  While (Result = -1) and (SocketError = ESOCKEWOULDBLOCK) Do Begin

    {$IFDEF SOCKETLOG} sLog('WriteBuf Blocking'); {$ENDIF}

    WaitMS(10);

    Result := fpSend(FSocketHandle, @Buf, Len, FPSENDOPT);
  End;
End;

Procedure TIOSocket.BufFlush;
Begin
  If FOutBufPos > 0 Then Begin
    If FTelnetClient or FTelnetServer Then
      WriteBufEscaped(FOutBuf, FOutBufPos)
    Else
      WriteBuf(FOutBuf, FOutBufPos);

    FOutBufPos := 0;
  End;
End;

Procedure TIOSocket.BufWriteChar (Ch: Char);
Begin
  FOutBuf[FOutBufPos] := Ch;

  Inc(FOutBufPos);

  If FOutBufPos > TIOBufferSize Then
    BufFlush;
End;

Procedure TIOSocket.BufWriteStr (Str: String);
Var
  Count : LongInt;
Begin
  For Count := 1 to Length(Str) Do
    BufWriteChar(Str[Count]);
End;

Function TIOSocket.WriteLine (Str: String) : LongInt;
Begin
  Result := WriteStr(Str + #13#10);
End;

Function TIOSocket.WriteChar (Ch: Char) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Ch, 1, FPSENDOPT);
End;

Function TIOSocket.WriteStr (Str: String) : LongInt;
Begin
  Result := fpSend(FSocketHandle, @Str[1], Length(Str), FPSENDOPT);
End;

Function TIOSocket.WriteFile (Str: String) : Boolean;
Var
  Buf  : Array[1..4096] of Char;
  Size : LongInt;
  F    : File;
Begin
  Result := False;

  FileMode := 66;

  Assign (F, Str);
  Reset  (F, 1);

  If IoResult <> 0 Then Exit;

  Repeat
    BlockRead (F, Buf, SizeOf(Buf), Size);

    If Size = 0 Then Break;

    If Buf[Size] = #26 Then Dec(Size);

    WriteBuf (Buf, Size);
  Until Size <> SizeOf(Buf);

  Result := True;
End;

Function TIOSocket.WriteBufEscaped (Var Buf: TIOBuffer; Var Len: LongInt) : LongInt;
Var
  Temp    : Array[0..TIOBufferSize * 2] of Char;
  TempPos : LongInt;
  Count   : LongInt;
Begin
  TempPos := 0;

  For Count := 0 to Len Do
    If Buf[Count] = TELNET_IAC Then Begin
      Temp[TempPos] := TELNET_IAC;
      Inc (TempPos);
      Temp[TempPos] := TELNET_IAC;
      Inc (TempPos);
    End Else Begin
      Temp[TempPos] := Buf[Count];
      Inc (TempPos);
    End;

  Dec(TempPos);

  Result := fpSend(FSocketHandle, @Temp, TempPos, FPSENDOPT);

  While (Result = -1) and (SocketError = ESOCKEWOULDBLOCK) Do Begin
    {$IFDEF SOCKETLOG} sLog('WriteBuf Blocking'); {$ENDIF}

    WaitMS(10);

    Result := fpSend(FSocketHandle, @Temp, TempPos, FPSENDOPT);
  End;
End;

Procedure TIOSocket.TelnetInBuffer (Var Buf: TIOBuffer; Var Len: LongInt);

  Procedure SendCommand (YesNo, CmdType: Char);
  Var
    Reply : String[3];
  Begin
    Reply[1] := Telnet_IAC;
    Reply[2] := Char(YesNo); {DO/DONT, WILL/WONT}
    Reply[3] := CmdType;

    fpSend (FSocketHandle, @Reply[1], 3, FPSENDOPT);

    {$IFDEF SOCKETLOG} sLog('Sending cmd: ' + sCmd(YesNo) + sCmd(CmdType)); sLog(''); {$ENDIF}
  End;

  Procedure SendData (CmdType: Char; Data: String);
  Var
    Reply   : String;
    DataLen : Byte;
  Begin
    DataLen  := Length(Data);
    Reply[1] := Telnet_IAC;
    Reply[2] := Telnet_SB;
    Reply[3] := CmdType;
    Reply[4] := #0;

    Move (Data[1], Reply[5], DataLen);

    Reply[5 + DataLen] := #0;
    Reply[6 + DataLen] := Telnet_IAC;
    Reply[7 + DataLen] := Telnet_SE;

    fpSend (FSocketHandle, @Reply[1], 7 + DataLen, FPSENDOPT);

    {$IFDEF SOCKETLOG} sLog('Sending data: ' + sCmd(CmdType) + Data); {$ENDIF}
  End;

Var
  Count     : LongInt;
  TempPos   : LongInt;
  Temp      : TIOBuffer;
  ReplyGood : Char;
  ReplyBad  : Char;
Begin
  TempPos := 0;

  For Count := 0 to Len - 1 Do Begin
    {$IFDEF SOCKETLOG} sLog('State loop: ' + strI2S(FTelnetState) + ' Cmd: ' + sCmd(Buf[Count]));{$ENDIF}

    Case FTelnetState of
      1 : If Buf[Count] = Telnet_IAC Then Begin
            FTelnetState := 0;
            Temp[TempPos] := Telnet_IAC;
            Inc (TempPos);
          End Else Begin
            Inc (FTelnetState);
            FTelnetCmd := Buf[Count];
          End;
      2 : Begin
            FTelnetState := 0;    // reset state after command

            Case FTelnetCmd of
              Telnet_WONT : Begin
//                              FTelnetSubCmd := Telnet_DONT;
//                              SockSend(FSocketHandle, FTelnetSubCmd, 1, 0);
                            End;
              Telnet_DONT : Begin
//                              FTelnetSubCmd := Telnet_WONT;
//                              SockSend(FSocketHandle, FTelnetSubCmd, 1, 0);
                            End;
              Telnet_SB   : Begin
                              FTelnetState  := 3;
                              FTelnetSubCmd := Buf[Count];
                            End;
              Telnet_WILL,
              Telnet_DO   : Begin
                              If FTelnetCmd = Telnet_DO Then Begin
                                ReplyGood := Telnet_WILL;
                                ReplyBad  := Telnet_WONT;
                              End Else Begin
                                ReplyGood := Telnet_DO;
                                ReplyBad  := Telnet_DONT;
                              End;

                              Case Buf[Count] of
                                Telnet_BINARY,
                                Telnet_ECHO,
                                Telnet_SGA,
                                Telnet_TERM : SendCommand(ReplyGood, Buf[Count])
                              Else
                                SendCommand(ReplyBad, Buf[Count]);
                              End;

                              If Buf[Count] = Telnet_Echo Then
                                FTelnetEcho := False;
                            End;
            End;
          End;
      3 : If Buf[Count] = Telnet_SE Then Begin
            If FTelnetClient Then
              Case FTelnetSubCmd of
                Telnet_TERM : SendData(Telnet_TERM, 'vt100');
              End;

            FTelnetState   := 0;
            FTelnetSubData := '';
          End Else
            FTelnetSubData := FTelnetSubData + Buf[Count];
    Else
      If Buf[Count] = Telnet_IAC Then Begin
        Inc (FTelnetState); // might need to make this := 1;
      End Else Begin
        Temp[TempPos] := Buf[Count];

        Inc (TempPos);
      End;
    End;
  End;

  Buf := Temp;
  Len := TempPos;
End;

Function TIOSocket.ReadChar : Char;
Begin
  ReadBuf(Result, 1);
End;

Function TIOSocket.PeekChar (Num: Byte) : Char;
Begin
  If (FInBufPos = FInBufEnd) and DataWaiting Then
    ReadBuf(Result, 0);

  If FInBufPos + Num < FInBufEnd Then
    Result := FInBuf[FInBufPos + Num];
End;

Function TIOSocket.ReadBuf (Var Buf; Len: LongInt) : LongInt;
Begin
  If FInBufPos = FInBufEnd Then Begin
    {$IFDEF OS2}
      FInBufEnd := Winsock.Recv(FSocketHandle, @FInBuf, TIOBufferSize, FPRECVOPT);
    {$ELSE}
      FInBufEnd := fpRecv(FSocketHandle, @FInBuf, TIOBufferSize, FPRECVOPT);
    {$ENDIF}

    FInBufPos := 0;

    If FInBufEnd <= 0 Then Begin
      FInBufEnd := 0;
      Result    := -1;
      Exit;
    End;

    If FTelnetClient or FTelnetServer Then TelnetInBuffer(FInBuf, FInBufEnd);
  End;

  If Len > FInBufEnd - FInBufPos Then Len := FInBufEnd - FInBufPos;

  Move (FInBuf[FInBufPos], Buf, Len);
  Inc  (FInBufPos, Len);

  Result := Len;
End;

Function TIOSocket.ReadLine (Var Str: String) : LongInt;
Var
  Ch  : Char;
  Res : LongInt;
Begin
  Str := '';
  Res := 0;

  Repeat
    If FInBufPos = FInBufEnd Then Res := ReadBuf(Ch, 0);

    Ch := FInBuf[FInBufPos];

    Inc (FInBufPos);

    If (Ch <> #10) And (Ch <> #13) And (FInBufEnd > 0) Then Str := Str + Ch;
  Until (Ch = #10) Or (Res < 0) Or (FInBufEnd = 0);

  If Res < 0 Then Result := -1 Else Result := Length(Str);
End;

Function TIOSocket.SetBlocking (Block: Boolean): LongInt;
//Var
//  Data : DWord;
Begin
  If FSocketHandle = -1 Then Begin
    Result := FSocketHandle;
    Exit;
  End;

// Data   := Ord(Not Block);
//  Result := ioctlSocket(FSocketHandle, FIONBIO, Data);
End;

Function TIOSocket.WaitForData (TimeOut: LongInt) : LongInt;
Var
  T      : TTimeVal;
  rFDSET,
  wFDSET,
  eFDSET : TFDSet;
Begin
  T.tv_sec  := 0;
  T.tv_usec := TimeOut * 1000;

  {$IFDEF UNIX}
    fpFD_Zero(rFDSET);
    fpFD_Zero(wFDSET);
    fpFD_Zero(eFDSET);
    fpFD_Set(FSocketHandle, rFDSET);
    Result := fpSelect(FSocketHandle + 1, @rFDSET, @wFDSET, @eFDSET, @T);
  {$ELSE}
    FD_Zero(rFDSET);
    FD_Zero(wFDSET);
    FD_Zero(eFDSET);
    FD_Set(FSocketHandle, rFDSET);
    Result := Select(FSocketHandle + 1, @rFDSET, @wFDSET, @eFDSET, @T);
  {$ENDIF}
End;

Function TIOSocket.ResolveAddress (Host: String) : LongInt;
Var
  HostEnt : PHostEnt;
Begin
  Host    := Host + #0;
  HostEnt := GetHostByName(@Host[1]);

  If Assigned(HostEnt) Then
    Result := PInAddr(HostEnt^.h_addr_list^)^.S_addr
  Else
    Result := LongInt(StrToNetAddr(Host));
End;

Function TIOSocket.Connect (Address: String; Port: Word) : Boolean;
Var
  Sin : TINetSockAddr;
Begin
  Result        := False;
  FSocketHandle := fpSocket(PF_INET, SOCK_STREAM, 0);

  If FSocketHandle = -1 Then Exit;

  FPeerName := Address;

  FillChar(Sin, SizeOf(Sin), 0);

  Sin.sin_Family      := PF_INET;
  Sin.sin_Port        := htons(Port);
  Sin.sin_Addr.S_Addr := ResolveAddress(Address);

  FPeerIP := NetAddrToStr(Sin.Sin_Addr);
  Result  := fpConnect(FSocketHandle, @Sin, SizeOf(Sin)) = 0;
End;

Procedure TIOSocket.WaitInit (Port: Word);
Var
  SIN : TINetSockAddr;
  Opt : LongInt;
Begin
  FSocketHandle := fpSocket(PF_INET, SOCK_STREAM, 0);

  Opt := 1;

  fpSetSockOpt (FSocketHandle, SOL_SOCKET, SO_REUSEADDR, @Opt, SizeOf(Opt));

  SIN.sin_family      := PF_INET;
  SIN.sin_addr.s_addr := 0;
  SIN.sin_port        := htons(Port);

  fpBind(FSocketHandle, @SIN, SizeOf(SIN));

  SetBlocking(True);
End;

Function TIOSocket.WaitConnection : TIOSocket;
Var
  Sock   : LongInt;
  Client : TIOSocket;
  PHE    : PHostEnt;
  SIN    : TINetSockAddr;
  Temp   : LongInt;
  SL     : TSockLen;
Begin
  Result := NIL;

  If fpListen(FSocketHandle, 5) = -1 Then Exit;

  Temp := SizeOf(SIN);

  {$IFDEF OS2}
    Sock := Winsock.Accept(FSocketHandle, @SIN, @Temp);
  {$ELSE}
    Sock := fpAccept(FSocketHandle, @SIN, @Temp);
  {$ENDIF}

  If Sock = -1 Then Exit;

  FPeerIP := NetAddrToStr(SIN.sin_addr);
  PHE     := GetHostByAddr(@SIN.sin_addr, 4, PF_INET);

  If Not Assigned(PHE) Then
    FPeerName := 'Unknown'
  Else
    FPeerName := StrPas(PHE^.h_name);

  SL := SizeOf(SIN);

  fpGetSockName(FSocketHandle, @SIN, @SL);

  FHostIP := NetAddrToStr(SIN.sin_addr);
  Client  := TIOSocket.Create;

  Client.SocketHandle  := Sock;
  Client.PeerName      := FPeerName;
  Client.PeerIP        := FPeerIP;
  Client.PeerPort      := FPort;
  Client.HostIP        := FHostIP;
  Client.FTelnetServer := FTelnetServer;
  Client.FTelnetClient := FTelnetClient;

  If FTelnetServer Then Begin
    {$IFDEF SOCKETLOG} sLog('Sending cmd: DO ECHO'); {$ENDIF}
    {$IFDEF SOCKETLOG} sLog('Sending cmd: WILL SGA'); {$ENDIF}

    Client.WriteStr (TELNET_IAC + TELNET_WILL + TELNET_ECHO +
                     TELNET_IAC + TELNET_WILL + TELNET_SGA  +
                     TELNET_IAC + TELNET_DO   + TELNET_BINARY);
  End;

  Result := Client;
End;

End.
