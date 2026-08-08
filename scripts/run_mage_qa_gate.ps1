param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotPath)) {
	Write-Output "[INCOMPLETE] Mage QA: Godot executable not found: $GodotPath"
	exit 2
}

$stdoutPath = Join-Path $env:TEMP "honor-and-iron-mage-qa.stdout.log"
$stderrPath = Join-Path $env:TEMP "honor-and-iron-mage-qa.stderr.log"
$process = Start-Process -FilePath $GodotPath `
	-ArgumentList "--headless --path `"$projectRoot`" res://tests/MageQaGate.tscn" `
	-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath -Wait -PassThru -NoNewWindow
$output = @()
$output += Get-Content $stdoutPath
$output += Get-Content $stderrPath
$output | ForEach-Object { Write-Output $_ }
$scriptErrors = @(
	Select-String -Path $stdoutPath, $stderrPath -Pattern 'SCRIPT ERROR:|Compile Error:|^\[FAIL\]' |
		ForEach-Object { $_.Line }
)
if ($process.ExitCode -ne 0 -or $scriptErrors.Count -gt 0) {
	Write-Output "[FAIL] Mage QA gate"
	exit 1
}
Write-Output "[PASS] Mage QA gate: 32 factory rows plus active skill/passive resolution"
exit 0
