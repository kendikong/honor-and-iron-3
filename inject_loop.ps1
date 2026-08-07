$content = Get-Content 'core\systems\ability_system.gd' -Raw
$lines = $content -split "
"
$newLines = @()
$inDamageBlock = $false

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ($line -match "^		GameEnums\.EffectType\.DAMAGE:") {
        $newLines += $line
        $newLines += "			for _hit_idx in range(effect.hit_count):"
        $inDamageBlock = $true
        continue
    }
    
    if ($inDamageBlock) {
        if ($line -match "^		GameEnums\.EffectType\.PUSH:") {
            $inDamageBlock = $false
            $newLines += $line
        } else {
            # Add one tab of indentation if it's not an empty line
            if ($line.Trim() -ne "") {
                $newLines += "	" + $line.TrimEnd("") + ""
            } else {
                $newLines += $line
            }
        }
    } else {
        $newLines += $line
    }
}

$newContent = $newLines -join "
"
Set-Content 'core\systems\ability_system.gd' $newContent
