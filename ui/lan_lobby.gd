extends Control

func _ready() -> void:
	$VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)
	
	if NetworkManager:
		NetworkManager.peer_connected.connect(_on_peer_connected)
		NetworkManager.connected_to_server.connect(_on_connected_to_server)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var username = $VBoxContainer/UsernameInput.text
	if username == "":
		username = "Host"
	var err = NetworkManager.host_game(7777, username)
	if err == OK:
		$VBoxContainer/StatusLabel.text = "Hosting on port 7777... Waiting for peer."
	else:
		$VBoxContainer/StatusLabel.text = "Failed to host."

func _on_join_pressed() -> void:
	var username = $VBoxContainer/UsernameInput.text
	if username == "":
		username = "Client"
	var ip = $VBoxContainer/IPInput.text
	if ip == "":
		ip = "127.0.0.1"
	var err = NetworkManager.join_game(ip, 7777, username)
	if err == OK:
		$VBoxContainer/StatusLabel.text = "Connecting to " + ip + "..."
	else:
		$VBoxContainer/StatusLabel.text = "Failed to connect."

func _on_peer_connected(id: int) -> void:
	$VBoxContainer/StatusLabel.text = "Peer connected! Entering waiting room..."
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/LanWaitingRoom.tscn")

func _on_connected_to_server() -> void:
	$VBoxContainer/StatusLabel.text = "Connected to server! Entering waiting room..."
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/LanWaitingRoom.tscn")

func _on_connection_failed() -> void:
	$VBoxContainer/StatusLabel.text = "Connection failed."

func _on_server_disconnected() -> void:
	$VBoxContainer/StatusLabel.text = "Server disconnected."

func _on_back_pressed() -> void:
	if NetworkManager.is_multiplayer:
		multiplayer.multiplayer_peer = null
		NetworkManager.is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
