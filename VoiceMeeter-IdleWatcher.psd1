@{
	IdleMinutes                         = 8
	DebugMode                           = $false

	MaxLogSizeBytes                     = 512000   # 500KB
	FallbackMaxLogSizeBytes             = 2097152  # 2MB

	ShutdownCommandLimit                = 3
	CheckIntervalSec                    = 10
	RetryIntervalSec                    = 30
	EngineAbsentProbeIntervalSec        = 3
	DisplayNotificationTimeoutSec       = 5
	PostShutdownProbeIntervalSec        = 1
	PostShutdownRestartProbeIntervalSec = 3
	PostShutdownConfirmationTimeoutSec  = 5
	ApiSessionRecoveryRetryIntervalSec  = 5
	StopWaitTimeoutSec                  = 20

	MutexName                           = 'Local\VoiceMeeter-IdleWatcher'
	StopEventName                       = 'Local\VoiceMeeter-IdleWatcher.Stop'
	SyncEventName                       = 'Local\VoiceMeeter-IdleWatcher.Sync'
	LogMutexName                        = 'Local\VoiceMeeter-IdleWatcher.Log'

	# Logical button ID (0-79), -1 to disable optional MacroButtons sync.
	MacroButtonLogicalIndex             = 1
	MacroButtonSyncIntervalSec          = 10
}
