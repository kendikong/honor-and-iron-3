$lines = Get-Content 'data/definitions/ability_module_bridge.gd'
$newLines = @()
$skip = $false

foreach ($line in $lines) {
    if ($line -match '^static func compile_modules_to_effects') {
        $skip = $true
    }
    
    if ($skip -and $line -match '^static func ensure_if_collided_followup_move') {
        $skip = $false
    }
    
    if ($skip -and $line -match '^static func finalize_ability') {
        $skip = $false
    }

    if ($line -match '^static func _module_from_primary_effect') {
        $skip = $true
    }

    if (-not $skip) {
        $newLines += $line
    }
}

[IO.File]::WriteAllLines('data/definitions/ability_module_bridge.gd', $newLines)
Write-Host "Cleaned ability_module_bridge.gd"