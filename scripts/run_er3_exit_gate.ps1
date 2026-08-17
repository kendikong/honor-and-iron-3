param(
	[string]$GodotPath = "C:\Users\Kendy\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe",
	[string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
	$ReportPath = Join-Path $projectRoot "reports\er3_exit_gate_latest.stdout.txt"
}

$checks = @(
	"res://tests/run_ability_module_bridge_test.gd",
	"res://tests/run_class_library_schema_typed_fields_test.gd",
	"res://tests/run_extra_rules_conversion_contract.gd"
)
$lines = New-Object System.Collections.Generic.List[string]
$failed = $false

foreach ($script in $checks) {
	$lines.Add("=== $script ===")
	$stdoutPath = Join-Path $env:TEMP "honor-and-iron-er3.stdout.log"
	$stderrPath = Join-Path $env:TEMP "honor-and-iron-er3.stderr.log"
	$process = Start-Process -FilePath $GodotPath `
		-ArgumentList "--headless --path `"$projectRoot`" --script `"$script`"" `
		-WorkingDirectory $projectRoot -RedirectStandardOutput $stdoutPath `
		-RedirectStandardError $stderrPath -PassThru -Wait -NoNewWindow
	$exitCode = [int]$process.ExitCode
	$output = @()
	if (Test-Path $stdoutPath) { $output += Get-Content $stdoutPath }
	if (Test-Path $stderrPath) { $output += Get-Content $stderrPath }
	$required = switch ($script) {
		"res://tests/run_ability_module_bridge_test.gd" {
			@(
				"ABILITY_MODULE_CHECK: er1_shared_homes PASS",
				"ABILITY_MODULE_SCENARIO: grant_scrap_runtime PASS",
				"ABILITY_MODULE_SCENARIO: grant_ap_runtime PASS",
				"ABILITY_MODULE_SCENARIO: hazard_spawn_runtime PASS",
				"ABILITY_MODULE_BRIDGE_TEST: PASS"
			)
		}
		"res://tests/run_class_library_schema_typed_fields_test.gd" {
			@("[PASS] typed class-library schema roundtrip")
		}
		default {
			@("[PASS] Extra Rules conversion contract")
		}
	}
	$joined = $output -join "`n"
	foreach ($marker in $required) {
		if ($joined -notmatch [regex]::Escape($marker)) {
			$failed = $true
			$output += "[FAIL] Missing required marker: $marker"
		}
	}
	foreach ($line in $output) {
		$text = [string]$line
		$lines.Add($text)
		Write-Output $text
	}
	if ($exitCode -ne 0) {
		$failed = $true
	}
}

if ($failed) {
	$lines.Add("[FAIL] ER-3 exit gate")
} else {
	$lines.Add("[PASS] ER-3 exit gate")
}
$utf8_no_bom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($ReportPath, [string[]]$lines, $utf8_no_bom)
if ($failed) {
	Write-Output "[FAIL] ER-3 exit gate"
	exit 1
}
Write-Output "[PASS] ER-3 exit gate"
exit 0
