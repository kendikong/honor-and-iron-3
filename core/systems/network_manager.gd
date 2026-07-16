extends Node
# Make this a global accessible by name "NetworkManager" in autoloads

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()

var is_multiplayer: bool = false
var local_player_id: int = 1
var local_username: String = "Player"
var player_usernames: Dictionary = {}
var upnp: UPNP = null

func setup_upnp(port: int) -> String:
	upnp = UPNP.new()
	var err = upnp.discover()
	if err != UPNP.UPNP_RESULT_SUCCESS:
		print("UPnP Discover Failed: ", err)
		return ""
		
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		var map_result = upnp.add_port_mapping(port, port, "Honor and Iron", "UDP")
		if map_result != UPNP.UPNP_RESULT_SUCCESS:
			print("UPnP Port Mapping Failed: ", map_result)
			return ""
			
		print("UPnP Port Mapping Successful on port: ", port)
		return upnp.query_external_address()
	return ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int, username: String) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_multiplayer = true
		local_player_id = 1
		local_username = username
		player_usernames[1] = username
	return err

func join_game(ip: String, port: int, username: String) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_multiplayer = true
		local_username = username
	return err

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		rpc_id(id, "sync_all_players", player_usernames)
	rpc_id(id, "register_player", local_username)
	peer_connected.emit(id)

@rpc("any_peer", "call_remote", "reliable")
func register_player(username: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	player_usernames[sender_id] = username
	if multiplayer.is_server():
		rpc("sync_player", sender_id, username)

@rpc("authority", "call_remote", "reliable")
func sync_player(id: int, username: String) -> void:
	player_usernames[id] = username

@rpc("authority", "call_remote", "reliable")
func sync_all_players(players: Dictionary) -> void:
	for id in players:
		player_usernames[id] = players[id]

func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	local_player_id = multiplayer.get_unique_id()
	player_usernames[local_player_id] = local_username
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
