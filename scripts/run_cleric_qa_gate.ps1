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

$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/ClericQaGate.tscn" `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath `
	-Wait -PassThru
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
$failures = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern '^\[FAIL\]|SCRIPT ERROR:' |
		ForEach-Object { $_.Line }
)
if ($process.ExitCode -ne 0 -or $failures.Count -gt 0) {
	exit 1
}
Write-Output "[PASS] Cleric QA gate: Bible data contract and Siphon scenario"
exit 0
