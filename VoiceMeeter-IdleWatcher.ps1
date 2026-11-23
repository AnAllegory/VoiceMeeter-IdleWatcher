[CmdletBinding()]
param(
	[ValidateSet('Start', 'Stop')]
	[string]$Mode = 'Start',

	[ValidateRange(1, 60)]
	[Nullable[int]]$IdleMinutes = $null,

	[switch]$DebugMode,

	[string]$StartupStatusFile = ''
)

$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -eq '.') {
	throw 'VoiceMeeter-IdleWatcher.ps1 cannot be dot-sourced. Run it in a fresh powershell.exe process with -File.'
}

# ==================== Settings & Config ====================
$ScriptDir = $PSScriptRoot
$ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
if ([string]::IsNullOrWhiteSpace($ScriptBaseName)) {
	$ScriptBaseName = 'VoiceMeeter-IdleWatcher'
}

$ConfigFile = Join-Path -Path $ScriptDir -ChildPath ($ScriptBaseName + '.psd1')
$ConfigData = @{}
$ConfigLoadError = $null
if ([System.IO.File]::Exists($ConfigFile)) {
	try {
		$LoadedConfig = Import-PowerShellDataFile -Path $ConfigFile -ErrorAction Stop
		if ($LoadedConfig -isnot [hashtable]) {
			throw 'Configuration file must contain a hashtable.'
		}
		$ConfigData = $LoadedConfig
	}
	catch {
		$ConfigLoadError = $_.Exception.Message
	}
}

function Get-ConfigValue {
	param(
		[hashtable]$Map,
		[string]$Key,
		$DefaultValue
	)

	if ($Map.ContainsKey($Key) -and ($null -ne $Map[$Key])) {
		return $Map[$Key]
	}
	return $DefaultValue
}

function Get-ValidatedConfigInt {
	param(
		[hashtable]$Map,
		[string]$Key,
		[int]$DefaultValue,
		[int]$Minimum,
		[int]$Maximum
	)

	$rawValue = Get-ConfigValue -Map $Map -Key $Key -DefaultValue $DefaultValue
	$parsedValue = 0
	if (($rawValue -is [bool]) -or (-not [int]::TryParse([string]$rawValue, [ref]$parsedValue))) {
		throw "Configuration '$Key' must be an integer between $Minimum and $Maximum. Value: '$rawValue'."
	}
	if (($parsedValue -lt $Minimum) -or ($parsedValue -gt $Maximum)) {
		throw "Configuration '$Key' must be between $Minimum and $Maximum. Value: $parsedValue."
	}
	return $parsedValue
}

function Get-ValidatedConfigLong {
	param(
		[hashtable]$Map,
		[string]$Key,
		[long]$DefaultValue,
		[long]$Minimum,
		[long]$Maximum
	)

	$rawValue = Get-ConfigValue -Map $Map -Key $Key -DefaultValue $DefaultValue
	$parsedValue = [long]0
	if (($rawValue -is [bool]) -or (-not [long]::TryParse([string]$rawValue, [ref]$parsedValue))) {
		throw "Configuration '$Key' must be an integer between $Minimum and $Maximum. Value: '$rawValue'."
	}
	if (($parsedValue -lt $Minimum) -or ($parsedValue -gt $Maximum)) {
		throw "Configuration '$Key' must be between $Minimum and $Maximum. Value: $parsedValue."
	}
	return $parsedValue
}

function Get-ValidatedConfigString {
	param(
		[hashtable]$Map,
		[string]$Key,
		[string]$DefaultValue
	)

	$value = [string](Get-ConfigValue -Map $Map -Key $Key -DefaultValue $DefaultValue)
	if ([string]::IsNullOrWhiteSpace($value) -or ($value.Length -gt 240)) {
		throw "Configuration '$Key' must be a non-empty string of at most 240 characters."
	}
	return $value
}

$LogFile = Join-Path -Path $ScriptDir -ChildPath ($ScriptBaseName + '.log')
$LocalLogRoot = $env:LOCALAPPDATA
if ([string]::IsNullOrWhiteSpace($LocalLogRoot)) {
	$LocalLogRoot = [System.IO.Path]::GetTempPath()
}
$FallbackLogDirectory = Join-Path -Path $LocalLogRoot -ChildPath 'VoiceMeeter-IdleWatcher'
$FallbackLogFile = Join-Path -Path $FallbackLogDirectory -ChildPath ($ScriptBaseName + '-fallback.log')
$EmergencyLogFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'VoiceMeeter-IdleWatcher-emergency.log'

# ==================== Module imports & bootstrap logging ====================
$SupportModulePath = Join-Path -Path $ScriptDir -ChildPath 'VoiceMeeter-IdleWatcher.Support.psm1'
$InteropModulePath = Join-Path -Path $ScriptDir -ChildPath 'VoiceMeeter-IdleWatcher.Interop.psm1'
$MacroButtonsModulePath = Join-Path -Path $ScriptDir -ChildPath 'VoiceMeeter-IdleWatcher.MacroButtons.psm1'

