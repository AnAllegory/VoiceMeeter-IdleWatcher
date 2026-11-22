@{
	# USER SETTINGS
	# Idle threshold in minutes (1-60). This is the main setting most users may want to change.
	IdleMinutes                         = 8

	# Keep false for normal use. Set true only temporarily when troubleshooting; it enables high-volume diagnostic logging.
	DebugMode                           = $false

	# INTERNAL IMPLEMENTATION SETTINGS
	# Log rotation limits in bytes. Keep the defaults.
	MaxLogSizeBytes                     = 512000
	FallbackMaxLogSizeBytes             = 2097152

	# Internal shutdown retry policy and main watcher timing. Do not tune these for ordinary use.
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

	# Internal single-instance and inter-thread coordination names. Keep these unchanged.
	MutexName                           = 'Local\VoiceMeeter-IdleWatcher'
	StopEventName                       = 'Local\VoiceMeeter-IdleWatcher.Stop'
	SyncEventName                       = 'Local\VoiceMeeter-IdleWatcher.Sync'
	LogMutexName                        = 'Local\VoiceMeeter-IdleWatcher.Log'

	# USER SETTING: logical Remote API button ID (0-79); -1 disables the optional MacroButtons indicator.
	# ID 1 is the default. Choose the logical ID assigned to your indicator in your MacroButtons layout.
	MacroButtonLogicalIndex             = 1

	# USER SETTING: repeat interval in seconds for the optional indicator while VoiceMeeter is available.
	MacroButtonSyncIntervalSec          = 10
}
