Set-StrictMode -Version Latest

$script:LogConfig = @{
	LogFile          = $null
	FallbackLogFile  = $null
	EmergencyLogFile = $null
	MaxLogSize       = 500KB
	FallbackMaxSize  = 2MB
	LogMutexName     = 'Local\VoiceMeeter-IdleWatcher.Log'
	DebugMode        = $false
}

$script:LogMutex = $null
$script:StartupStatusFile = ''
$script:StartupStatusWritten = $false

function Initialize-WatcherSupport {
	param(
		[Parameter(Mandatory = $true)][string]$LogFile,
		[Parameter(Mandatory = $true)][string]$FallbackLogFile,
		[Parameter(Mandatory = $true)][string]$EmergencyLogFile,
		[Parameter(Mandatory = $true)][long]$MaxLogSize,
		[Parameter(Mandatory = $true)][long]$FallbackMaxLogSize,
		[Parameter(Mandatory = $true)][string]$LogMutexName,
		[Parameter(Mandatory = $true)][bool]$DebugMode,
		[string]$StartupStatusFile = ''
	)

	$script:LogConfig.LogFile          = $LogFile
	$script:LogConfig.FallbackLogFile  = $FallbackLogFile
	$script:LogConfig.EmergencyLogFile = $EmergencyLogFile
	$script:LogConfig.MaxLogSize       = $MaxLogSize
	$script:LogConfig.FallbackMaxSize  = $FallbackMaxLogSize
	$script:LogConfig.LogMutexName     = $LogMutexName
	$script:LogConfig.DebugMode        = $DebugMode

	$script:StartupStatusFile    = $StartupStatusFile
	$script:StartupStatusWritten = $false
}

function Test-StartupStatusWritten {
	return [bool]$script:StartupStatusWritten
}

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

	if (($Level -eq 'DEBUG') -and (-not $script:LogConfig.DebugMode)) {
		return
	}

	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
	$line = "[$timestamp] [$Level] $Message"
	$primaryError = $null
	$lockAcquired = $false

	try {
		if ($null -eq $script:LogMutex) {
			$script:LogMutex = [System.Threading.Mutex]::new($false, $script:LogConfig.LogMutexName)
		}

		try {
			$lockAcquired = $script:LogMutex.WaitOne(3000)
		}
		catch [System.Threading.AbandonedMutexException] {
			$lockAcquired = $true
		}

		if (-not $lockAcquired) {
			throw 'Timed out waiting for the log-file mutex.'
		}

		Add-LogLineToFile -Path $script:LogConfig.LogFile -Line $line -MaxBytes $script:LogConfig.MaxLogSize
		return
	}
	catch {
		$primaryError = $_.Exception.Message
	}
	finally {
		if ($lockAcquired -and ($null -ne $script:LogMutex)) {
			try { $script:LogMutex.ReleaseMutex() }
			catch { [void]$_.Exception.Message }
		}
	}

	$fallbackLine = "$line [PRIMARY LOG WRITE FAILED: $primaryError]"
	$fallbackLockAcquired = $false

	try {
		if ($null -eq $script:LogMutex) {
			$script:LogMutex = [System.Threading.Mutex]::new($false, $script:LogConfig.LogMutexName)
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

		Add-LogLineToFile -Path $script:LogConfig.FallbackLogFile -Line $fallbackLine -MaxBytes $script:LogConfig.FallbackMaxSize
		return
	}
	catch {
		$fallbackError = $_.Exception.Message
	}
	finally {
		if ($fallbackLockAcquired -and ($null -ne $script:LogMutex)) {
			try { $script:LogMutex.ReleaseMutex() }
			catch { [void]$_.Exception.Message }
		}
	}

	try {
		$emergencyLine = "$fallbackLine [FALLBACK LOG WRITE FAILED: $fallbackError]"
		Add-LogLineToFile -Path $script:LogConfig.EmergencyLogFile -Line $emergencyLine -MaxBytes $script:LogConfig.FallbackMaxSize
	}
	catch {
		try {
			[Console]::Error.WriteLine("VoiceMeeter IdleWatcher logging failure: $primaryError; fallback failure: $fallbackError; message: $Message")
		}
		catch { [void]$_.Exception.Message }
	}
}

function Write-StartupStatus {
	param([ValidateSet('READY', 'ALREADY_RUNNING', 'STOPPED', 'FAILED')][string]$Status)

	if ([string]::IsNullOrWhiteSpace($script:StartupStatusFile) -or $script:StartupStatusWritten) {
		return
	}

	try {
		$statusDirectory = [System.IO.Path]::GetDirectoryName($script:StartupStatusFile)
		if (-not [string]::IsNullOrWhiteSpace($statusDirectory)) {
			[void][System.IO.Directory]::CreateDirectory($statusDirectory)
		}
		$temporaryStatusFile = $script:StartupStatusFile + '.' + $PID + '.tmp'
		[System.IO.File]::WriteAllText(
			$temporaryStatusFile,
			$Status,
			[System.Text.UTF8Encoding]::new($false)
		)
		if ([System.IO.File]::Exists($script:StartupStatusFile)) {
			[System.IO.File]::Delete($script:StartupStatusFile)
		}
		[System.IO.File]::Move($temporaryStatusFile, $script:StartupStatusFile)
		$script:StartupStatusWritten = $true
	}
	catch {
		Write-Log "Could not write startup status file '$($script:StartupStatusFile)': $($_.Exception.Message)" -Level 'ERROR'
	}
}

function Send-SyncRequestToExistingWatcher {
	param([Parameter(Mandatory = $true)][string]$EventName)

	$attempts = 20
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
			Write-Log "Could not request immediate MacroButtons refresh: $($_.Exception.Message). The watcher will keep its normal refresh schedule." -Level 'DEBUG'
			return $false
		}
		finally {
			if ($null -ne $eventHandle) { $eventHandle.Dispose() }
		}
	}

	Write-Log 'Could not find the active watcher sync event. It will keep its normal MacroButtons refresh schedule.' -Level 'DEBUG'
	return $false
}

function Send-StopRequestToExistingWatcher {
	param(
		[Parameter(Mandatory = $true)][string]$EventName,
		[Parameter(Mandatory = $true)][int]$TimeoutSec
	)

	$attempts = $TimeoutSec * 10
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
			if ($null -ne $eventHandle) { $eventHandle.Dispose() }
		}
	}

	Write-Log "The watcher owns the mutex, but its stop event was not available within $TimeoutSec seconds." -Level 'ERROR'
	return $false
}

Export-ModuleMember -Function @(
	'Initialize-WatcherSupport',
	'Test-StartupStatusWritten',
	'Write-Log',
	'Write-StartupStatus',
	'Send-SyncRequestToExistingWatcher',
	'Send-StopRequestToExistingWatcher'
)
