[CmdletBinding()]
param(
    [ValidateSet('Start', 'Stop')]
    [string]$Mode = 'Start',

    [ValidateRange(1, 60)]
    [int]$IdleMinutes = 8,

    [switch]$DebugMode,

    [string]$StartupStatusFile = ''
)

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -eq '.') {
    throw 'VoiceMeeter-IdleWatcher.ps1 cannot be dot-sourced. Run it in a fresh powershell.exe process with -File.'
}

# ==================== Settings ====================
$ScriptDir = $PSScriptRoot
$ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
if ([string]::IsNullOrWhiteSpace($ScriptBaseName)) {
    $ScriptBaseName = 'VoiceMeeter-IdleWatcher'
}
$LogFile = Join-Path -Path $ScriptDir -ChildPath ($ScriptBaseName + '.log')
$MaxLogSize = 500KB
$FallbackMaxLogSize = 2MB
$CheckIntervalSec = 10
$RetryIntervalSec = 30
$EngineAbsentProbeIntervalSec = 3
$DisplayNotificationTimeoutSec = 5
$PostShutdownProbeIntervalSec = 1
$PostShutdownRestartProbeIntervalSec = 3
$PostShutdownConfirmationTimeoutSec = 5
$ApiSessionRecoveryRetryIntervalSec = 5
$MutexName = 'Local\VoiceMeeter-IdleWatcher'
$StopEventName = 'Local\VoiceMeeter-IdleWatcher.Stop'
$LogMutexName = 'Local\VoiceMeeter-IdleWatcher.Log'
$StopWaitTimeoutSec = 20

# Optional MacroButtons displayed-state synchronization.
# This is the VoiceMeeter Remote API logical button ID (0-79), not a
# one-based label. Logical ID 0 is reserved by the maintainer for the mic.
# Set to -1 to disable the optional synchronization.
$MacroButtonLogicalIndex = 1
if (($MacroButtonLogicalIndex -lt -1) -or ($MacroButtonLogicalIndex -gt 79)) {
    throw 'MacroButtonLogicalIndex must be -1 (disabled) or a value from 0 to 79.'
}
$MacroButtonSyncIntervalSec = 10
$MacroButtonStateOnlyMode = 0x00000002

$LocalLogRoot = $env:LOCALAPPDATA
if ([string]::IsNullOrWhiteSpace($LocalLogRoot)) {
    $LocalLogRoot = [System.IO.Path]::GetTempPath()
}
$FallbackLogDirectory = Join-Path -Path $LocalLogRoot -ChildPath 'VoiceMeeter-IdleWatcher'
$FallbackLogFile = Join-Path -Path $FallbackLogDirectory -ChildPath ($ScriptBaseName + '-fallback.log')
$EmergencyLogFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'VoiceMeeter-IdleWatcher-emergency.log'
$script:LogMutex = $null

# ==================== Logging ====================
function Add-LogLineToFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Line,
        [Parameter(Mandatory = $true)][long]$MaxBytes
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    if ([System.IO.File]::Exists($Path)) {
        $item = [System.IO.FileInfo]::new($Path)
        if ($item.Length -ge $MaxBytes) {
            $archive = "$Path.old"
            if ([System.IO.File]::Exists($archive)) {
                [System.IO.File]::Delete($archive)
            }
            [System.IO.File]::Move($Path, $archive)
        }
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::AppendAllText($Path, $Line + [Environment]::NewLine, $encoding)
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (($Level -eq 'DEBUG') -and (-not $DebugMode)) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$timestamp] [$Level] $Message"
    $primaryError = $null
    $lockAcquired = $false

    try {
        if ($null -eq $script:LogMutex) {
            $script:LogMutex = [System.Threading.Mutex]::new($false, $LogMutexName)
        }

        try {
            $lockAcquired = $script:LogMutex.WaitOne(3000)
        }
        catch [System.Threading.AbandonedMutexException] {
            # The abandoned log mutex is now owned by this process.
            $lockAcquired = $true
        }

        if (-not $lockAcquired) {
            throw 'Timed out waiting for the log-file mutex.'
        }

        Add-LogLineToFile -Path $LogFile -Line $line -MaxBytes $MaxLogSize
        return
    }
    catch {
        $primaryError = $_.Exception.Message
    }
    finally {
        if ($lockAcquired -and ($null -ne $script:LogMutex)) {
            try { $script:LogMutex.ReleaseMutex() } catch { }
        }
    }

    # Never discard a logging failure silently. Preserve the original message
    # in a per-user fallback file and include the primary-file error.
    $fallbackLine = "$line [PRIMARY LOG WRITE FAILED: $primaryError]"
    $fallbackLockAcquired = $false

    try {
        if ($null -eq $script:LogMutex) {
            $script:LogMutex = [System.Threading.Mutex]::new($false, $LogMutexName)
        }

        try {
            $fallbackLockAcquired = $script:LogMutex.WaitOne(1000)
        }
        catch [System.Threading.AbandonedMutexException] {
            $fallbackLockAcquired = $true
        }

        if (-not $fallbackLockAcquired) {
            throw 'Timed out waiting for the log-file mutex before writing the fallback log.'
        }

        Add-LogLineToFile -Path $FallbackLogFile -Line $fallbackLine -MaxBytes $FallbackMaxLogSize
        return
    }
    catch {
        $fallbackError = $_.Exception.Message
    }
    finally {
        if ($fallbackLockAcquired -and ($null -ne $script:LogMutex)) {
            try { $script:LogMutex.ReleaseMutex() } catch { }
        }
    }

    # Last-resort path. This is intentionally independent of the watcher folder.
    try {
        $emergencyLine = "$fallbackLine [FALLBACK LOG WRITE FAILED: $fallbackError]"
        Add-LogLineToFile -Path $EmergencyLogFile -Line $emergencyLine -MaxBytes $FallbackMaxLogSize
    }
    catch {
        try {
            [Console]::Error.WriteLine("VoiceMeeter IdleWatcher logging failure: $primaryError; fallback failure: $fallbackError; message: $Message")
        }
        catch { }
    }
}