Import-Module -Name $SupportModulePath -Force -DisableNameChecking -ErrorAction Stop
Import-Module -Name $InteropModulePath -Force -DisableNameChecking -ErrorAction Stop
Import-Module -Name $MacroButtonsModulePath -Force -DisableNameChecking -ErrorAction Stop

$SupportConfig = @{
	LogFile = $LogFile
	FallbackLogFile = $FallbackLogFile
	EmergencyLogFile = $EmergencyLogFile
	MaxLogSize = 500KB
	FallbackMaxLogSize = 2MB
	LogMutexName = 'Local\VoiceMeeter-IdleWatcher.Log'
	DebugMode = $false
	StartupStatusFile = $StartupStatusFile
}
Initialize-WatcherSupport @SupportConfig

if ($null -ne $ConfigLoadError) {
	Write-Log "Failed to load config file '$ConfigFile': $ConfigLoadError" -Level 'ERROR'
	Write-StartupStatus -Status 'FAILED'
	throw "Failed to load config file '$ConfigFile': $ConfigLoadError"
}

try {
	$ResolvedIdleMinutes = Get-ValidatedConfigInt -Map $ConfigData -Key 'IdleMinutes' -DefaultValue 8 -Minimum 1 -Maximum 60
	if ($PSBoundParameters.ContainsKey('IdleMinutes')) {
		if ($null -eq $IdleMinutes) {
			throw 'IdleMinutes cannot be null when explicitly provided.'
		}
		$ResolvedIdleMinutes = [int]$IdleMinutes
	}

	if ($ConfigData.ContainsKey('DebugMode') -and ($ConfigData['DebugMode'] -isnot [bool])) {
		throw "Configuration 'DebugMode' must be a Boolean value."
	}
	$ConfigDebugMode = [bool](Get-ConfigValue -Map $ConfigData -Key 'DebugMode' -DefaultValue $false)
	if ($PSBoundParameters.ContainsKey('DebugMode')) {
		$ResolvedDebugMode = [bool]$DebugMode.IsPresent
	}
	else {
		$ResolvedDebugMode = $ConfigDebugMode
	}

	$MaxLogSize = Get-ValidatedConfigLong -Map $ConfigData -Key 'MaxLogSizeBytes' -DefaultValue 500KB -Minimum 4096 -Maximum 104857600
	$FallbackMaxLogSize = Get-ValidatedConfigLong -Map $ConfigData -Key 'FallbackMaxLogSizeBytes' -DefaultValue 2MB -Minimum 4096 -Maximum 209715200
	$WatcherVersion = '1.0.5'
	$ShutdownCommandLimit = Get-ValidatedConfigInt -Map $ConfigData -Key 'ShutdownCommandLimit' -DefaultValue 3 -Minimum 1 -Maximum 10
	$CheckIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'CheckIntervalSec' -DefaultValue 10 -Minimum 1 -Maximum 60
	$RetryIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'RetryIntervalSec' -DefaultValue 30 -Minimum 1 -Maximum 600
	$EngineAbsentProbeIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'EngineAbsentProbeIntervalSec' -DefaultValue 3 -Minimum 1 -Maximum 60
	$DisplayNotificationTimeoutSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'DisplayNotificationTimeoutSec' -DefaultValue 5 -Minimum 1 -Maximum 30
	$PostShutdownProbeIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'PostShutdownProbeIntervalSec' -DefaultValue 1 -Minimum 1 -Maximum 30
	$PostShutdownRestartProbeIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'PostShutdownRestartProbeIntervalSec' -DefaultValue 3 -Minimum 1 -Maximum 60
	$PostShutdownConfirmationTimeoutSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'PostShutdownConfirmationTimeoutSec' -DefaultValue 5 -Minimum 1 -Maximum 120
	$ApiSessionRecoveryRetryIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'ApiSessionRecoveryRetryIntervalSec' -DefaultValue 5 -Minimum 1 -Maximum 120
	$StopWaitTimeoutSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'StopWaitTimeoutSec' -DefaultValue 20 -Minimum 1 -Maximum 120

	$MacroButtonLogicalIndex = Get-ValidatedConfigInt -Map $ConfigData -Key 'MacroButtonLogicalIndex' -DefaultValue 1 -Minimum -1 -Maximum 79
	$MacroButtonSyncIntervalSec = Get-ValidatedConfigInt -Map $ConfigData -Key 'MacroButtonSyncIntervalSec' -DefaultValue 10 -Minimum 1 -Maximum 300

	$MutexName = Get-ValidatedConfigString -Map $ConfigData -Key 'MutexName' -DefaultValue 'Local\VoiceMeeter-IdleWatcher'
	$StopEventName = Get-ValidatedConfigString -Map $ConfigData -Key 'StopEventName' -DefaultValue 'Local\VoiceMeeter-IdleWatcher.Stop'
	$SyncEventName = Get-ValidatedConfigString -Map $ConfigData -Key 'SyncEventName' -DefaultValue 'Local\VoiceMeeter-IdleWatcher.Sync'
	$LogMutexName = Get-ValidatedConfigString -Map $ConfigData -Key 'LogMutexName' -DefaultValue 'Local\VoiceMeeter-IdleWatcher.Log'
}
catch {
	Write-Log "Configuration validation failed: $($_.Exception.Message)" -Level 'ERROR'
	Write-StartupStatus -Status 'FAILED'
	throw
}

