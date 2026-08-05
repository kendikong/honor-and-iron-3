extends Control

func _ready() -> void:
	$VBoxContainer/LeaveButton.pressed.connect(_on_leave_pressed)
	MenuNavigation.register(self, _on_leave_pressed)
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/ChatContainer/HBoxContainer/SendButton.pressed.connect(_on_send_pressed)
	$VBoxContainer/ChatContainer/HBoxContainer/ChatInput.text_submitted.connect(func(text): _on_send_pressed())
	
	if NetworkManager:
		NetworkManager.peer_connected.connect(_on_peer_connected)
		NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	_update_ui()

func _update_ui() -> void:
	var player_count = 1
	var usernames = [NetworkManager.local_username]
	if multiplayer.has_multiplayer_peer():
		player_count = 1 + multiplayer.get_peers().size()
		for peer_id in multiplayer.get_peers():
			if NetworkManager.player_usernames.has(peer_id):
				usernames.append(NetworkManager.player_usernames[peer_id])
			else:
				usernames.append("Player " + str(peer_id))
	
	$VBoxContainer/PlayersLabel.text = "Players in lobby: " + str(player_count) + " (" + ", ".join(usernames) + ")"
	
	# Only host can start the game
	if multiplayer.is_server():
		$VBoxContainer/StartButton.visible = true
		$VBoxContainer/StatusLabel.visible = false
		$VBoxContainer/StartButton.disabled = (player_count < 2)
	else:
		$VBoxContainer/StartButton.visible = false
		$VBoxContainer/StatusLabel.visible = true
		$VBoxContainer/StatusLabel.text = "Waiting for host to start..."

func _on_peer_connected(id: int) -> void:
	_update_ui()

func _on_peer_disconnected(id: int) -> void:
	_update_ui()

func _on_server_disconnected() -> void:
	_on_leave_pressed()

func _on_leave_pressed() -> void:
	if NetworkManager.is_multiplayer:
		multiplayer.multiplayer_peer = null
		NetworkManager.is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/LanLobby.tscn")

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		rpc_start_game.rpc()

func _on_send_pressed() -> void:
	var input_box = $VBoxContainer/ChatContainer/HBoxContainer/ChatInput
	var text = input_box.text.strip_edges()
	if text != "":
		rpc_receive_chat.rpc(NetworkManager.local_username, text)
		input_box.text = ""

@rpc("any_peer", "call_local")
func rpc_receive_chat(username: String, message: String) -> void:
	var chat_history = $VBoxContainer/ChatContainer/ChatHistory
	chat_history.append_text("[b]" + username + ":[/b] " + message + "\n")

@rpc("authority", "call_local")
func rpc_start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleSetup.tscn")
