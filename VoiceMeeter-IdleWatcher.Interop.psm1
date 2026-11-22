Set-StrictMode -Version Latest

function Get-VoicemeeterRemoteDll {
	if ([Environment]::Is64BitProcess) {
		$requiredDll = 'VoicemeeterRemote64.dll'
	}
	else {
		$requiredDll = 'VoicemeeterRemote.dll'
	}

	$folders = [System.Collections.Generic.List[string]]::new()

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

				if ($uninstallString -match '^\s*"(?<quotedExe>[^"]+)"') {
					$uninstallExe = $Matches['quotedExe']
				}
				elseif ($uninstallString -match '^\s*(?<unquotedExe>.+?\.exe)(?:\s|$)') {
					$uninstallExe = $Matches['unquotedExe']
				}

				if ($uninstallExe -and [System.IO.File]::Exists($uninstallExe)) {
					$uninstallFolder = [System.IO.Path]::GetDirectoryName($uninstallExe)
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
			$errorType = $_.Exception.GetType().FullName
			$errorId = $_.FullyQualifiedErrorId
			Write-Log "Could not inspect Voicemeeter uninstall registry view '$registryView' ($errorType; error ID '$errorId'): $($_.Exception.Message)" -Level 'DEBUG'
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

function Initialize-VoicemeeterNativeInterop {
	param(
		[Parameter(Mandatory = $true)]
		[string]$DllPath,

		[string]$SourcePath = (Join-Path -Path $PSScriptRoot -ChildPath 'VMRIdleWatcherNative.cs')
	)

	if ('VMRIdleWatcherNative' -as [type]) {
		throw 'VMRIdleWatcherNative is already loaded in this PowerShell process. Run each watcher/test instance in a fresh powershell.exe process; the native DLL path and event handles are process-static.'
	}

	if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
		throw "C# interop source file not found: $SourcePath"
	}

	$marker = '__VOICEMEETER_DLL_PATH__'
	$templateSource = [System.IO.File]::ReadAllText($SourcePath, [System.Text.Encoding]::UTF8)
	$markerCount = [regex]::Matches($templateSource, [regex]::Escape($marker)).Count

	if ($markerCount -ne 1) {
		throw "Expected exactly one DLL path marker '$marker' in '$SourcePath'; found $markerCount."
	}

	$escapedDllPath = $DllPath.Replace('"', '""')
	$source = $templateSource.Replace($marker, $escapedDllPath)

	Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}

function Invoke-VoiceMeeterApiLogin {
	$loginResult = [VMRIdleWatcherNative]::Login()

	if ($loginResult -eq -2) {
		Write-Log 'VoiceMeeter API Login returned -2 (Logout required). Calling Logout before retrying Login.' -Level 'WARN'
		$logoutResult = [VMRIdleWatcherNative]::Logout()
		if ($logoutResult -lt 0) {
			throw "VoiceMeeter API Logout-before-Login recovery failed (code $logoutResult)."
		}
		$loginResult = [VMRIdleWatcherNative]::Login()
	}

	return [int]$loginResult
}

Export-ModuleMember -Function @(
	'Get-VoicemeeterRemoteDll',
	'Initialize-VoicemeeterNativeInterop',
	'Invoke-VoiceMeeterApiLogin'
)
