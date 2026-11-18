Option Explicit

Dim WshShell
Dim FSO
Dim ScriptDir
Dim ScriptPath
Dim PowerShellPath
Dim Wow64Architecture
Dim Mode
Dim WaitOnReturn
Dim Command
Dim RunResult
Dim RunErrorNumber
Dim RunErrorDescription
Dim LogPath
Dim FallbackLogPath
Dim LocalAppDataPath
Dim StartupStatusPath
Dim TempDirectory
Dim StartupWait
Dim StatusText
Dim StatusFile
Dim ScriptBaseName
Dim StatusReadError

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
ScriptBaseName = FSO.GetBaseName(WScript.ScriptName)

Sub ShowLauncherMessage(ByVal MessageText, ByVal MessageStyle, ByVal MessageTitle)
    If LCase(FSO.GetFileName(WScript.FullName)) = "cscript.exe" Then
        WScript.Echo MessageTitle & ": " & MessageText
    Else
        MsgBox MessageText, MessageStyle, MessageTitle
    End If
End Sub

' Default is Start. A second Start request is harmless and does not stop the watcher.
Mode = "Start"
WaitOnReturn = False

If WScript.Arguments.Count > 1 Then
    ShowLauncherMessage "Usage: " & ScriptBaseName & ".vbs [/start|/stop]", vbExclamation, "VoiceMeeter IdleWatcher"
    WScript.Quit 4
ElseIf WScript.Arguments.Count = 1 Then
    Select Case LCase(WScript.Arguments(0))
        Case "/stop", "-stop"
            Mode = "Stop"
            WaitOnReturn = True
        Case "/start", "-start"
            Mode = "Start"
        Case Else
            ShowLauncherMessage "Unknown argument: " & WScript.Arguments(0) & vbCrLf & _
                "Usage: " & ScriptBaseName & ".vbs [/start|/stop]", _
                vbExclamation, "VoiceMeeter IdleWatcher"
            WScript.Quit 4
    End Select
End If