$SupportConfig = @{
	LogFile = $LogFile
	FallbackLogFile = $FallbackLogFile
	EmergencyLogFile = $EmergencyLogFile
	MaxLogSize = $MaxLogSize
	FallbackMaxLogSize = $FallbackMaxLogSize
	LogMutexName = $LogMutexName
	DebugMode = $ResolvedDebugMode
	StartupStatusFile = $StartupStatusFile
}
Initialize-WatcherSupport @SupportConfig

Initialize-MacroButtonConfig -LogicalIndex $MacroButtonLogicalIndex -SyncIntervalSec $MacroButtonSyncIntervalSec

Write-Log "Resolved configuration: IdleMinutes=$ResolvedIdleMinutes; CheckIntervalSec=$CheckIntervalSec; RetryIntervalSec=$RetryIntervalSec; EngineAbsentProbeIntervalSec=$EngineAbsentProbeIntervalSec; DisplayNotificationTimeoutSec=$DisplayNotificationTimeoutSec; PostShutdownProbeIntervalSec=$PostShutdownProbeIntervalSec; PostShutdownRestartProbeIntervalSec=$PostShutdownRestartProbeIntervalSec; PostShutdownConfirmationTimeoutSec=$PostShutdownConfirmationTimeoutSec; ApiSessionRecoveryRetryIntervalSec=$ApiSessionRecoveryRetryIntervalSec; StopWaitTimeoutSec=$StopWaitTimeoutSec; ShutdownCommandLimit=$ShutdownCommandLimit; MacroButtonLogicalIndex=$MacroButtonLogicalIndex; MacroButtonSyncIntervalSec=$MacroButtonSyncIntervalSec; DebugMode=$ResolvedDebugMode"
# ==================== Runtime state and lifecycle resources ====================
$thresholdMs = [uint32]($ResolvedIdleMinutes * 60 * 1000)
$macroButtonRefreshDelayMs = 1000
$shutdownSentThisIdle = $false
$shutdownCommandsSinceEngineStop = 0
$shutdownRetryExhaustedLogged = $false
$engineStoppedAfterShutdown = $false
$lastShutdownCommandAt = [datetime]::MinValue
$nextApiAttempt = [datetime]::MinValue
$nextEngineStateProbeAt = [datetime]::MinValue
$loginCompleted = $false
$voiceMeeterIsRunning = $false
# Track an OFF state sent before Command.Shutdown while the Remote API is still available.
$macroButtonOffForPendingShutdown = $false
$watcherIsActive = $false
$connectionWarningLogged = $false
$shutdownWarningLogged = $false
$displayNotificationRegistered = $false
$stopEventCreated = $false
$syncEventCreated = $false
$lastLoggedDisplayState = -999
$lastLoggedApiProbeCategory = 'NotChecked'
$apiEngineStateKnown = $false
$lastStatusSummaryAt = [datetime]::MinValue

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
		$mutexOwned = $true
		$mutexWasAbandoned = $true
	}

	if ($Mode -eq 'Stop') {
		$stopFailed = $false

		if ($mutexOwned) {
			if ($mutexWasAbandoned) {
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

			Write-StartupStatus -Status 'STOPPED'
			return
		}

		Write-Log 'Graceful stop requested. Signalling the running watcher...'
		$stopRequestSent = Send-StopRequestToExistingWatcher -EventName $StopEventName -TimeoutSec $StopWaitTimeoutSec

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

		Write-StartupStatus -Status 'STOPPED'
		return
	}

	if (-not $mutexOwned) {
		if ($MacroButtonLogicalIndex -ge 0) {
			$syncRequestSent = Send-SyncRequestToExistingWatcher -EventName $SyncEventName
			if ($syncRequestSent) {
				Write-Log 'Watcher is already running. Requested an immediate MacroButtons display-state refresh; no second instance was created.'
			}
			else {
				Write-Log 'Watcher is already running. This Start request will not create a second instance.'
			}
		}
		else {
			Write-Log 'Watcher is already running. This Start request will not create a second instance.'
		}
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
			try {
				$watcherMutex.ReleaseMutex()
			}
			catch {
				Write-Log "Failed to release single-instance mutex while handling startup failure: $($_.Exception.Message)" -Level 'WARN'
			}
		}

		$watcherMutex.Dispose()
		$watcherMutex = $null
	}

	Write-Log "Failed during single-instance or stop-request handling: $($_.Exception.Message)" -Level 'ERROR'

	if (-not (Test-StartupStatusWritten)) {
		Write-StartupStatus -Status 'FAILED'
	}

	throw
}

