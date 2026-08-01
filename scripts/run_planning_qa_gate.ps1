param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Error "Godot not found at: $GodotPath. Pass -GodotPath to your Godot_v4.7-stable_win64.exe"
}

Write-Output "=== Tier 1/2: planning contracts (headless) ==="
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-planning-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/PlanningQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait `
	-PassThru
$godotExit = $process.ExitCode
Get-Content $stdoutPath
Get-Content $stderrPath

$testFailures = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]' | ForEach-Object { $_.Line })
$scriptErrors = @(Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)SCRIPT ERROR:' | ForEach-Object { $_.Line })
$leakDiagnostics = Select-String -Path $stdoutPath, $stderrPath -Pattern 'WARNING: .*leaked|ERROR: .*resources still in use'
$runtimeErrors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '(^|\s)ERROR:' |
		Where-Object { $_.Line -notmatch 'resources still in use' } |
		ForEach-Object { $_.Line }
)

$tier12Pass = ($godotExit -eq 0) -and ($testFailures.Count -eq 0) -and ($scriptErrors.Count -eq 0) -and ($runtimeErrors.Count -eq 0)

if (-not $tier12Pass) {
	Write-Output "--- Tier 1/2: FAIL ---"
	if ($testFailures.Count -gt 0) {
		Write-Output "Assertion failures ($($testFailures.Count)):"
		$testFailures | ForEach-Object { Write-Output $_ }
	}
	if ($scriptErrors.Count -gt 0) {
		Write-Output "Script errors ($($scriptErrors.Count)) (first 5):"
		$scriptErrors | Select-Object -First 5 | ForEach-Object { Write-Output $_ }
	}
	if ($runtimeErrors.Count -gt 0) {
		Write-Output "Runtime errors ($($runtimeErrors.Count)) (first 5):"
		$runtimeErrors | Select-Object -First 5 | ForEach-Object { Write-Output $_ }
	}
} else {
	Write-Output "--- Tier 1/2: PASS ---"
	if ($null -ne $leakDiagnostics) {
		Write-Warning "Tier 1/2 passed assertions; engine reported residual leaks (not gate-blocking):"
		$leakDiagnostics | ForEach-Object { Write-Warning $_.Line }
	}
}

Write-Output ""
Write-Output "=== Tier 3: TestBattle scene acceptance (GdUnit4) ==="
$sceneGate = Join-Path $PSScriptRoot "run_planning_scene_acceptance.ps1"
if (-not (Test-Path $sceneGate)) {
	Write-Error "[INCOMPLETE] Tier 3 runner missing: $sceneGate"
	exit 2
}

$tier3Stdout = Join-Path $env:TEMP "honor-and-iron-planning-qa-tier3.stdout.log"
$tier3Stderr = Join-Path $env:TEMP "honor-and-iron-planning-qa-tier3.stderr.log"
$tier3Process = Start-Process -FilePath "powershell.exe" `
	-ArgumentList "-NoProfile -File `"$sceneGate`" -GodotPath `"$GodotPath`"" `
	-RedirectStandardOutput $tier3Stdout `
	-RedirectStandardError $tier3Stderr `
	-Wait `
	-PassThru
$sceneExit = $tier3Process.ExitCode
Get-Content $tier3Stdout
Get-Content $tier3Stderr

$tier3Pass = $false
$tier3Incomplete = $false
if ($sceneExit -eq 2) {
	$tier3Incomplete = $true
	Write-Output "--- Tier 3: INCOMPLETE ---"
} elseif ($sceneExit -eq 0) {
	$tier3Pass = $true
	Write-Output "--- Tier 3: PASS ---"
} else {
	Write-Output "--- Tier 3: FAIL (exit $sceneExit) ---"
}

Write-Output ""
Write-Output "=== Planning QA gate summary ==="
$tier12Label = if ($tier12Pass) { "PASS" } else { "FAIL ($($testFailures.Count) assertion(s))" }
$tier3Label = if ($tier3Incomplete) { "INCOMPLETE" } elseif ($tier3Pass) { "PASS" } else { "FAIL" }
Write-Output ("Tier 1/2: {0}" -f $tier12Label)
Write-Output ("Tier 3:   {0}" -f $tier3Label)

if ($tier3Incomplete) {
	exit 2
}
if (-not $tier12Pass -or -not $tier3Pass) {
	exit 1
}
Write-Output "[PASS] Planning QA gate: Tier 1/2 and Tier 3."
exit 0
