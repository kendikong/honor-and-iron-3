if (-not ([System.Management.Automation.PSTypeName]::new("QaWindowPlacement").Type)) {
	Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class QaWindowPlacement {
	[StructLayout(LayoutKind.Sequential)]
	private struct Rect {
		public int Left;
		public int Top;
		public int Right;
		public int Bottom;
	}

	[StructLayout(LayoutKind.Sequential)]
	private struct MonitorInfo {
		public int Size;
		public Rect Monitor;
		public Rect Work;
		public uint Flags;
	}

	[DllImport("user32.dll")]
	private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

	[DllImport("user32.dll", CharSet = CharSet.Unicode)]
	private static extern bool GetMonitorInfo(
		IntPtr monitor,
		ref MonitorInfo info
	);

	[DllImport("user32.dll")]
	private static extern bool SetWindowPos(
		IntPtr window,
		IntPtr insertAfter,
		int x,
		int y,
		int width,
		int height,
		uint flags
	);

	[DllImport("user32.dll")]
	private static extern bool ShowWindow(IntPtr window, int command);

	[DllImport("user32.dll")]
	private static extern short GetAsyncKeyState(int vKey);

	public static bool IsEscapePressed() {
		return (GetAsyncKeyState(0x1B) & 0x8000) != 0;
	}

	public static int[] WorkAreaForWindow(IntPtr window) {
		IntPtr monitor = MonitorFromWindow(window, 2);
		if (monitor == IntPtr.Zero) {
			return null;
		}
		MonitorInfo info = new MonitorInfo();
		info.Size = Marshal.SizeOf(info);
		if (!GetMonitorInfo(monitor, ref info)) {
			return null;
		}
		return new int[] {
			info.Work.Left,
			info.Work.Top,
			info.Work.Right - info.Work.Left,
			info.Work.Bottom - info.Work.Top
		};
	}

	public static void PlaceOnWorkArea(IntPtr window, int[] area) {
		if (window == IntPtr.Zero || area == null || area.Length != 4) {
			return;
		}
		const uint NoActivate = 0x0010;
		const uint ShowWindow = 0x0040;
		SetWindowPos(window, IntPtr.Zero, area[0], area[1], area[2], area[3], NoActivate | ShowWindow);
		QaWindowPlacement.Show(window);
	}

	public static void Show(IntPtr window) {
		if (window != IntPtr.Zero) {
			ShowWindow(window, 9);
		}
	}
}
"@
}


function Get-CursorMonitorWorkArea {
	$cursor = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue |
		Where-Object { $_.MainWindowHandle -ne 0 } |
		Select-Object -First 1
	if ($null -eq $cursor) {
		return $null
	}
	return [QaWindowPlacement]::WorkAreaForWindow($cursor.MainWindowHandle)
}


function Start-GodotOnCursorMonitor {
	param(
		[Parameter(Mandatory = $true)]
		[string]$GodotPath,
		[Parameter(Mandatory = $true)]
		[object[]]$ArgumentList,
		[Parameter(Mandatory = $true)]
		[string]$WorkingDirectory,
		[Parameter(Mandatory = $true)]
		[string]$RedirectStandardOutput,
		[Parameter(Mandatory = $true)]
		[string]$RedirectStandardError
	)

	$workArea = Get-CursorMonitorWorkArea
	$process = Start-Process -FilePath $GodotPath `
		-ArgumentList $ArgumentList `
		-WorkingDirectory $WorkingDirectory `
		-WindowStyle Minimized `
		-RedirectStandardOutput $RedirectStandardOutput `
		-RedirectStandardError $RedirectStandardError `
		-PassThru

	if ($null -eq $workArea) {
		return $process
	}
	for ($attempt = 0; $attempt -lt 100; $attempt++) {
		$process.Refresh()
		if ($process.MainWindowHandle -ne 0) {
			[QaWindowPlacement]::PlaceOnWorkArea($process.MainWindowHandle, $workArea)
			break
		}
		Start-Sleep -Milliseconds 50
	}
	return $process
}


function Test-EscKeyPressed {
	if ([QaWindowPlacement]::IsEscapePressed()) {
		return $true
	}
	try {
		if ([Console]::KeyAvailable) {
			$key = [Console]::ReadKey($true)
			if ($key.Key -eq 'Escape') {
				return $true
			}
		}
	} catch {
		# Non-interactive hosts may not expose Console.KeyAvailable.
	}
	return $false
}


function Stop-GodotProcessTree {
	param(
		[System.Diagnostics.Process]$Process
	)
	if ($null -eq $Process) {
		return
	}
	try {
		if (-not $Process.HasExited) {
			$Process.Kill($true)
		}
	} catch {
		try {
			Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
		} catch {
			# Process may already be gone.
		}
	}
}


function Test-GdUnitCmdSucceeded {
	param(
		$ExitCode,
		[Parameter(Mandatory = $true)]
		[string[]]$LogPaths
	)
	if ($ExitCode -eq 130) {
		return $false
	}
	$existingLogs = @($LogPaths | Where-Object { $_ -and (Test-Path $_) })
	if ($existingLogs.Count -eq 0) {
		return $false
	}
	$summary = Select-String -Path $existingLogs -Pattern 'Overall Summary:' | Select-Object -Last 1
	if ($null -ne $summary -and $summary.Line -match '\|\s*(\d+)\s+errors\s*\|\s*(\d+)\s+failures\s*\|') {
		return ([int]$Matches[1] -eq 0) -and ([int]$Matches[2] -eq 0)
	}
	return Test-GodotQaHarnessSucceeded -ExitCode $ExitCode -LogPaths $existingLogs
}


function Test-GodotQaHarnessSucceeded {
	param(
		$ExitCode,
		[Parameter(Mandatory = $true)]
		[string[]]$LogPaths,
		[string]$PassPattern = '^\[PASS\]'
	)
	$existingLogs = @($LogPaths | Where-Object { $_ -and (Test-Path $_) })
	$testFailures = @(
		Select-String -Path $existingLogs -Pattern '^\[FAIL\]' -ErrorAction SilentlyContinue |
			ForEach-Object { $_.Line }
	)
	$scriptErrors = @(
		Select-String -Path $existingLogs -Pattern 'SCRIPT ERROR:' -ErrorAction SilentlyContinue |
			ForEach-Object { $_.Line }
	)
	if ($ExitCode -eq 130) {
		return $false
	}
	if ($testFailures.Count -gt 0 -or $scriptErrors.Count -gt 0) {
		return $false
	}
	if ($null -ne $ExitCode -and $ExitCode -ne '' -and [int]$ExitCode -ne 0) {
		return $false
	}
	if ($null -eq $ExitCode -or $ExitCode -eq '') {
		# Start-Process -PassThru + redirected streams often omits ExitCode on Windows.
		return (Select-String -Path $existingLogs -Pattern $PassPattern -Quiet)
	}
	return $true
}


function Wait-GodotProcessWithEscCancel {
	param(
		[Parameter(Mandatory = $true)]
		[System.Diagnostics.Process]$Process,
		[string]$Label = "Godot test"
	)
	Write-Host "[QA] $Label running - press ESC to force-stop."
	while (-not $Process.HasExited) {
		if (Test-EscKeyPressed) {
			Write-Host "[CANCEL] ESC pressed - force-stopping $Label."
			Stop-GodotProcessTree -Process $Process
			return 130
		}
		Start-Sleep -Milliseconds 50
	}
	$Process.Refresh()
	$rawExit = $Process.ExitCode
	if ($null -eq $rawExit -or [string]::IsNullOrEmpty([string]$rawExit)) {
		return $null
	}
	return [int]$rawExit
}
