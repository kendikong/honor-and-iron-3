extends SceneTree

const _REGISTRY = preload("res://tests/bruiser_scenario_registry.gd")
const _UPGRADES = preload("res://tests/bruiser_qa_harness_upgrades.gd")

func _init() -> void:
	var failures: Array[String] = []
	for entry: Dictionary in _REGISTRY.all_entries():
		var name: String = String(entry.get("name", "?"))
		_UPGRADES.run_upgrade_for(name, failures)
	
	if failures.is_empty():
		print("[PASS] Bruiser upgrades passed")
		quit(0)
	else:
		print("[FAIL] Bruiser upgrades failed")
		for f in failures:
			print("  " + f)
		quit(1)

