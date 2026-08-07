$files = Get-ChildItem -Path . -Filter "*.gd" -Recurse
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $newContent = $content -replace 'EffectData', 'AbilityModule'
    if ($content -ne $newContent) {
        [IO.File]::WriteAllText($file.FullName, $newContent)
        Write-Host "Updated  (EffectData -> AbilityModule)"
    }
}