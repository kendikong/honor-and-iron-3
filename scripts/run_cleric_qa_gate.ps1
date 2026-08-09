param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-cleric-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-cleric-qa.stderr.log"

if (-not (Test-Path $GodotPath)) {
	"[FAIL] Godot not found at: $GodotPath"
	exit 1
}

. (Join-Path $PSScriptRoot "qa_window_placement.ps1")
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/ClericQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-PassThru
$exitCode = Wait-GodotProcessWithEscCancel -Process $process -Label "Cleric QA gate"
if ($exitCode -eq 130) {
	Write-Output "[CANCEL] Cleric QA gate stopped by ESC."
	exit 130
}
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]|SCRIPT ERROR:' |
		ForEach-Object { $_.Line }
)
if ($exitCode -ne 0 -or $failures.Count -gt 0) {
	exit 1
}
Write-Output "[PASS] Cleric QA gate: Bible data contract and Siphon scenario"
exit 0