# The VBS launcher waits for a short status token, so startup failures are not
# hidden by WshShell.Run(..., WaitOnReturn=False).
$script:StartupStatusWritten = $false
function Write-StartupStatus {
    param([ValidateSet('READY', 'ALREADY_RUNNING', 'STOPPED', 'FAILED')][string]$Status)

    if ([string]::IsNullOrWhiteSpace($StartupStatusFile) -or $script:StartupStatusWritten) {
        return
    }

    try {
        $statusDirectory = [System.IO.Path]::GetDirectoryName($StartupStatusFile)
        if (-not [string]::IsNullOrWhiteSpace($statusDirectory)) {
            [void][System.IO.Directory]::CreateDirectory($statusDirectory)
        }
        $temporaryStatusFile = $StartupStatusFile + '.' + $PID + '.tmp'
        [System.IO.File]::WriteAllText(
            $temporaryStatusFile,
            $Status,
            [System.Text.UTF8Encoding]::new($false)
        )
        if ([System.IO.File]::Exists($StartupStatusFile)) {
            [System.IO.File]::Delete($StartupStatusFile)
        }
        [System.IO.File]::Move($temporaryStatusFile, $StartupStatusFile)
        $script:StartupStatusWritten = $true
    }
    catch {
        Write-Log "Could not write startup status file '$StartupStatusFile': $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ==================== DLL discovery ====================
function Get-VoicemeeterRemoteDll {
    if ([Environment]::Is64BitProcess) {
        $requiredDll = 'VoicemeeterRemote64.dll'
    }
    else {
        $requiredDll = 'VoicemeeterRemote.dll'
    }

    $folders = [System.Collections.Generic.List[string]]::new()

    # Use RegistryKey directly. The product key includes a literal colon
    # (VB:Voicemeeter), which can be misread as a provider drive separator in HKLM: paths.
    $uninstallSubKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VB:Voicemeeter {17359A74-1236-5467}'
    $registryViews = @([Microsoft.Win32.RegistryView]::Registry32)
    if ([Environment]::Is64BitOperatingSystem) {
        $registryViews = @(
            [Microsoft.Win32.RegistryView]::Registry64,
            [Microsoft.Win32.RegistryView]::Registry32
        )
    }

    foreach ($registryView in $registryViews) {
        $baseKey = $null
        $entryKey = $null
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine,
                $registryView
            )
            $entryKey = $baseKey.OpenSubKey($uninstallSubKey)
            if ($null -eq $entryKey) { continue }

            $installLocation = [string]$entryKey.GetValue('InstallLocation', '')
            if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
                $installFolder = [Environment]::ExpandEnvironmentVariables($installLocation.Trim()).Trim('"')
                if (-not [string]::IsNullOrWhiteSpace($installFolder)) {
                    $folders.Add($installFolder)
                }
            }

            $uninstallString = [string]$entryKey.GetValue('UninstallString', '')
            if (-not [string]::IsNullOrWhiteSpace($uninstallString)) {
                $uninstallString = [Environment]::ExpandEnvironmentVariables($uninstallString).Trim()
                $uninstallExe = $null

                # Accept quoted paths and unquoted Inno Setup paths with spaces.
                if ($uninstallString -match '^\s*"(?<quotedExe>[^"]+)"') {
                    $uninstallExe = $Matches['quotedExe']
                }
                elseif ($uninstallString -match '^\s*(?<unquotedExe>.+?\.exe)(?:\s|$)') {
                    $uninstallExe = $Matches['unquotedExe']
                }

                if ($uninstallExe -and (Test-Path -LiteralPath $uninstallExe -PathType Leaf)) {
                    $uninstallFolder = Split-Path -LiteralPath $uninstallExe -Parent
                    if (-not [string]::IsNullOrWhiteSpace($uninstallFolder)) {
                        $folders.Add($uninstallFolder)
                    }
                }
                elseif ($uninstallExe) {
                    Write-Log "UninstallString executable was parsed but not found: $uninstallExe" -Level 'DEBUG'
                }
                else {
                    Write-Log "Could not parse Voicemeeter UninstallString: $uninstallString" -Level 'DEBUG'
                }
            }
        }
        catch {
            Write-Log "Could not inspect Voicemeeter uninstall registry view '$registryView': $($_.Exception.Message)" -Level 'DEBUG'
        }
        finally {
            if ($null -ne $entryKey) { $entryKey.Dispose() }
            if ($null -ne $baseKey) { $baseKey.Dispose() }
        }
    }

    $programRoots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:ProgramW6432
    )

    foreach ($programRoot in $programRoots) {
        if ($programRoot) {
            $folders.Add((Join-Path -Path $programRoot -ChildPath 'VB\Voicemeeter'))
        }
    }

    foreach ($folder in ($folders | Select-Object -Unique)) {
        $candidate = Join-Path -Path $folder -ChildPath $requiredDll

        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw "Compatible DLL $requiredDll not found. Verify Voicemeeter installation and PowerShell process architecture."
}

# ==================== Native API interop ====================
function Initialize-VoicemeeterNativeInterop {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DllPath
    )

    $source = @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

public static class VMRIdleWatcherNative
{
    private const string Dll = @"$DllPath";

    private const uint DeviceNotifyCallback = 2;
    private const uint PowerSettingChange = 0x8013;

    private static readonly Guid SessionDisplayStatusGuid =
        new Guid("2B84C20E-AD23-4DDF-93DB-05FFBD7EFCA5");

    private static int _displayState = -1;
    private static IntPtr _displayRegistrationHandle = IntPtr.Zero;
    private static IntPtr _displaySubscribeParameters = IntPtr.Zero;
    private static readonly ManualResetEvent DisplayStateReceived = new ManualResetEvent(false);

    private static readonly ManualResetEvent ExitRequested = new ManualResetEvent(false);
    private static EventWaitHandle _externalStopEvent;

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint DeviceNotifyCallbackRoutine(
        IntPtr context,
        uint type,
        IntPtr setting
    );

    // Keep the unmanaged display callback alive for the entire registration lifetime.
    private static readonly DeviceNotifyCallbackRoutine DisplayCallback =
        OnDisplayPowerSettingChanged;

    [DllImport("powrprof.dll", SetLastError = true)]
    private static extern uint PowerSettingRegisterNotification(
        ref Guid settingGuid,
        uint flags,
        IntPtr recipient,
        out IntPtr registrationHandle
    );

