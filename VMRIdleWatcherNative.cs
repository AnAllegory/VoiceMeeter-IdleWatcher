using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

public static class VMRIdleWatcherNative
{
	private const string Dll = @"__VOICEMEETER_DLL_PATH__";

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
	private static EventWaitHandle _externalSyncEvent;

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

			// POWERBROADCAST_SETTING: GUID (16 bytes), DataLength (4 bytes), Data (DWORD).
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

	public static void CreateExternalSyncEvent(string eventName)
	{
		if (_externalSyncEvent != null)
		{
			return;
		}

		bool createdNew;
		EventWaitHandle syncEvent = new EventWaitHandle(
			false,
			EventResetMode.AutoReset,
			eventName,
			out createdNew
		);

		if (!createdNew)
		{
			syncEvent.Dispose();
			throw new InvalidOperationException(
				"The named sync event already exists. Another watcher may still be active."
			);
		}

		_externalSyncEvent = syncEvent;
	}

	public static void DisposeExternalSyncEvent()
	{
		if (_externalSyncEvent != null)
		{
			_externalSyncEvent.Dispose();
			_externalSyncEvent = null;
		}
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

	// Returns 0 on timeout, 1 on graceful stop, and 2 when an existing
	// Start request asks the running watcher to refresh its MacroButtons state.
	public static int WaitForWatcherEvent(int timeoutMilliseconds)
	{
		if (_externalStopEvent != null && _externalSyncEvent != null)
		{
			WaitHandle[] waitHandles = new WaitHandle[]
			{
				ExitRequested,
				_externalStopEvent,
				_externalSyncEvent
			};

			int result = WaitHandle.WaitAny(waitHandles, timeoutMilliseconds);
			if (result == 1)
			{
				ExitRequested.Set();
				return 1;
			}

			if (result == 2)
			{
				return 2;
			}

			return result == 0 ? 1 : 0;
		}

		if (_externalStopEvent != null)
		{
			WaitHandle[] stopHandles = new WaitHandle[]
			{
				ExitRequested,
				_externalStopEvent
			};

			int stopResult = WaitHandle.WaitAny(stopHandles, timeoutMilliseconds);
			if (stopResult == 1)
			{
				ExitRequested.Set();
				return 1;
			}

			return stopResult == 0 ? 1 : 0;
		}

		if (_externalSyncEvent != null)
		{
			WaitHandle[] syncHandles = new WaitHandle[]
			{
				ExitRequested,
				_externalSyncEvent
			};

			int syncResult = WaitHandle.WaitAny(syncHandles, timeoutMilliseconds);
			if (syncResult == 1)
			{
				return 2;
			}

			return syncResult == 0 ? 1 : 0;
		}

		return ExitRequested.WaitOne(timeoutMilliseconds) ? 1 : 0;
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
			IntPtr callbackPointer = Marshal.GetFunctionPointerForDelegate(DisplayCallback);
			Marshal.WriteIntPtr(subscribeParameters, 0, callbackPointer);
			Marshal.WriteIntPtr(subscribeParameters, IntPtr.Size, IntPtr.Zero);

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

		uint result = PowerSettingUnregisterNotification(_displayRegistrationHandle);
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

	[DllImport(Dll, EntryPoint = "VBVMR_MacroButton_SetStatus", CallingConvention = CallingConvention.StdCall, ExactSpelling = true)]
	public static extern int MacroButtonSetStatus(int logicalButton, float value, int bitmode);
}
