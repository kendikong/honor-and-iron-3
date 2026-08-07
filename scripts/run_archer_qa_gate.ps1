param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot "qa_archer_gate_latest.txt"
$stdoutPath = Join-Path $env:TEMP "honor-and-iron-archer-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-archer-qa.stderr.log"

if (-not (Test-Path $GodotPath)) {
	"[FAIL] Godot not found at: $GodotPath" | Set-Content -Path $logPath -Encoding utf8
	exit 1
}

$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/ArcherQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru

$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | Set-Content -Path $logPath -Encoding utf8
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]|SCRIPT ERROR:' -ErrorAction SilentlyContinue
)
if ($process.ExitCode -ne 0 -or $failures.Count -gt 0) {
	$output | ForEach-Object { Write-Output $_ }
	exit 1
}
Write-Output "[PASS] Archer QA gate: 30 Bible rows + modular bridge smoke"
exit 0
