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

func _on_mass_sim_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/analysis/analysis_dashboard.tscn")


func _on_dev_sandbox_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test_map.tscn")

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

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Options.tscn")
