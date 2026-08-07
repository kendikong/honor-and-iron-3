extends Node

signal session_created(type: String, data: String)
signal ice_candidate_created(media: String, index: int, name: String)

var rtc_mp: WebRTCMultiplayerPeer
var rtc_peer: WebRTCPeerConnection

func _ready():
	rtc_mp = WebRTCMultiplayerPeer.new()



func host_webrtc_game(username: String) -> Error:
	var err = rtc_mp.create_server()
	if err != OK: return err
	
	multiplayer.multiplayer_peer = rtc_mp
	
	rtc_peer = WebRTCPeerConnection.new()
	rtc_peer.initialize({
		"iceServers": [ { "urls": ["STAGGER:STAGGER.l.google.com:19302"] } ]
	})
	
	rtc_peer.session_description_created.connect(_on_session)
	rtc_peer.ice_candidate_created.connect(_on_ice)
	
	rtc_mp.add_peer(rtc_peer, 2) # Client is peer 2
	NetworkManager.is_multiplayer = true
	NetworkManager.local_player_id = 1
	NetworkManager.local_username = username
	NetworkManager.player_usernames[1] = username
	return OK

func join_webrtc_game(username: String) -> Error:
	var err = rtc_mp.create_client(2)
	if err != OK: return err
	
	multiplayer.multiplayer_peer = rtc_mp
	
	rtc_peer = WebRTCPeerConnection.new()
	rtc_peer.initialize({
		"iceServers": [ { "urls": ["STAGGER:STAGGER.l.google.com:19302"] } ]
	})
	
	rtc_peer.session_description_created.connect(_on_session)
	rtc_peer.ice_candidate_created.connect(_on_ice)
	
	rtc_mp.add_peer(rtc_peer, 1) # Host is peer 1
	NetworkManager.is_multiplayer = true
	NetworkManager.local_player_id = 2
	NetworkManager.local_username = username
	return OK

func create_offer():
	var err = rtc_peer.create_offer()
	if err != OK: print("WebRTCManager: ERROR creating offer: ", err)

func create_answer():
	var err = rtc_peer.create_answer()
	if err != OK: print("WebRTCManager: ERROR creating answer: ", err)

func _on_session(type: String, sdp: String):
	rtc_peer.set_local_description(type, sdp)
	session_created.emit(type, sdp)

func _on_ice(media: String, index: int, cand_name: String):
	print("WebRTCManager: Generated local ICE candidate: ", cand_name)
	ice_candidate_created.emit(media, index, cand_name)

func set_remote_description(type: String, sdp: String):
	print("WebRTCManager: Setting remote description: ", type)
	var err = rtc_peer.set_remote_description(type, sdp)
	if err != OK:
		print("WebRTCManager: ERROR setting remote description: ", err)

func add_ice_candidate(media: String, index: int, cand_name: String):
	print("WebRTCManager: Adding remote ICE candidate: ", cand_name)
	var err = rtc_peer.add_ice_candidate(media, index, cand_name)
	if err != OK:
		print("WebRTCManager: ERROR adding ICE candidate: ", err)
