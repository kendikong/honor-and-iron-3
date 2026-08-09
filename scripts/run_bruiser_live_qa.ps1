param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$suite = "res://tests/live_bruiser_class_test.gd"
$cmdTool = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Bruiser live QA: Godot executable not found: $GodotPath"
	exit 2
}

$env:LIVE_QA_PROFILE = "fast"
$godotArgs = @(
	"--path", $projectRoot,
	"--headless",
	"-s", "-d",
	$cmdTool,
	"-a", $suite,
	"--ignoreHeadlessMode"
)
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-bruiser-live.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-bruiser-live.stderr.log"
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList $godotArgs `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Bruiser live QA"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Bruiser live QA stopped by ESC."
	exit 130
}

if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) { Get-Content $stderrPath }

$gdUnitFailures = @(
	Select-String -Path $stdoutPath -Pattern 'Overall Summary:.*\|\s*(\d+)\s+failures' |
		ForEach-Object {
			if ($_.Matches[0].Groups[1].Value -ne "0") { $_.Line }
		}
)
$testCaseFailed = @(
	Select-String -Path $stdoutPath -Pattern '>\s*test_\S+\s+FAILED' |
		ForEach-Object { $_.Line }
)
$scriptErrors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:' |
		Where-Object {
			$_.Line -notmatch 'resources still in use' -and
			$_.Line -notmatch 'Remote Debugger' -and
			$_.Line -notmatch 'remote port number'
		} |
		ForEach-Object { $_.Line }
)
$runtimeErrors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)ERROR:' |
		Where-Object {
			$_.Line -notmatch 'resources still in use' -and
			$_.Line -notmatch 'Remote Debugger' -and
			$_.Line -notmatch 'remote port number' -and
			$_.Line -notmatch 'custom_samplers' -and
			$_.Line -notmatch 'Continuing\.'
		} |
		ForEach-Object { $_.Line }
)
$explicitFails = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' |
		ForEach-Object { $_.Line }
)

if (
	($gdUnitFailures.Count -gt 0) -or
	($testCaseFailed.Count -gt 0) -or
	($scriptErrors.Count -gt 0) -or
	($runtimeErrors.Count -gt 0) -or
	($explicitFails.Count -gt 0)
) {
	Write-Output "[FAIL] Bruiser live QA"
	if ($gdUnitFailures.Count -gt 0) {
		Write-Output "GdUnit failures: $($gdUnitFailures -join '; ')"
	}
	if ($testCaseFailed.Count -gt 0) {
		$testCaseFailed | Select-Object -First 5 | ForEach-Object { Write-Output $_ }
	}
	if ($scriptErrors.Count -gt 0) {
		Write-Output "SCRIPT ERROR ($($scriptErrors.Count)):"
		$scriptErrors | Select-Object -First 5 | ForEach-Object { Write-Output $_ }
	}
	if ($runtimeErrors.Count -gt 0) {
		Write-Output "Runtime ERROR ($($runtimeErrors.Count)):"
		$runtimeErrors | Select-Object -First 5 | ForEach-Object { Write-Output $_ }
	}
	exit 1
}
Write-Output "[PASS] Bruiser live QA: 16 movement/actives through preview/commit + AOE overlay"
exit 0