' Resolve the directory containing this VBS file.
ScriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)
ScriptPath = FSO.BuildPath(ScriptDir, ScriptBaseName & ".ps1")
LogPath = FSO.BuildPath(ScriptDir, ScriptBaseName & ".log")
LocalAppDataPath = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
If LocalAppDataPath = "%LOCALAPPDATA%" Or LocalAppDataPath = "" Then
    FallbackLogPath = WshShell.ExpandEnvironmentStrings("%TEMP%\VoiceMeeter-IdleWatcher\" & ScriptBaseName & "-fallback.log")
Else
    FallbackLogPath = FSO.BuildPath(LocalAppDataPath, _
        "VoiceMeeter-IdleWatcher\" & ScriptBaseName & "-fallback.log")
End If

If Mode = "Start" Then
    TempDirectory = WshShell.ExpandEnvironmentStrings("%TEMP%")
    If TempDirectory = "%TEMP%" Or TempDirectory = "" Then TempDirectory = ScriptDir
    StartupStatusPath = FSO.BuildPath(TempDirectory, ScriptBaseName & "-" & FSO.GetTempName() & ".status")
End If

If Not FSO.FileExists(ScriptPath) Then
    ShowLauncherMessage ScriptBaseName & ".ps1 was not found:" & vbCrLf & ScriptPath, _
        vbCritical, "VoiceMeeter IdleWatcher"
    WScript.Quit 2
End If

' A 32-bit WScript process on 64-bit Windows is redirected from System32
' to SysWOW64. Sysnative reaches native 64-bit Windows PowerShell in that case.
Wow64Architecture = WshShell.ExpandEnvironmentStrings("%PROCESSOR_ARCHITEW6432%")

If Wow64Architecture <> "%PROCESSOR_ARCHITEW6432%" And Wow64Architecture <> "" Then
    PowerShellPath = WshShell.ExpandEnvironmentStrings( _
        "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
Else
    PowerShellPath = WshShell.ExpandEnvironmentStrings( _
        "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
End If

If Not FSO.FileExists(PowerShellPath) Then
    ShowLauncherMessage "Windows PowerShell was not found:" & vbCrLf & PowerShellPath, _
        vbCritical, "VoiceMeeter IdleWatcher"
    WScript.Quit 3
End If

Command = Chr(34) & PowerShellPath & Chr(34) & _
    " -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & _
    Chr(34) & ScriptPath & Chr(34) & " -Mode " & Mode

If Mode = "Start" Then
    Command = Command & " -StartupStatusFile " & Chr(34) & StartupStatusPath & Chr(34)
End If

' Start runs detached. Stop waits and checks the PowerShell exit code.
On Error Resume Next
RunResult = WshShell.Run(Command, 0, WaitOnReturn)
RunErrorNumber = Err.Number
RunErrorDescription = Err.Description
Err.Clear
On Error GoTo 0

If RunErrorNumber <> 0 Then
    ShowLauncherMessage "Could not start Windows PowerShell." & vbCrLf & _
        "Error " & RunErrorNumber & ": " & RunErrorDescription & vbCrLf & _
        "Log: " & LogPath, vbCritical, "VoiceMeeter IdleWatcher"
    WScript.Quit 5
End If

If Mode = "Start" Then
    ' Start remains detached, but the launcher now waits for an explicit status
    ' from PowerShell so an early DLL/Login failure is not silently reported as success.
    For StartupWait = 1 To 600
        If FSO.FileExists(StartupStatusPath) Then Exit For
        WScript.Sleep 100
    Next

    If FSO.FileExists(StartupStatusPath) Then
        StatusReadError = 0
        On Error Resume Next
        Set StatusFile = FSO.OpenTextFile(StartupStatusPath, 1, False)
        If Err.Number = 0 Then
            StatusText = Trim(StatusFile.ReadAll)
            StatusFile.Close
            Set StatusFile = Nothing
        End If
        StatusReadError = Err.Number
        Err.Clear
        On Error GoTo 0
        If FSO.FileExists(StartupStatusPath) Then FSO.DeleteFile StartupStatusPath, True

        If StatusReadError <> 0 Then
            ShowLauncherMessage "Could not read the startup status file. Error " & StatusReadError & ". Check the log: " & LogPath, _
                vbCritical, "VoiceMeeter IdleWatcher"
            WScript.Quit 7
        ElseIf StatusText = "FAILED" Then
            ShowLauncherMessage "VoiceMeeter IdleWatcher failed during startup." & vbCrLf & _
                "Check the log: " & LogPath & vbCrLf & _
                "Fallback log: " & FallbackLogPath, _
                vbCritical, "VoiceMeeter IdleWatcher"
            WScript.Quit 6
        ElseIf StatusText = "STOPPED" Then
            ' A Stop request arrived during initialization. This is a clean cancellation,
            ' not a failed Start and not a reason to block cscript with a modal dialog.
            WScript.Quit 0
        ElseIf StatusText <> "READY" And StatusText <> "ALREADY_RUNNING" Then
            ShowLauncherMessage "Unexpected startup status: " & StatusText & vbCrLf & _
                "Check the log: " & LogPath, vbExclamation, "VoiceMeeter IdleWatcher"
            WScript.Quit 7
        End If
    Else
        ShowLauncherMessage "PowerShell did not confirm watcher startup within 60 seconds." & vbCrLf & _
            "The process was not forcibly terminated." & vbCrLf & _
            "Check the log: " & LogPath & vbCrLf & _
            "Fallback log: " & FallbackLogPath, _
            vbExclamation, "VoiceMeeter IdleWatcher"
        WScript.Quit 8
    End If
End If

If Mode = "Stop" And RunResult <> 0 Then
    ShowLauncherMessage "The watcher did not confirm a clean stop." & vbCrLf & _
        "PowerShell exit code: " & RunResult & vbCrLf & _
        "Check the log: " & LogPath & vbCrLf & _
        "Fallback log: " & FallbackLogPath, _
        vbExclamation, "VoiceMeeter IdleWatcher"
    WScript.Quit RunResult
End If

Set FSO = Nothing
Set WshShell = Nothing
