extends Control

func _ready() -> void:
	$VBoxContainer/LocalCoopButton.pressed.connect(_on_local_coop_pressed)
	$VBoxContainer/LanCoopButton.pressed.connect(_on_lan_coop_pressed)
	$VBoxContainer/OnlineCoopButton.pressed.connect(_on_online_coop_pressed)
	$VBoxContainer/CompendiumButton.pressed.connect(_on_compendium_pressed)
	$VBoxContainer/OptionsButton.pressed.connect(_on_options_pressed)
	
	var sim_btn = Button.new()
	sim_btn.text = "Mass Simulation Analytics"
	sim_btn.pressed.connect(_on_mass_sim_pressed)
	$VBoxContainer.add_child(sim_btn)

	var dev_btn := Button.new()
	dev_btn.text = "Map Dev Sandbox"
	dev_btn.pressed.connect(_on_dev_sandbox_pressed)
	$VBoxContainer.add_child(dev_btn)

	var test_battle_btn := Button.new()
	test_battle_btn.text = "Skill Test Arena"
	test_battle_btn.pressed.connect(_on_test_battle_pressed)
	$VBoxContainer.add_child(test_battle_btn)

	var library_btn := Button.new()
	library_btn.text = "Class Library Editor"
	library_btn.pressed.connect(_on_class_library_pressed)
	$VBoxContainer.add_child(library_btn)

func _on_mass_sim_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MassSimDashboard.tscn")


func _on_dev_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test_map.tscn")


func _on_test_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TestBattle.tscn")

func _on_local_coop_pressed() -> void:
	if NetworkManager:
		NetworkManager.is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")

func _on_lan_coop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/LanLobby.tscn")

func _on_online_coop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")

func _on_compendium_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Compendium.tscn")


func _on_class_library_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ClassLibraryEditor.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Options.tscn")
