Set-StrictMode -Version Latest

$script:MacroConfig = @{
	LogicalIndex    = -1
	SyncIntervalSec = 10
}

$script:MacroButtonStateOnlyMode = 0x00000002

$script:MacroButtonWriteStatus = 'NotChecked'
$script:MacroButtonLastSuccessfulState = $null
$script:MacroButtonLastSuccessfulAt = $null
$script:MacroButtonNextSyncAt = [datetime]::MinValue

function Initialize-MacroButtonConfig {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateRange(-1, 79)]
		[int]$LogicalIndex,

		[Parameter(Mandatory = $true)]
		[ValidateRange(1, 300)]
		[int]$SyncIntervalSec
	)

	$script:MacroConfig.LogicalIndex    = $LogicalIndex
	$script:MacroConfig.SyncIntervalSec = $SyncIntervalSec
	Write-Log "MacroButtons initialized: logical button=$LogicalIndex; sync interval=${SyncIntervalSec}s; fixed mode=STATEONLY (0x00000002)." -Level 'DEBUG'
}

function Invoke-MacroButtonStateSync {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateSet(0, 1)]
		[int]$DesiredState,

		[switch]$Force,
		[switch]$PassThru
	)

	$logicalIndex = $script:MacroConfig.LogicalIndex
	if (($logicalIndex -lt 0) -or ($script:MacroButtonWriteStatus -eq 'Unsupported')) {
		if ($PassThru) {
			return $false
		}
		return
	}

	$now = Get-Date
	if ((-not $Force) -and ($now -lt $script:MacroButtonNextSyncAt)) {
		if ($PassThru) {
			return $null
		}
		return
	}

	$script:MacroButtonNextSyncAt = $now.AddSeconds($script:MacroConfig.SyncIntervalSec)
	$stateLabel = if ($DesiredState -eq 1) { 'ON' } else { 'OFF' }
	Write-Log "MacroButtons STATEONLY request: button=$logicalIndex; desired=$stateLabel; mode=0x00000002; forced=$([bool]$Force)." -Level 'DEBUG'

	try {
		$setResult = [VMRIdleWatcherNative]::MacroButtonSetStatus(
			[int]$logicalIndex,
			[single]$DesiredState,
			[int]$script:MacroButtonStateOnlyMode
		)
	}
	catch [System.EntryPointNotFoundException] {
		if ($script:MacroButtonWriteStatus -ne 'Unsupported') {
			Write-Log 'MacroButtons SetStatus is not exported by this Remote API DLL. Continuing without optional button synchronization.' -Level 'WARN'
		}
		$script:MacroButtonWriteStatus = 'Unsupported'
		$script:MacroButtonNextSyncAt = [datetime]::MaxValue
		if ($PassThru) {
			return $false
		}
		return
	}
	catch {
		$writeStatus = 'WriteException'
		if ($script:MacroButtonWriteStatus -ne $writeStatus) {
			Write-Log "Could not update MacroButtons logical button $logicalIndex display state: $($_.Exception.Message). The watcher will continue and retry later." -Level 'WARN'
		}
		$script:MacroButtonWriteStatus = $writeStatus
		if ($PassThru) {
			return $false
		}
		return
	}

	if ($setResult -ne 0) {
		$writeStatus = "WriteResult:$setResult"
		if ($script:MacroButtonWriteStatus -ne $writeStatus) {
			$errorDescription = switch ($setResult) {
				-1 { 'General Remote API error' }
				-2 { 'VoiceMeeter Remote API server is not available' }
				-3 { 'Unknown MacroButtons parameter' }
				-5 { 'Remote API data-structure mismatch' }
				default { 'Unknown Remote API error' }
			}
			Write-Log "MacroButtons logical button $logicalIndex display state update failed (Remote API code ${setResult}: $errorDescription). The watcher will continue and retry later." -Level 'WARN'
		}
		$script:MacroButtonWriteStatus = $writeStatus
		if ($PassThru) {
			return $false
		}
		return
	}

	if (($script:MacroButtonWriteStatus -ne 'Available') -or
		($script:MacroButtonLastSuccessfulState -ne $DesiredState) -or $Force) {
		Write-Log "MacroButtons STATEONLY command for logical button $logicalIndex ($stateLabel) was accepted by Remote API (return code 0). The displayed state is not read back."
	}

	$script:MacroButtonWriteStatus = 'Available'
	$script:MacroButtonLastSuccessfulState = $DesiredState
	$script:MacroButtonLastSuccessfulAt = Get-Date
	if ($PassThru) {
		return $true
	}
}


function Get-MacroButtonSyncStatus {
	return [pscustomobject]@{
		LogicalIndex = $script:MacroConfig.LogicalIndex
		WriteStatus = $script:MacroButtonWriteStatus
		LastSuccessfulState = $script:MacroButtonLastSuccessfulState
		LastSuccessfulAt = $script:MacroButtonLastSuccessfulAt
		NextSyncAt = $script:MacroButtonNextSyncAt
	}
}

Export-ModuleMember -Function @(
	'Initialize-MacroButtonConfig',
	'Invoke-MacroButtonStateSync',
	'Get-MacroButtonSyncStatus'
)