Write-Log "=== Starting VoiceMeeter-IdleWatcher v$WatcherVersion ==="
Write-Log "IdleMinutes = $ResolvedIdleMinutes | CheckInterval = ${CheckIntervalSec}s | RetryInterval = ${RetryIntervalSec}s | ShutdownCommandLimit = $ShutdownCommandLimit | DebugMode = $ResolvedDebugMode"
Write-Log "MacroButtons indicator policy: ON while VoiceMeeter is confirmed available; STATEONLY only; button ID = $MacroButtonLogicalIndex; periodic sync = ${MacroButtonSyncIntervalSec}s."
Write-Log "Primary log: $LogFile | Fallback log: $FallbackLogFile"

try {
	$dllPath = Get-VoicemeeterRemoteDll
	Write-Log "Found DLL: $dllPath"

	Initialize-VoicemeeterNativeInterop -DllPath $dllPath
	[VMRIdleWatcherNative]::CreateExternalStopEvent($StopEventName)
	$stopEventCreated = $true

	if ($MacroButtonLogicalIndex -ge 0) {
		try {
			[VMRIdleWatcherNative]::CreateExternalSyncEvent($SyncEventName)
			$syncEventCreated = $true
		}
		catch {
			Write-Log "Optional MacroButtons refresh event could not be created: $($_.Exception.Message). Periodic refresh remains available." -Level 'DEBUG'
		}
	}

	Write-Log 'Graceful stop event is ready. Run the VBS file with /stop to request a clean shutdown.'

	[VMRIdleWatcherNative]::RegisterDisplayNotification()
	$displayNotificationRegistered = $true

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
			0 { Write-Log 'Display state: Off.' }
			1 { Write-Log 'Display state: On. VoiceMeeter auto-shutdown blocked.' }
			2 { Write-Log 'Display state: Dimmed. VoiceMeeter auto-shutdown blocked.' }
			default { }
		}

		$login = Invoke-VoiceMeeterApiLogin
		if ($login -lt 0) {
			throw "Failed to connect to VoiceMeeter API. Return code: $login"
		}

		$loginCompleted = $true
		$voiceMeeterIsRunning = ($login -eq 0)
		$apiEngineStateKnown = $true
		$watcherIsActive = $true
		if ($voiceMeeterIsRunning) {
			Invoke-MacroButtonStateSync -DesiredState 1 -Force
		}
		else {
			Write-Log 'Initial MacroButtons synchronization skipped because VoiceMeeter is not running and the Remote API cannot accept a button-state write.' -Level 'DEBUG'
		}
		$nextEngineStateProbeAt = (Get-Date).AddSeconds($CheckIntervalSec)

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
				if ($loginCompleted -and ((Get-Date) -ge $nextEngineStateProbeAt)) {
					$engineStateProbe = [VMRIdleWatcherNative]::IsParametersDirty()
					$nextEngineStateProbeAt = (Get-Date).AddSeconds($CheckIntervalSec)
					Write-Log "IsParametersDirty probe returned $engineStateProbe." -Level 'DEBUG'

					$apiProbeCategory = if ($engineStateProbe -ge 0) {
						'Available'
					}
					elseif ($engineStateProbe -eq -2) {
						'NoServer'
					}
					elseif ($engineStateProbe -eq -1) {
						'UnexpectedClientError'
					}
					else {
						"UnexpectedCode:$engineStateProbe"
					}

					if ($apiProbeCategory -ne $lastLoggedApiProbeCategory) {
						switch -Wildcard ($apiProbeCategory) {
							'Available' {
								Write-Log "Remote API is available (IsParametersDirty=$engineStateProbe)."
							}
							'NoServer' {
								Write-Log 'Remote API reports no server (IsParametersDirty=-2). VoiceMeeter is not currently confirmed available.' -Level 'WARN'
							}
							'UnexpectedClientError' {
								Write-Log 'Remote API returned -1 (unexpected client error). The previous engine state is retained until a valid probe resolves it.' -Level 'WARN'
							}
							default {
								Write-Log "Remote API returned an undocumented negative result ($engineStateProbe). The previous engine state is retained." -Level 'WARN'
							}
						}
						$lastLoggedApiProbeCategory = $apiProbeCategory
					}

					if ($engineStateProbe -ge 0) {
						$apiEngineStateKnown = $true
						if (-not $voiceMeeterIsRunning) {
							$voiceMeeterIsRunning = $true
							$macroButtonOffForPendingShutdown = $false
							Write-Log 'VoiceMeeter engine availability confirmed. Requesting MacroButtons logical button ON.'
							Invoke-MacroButtonStateSync -DesiredState 1 -Force
						}
					}
					elseif ($engineStateProbe -eq -2) {
						$apiEngineStateKnown = $true
						if ($voiceMeeterIsRunning) {
							$voiceMeeterIsRunning = $false
							if ($macroButtonOffForPendingShutdown) {
								Write-Log "VoiceMeeter engine stop detected. MacroButton OFF command had already been accepted before the watcher's own Shutdown command."
							}
							else {
								Write-Log 'VoiceMeeter engine/API stop detected (Remote API code -2). The server is unavailable, so MacroButtons OFF cannot be sent; the last accepted state is retained.' -Level 'WARN'
							}
						}
					}
					else {
						$apiEngineStateKnown = $false
						# -1 and undocumented errors mean API/client state is unknown, not that the engine stopped.
						# Keep the last confirmed engine state and do not request a false MacroButton OFF.
					}
				}

				if ($apiEngineStateKnown -and $voiceMeeterIsRunning) {
					$macroButtonDesiredState = if (-not $macroButtonOffForPendingShutdown) { 1 } else { 0 }
					$macroButtonSyncResult = Invoke-MacroButtonStateSync -DesiredState $macroButtonDesiredState -PassThru
					if ($macroButtonSyncResult -eq $true) {
						$macroButtonOffForPendingShutdown = ($macroButtonDesiredState -eq 0)
					}
				}
				elseif (-not $apiEngineStateKnown) {
					Write-Log 'Skipping periodic MacroButtons synchronization because VoiceMeeter/API state is unknown.' -Level 'DEBUG'
				}
				else {
					Write-Log 'Skipping periodic MacroButtons synchronization because VoiceMeeter is confirmed stopped and the Remote API server is unavailable.' -Level 'DEBUG'
				}

				$idleMs = [VMRIdleWatcherNative]::GetIdleMilliseconds()
				$idleSec = [math]::Round($idleMs / 1000, 1)
				$displayState = [VMRIdleWatcherNative]::GetDisplayState()

				$summaryNow = Get-Date
				if (($lastStatusSummaryAt -eq [datetime]::MinValue) -or (($summaryNow - $lastStatusSummaryAt).TotalSeconds -ge 300)) {
					$apiStateSummary = if (-not $apiEngineStateKnown) {
						'Unknown'
					}
					elseif ($voiceMeeterIsRunning) {
						'Available / VoiceMeeter running'
					}
					else {
						'No running VoiceMeeter engine confirmed'
					}

					$macroButtonDesiredSummary = if ($MacroButtonLogicalIndex -lt 0) {
						'Disabled'
					}
					elseif (-not $apiEngineStateKnown) {
						'Unknown; writes paused'
					}
					elseif ($macroButtonOffForPendingShutdown -or (-not $voiceMeeterIsRunning)) {
						'OFF'
					}
					else {
						'ON'
					}

					$macroButtonStatus = Get-MacroButtonSyncStatus
					$macroButtonLastAccepted = if ($null -eq $macroButtonStatus.LastSuccessfulState) {
						'None'
					}
					elseif ($macroButtonStatus.LastSuccessfulState -eq 1) {
						'ON'
					}
					else {
						'OFF'
					}
					$macroButtonLastAcceptedAt = if ($null -eq $macroButtonStatus.LastSuccessfulAt) {
						'Never'
					}
					else {
						$macroButtonStatus.LastSuccessfulAt.ToString('yyyy-MM-dd HH:mm:ss')
					}

					Write-Log "Status snapshot: API=$apiStateSummary; Idle=$([math]::Round($idleMs / 1000, 1))s/$($ResolvedIdleMinutes * 60)s; DisplayState=$displayState; ShutdownSentThisIdle=$shutdownSentThisIdle; ShutdownCommandsSinceLastEngineStop=$shutdownCommandsSinceEngineStop; MacroButton[$MacroButtonLogicalIndex]: Desired=$macroButtonDesiredSummary; LastAccepted=$macroButtonLastAccepted; WriterStatus=$($macroButtonStatus.WriteStatus); LastAcceptedAt=$macroButtonLastAcceptedAt."
					$lastStatusSummaryAt = $summaryNow
				}

				if ($apiEngineStateKnown -and $voiceMeeterIsRunning -and $macroButtonOffForPendingShutdown -and ($displayState -ne 0)) {
					Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru | Out-Null
					$macroButtonOffForPendingShutdown = $false
				}

				if ($displayState -ne $lastLoggedDisplayState) {
					switch ($displayState) {
						0 { Write-Log 'Display state changed: Off. VoiceMeeter auto-shutdown permitted upon reaching idle threshold.' }
						1 { Write-Log 'Display state changed: On. VoiceMeeter auto-shutdown blocked.' }
						2 { Write-Log 'Display state changed: Dimmed. VoiceMeeter auto-shutdown blocked.' }
						default { Write-Log 'Display state changed to unknown. VoiceMeeter auto-shutdown remains blocked.' -Level 'WARN' }
					}
					$lastLoggedDisplayState = $displayState
				}

				Write-Log "Current idle: ${idleSec}s (threshold: $($ResolvedIdleMinutes * 60)s) | DisplayState = $displayState | shutdownSentThisIdle = $shutdownSentThisIdle | engineStoppedAfterShutdown = $engineStoppedAfterShutdown" -Level 'DEBUG'

				if ($idleMs -lt $thresholdMs) {
					if ($apiEngineStateKnown -and $voiceMeeterIsRunning -and $macroButtonOffForPendingShutdown) {
						Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru | Out-Null
						$macroButtonOffForPendingShutdown = $false
					}
					if ($shutdownSentThisIdle) {
						Write-Log "User activity detected (idle = ${idleSec}s). Resetting idle cycle flags."
					}

					$shutdownSentThisIdle = $false
					$shutdownCommandsSinceEngineStop = 0
					$shutdownRetryExhaustedLogged = $false
					$engineStoppedAfterShutdown = $false
					$lastShutdownCommandAt = [datetime]::MinValue
					$nextApiAttempt = [datetime]::MinValue
					$connectionWarningLogged = $false
					$shutdownWarningLogged = $false
				}
				elseif (($displayState -eq 0) -and ((Get-Date) -ge $nextApiAttempt)) {
					Write-Log "Idle threshold reached (${idleSec}s). Checking VoiceMeeter availability..." -Level 'DEBUG'

					if (-not $loginCompleted) {
						$relogin = Invoke-VoiceMeeterApiLogin

						if ($relogin -ge 0) {
							$loginCompleted = $true
							$voiceMeeterIsRunning = ($relogin -eq 0)
							$apiEngineStateKnown = $true
							if ($voiceMeeterIsRunning) {
								$macroButtonOffForPendingShutdown = $false
							}
							if ($voiceMeeterIsRunning) {
								Invoke-MacroButtonStateSync -DesiredState 1 -Force
							}
							else {
								Write-Log 'API session re-established, but VoiceMeeter is not running. MacroButtons synchronization remains paused until engine availability is confirmed.' -Level 'DEBUG'
							}
							$nextEngineStateProbeAt = (Get-Date).AddSeconds($CheckIntervalSec)
							$connectionWarningLogged = ($relogin -eq 1)
							if ($relogin -eq 1) {
								Write-Log 'VoiceMeeter API session re-established; the engine is not running yet.'
							}
							else {
								Write-Log "VoiceMeeter API session re-established (Login code $relogin)."
							}
							$nextApiAttempt = (Get-Date).AddSeconds($PostShutdownProbeIntervalSec)
						}
						else {
							$apiEngineStateKnown = $false
							Write-Log "VoiceMeeter API Login recovery failed (code $relogin). Retrying in ${RetryIntervalSec}s." -Level 'ERROR'
							$nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
						}
					}
					else {
						$connection = [VMRIdleWatcherNative]::IsParametersDirty()
						Write-Log "Shutdown/recovery IsParametersDirty probe returned $connection." -Level 'DEBUG'

						if ($connection -eq -2) {
							$apiEngineStateKnown = $true
							if ($voiceMeeterIsRunning) {
								$voiceMeeterIsRunning = $false
								if ($macroButtonOffForPendingShutdown) {
									Write-Log 'VoiceMeeter engine stop confirmed by the shutdown monitor. MacroButtons was already set to OFF before Command.Shutdown.'
								}
								else {
									Write-Log 'VoiceMeeter engine stop confirmed by the shutdown monitor (Remote API code -2). MacroButtons cannot be updated after the server has disappeared; the last accepted state is retained.' -Level 'WARN'
								}
							}
							if ($shutdownSentThisIdle) {
								if (-not $engineStoppedAfterShutdown) {
									Write-Log 'VoiceMeeter stopped after the previous Shutdown command. Monitoring for a restart during this idle period.'
									$engineStoppedAfterShutdown = $true
									$shutdownCommandsSinceEngineStop = 0
									$shutdownRetryExhaustedLogged = $false
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
							$apiEngineStateKnown = $false
							if (-not $connectionWarningLogged) {
								Write-Log 'VoiceMeeter API returned -1 (unexpected client error). Closing the client session before re-login.' -Level 'WARN'
								$connectionWarningLogged = $true
							}
							else {
								Write-Log 'VoiceMeeter API still returns -1. Attempting client-session recovery.' -Level 'DEBUG'
							}

							try {
								$recoveryLogout = [VMRIdleWatcherNative]::Logout()
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
								$loginCompleted = $false
								Write-Log "Exception during VoiceMeeter API recovery Logout: $($_.Exception.Message). Local session state invalidated; fresh Login scheduled." -Level 'ERROR'
								$nextApiAttempt = (Get-Date).AddSeconds($ApiSessionRecoveryRetryIntervalSec)
							}
						}
						elseif ($connection -lt 0) {
							$apiEngineStateKnown = $false
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
							$apiEngineStateKnown = $true
							if (-not $voiceMeeterIsRunning) {
								$voiceMeeterIsRunning = $true
								$macroButtonOffForPendingShutdown = $false
								Invoke-MacroButtonStateSync -DesiredState 1 -Force
								Write-Log 'VoiceMeeter engine availability confirmed. MacroButtons ON synchronization requested.'
							}
							if ($connectionWarningLogged) {
								Write-Log 'Connection to VoiceMeeter restored.'
								$connectionWarningLogged = $false
							}

							$secondsSinceShutdownCommand = [double]::PositiveInfinity
							if ($lastShutdownCommandAt -ne [datetime]::MinValue) {
								$secondsSinceShutdownCommand = ((Get-Date) - $lastShutdownCommandAt).TotalSeconds
							}

							$unconfirmedShutdownRetry = (
								$shutdownSentThisIdle -and
								(-not $engineStoppedAfterShutdown) -and
								($secondsSinceShutdownCommand -ge $PostShutdownConfirmationTimeoutSec)
							)
							$shouldSendShutdown = (-not $shutdownSentThisIdle) -or $engineStoppedAfterShutdown -or $unconfirmedShutdownRetry
							if ($shouldSendShutdown) {
								if ($unconfirmedShutdownRetry -and ($shutdownCommandsSinceEngineStop -ge $ShutdownCommandLimit)) {
									if ($macroButtonOffForPendingShutdown) {
										Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru | Out-Null
										$macroButtonOffForPendingShutdown = $false
									}
									if (-not $shutdownRetryExhaustedLogged) {
										Write-Log "Command.Shutdown was sent $shutdownCommandsSinceEngineStop times, but the engine is still available. Further retries are suspended until VoiceMeeter stops or the idle cycle resets." -Level 'WARN'
										$shutdownRetryExhaustedLogged = $true
									}
									else {
										Write-Log 'Shutdown retries remain suspended; engine is still available.' -Level 'DEBUG'
									}
									$nextApiAttempt = (Get-Date).AddSeconds($RetryIntervalSec)
								}
								else {
									$isRestartAfterShutdown = $shutdownSentThisIdle -and $engineStoppedAfterShutdown

									if ($isRestartAfterShutdown) {
										Write-Log 'VoiceMeeter has restarted during the same idle period. Sending Command.Shutdown again.'
									}
									elseif ($unconfirmedShutdownRetry) {
										Write-Log 'VoiceMeeter API remained available after the previous Shutdown request; re-sending Command.Shutdown in the same idle period.' -Level 'WARN'
									}

									Write-Log "Engine available (IsParametersDirty = $connection). Checking final idle/display conditions before Command.Shutdown..." -Level 'DEBUG'

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
										$shutdownFinalCheckFailed = $false

										if ($MacroButtonLogicalIndex -ge 0) {
											$macroButtonOffResult = Invoke-MacroButtonStateSync -DesiredState 0 -Force -PassThru
											if ($macroButtonOffResult -eq $true) {
												$macroButtonOffForPendingShutdown = $true
												Write-Log "MacroButtons logical button $MacroButtonLogicalIndex OFF command accepted by Remote API before Command.Shutdown."
												Write-Log "Allowing ${macroButtonRefreshDelayMs}ms for the MacroButtons application to process the OFF state change."
												Start-Sleep -Milliseconds $macroButtonRefreshDelayMs
											}
											elseif ($macroButtonOffResult -eq $false) {
												Write-Log 'MacroButtons OFF command was not accepted before Command.Shutdown. Continuing because MacroButtons is optional; see the preceding warning.' -Level 'WARN'
											}
										}

										# Revalidate after the OFF request and UI refresh allowance, immediately before Shutdown.
										$idleMsAfterOff = [VMRIdleWatcherNative]::GetIdleMilliseconds()
										$displayStateAfterOff = [VMRIdleWatcherNative]::GetDisplayState()
										$stopRequestedAfterOff = [VMRIdleWatcherNative]::IsExitRequested()
										$shutdownFinalCheckFailed = (
											($idleMsAfterOff -lt $thresholdMs) -or
											($displayStateAfterOff -ne 0) -or
											$stopRequestedAfterOff
										)

										if ($shutdownFinalCheckFailed) {
											Write-Log "Final pre-Shutdown validation failed after MacroButtons OFF attempt (idle=$([math]::Round($idleMsAfterOff / 1000, 1))s; DisplayState=$displayStateAfterOff; StopRequested=$stopRequestedAfterOff). Command.Shutdown will not be sent." -Level 'WARN'

											if ($macroButtonOffForPendingShutdown) {
												$macroButtonRestoreResult = Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru
												$macroButtonOffForPendingShutdown = $false
												if ($macroButtonRestoreResult -eq $true) {
													Write-Log 'MacroButtons ON command accepted after shutdown was cancelled.'
												}
												elseif ($macroButtonRestoreResult -eq $false) {
													Write-Log 'MacroButtons ON restoration was not accepted after shutdown cancellation. The normal sync path will retry while the watcher remains active.' -Level 'WARN'
												}
											}

											$nextApiAttempt = (Get-Date).AddSeconds($CheckIntervalSec)
											if ($stopRequestedAfterOff) {
												Write-Log 'Graceful stop request arrived during the pre-Shutdown sequence. Leaving the main loop.'
												break
											}
										}
										else {
											$result = [VMRIdleWatcherNative]::SetParameterFloat('Command.Shutdown', [single]1)
											Write-Log "Final pre-Shutdown validation passed (idle=$([math]::Round($idleMsAfterOff / 1000, 1))s; DisplayState=Off; StopRequested=False). Command.Shutdown returned code $result."
										}

										if ($shutdownFinalCheckFailed) {
											# No Shutdown API call was made. Keep the normal monitoring loop active.
										}
										elseif ($result -ge 0) {
											if ($isRestartAfterShutdown) {
												Write-Log "Repeated Command.Shutdown = 1 sent successfully after VoiceMeeter restart (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
											}
											elseif ($unconfirmedShutdownRetry) {
												Write-Log "Repeated Command.Shutdown = 1 sent after no stop notification was observed (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
											}
											else {
												Write-Log "Command.Shutdown = 1 sent successfully (code $result, idle = $([math]::Round($idleMsNow / 1000, 1))s)."
											}

											$shutdownCommandsSinceEngineStop++
											$shutdownSentThisIdle = $true
											$engineStoppedAfterShutdown = $false
											$lastShutdownCommandAt = Get-Date
											$shutdownWarningLogged = $false
											$connectionWarningLogged = $false
											$nextApiAttempt = (Get-Date).AddSeconds($PostShutdownProbeIntervalSec)
										}
										else {
											if ($macroButtonOffForPendingShutdown) {
												Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru | Out-Null
												$macroButtonOffForPendingShutdown = $false
											}
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

			$waitMilliseconds = $CheckIntervalSec * 1000
			if ($nextApiAttempt -gt (Get-Date)) {
				$millisecondsUntilApiAttempt = [int][math]::Ceiling(($nextApiAttempt - (Get-Date)).TotalMilliseconds)
				$waitMilliseconds = [Math]::Min($waitMilliseconds, [Math]::Max(100, $millisecondsUntilApiAttempt))
			}

			$waitResult = [VMRIdleWatcherNative]::WaitForWatcherEvent($waitMilliseconds)
			if ($waitResult -eq 1) {
				Write-Log 'Stop request received. Leaving main loop for graceful cleanup.'
				break
			}
			elseif ($waitResult -eq 2) {
				if ($apiEngineStateKnown -and $voiceMeeterIsRunning) {
					$refreshMacroButtonState = if (-not $macroButtonOffForPendingShutdown) { 1 } else { 0 }
					Invoke-MacroButtonStateSync -DesiredState $refreshMacroButtonState -Force
				}
				elseif (-not $apiEngineStateKnown) {
					Write-Log 'MacroButtons refresh request ignored because VoiceMeeter/API state is unknown.' -Level 'DEBUG'
				}
				else {
					Write-Log 'MacroButtons refresh request ignored because VoiceMeeter is confirmed stopped and the Remote API server is unavailable.' -Level 'DEBUG'
				}
			}
		}
	}
}
catch {
	Write-Log "Fatal error: $($_.Exception.Message)" -Level 'ERROR'
	if (-not (Test-StartupStatusWritten)) { Write-StartupStatus -Status 'FAILED' }
	throw
}
finally {
	Write-Log 'Graceful cleanup started.'

	try {
		if ($watcherIsActive) {
			if (($MacroButtonLogicalIndex -ge 0) -and $loginCompleted) {
				$cleanupApiState = [VMRIdleWatcherNative]::IsParametersDirty()
				$apiEngineStateKnown = ($cleanupApiState -ge 0) -or ($cleanupApiState -eq -2)
				Write-Log "Cleanup API probe returned $cleanupApiState."

				if ($cleanupApiState -ge 0) {
					$cleanupButtonResult = Invoke-MacroButtonStateSync -DesiredState 1 -Force -PassThru
					$macroButtonOffForPendingShutdown = $false
					if ($cleanupButtonResult -eq $true) {
						Write-Log 'Watcher is stopping while VoiceMeeter is confirmed available. MacroButtons ON command was accepted by Remote API; no button readback is performed.'
					}
					elseif ($cleanupButtonResult -eq $false) {
						Write-Log 'Watcher is stopping while VoiceMeeter is available, but MacroButtons ON could not be applied. The last accepted indicator state may remain stale.' -Level 'WARN'
					}
				}
				elseif ($cleanupApiState -eq -2) {
					Write-Log 'Watcher is stopping after the Remote API reported no server. MacroButtons cannot be updated; the last accepted indicator state is retained.' -Level 'WARN'
				}
				else {
					Write-Log "Watcher is stopping while Remote API state is unknown (code $cleanupApiState). MacroButtons is left unchanged rather than asserting a potentially false state." -Level 'WARN'
				}
			}
			elseif (($MacroButtonLogicalIndex -ge 0) -and (-not $loginCompleted)) {
				Write-Log 'Watcher is stopping without a valid Remote API session. MacroButtons is left at its last accepted state.' -Level 'WARN'
			}
			$watcherIsActive = $false
		}
	}
	catch {
		Write-Log "Optional MacroButtons indicator reconciliation failed during cleanup: $($_.Exception.Message)" -Level 'DEBUG'
	}

	try {
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

		if ($syncEventCreated) {
			try {
				[VMRIdleWatcherNative]::DisposeExternalSyncEvent()
				$syncEventCreated = $false
				Write-Log 'MacroButtons refresh event closed.'
			}
			catch {
				Write-Log "Failed to close MacroButtons refresh event: $($_.Exception.Message)" -Level 'ERROR'
			}
		}

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
		Write-Log "Unexpected error in graceful cleanup: $($_.Exception.Message)" -Level 'ERROR'
	}
	finally {
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