    [DllImport("powrprof.dll", SetLastError = true)]
    private static extern uint PowerSettingUnregisterNotification(
        IntPtr registrationHandle
    );

    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO info);

    public static uint GetIdleMilliseconds()
    {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));

        if (!GetLastInputInfo(ref info))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        // TickCount is 32-bit and wraps approximately every 49.7 days.
        // unchecked + uint handles wrap-around correctly for idle deltas.
        return unchecked((uint)Environment.TickCount - info.dwTime);
    }

    private static uint OnDisplayPowerSettingChanged(
        IntPtr context,
        uint type,
        IntPtr setting
    )
    {
        try
        {
            if (type != PowerSettingChange || setting == IntPtr.Zero)
            {
                return 0;
            }

            Guid receivedGuid = (Guid)Marshal.PtrToStructure(
                setting,
                typeof(Guid)
            );

            if (receivedGuid != SessionDisplayStatusGuid)
            {
                return 0;
            }

            // POWERBROADCAST_SETTING:
            // GUID (16 bytes), DataLength (4 bytes), Data (DWORD).
            uint dataLength = unchecked((uint)Marshal.ReadInt32(setting, 16));
            if (dataLength < 4)
            {
                return 0;
            }

            int state = Marshal.ReadInt32(setting, 20);

            // 0 = Off, 1 = On, 2 = Dim.
            if (state >= 0 && state <= 2)
            {
                Interlocked.Exchange(ref _displayState, state);
                DisplayStateReceived.Set();
            }
        }
        catch
        {
            // Never let an exception cross the unmanaged callback boundary.
        }

        return 0;
    }

    public static void CreateExternalStopEvent(string eventName)
    {
        if (_externalStopEvent != null)
        {
            return;
        }

        bool createdNew;
        EventWaitHandle stopEvent = new EventWaitHandle(
            false,
            EventResetMode.ManualReset,
            eventName,
            out createdNew
        );

        if (!createdNew)
        {
            stopEvent.Dispose();
            throw new InvalidOperationException(
                "The named stop event already exists. Another watcher may still be active."
            );
        }

        _externalStopEvent = stopEvent;
    }

    public static void DisposeExternalStopEvent()
    {
        if (_externalStopEvent != null)
        {
            _externalStopEvent.Dispose();
            _externalStopEvent = null;
        }
    }

    public static bool IsExitRequested()
    {
        if (ExitRequested.WaitOne(0))
        {
            return true;
        }

        if (_externalStopEvent != null && _externalStopEvent.WaitOne(0))
        {
            ExitRequested.Set();
            return true;
        }

        return false;
    }

    public static bool WaitForExit(int timeoutMilliseconds)
    {
        if (_externalStopEvent == null)
        {
            return ExitRequested.WaitOne(timeoutMilliseconds);
        }

        WaitHandle[] waitHandles = new WaitHandle[]
        {
            ExitRequested,
            _externalStopEvent
        };

        int result = WaitHandle.WaitAny(waitHandles, timeoutMilliseconds);

        if (result == 1)
        {
            ExitRequested.Set();
            return true;
        }

        return result == 0;
    }

    // Returns 0 when the first display state arrives, 1 when shutdown was
    // requested, and -1 on timeout. Unknown display state remains fail-safe.
    public static int WaitForDisplayState(int timeoutMilliseconds)
    {
        WaitHandle[] waitHandles;

        if (_externalStopEvent != null)
        {
            waitHandles = new WaitHandle[]
            {
                DisplayStateReceived,
                ExitRequested,
                _externalStopEvent
            };
        }
        else
        {
            waitHandles = new WaitHandle[]
            {
                DisplayStateReceived,
                ExitRequested
            };
        }

        int result = WaitHandle.WaitAny(waitHandles, timeoutMilliseconds);

        if (result == 0)
        {
            return 0;
        }

        if (result == 1 || (result == 2 && _externalStopEvent != null))
        {
            ExitRequested.Set();
            return 1;
        }

        return -1;
    }

    public static int GetDisplayState()
    {
        return Interlocked.CompareExchange(ref _displayState, 0, 0);
    }

    public static void RegisterDisplayNotification()
    {
        if (_displayRegistrationHandle != IntPtr.Zero)
        {
            return;
        }

        DisplayStateReceived.Reset();

        // DEVICE_NOTIFY_SUBSCRIBE_PARAMETERS contains callback and context pointers.
        IntPtr subscribeParameters = Marshal.AllocHGlobal(IntPtr.Size * 2);

        try
        {
            IntPtr callbackPointer = Marshal.GetFunctionPointerForDelegate(
                DisplayCallback
            );

            Marshal.WriteIntPtr(subscribeParameters, 0, callbackPointer);
            Marshal.WriteIntPtr(
                subscribeParameters,
                IntPtr.Size,
                IntPtr.Zero
            );

            Guid settingGuid = SessionDisplayStatusGuid;
            IntPtr registrationHandle;

            uint result = PowerSettingRegisterNotification(
                ref settingGuid,
                DeviceNotifyCallback,
                subscribeParameters,
                out registrationHandle
            );

            if (result != 0)
            {
                throw new Win32Exception(
                    (int)result,
                    "Failed to register display power state notification."
                );
            }

            if (registrationHandle == IntPtr.Zero)
            {
                throw new InvalidOperationException(
                    "Windows returned a null handle for display notification registration."
                );
            }

            _displaySubscribeParameters = subscribeParameters;
            _displayRegistrationHandle = registrationHandle;
        }
        catch
        {
            Marshal.FreeHGlobal(subscribeParameters);
            throw;
        }
    }

    public static void UnregisterDisplayNotification()
    {
        if (_displayRegistrationHandle == IntPtr.Zero)
        {
            return;
        }

        uint result = PowerSettingUnregisterNotification(
            _displayRegistrationHandle
        );

        if (result != 0)
        {
            throw new Win32Exception(
                (int)result,
                "Failed to unregister display power state notification."
            );
        }

        _displayRegistrationHandle = IntPtr.Zero;

        if (_displaySubscribeParameters != IntPtr.Zero)
        {
            Marshal.FreeHGlobal(_displaySubscribeParameters);
            _displaySubscribeParameters = IntPtr.Zero;
        }

        Interlocked.Exchange(ref _displayState, -1);
        DisplayStateReceived.Reset();
    }

    [DllImport(Dll, EntryPoint = "VBVMR_Login", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
    public static extern int Login();

    [DllImport(Dll, EntryPoint = "VBVMR_Logout", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
    public static extern int Logout();

    [DllImport(Dll, EntryPoint = "VBVMR_IsParametersDirty", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
    public static extern int IsParametersDirty();

    [DllImport(Dll, EntryPoint = "VBVMR_SetParameterFloat", CallingConvention = CallingConvention.StdCall, ExactSpelling = true, CharSet = CharSet.Ansi)]
    public static extern int SetParameterFloat([MarshalAs(UnmanagedType.LPStr)] string parameter, float value);

    [DllImport(Dll, EntryPoint = "VBVMR_MacroButton_GetStatus", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
    public static extern int MacroButtonGetStatus(int logicalButton, out float value, int bitmode);

    [DllImport(Dll, EntryPoint = "VBVMR_MacroButton_SetStatus", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
    public static extern int MacroButtonSetStatus(int logicalButton, float value, int bitmode);
}
"@

    if ('VMRIdleWatcherNative' -as [type]) {
        throw 'VMRIdleWatcherNative is already loaded in this PowerShell process. Run each watcher/test instance in a fresh powershell.exe process; the native DLL path and event handles are process-static.'
    }
    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}

function Invoke-VoiceMeeterApiLogin {
    $loginResult = [VMRIdleWatcherNative]::Login()

    if ($loginResult -eq -2) {
        # Login -2 explicitly means a Logout was expected before another Login.
        Write-Log 'VoiceMeeter API Login returned -2 (Logout required). Calling Logout before retrying Login.' -Level 'WARN'
        $logoutResult = [VMRIdleWatcherNative]::Logout()
        if ($logoutResult -lt 0) {
            throw "VoiceMeeter API Logout-before-Login recovery failed (code $logoutResult)."
        }
        $loginResult = [VMRIdleWatcherNative]::Login()
    }

    return [int]$loginResult
}

# ==================== Optional MacroButtons display-state synchronization ====================
$script:MacroButtonReadStatus = 'NotChecked'
$script:MacroButtonWriteStatus = 'NotChecked'
$script:MacroButtonNextSyncAt = [datetime]::MinValue

function Invoke-MacroButtonStateSync {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(0, 1)]
        [int]$DesiredState,

        [switch]$Force
    )

    if (($MacroButtonLogicalIndex -lt 0) -or ($script:MacroButtonReadStatus -eq 'Unsupported')) {
        return
    }

    $now = Get-Date
    if ((-not $Force) -and ($now -lt $script:MacroButtonNextSyncAt)) {
        return
    }

    $script:MacroButtonNextSyncAt = $now.AddSeconds($MacroButtonSyncIntervalSec)
    $currentButtonState = [single]0

    try {
        $getResult = [VMRIdleWatcherNative]::MacroButtonGetStatus(
            [int]$MacroButtonLogicalIndex,
            [ref]$currentButtonState,
            [int]$MacroButtonStateOnlyMode
        )
    }
    catch [System.EntryPointNotFoundException] {
        if ($script:MacroButtonReadStatus -ne 'Unsupported') {
            Write-Log 'MacroButtons synchronization functions are not exported by this Remote API DLL. Continuing without optional button synchronization.' -Level 'DEBUG'
        }
        $script:MacroButtonReadStatus = 'Unsupported'
        $script:MacroButtonNextSyncAt = [datetime]::MaxValue
        return
    }
    catch {
        $readStatus = 'ReadException'
        if ($script:MacroButtonReadStatus -ne $readStatus) {
            Write-Log "Could not read MacroButtons logical button $MacroButtonLogicalIndex state: $($_.Exception.Message). The watcher will continue and retry later." -Level 'DEBUG'
        }
        $script:MacroButtonReadStatus = $readStatus
        return
    }

    if ($getResult -ne 0) {
        $readStatus = "ReadResult:$getResult"
        if ($script:MacroButtonReadStatus -ne $readStatus) {
            Write-Log "MacroButtons logical button $MacroButtonLogicalIndex is not currently available (Remote API code $getResult). The watcher continues normally and will retry later." -Level 'DEBUG'
        }
        $script:MacroButtonReadStatus = $readStatus
        return
    }

    if (($script:MacroButtonReadStatus -ne 'Available') -and ($script:MacroButtonReadStatus -ne 'NotChecked')) {
        Write-Log "MacroButtons state access recovered for logical button $MacroButtonLogicalIndex." -Level 'DEBUG'
    }
    $script:MacroButtonReadStatus = 'Available'

    $currentState = if ($currentButtonState -ge 0.5) { 1 } else { 0 }
    if ($currentState -eq $DesiredState) {
        $script:MacroButtonWriteStatus = 'NoChangeNeeded'
        return
    }

    try {
        $setResult = [VMRIdleWatcherNative]::MacroButtonSetStatus(
            [int]$MacroButtonLogicalIndex,
            [single]$DesiredState,
            [int]$MacroButtonStateOnlyMode
        )
    }
    catch [System.EntryPointNotFoundException] {
        Write-Log 'MacroButtons SetStatus is not exported by this Remote API DLL. Continuing without optional button synchronization.' -Level 'DEBUG'
        $script:MacroButtonReadStatus = 'Unsupported'
        $script:MacroButtonNextSyncAt = [datetime]::MaxValue
        return
    }
    catch {
        $writeStatus = 'WriteException'
        if ($script:MacroButtonWriteStatus -ne $writeStatus) {
            Write-Log "Could not update MacroButtons logical button $MacroButtonLogicalIndex display state: $($_.Exception.Message). The watcher continues normally and will retry later." -Level 'DEBUG'
        }
        $script:MacroButtonWriteStatus = $writeStatus
        return
    }

    if ($setResult -ne 0) {
        $writeStatus = "WriteResult:$setResult"
        if ($script:MacroButtonWriteStatus -ne $writeStatus) {
            Write-Log "MacroButtons logical button $MacroButtonLogicalIndex display state could not be updated (Remote API code $setResult). The watcher continues normally and will retry later." -Level 'DEBUG'
        }
        $script:MacroButtonWriteStatus = $writeStatus
        return
    }

    $script:MacroButtonWriteStatus = 'Available'
    $stateLabel = if ($DesiredState -eq 1) { 'ON' } else { 'OFF' }
    Write-Log "MacroButtons logical button $MacroButtonLogicalIndex display state synchronized to $stateLabel using STATEONLY." -Level 'INFO'
}

# ==================== Runtime state and lifecycle resources ====================
$thresholdMs = [uint32]($IdleMinutes * 60 * 1000)
$shutdownSentThisIdle = $false
$engineStoppedAfterShutdown = $false
$lastShutdownCommandAt = [datetime]::MinValue
$nextApiAttempt = [datetime]::MinValue
$loginCompleted = $false
$watcherIsActive = $false
$connectionWarningLogged = $false
$shutdownWarningLogged = $false
$displayNotificationRegistered = $false
$stopEventCreated = $false
$lastLoggedDisplayState = -999

function Send-StopRequestToExistingWatcher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventName
    )

    # The watcher creates this event shortly after acquiring the mutex. Retry
    # briefly to cover the small window between mutex acquisition and event creation.
    $attempts = $StopWaitTimeoutSec * 10

    for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
        $eventHandle = $null

        try {
            $eventHandle = [System.Threading.EventWaitHandle]::OpenExisting($EventName)
            [void]$eventHandle.Set()
            return $true
        }
        catch [System.Threading.WaitHandleCannotBeOpenedException] {
            Start-Sleep -Milliseconds 100
        }
        catch {
            Write-Log "Could not send graceful stop request: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
        finally {
            if ($null -ne $eventHandle) {
                $eventHandle.Dispose()
            }
        }
    }

    Write-Log "The watcher owns the mutex, but its stop event was not available within $StopWaitTimeoutSec seconds." -Level 'ERROR'
    return $false
}

# ==================== Single-instance protection ====================
$watcherMutex = $null
$mutexOwned = $false
$mutexWasAbandoned = $false

try {
    $watcherMutex = [System.Threading.Mutex]::new($false, $MutexName)

    try {
        $mutexOwned = $watcherMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        # The previous process died without releasing the mutex. This process
        # now owns it, but that is not evidence that graceful cleanup completed.
        $mutexOwned = $true
        $mutexWasAbandoned = $true
    }

    if ($Mode -eq 'Stop') {
        $stopFailed = $false

        if ($mutexOwned) {
            if ($mutexWasAbandoned) {
                # No watcher is alive, but the abandoned mutex proves that the
                # previous process did not complete a confirmed graceful cleanup.
                # Report this as an abnormal stop rather than a successful Logout.
                Write-Log 'No running watcher remains, but its mutex was abandoned. The previous process did not confirm graceful Logout.' -Level 'ERROR'
                $stopFailed = $true
            }
            else {
                Write-Log 'No running VoiceMeeter-IdleWatcher instance found.'
            }

            $watcherMutex.ReleaseMutex()
            $mutexOwned = $false
            $watcherMutex.Dispose()
            $watcherMutex = $null
            if ($stopFailed) {
                throw 'The previous watcher terminated unexpectedly; graceful cleanup cannot be confirmed. Check the log.'
            }
            return
        }

        Write-Log 'Graceful stop requested. Signalling the running watcher...'
        $stopRequestSent = Send-StopRequestToExistingWatcher -EventName $StopEventName

        if ($stopRequestSent) {
            Write-Log 'Stop signal delivered. Waiting for the watcher to finish Logout and release its mutex.'
            $mutexAcquiredAfterStop = $false
            $mutexAbandonedAfterStop = $false

            try {
                $mutexAcquiredAfterStop = $watcherMutex.WaitOne($StopWaitTimeoutSec * 1000)
            }
            catch [System.Threading.AbandonedMutexException] {
                $mutexAcquiredAfterStop = $true
                $mutexAbandonedAfterStop = $true
            }

            if ($mutexAcquiredAfterStop) {
                if ($mutexAbandonedAfterStop) {
                    Write-Log 'The watcher process terminated without releasing its mutex. Graceful cleanup was not completed.' -Level 'ERROR'
                    $stopFailed = $true
                }
                else {
                    Write-Log 'Stop confirmed: the watcher completed its cleanup sequence and released the mutex. Check preceding ERROR entries for any individual cleanup failures.'
                }

                $watcherMutex.ReleaseMutex()
            }
            else {
                Write-Log "Timed out after $StopWaitTimeoutSec seconds. The watcher was not forcibly terminated; inspect the log for the reason." -Level 'ERROR'
                $stopFailed = $true
            }
        }
        else {
            # The event may disappear if the watcher was already in its final
            # cleanup steps when this Stop controller started. Check the mutex once
            # more so that a completed watcher is not misreported as still running.
            $mutexAcquiredAfterFailedSignal = $false
            $mutexAbandonedAfterFailedSignal = $false

            try {
                $mutexAcquiredAfterFailedSignal = $watcherMutex.WaitOne(0)
            }
            catch [System.Threading.AbandonedMutexException] {
                $mutexAcquiredAfterFailedSignal = $true
                $mutexAbandonedAfterFailedSignal = $true
            }

            if ($mutexAcquiredAfterFailedSignal) {
                if ($mutexAbandonedAfterFailedSignal) {
                    Write-Log 'The watcher mutex was abandoned. The previous process did not complete graceful cleanup.' -Level 'ERROR'
                    $stopFailed = $true
                }
                else {
                    Write-Log 'The watcher mutex became available while the Stop request was being prepared; the watcher has exited.'
                }
                $watcherMutex.ReleaseMutex()
            }
            else {
                $stopFailed = $true
            }
        }

        $watcherMutex.Dispose()
        $watcherMutex = $null

        if ($stopFailed) {
            throw 'Graceful stop was not confirmed. The watcher may still be running or may have terminated unexpectedly. Check the log.'
        }
        return
    }

    # Start mode is deliberately non-destructive. A duplicate scheduled launch
    # must never stop an already-running watcher.
    if (-not $mutexOwned) {
        Write-Log 'Watcher is already running. This Start request will not create a second instance.'
        Write-StartupStatus -Status 'ALREADY_RUNNING'
        $watcherMutex.Dispose()
        $watcherMutex = $null
        return
    }

    if ($mutexWasAbandoned) {
        Write-Log 'Previous watcher terminated unexpectedly. Mutex lock acquired; starting a fresh instance.' -Level 'WARN'
    }

    Write-Log 'Single-instance mutex protection enabled.'
}
catch {
    if ($null -ne $watcherMutex) {
        if ($mutexOwned) {
            try { $watcherMutex.ReleaseMutex() } catch { }
        }
        $watcherMutex.Dispose()
        $watcherMutex = $null
    }

    Write-Log "Failed during single-instance or stop-request handling: $($_.Exception.Message)" -Level 'ERROR'
    if ($Mode -eq 'Start') { Write-StartupStatus -Status 'FAILED' }
    throw
}

Write-Log '=== Starting VoiceMeeter-IdleWatcher ==='
Write-Log "IdleMinutes = $IdleMinutes | CheckInterval = ${CheckIntervalSec}s | RetryInterval = ${RetryIntervalSec}s | DebugMode = $DebugMode"
Write-Log "Primary log: $LogFile | Fallback log: $FallbackLogFile"

try {
    $dllPath = Get-VoicemeeterRemoteDll
    Write-Log "Found DLL: $dllPath"

    Initialize-VoicemeeterNativeInterop -DllPath $dllPath
    [VMRIdleWatcherNative]::CreateExternalStopEvent($StopEventName)
    $stopEventCreated = $true
    Write-Log 'Graceful stop event is ready. Run the VBS file with /stop to request a clean shutdown.'

    # Register for the display state of this interactive Windows session.
    [VMRIdleWatcherNative]::RegisterDisplayNotification()
    $displayNotificationRegistered = $true

    # Windows normally sends the current value immediately after registration.
    # Still wait briefly and explicitly report a missing initial notification.
    $displayWaitResult = [VMRIdleWatcherNative]::WaitForDisplayState($DisplayNotificationTimeoutSec * 1000)
    $displayState = [VMRIdleWatcherNative]::GetDisplayState()
    $lastLoggedDisplayState = $displayState

    if ($displayWaitResult -eq 1 -or [VMRIdleWatcherNative]::IsExitRequested()) {
        Write-Log 'Stop request received during initialization. Skipping VoiceMeeter API login.'
        Write-StartupStatus -Status 'STOPPED'
    }
    else {
        if ($displayState -lt 0) {
            Write-Log "No valid initial display-state notification received within $DisplayNotificationTimeoutSec seconds. Display state remains unknown; auto-shutdown is blocked until a valid notification arrives." -Level 'WARN'
        }

        switch ($displayState) {
            0 {
                Write-Log 'Display state: Off.'
            }
            1 {
                Write-Log 'Display state: On. VoiceMeeter auto-shutdown blocked.'
            }
            2 {
                Write-Log 'Display state: Dimmed. VoiceMeeter auto-shutdown blocked.'
            }
            default {
                # Unknown state is deliberately fail-safe: never allow shutdown.
            }
        }

        # Login is required once per watcher process. A return value of 1 means
        # the API client logged in successfully while Voicemeeter is not running.
        $login = Invoke-VoiceMeeterApiLogin

        if ($login -lt 0) {
            throw "Failed to connect to VoiceMeeter API. Return code: $login"
        }

        $loginCompleted = $true
        $watcherIsActive = $true

        # Publish the real watcher state. This feature is optional and must
        # never block startup or the main idle-monitoring function.
        Invoke-MacroButtonStateSync -DesiredState 1

        if ($login -eq 1) {
            Write-Log 'API Login succeeded; VoiceMeeter is not running yet. Waiting for startup.'
        }
        else {
            Write-Log "Successfully logged in to VoiceMeeter API (code $login)."
        }

        Write-StartupStatus -Status 'READY'

        # ==================== Main loop ====================
        while (-not [VMRIdleWatcherNative]::IsExitRequested()) {
            try {
                # Reconcile the configured MacroButtons display state with the
                # watcher's real process state. STATEONLY does not run its macro.
                Invoke-MacroButtonStateSync -DesiredState 1

                # 1. Retrieve user idle time and current display power state.
                $idleMs = [VMRIdleWatcherNative]::GetIdleMilliseconds()
                $idleSec = [math]::Round($idleMs / 1000, 1)
                $displayState = [VMRIdleWatcherNative]::GetDisplayState()

                if ($displayState -ne $lastLoggedDisplayState) {
                    switch ($displayState) {
                        0 {
                            Write-Log 'Display state changed: Off. VoiceMeeter auto-shutdown permitted upon reaching idle threshold.'
                        }
                        1 {
                            Write-Log 'Display state changed: On. VoiceMeeter auto-shutdown blocked.'
                        }
                        2 {
                            Write-Log 'Display state changed: Dimmed. VoiceMeeter auto-shutdown blocked.'
                        }
                        default {
                            Write-Log 'Display state changed to unknown. VoiceMeeter auto-shutdown remains blocked.' -Level 'WARN'
                        }
                    }

                    $lastLoggedDisplayState = $displayState
                }

                Write-Log "Current idle: ${idleSec}s (threshold: $($IdleMinutes * 60)s) | DisplayState = $displayState | shutdownSentThisIdle = $shutdownSentThisIdle | engineStoppedAfterShutdown = $engineStoppedAfterShutdown" -Level 'DEBUG'

                # 2. User activity starts a new cycle and resets state flags.
                if ($idleMs -lt $thresholdMs) {
                    if ($shutdownSentThisIdle) {
                        Write-Log "User activity detected (idle = ${idleSec}s). Resetting idle cycle flags."
                    }

                    $shutdownSentThisIdle = $false
                    $engineStoppedAfterShutdown = $false
                    $lastShutdownCommandAt = [datetime]::MinValue
                    $nextApiAttempt = [datetime]::MinValue
                    $connectionWarningLogged = $false
                    $shutdownWarningLogged = $false
                }
                # 3. Query API only after idle threshold is reached, display is off,
                #    and retry/probe backoff has elapsed. This continues after a
                #    successful Shutdown so a later restart in the same idle cycle
                #    can be detected and shut down again.
                elseif (($displayState -eq 0) -and ((Get-Date) -ge $nextApiAttempt)) {
                    Write-Log "Idle threshold reached (${idleSec}s). Checking VoiceMeeter availability..." -Level 'DEBUG'

                    # 4. Recover a broken API client session before querying the engine.
                    if (-not $loginCompleted) {
                        $relogin = Invoke-VoiceMeeterApiLogin

                        if ($relogin -ge 0) {
                            $loginCompleted = $true
                            $connectionWarningLogged = $true
                            if ($relogin -eq 1) {
                                Write-Log 'VoiceMeeter API session re-established; the engine is not running yet.'
                            }
                            else {
                                Write-Log "VoiceMeeter API session re-established (Login code $relogin)."
                            }
                            $nextApiAttempt = (Get-Date).AddSeconds($PostShutdownProbeIntervalSec)
                        }
                        else {
                            Write-Log "VoiceMeeter API Login recovery failed (code $relogin). Retrying in ${RetryIntervalSec}s." -Level 'ERROR'
                            $nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
                        }
                    }
                    else {
                        $connection = [VMRIdleWatcherNative]::IsParametersDirty()

                        if ($connection -eq -2) {
                            # -2 means the server is absent. Keep the existing login
                            # session because the API supports engine restarts in-session.
                            if ($shutdownSentThisIdle) {
                                if (-not $engineStoppedAfterShutdown) {
                                    Write-Log 'VoiceMeeter stopped after the previous Shutdown command. Monitoring for a restart during this idle period.'
                                    $engineStoppedAfterShutdown = $true
                                }
                                else {
                                    Write-Log 'VoiceMeeter remains stopped. Monitoring for a restart during this idle period.' -Level 'DEBUG'
                                }
                                $connectionWarningLogged = $true
                                $nextApiAttempt = (Get-Date).AddSeconds($PostShutdownRestartProbeIntervalSec)
                            }
                            else {
                                if (-not $connectionWarningLogged) {
                                    Write-Log "VoiceMeeter is not running (IsParametersDirty = -2). Nothing to shut down. Next check in ${EngineAbsentProbeIntervalSec}s."
                                    $connectionWarningLogged = $true
                                }
                                else {
                                    Write-Log 'VoiceMeeter is still not running (IsParametersDirty = -2).' -Level 'DEBUG'
                                }
                                $nextApiAttempt = (Get-Date).AddSeconds($EngineAbsentProbeIntervalSec)
                            }
                        }
                        elseif ($connection -eq -1) {
                            # -1 is an unexpected client/API error. Close the broken
                            # client session; the next pass performs a fresh Login.
                            if (-not $connectionWarningLogged) {
                                Write-Log 'VoiceMeeter API returned -1 (unexpected client error). Closing the client session before re-login.' -Level 'WARN'
                                $connectionWarningLogged = $true
                            }
                            else {
                                Write-Log 'VoiceMeeter API still returns -1. Attempting client-session recovery.' -Level 'DEBUG'
                            }

                            try {
                                $recoveryLogout = [VMRIdleWatcherNative]::Logout()
                                # Invalidate the local session state even if Logout reports an
                                # error. The next fresh Login can return -2, which is handled by
                                # Invoke-VoiceMeeterApiLogin with its required Logout-and-retry path.
                                $loginCompleted = $false

                                if ($recoveryLogout -ge 0) {
                                    Write-Log "VoiceMeeter API client Logout succeeded during recovery (code $recoveryLogout). Re-login scheduled."
                                }
                                else {
                                    Write-Log "VoiceMeeter API recovery Logout returned error $recoveryLogout. Local session state invalidated; a fresh Login will be attempted and may request another Logout." -Level 'ERROR'
                                }
                                $nextApiAttempt = (Get-Date).AddSeconds($ApiSessionRecoveryRetryIntervalSec)
                            }
                            catch {
                                # Even when the native Logout call throws, do not remain
                                # permanently marked as logged in. Try a fresh Login; the
                                # helper resolves Login -2 by performing Logout first.
                                $loginCompleted = $false
                                Write-Log "Exception during VoiceMeeter API recovery Logout: $($_.Exception.Message). Local session state invalidated; fresh Login scheduled." -Level 'ERROR'
                                $nextApiAttempt = (Get-Date).AddSeconds($ApiSessionRecoveryRetryIntervalSec)
                            }
                        }
                        elseif ($connection -lt 0) {
                            if (-not $connectionWarningLogged) {
                                Write-Log "VoiceMeeter API returned unexpected error $connection. Retrying in ${RetryIntervalSec}s." -Level 'WARN'
                                $connectionWarningLogged = $true
                            }
                            else {
                                Write-Log "VoiceMeeter API still returns unexpected error $connection." -Level 'DEBUG'
                            }
                            $nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
                        }
                        else {
                            if ($connectionWarningLogged) {
                                Write-Log 'Connection to VoiceMeeter restored.'
                                $connectionWarningLogged = $false
                            }

                            $secondsSinceShutdownCommand = [double]::PositiveInfinity
                            if ($lastShutdownCommandAt -ne [datetime]::MinValue) {
                                $secondsSinceShutdownCommand = ((Get-Date) - $lastShutdownCommandAt).TotalSeconds
                            }

                            # A fast stop/restart can happen between two probes, so -2
                            # may never be observed. Retry if the API remains online
                            # beyond the confirmation window after an accepted command.
                            $unconfirmedShutdownRetry = (
                                $shutdownSentThisIdle -and
                                (-not $engineStoppedAfterShutdown) -and
                                ($secondsSinceShutdownCommand -ge $PostShutdownConfirmationTimeoutSec)
                            )
                            $shouldSendShutdown = (-not $shutdownSentThisIdle) -or $engineStoppedAfterShutdown -or $unconfirmedShutdownRetry

                            if ($shouldSendShutdown) {
                                $isRestartAfterShutdown = $shutdownSentThisIdle -and $engineStoppedAfterShutdown

                                if ($isRestartAfterShutdown) {
                                    Write-Log 'VoiceMeeter has restarted during the same idle period. Sending Command.Shutdown again.'
                                }
                                elseif ($unconfirmedShutdownRetry) {
                                    Write-Log 'VoiceMeeter API remained available after the previous Shutdown request; re-sending Command.Shutdown in the same idle period.' -Level 'WARN'
                                }

                                # Re-verify conditions immediately before dispatching the command.
                                $idleMsNow = [VMRIdleWatcherNative]::GetIdleMilliseconds()
                                $displayStateNow = [VMRIdleWatcherNative]::GetDisplayState()

                                if (($idleMsNow -lt $thresholdMs) -or ($displayStateNow -ne 0)) {
                                    Write-Log "Conditions changed prior to Shutdown (idle = $([math]::Round($idleMsNow / 1000, 1))s, DisplayState = $displayStateNow). Aborting command." -Level 'DEBUG'
                                    $nextApiAttempt = (Get-Date).AddSeconds($CheckIntervalSec)
                                }
                                elseif ([VMRIdleWatcherNative]::IsExitRequested()) {
                                    Write-Log 'Stop request received before Command.Shutdown. Aborting command and leaving the main loop.'
                                    break
                                }
                                else {
                                    Write-Log "Engine available (IsParametersDirty = $connection). Sending Command.Shutdown..." -Level 'DEBUG'
                                    $result = [VMRIdleWatcherNative]::SetParameterFloat('Command.Shutdown', [single]1)

                                    if ($result -ge 0) {
                                        if ($isRestartAfterShutdown) {
                                            Write-Log "Repeated Command.Shutdown = 1 sent successfully after VoiceMeeter restart (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
                                        }
                                        elseif ($unconfirmedShutdownRetry) {
                                            Write-Log "Repeated Command.Shutdown = 1 sent after no stop notification was observed (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
                                        }
                                        else {
                                            Write-Log "Command.Shutdown = 1 sent successfully (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
                                        }

                                        $shutdownSentThisIdle = $true
                                        $engineStoppedAfterShutdown = $false
                                        $lastShutdownCommandAt = Get-Date
                                        $shutdownWarningLogged = $false
                                        $connectionWarningLogged = $false

                                        # Always verify the result promptly, including after a retry.
                                        # A 30-second delay here could miss a fast stop/restart cycle.
                                        $nextApiAttempt = (Get-Date).AddSeconds($PostShutdownProbeIntervalSec)
                                    }
                                    else {
                                        if (-not $shutdownWarningLogged) {
                                            Write-Log "SetParameterFloat failed (code $result). Retrying in ${RetryIntervalSec}s." -Level 'WARN'
                                            $shutdownWarningLogged = $true
                                        }
                                        else {
                                            Write-Log "SetParameterFloat still returning error $result." -Level 'DEBUG'
                                        }
                                        $nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
                                    }
                                }
                            }
                            else {
                                Write-Log 'VoiceMeeter still responds after the previous Shutdown request. Waiting for stop confirmation.' -Level 'DEBUG'
                                $nextApiAttempt = (Get-Date).AddSeconds($PostShutdownProbeIntervalSec)
                            }
                        }
                    }
                }
            }
            catch {
                Write-Log "Error in main loop: $($_.Exception.Message)" -Level 'ERROR'
                $nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
            }

            # This wait is interrupted by the named stop event, allowing the
            # main PowerShell thread to enter finally promptly.
            # Sleep only until the next scheduled API probe, capped by the normal
            # loop interval. This keeps fast restart checks responsive without spinning.
            $waitMilliseconds = $CheckIntervalSec * 1000
            if ($nextApiAttempt -gt (Get-Date)) {
                $millisecondsUntilApiAttempt = [int][math]::Ceiling(($nextApiAttempt - (Get-Date)).TotalMilliseconds)
                $waitMilliseconds = [Math]::Min($waitMilliseconds, [Math]::Max(100, $millisecondsUntilApiAttempt))
            }

            if ([VMRIdleWatcherNative]::WaitForExit($waitMilliseconds)) {
                Write-Log 'Stop request received. Leaving main loop for graceful cleanup.'
                break
            }
        }
    }
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
    if (-not $script:StartupStatusWritten) { Write-StartupStatus -Status 'FAILED' }
    throw
}
finally {
    Write-Log 'Graceful cleanup started.'

    try {
        # Show OFF before logging out when a graceful cleanup is possible.
        # This optional cosmetic update must never interfere with cleanup.
        if ($watcherIsActive) {
            Invoke-MacroButtonStateSync -DesiredState 0 -Force
            $watcherIsActive = $false
        }
    }
    catch {
        Write-Log "Optional MacroButtons OFF synchronization failed during cleanup: $($_.Exception.Message)" -Level 'DEBUG'
    }

    try {
        # 1. End the VoiceMeeter API session before disposing notification resources.
        if ($loginCompleted) {
            try {
                $logout = [VMRIdleWatcherNative]::Logout()
                if ($logout -lt 0) {
                    Write-Log "VoiceMeeter API Logout failed (code $logout)." -Level 'ERROR'
                }
                else {
                    Write-Log "Logout succeeded (code $logout)."
                }
            }
            catch {
                Write-Log "Exception during VoiceMeeter API Logout: $($_.Exception.Message)" -Level 'ERROR'
            }
        }
        else {
            Write-Log 'VoiceMeeter API Logout skipped because Login did not complete.' -Level 'DEBUG'
        }

        # 2. Unregister display power-state notifications.
        if ($displayNotificationRegistered) {
            try {
                [VMRIdleWatcherNative]::UnregisterDisplayNotification()
                $displayNotificationRegistered = $false
                Write-Log 'Display state notifications unregistered.'
            }
            catch {
                Write-Log "Failed to unregister display state notifications: $($_.Exception.Message)" -Level 'ERROR'
            }
        }

        # 3. Close the stop event before releasing the mutex.
        if ($stopEventCreated) {
            try {
                [VMRIdleWatcherNative]::DisposeExternalStopEvent()
                $stopEventCreated = $false
                Write-Log 'Graceful stop event closed.'
            }
            catch {
                Write-Log "Failed to close graceful stop event: $($_.Exception.Message)" -Level 'ERROR'
            }
        }

        Write-Log 'Graceful cleanup operations finished. Releasing the single-instance mutex.'
    }
    catch {
        # An unexpected cleanup error must not skip the mutex-release attempt.
        Write-Log "Unexpected error in graceful cleanup: $($_.Exception.Message)" -Level 'ERROR'
    }
    finally {
        # 4. Release the mutex last. The Stop controller treats a normal mutex
        #    hand-off as confirmation that this process has completed its cleanup path.
        if ($null -ne $watcherMutex) {
            if ($mutexOwned) {
                try {
                    $watcherMutex.ReleaseMutex()
                    $mutexOwned = $false
                    Write-Log 'Single-instance mutex released successfully.'
                }
                catch {
                    Write-Log "Failed to release single-instance mutex: $($_.Exception.Message)" -Level 'ERROR'
                }
            }

            try {
                $watcherMutex.Dispose()
            }
            catch {
                Write-Log "Failed to dispose single-instance mutex handle: $($_.Exception.Message)" -Level 'WARN'
            }
            $watcherMutex = $null
        }

        Write-Log 'Watcher process cleanup sequence has ended.'
    }
}
