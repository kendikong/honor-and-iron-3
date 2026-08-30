extends SceneTree

func _init():
	print("Running architecture heuristics audit...")
	var has_failures := false
	
	var files_to_check: Array[String] = [
		"res://core/systems/ability_system.gd",
		"res://core/systems/physics_system.gd",
		"res://core/systems/combat_system.gd",
		"res://core/systems/movement_system.gd",
		"res://core/systems/terrain_system.gd",
		"res://core/simulation/simulator.gd"
	]
	
	var forbidden_strings: Array[String] = [
		"ability.id ==",
		"ability_id ==",
		"\"knight_",
		"&\"knight_",
		"\"mage_",
		"&\"mage_",
		"\"is_dash\""
	]
	
	for file_path in files_to_check:
		if not FileAccess.file_exists(file_path):
			continue
			
		var file := FileAccess.open(file_path, FileAccess.READ)
		var content := file.get_as_text()
		var lines := content.split("\n")
		
		for line_num in range(lines.size()):
			var line := lines[line_num]
			
			# Ignore comments
			if line.strip_edges().begins_with("#"):
				continue
				
			for forbidden in forbidden_strings:
				if line.find(forbidden) != -1:
					has_failures = true
					push_error("ARCHITECTURAL VIOLATION: Found forbidden string '%s' in %s at line %d:\n\t%s" % [forbidden, file_path, line_num + 1, line.strip_edges()])
					
	if has_failures:
		push_error("Architecture Heuristics Audit FAILED! You must use data-driven modifiers (EffectType / StatusType) instead of hardcoding ability IDs or class names in the engine backend.")
		quit(1)
	else:
		print("Architecture Heuristics Audit PASSED.")
		quit(0)
