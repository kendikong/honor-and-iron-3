 = "resources/character/lpc_catalog.json"
 = Get-Content -Path $path -Raw | ConvertFrom-Json
if ("skeleton" -notin $j.body_types) { $j.body_types += "skeleton" }
if ("zombie" -notin $j.body_types) { $j.body_types += "zombie" }
$bodySlot = $j.slots.body.items | Where-Object { $_._id -eq "body" -or $_.id -eq "body" }
if (-not $bodySlot.paths.PSObject.Properties.Match("skeleton").Count) { $bodySlot.paths | Add-Member -Type NoteProperty -Name "skeleton" -Value "body/bodies/skeleton/" }
if (-not $bodySlot.paths.PSObject.Properties.Match("zombie").Count) { $bodySlot.paths | Add-Member -Type NoteProperty -Name "zombie" -Value "body/bodies/zombie/" }
if ("skeleton" -notin $bodySlot.required_body_types) { $bodySlot.required_body_types += "skeleton" }
if ("zombie" -notin $bodySlot.required_body_types) { $bodySlot.required_body_types += "zombie" }
$jsonString = $j | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText("C:\Users\Kendy\Downloads\mana-seed-test/resources/character/lpc_catalog.json", $jsonString, [System.Text.Encoding]::UTF8)
