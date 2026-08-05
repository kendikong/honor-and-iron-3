extends Node

signal timeline_updated()
signal player_ready_changed(player_id: int, is_ready: bool)

var actions: Array = []
var player_ready_states: Dictionary = {}

func _ready() -> void:
	pass

@rpc("any_peer", "call_local")
func rpc_add_action(action_data: Dictionary) -> void:
	actions.append(action_data)
	timeline_updated.emit()

@rpc("any_peer", "call_local")
func rpc_remove_action(index: int) -> void:
	if index >= 0 and index < actions.size():
		actions.remove_at(index)
		timeline_updated.emit()

@rpc("any_peer", "call_local")
func rpc_clear_actions() -> void:
	actions.clear()
	timeline_updated.emit()

@rpc("any_peer", "call_local")
func rpc_set_ready(is_ready: bool) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = NetworkManager.local_player_id
	player_ready_states[sender_id] = is_ready
	player_ready_changed.emit(sender_id, is_ready)

func is_everyone_ready() -> bool:
	if not NetworkManager.is_multiplayer:
		return player_ready_states.get(1, false)
	
	for peer_id in multiplayer.get_peers():
		if not player_ready_states.get(peer_id, false):
			return false
	if not player_ready_states.get(1, false):
		return false
	return true

@rpc("authority", "call_local")
func rpc_reset_ready_states() -> void:
	for k in player_ready_states.keys():
		player_ready_states[k] = false
		player_ready_changed.emit(k, false)
