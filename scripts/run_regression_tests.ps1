param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$resultPath = Join-Path $env:APPDATA "Godot\app_userdata\Honor and Iron 3\regression_test_result.txt"
$diagnosticPath = Join-Path $projectRoot "reports\regression_latest.stderr.txt"

if (Test-Path $resultPath) {
	Remove-Item $resultPath -Force
}

Write-Output "=== Sim/bridge regression (headless) ==="
. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-regression.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-regression.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList @("--headless", "--path", $projectRoot, "--script", "res://tests/regression_test.gd") `
	-WorkingDirectory $projectRoot `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru -NoNewWindow
$regressionExit = Wait-GodotProcessWithEscCancel -Process $process -Label "Regression suite"
if ($regressionExit -eq 130) {
	Write-Output "[CANCEL] Regression suite stopped by ESC."
	exit 130
}
if (Test-Path $stdoutPath) { Get-Content $stdoutPath }
if (Test-Path $stderrPath) {
	$diagnosticDir = Split-Path -Parent $diagnosticPath
	if (-not (Test-Path $diagnosticDir)) {
		New-Item -ItemType Directory -Path $diagnosticDir -Force | Out-Null
	}
	Get-Content $stderrPath | Set-Content -Path $diagnosticPath -Encoding UTF8
	Write-Output "[QA] Regression diagnostics saved to reports/regression_latest.stderr.txt"
}

$report = @()
$complete = $false
$maxWaitSec = 90
$attempts = $maxWaitSec * 2
for ($attempt = 0; $attempt -lt $attempts; $attempt++) {
	if (Test-Path $resultPath) {
		$report = Get-Content $resultPath
		$failures = $report | Where-Object {
			$_ -match '^\[(BRIDGE|SIM)\] '
		}
		if (($report -contains "PASS") -or $failures.Count -gt 0) {
			$complete = $true
			break
		}
	}
	Start-Sleep -Milliseconds 500
}

if (-not $complete) {
	Write-Error "Regression runner did not finish within $maxWaitSec seconds."
	exit 1
}

$report | ForEach-Object { Write-Output $_ }

$bridgeFails = @($report | Where-Object { $_ -like "[[]BRIDGE[]]*" })
$simFails = @($report | Where-Object { $_ -like "[[]SIM[]]*" })

Write-Output ""
Write-Output "=== ER-3 exit contracts ==="
$er3Gate = Join-Path $PSScriptRoot "run_er3_exit_gate.ps1"
& $er3Gate -GodotPath $GodotPath
$er3Exit = $LASTEXITCODE

Write-Output ""
Write-Output "=== Regression summary ==="
if (
	$report -contains "PASS" `
	-and $bridgeFails.Count -eq 0 `
	-and $simFails.Count -eq 0 `
	-and $er3Exit -eq 0
) {
	Write-Output "Regression: PASS"
	exit 0
}
Write-Output ("Regression: FAIL ({0} bridge, {1} sim)" -f $bridgeFails.Count, $simFails.Count)
exit 1
