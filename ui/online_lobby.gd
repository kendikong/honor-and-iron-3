extends Control

const SERVER_URL = "http://127.0.0.1:8080"
const PORT = 7777

@onready var username_input: LineEdit = $VBoxContainer/UsernameInput
@onready var room_list_container: VBoxContainer = $VBoxContainer/ScrollContainer/RoomList
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Create Room Popup
@onready var create_popup: Panel = $CreateRoomPopup
@onready var create_name_input: LineEdit = $CreateRoomPopup/VBox/RoomNameInput
@onready var create_pass_input: LineEdit = $CreateRoomPopup/VBox/RoomPassInput

# Join Room Popup
@onready var join_popup: Panel = $JoinRoomPopup
@onready var join_pass_input: LineEdit = $JoinRoomPopup/VBox/RoomPassInput
var _selected_room_id: String = ""

# HTTP Requests
var _http_request: HTTPRequest
var _ip_request: HTTPRequest
var _public_ip: String = ""
var _pending_create_data: Dictionary = {}


func _ready() -> void:
	$VBoxContainer/TopBar/RefreshButton.pressed.connect(_on_refresh_pressed)
	$VBoxContainer/TopBar/CreateButton.pressed.connect(_on_create_popup_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	MenuNavigation.register(self, _on_back_pressed)
	
	$CreateRoomPopup/VBox/HBox/ConfirmButton.pressed.connect(_on_create_confirm)
	$CreateRoomPopup/VBox/HBox/CancelButton.pressed.connect(func(): create_popup.hide())
	
	$JoinRoomPopup/VBox/HBox/ConfirmButton.pressed.connect(_on_join_confirm)
	$JoinRoomPopup/VBox/HBox/CancelButton.pressed.connect(func(): join_popup.hide())
	
	create_popup.hide()
	join_popup.hide()
	
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.timeout = 5.0 # Set a 5 second timeout
	_http_request.request_completed.connect(_on_http_request_completed)
	
	if NetworkManager != null:
		NetworkManager.is_multiplayer = true
		username_input.text = NetworkManager.player_usernames.get(1, "")
		if username_input.text == "":
			username_input.text = "Player" + str(randi() % 1000)
			
	_refresh_rooms()

func _on_back_pressed() -> void:
	if NetworkManager and NetworkManager.multiplayer.has_multiplayer_peer():
		NetworkManager.multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_refresh_pressed() -> void:
	_refresh_rooms()

func _refresh_rooms() -> void:
	status_label.text = "Refreshing rooms..."
	print("Lobby: Refreshing rooms from server...")
	var err = _http_request.request(SERVER_URL + "/rooms", [], HTTPClient.METHOD_GET)
	if err != OK:
		print("Lobby: Failed to initiate get rooms request: ", err)
		status_label.text = "Failed to connect to lobby server."

func _on_create_popup_pressed() -> void:
	if username_input.text.strip_edges() == "":
		status_label.text = "Please enter a username first."
		return
	create_name_input.text = username_input.text + "'s Room"
	create_pass_input.text = ""
	create_popup.show()

func _on_create_confirm() -> void:
	var room_name = create_name_input.text.strip_edges()
	var room_pass = create_pass_input.text
	if room_name == "": return
	
	status_label.text = "Creating room..."
	create_popup.hide()
	
	# Prepare data for create request
	var data = {
		"name": room_name,
		"password": room_pass,
		"port": PORT
	}
	# If we already have public IP, include it. Otherwise fetch first.
	if _public_ip != "":
		data["override_ip"] = _public_ip
		_send_create_request(data)
	else:
		# Store pending data and fetch public IP first
		_pending_create_data = data
		_fetch_public_ip()

func _on_join_pressed(room_id: String) -> void:
	if username_input.text.strip_edges() == "":
		status_label.text = "Please enter a username first."
		return
	_selected_room_id = room_id
	join_pass_input.text = ""
	join_popup.show()

func _on_join_confirm() -> void:
	var room_pass = join_pass_input.text
	status_label.text = "Joining room..."
	join_popup.hide()
	
	var data = {
		"room_id": _selected_room_id,
		"password": room_pass
	}
	var headers = ["Content-Type: application/json"]
	_http_request.request(SERVER_URL + "/join", headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Lobby: HTTP Request Completed. Code: ", response_code, " Result: ", result)
	if result != HTTPRequest.RESULT_SUCCESS:
		status_label.text = "HTTP Request failed (Timeout or no connection)."
		return
	
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(response_text) != OK:
		print("Lobby: Failed to parse JSON response: ", response_text)
		status_label.text = "Invalid server response."
		return
	
	var data = json.get_data()
	
	if response_code == 200:
		if data.has("rooms"):
			_populate_room_list(data["rooms"])
			status_label.text = "Rooms updated."
		elif data.has("id"): # Create success
			_selected_room_id = data["id"]
			status_label.text = "Room created. Hosting game..."
			_host_and_wait()
		elif data.has("ip") and data.has("port"): # Join success
			status_label.text = "Connecting to Host %s:%d..." % [data["ip"], data["port"]]
			_join_and_wait(data["ip"], data["port"])
		else:
			# Unexpected successful response
			status_label.text = "Unexpected response from server."
	else:
		if data is Dictionary and data.has("error"):
			status_label.text = "Error: " + str(data["error"])
		else:
			status_label.text = "Error %d" % response_code

func _fetch_public_ip() -> void:
	status_label.text = "Configuring UPnP on router..."
	print("Lobby: Starting UPnP configuration...")
	var upnp_ip = NetworkManager.setup_upnp(PORT)
	if upnp_ip != "":
		status_label.text = "UPnP successful!"
		_public_ip = upnp_ip
		if _pending_create_data.size() > 0:
			_pending_create_data["override_ip"] = _public_ip
			_send_create_request(_pending_create_data)
			_pending_create_data.clear()
		return
		
	status_label.text = "UPnP failed. Fetching IP..."
	print("Lobby: UPnP failed. Falling back to HTTP IP discovery...")
	if _ip_request == null:
		_ip_request = HTTPRequest.new()
		add_child(_ip_request)
		_ip_request.timeout = 3.0 # Set a 3 second timeout for IP discovery
		_ip_request.request_completed.connect(_on_ip_request_completed)
	
	# Use HTTP instead of HTTPS to bypass SSL certificate issues
	var err = _ip_request.request("http://api.ipify.org?format=json")
	if err != OK:
		print("Lobby: Failed to start IP discovery request: ", err)
		status_label.text = "Failed to start IP request. Proceeding..."
		_fallback_create_room()

func _on_ip_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Lobby: IP Fetch request completed. Result: ", result)
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Lobby: IP fetch failed (timeout or network error). Proceeding without override...")
		status_label.text = "IP fetch failed. Proceeding without override..."
		_fallback_create_room()
		return
	var txt = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(txt) != OK:
		print("Lobby: IP parse failed. Plain text response: ", txt)
		status_label.text = "IP parse failed. Proceeding..."
		_fallback_create_room()
		return
	var ip_data = json.get_data()
	if typeof(ip_data) == TYPE_STRING:
		_public_ip = ip_data
	elif ip_data.has("ip"):
		_public_ip = ip_data["ip"]
	else:
		_public_ip = ""
		
	if _public_ip != "":
		print("Lobby: Obtained public IP: ", _public_ip)
		if _pending_create_data.size() > 0:
			_pending_create_data["override_ip"] = _public_ip
			_send_create_request(_pending_create_data)
			_pending_create_data.clear()
	else:
		print("Lobby: Public IP parse returned empty. Proceeding...")
		_fallback_create_room()

func _fallback_create_room() -> void:
	print("Lobby: Executing fallback room creation (no public IP override)")
	if _pending_create_data.size() > 0:
		# Send without override_ip so the server falls back to request sender IP
		_send_create_request(_pending_create_data)
		_pending_create_data.clear()

func _send_create_request(data: Dictionary) -> void:
	var headers = ["Content-Type: application/json"]
	_http_request.request(SERVER_URL + "/create", headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _populate_room_list(rooms: Array) -> void:
	for child in room_list_container.get_children():
		child.queue_free()
		
	if rooms.is_empty():
		var lbl = Label.new()
		lbl.text = "No active rooms found."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		room_list_container.add_child(lbl)
		return
		
	for r in rooms:
		var hbox = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = r["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var join_btn = Button.new()
		join_btn.text = "Join"
		join_btn.pressed.connect(func(): _on_join_pressed(r["id"]))
		hbox.add_child(join_btn)
		
		room_list_container.add_child(hbox)

# --- WEBRTC SIGNALING LOGIC ---

var is_host: bool = false
var webrtc_manager: Node
var poll_timer: Timer
var peer_id_str: String = ""

func _setup_webrtc():
	if not has_node("WebrtcManager"):
		webrtc_manager = load("res://core/systems/webrtc_manager.gd").new()
		webrtc_manager.name = "WebrtcManager"
		add_child(webrtc_manager)
		webrtc_manager.session_created.connect(_on_session_created)
		webrtc_manager.ice_candidate_created.connect(_on_ice_candidate_created)
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not has_node("PollTimer"):
		poll_timer = Timer.new()
		poll_timer.name = "PollTimer"
		poll_timer.wait_time = 0.25
		poll_timer.timeout.connect(_on_poll_timeout)
		add_child(poll_timer)

var _last_state = -1
func _process(_delta):
	if webrtc_manager and webrtc_manager.rtc_peer:
		var state = webrtc_manager.rtc_peer.get_connection_state()
		if state != _last_state:
			_last_state = state
			print("Lobby: WebRTC State Changed -> ", state)



func _on_session_created(type: String, data: String):
	print("Lobby: Sending ", type, " to server.")
	var req = { "room_id": _selected_room_id, "peer_id": peer_id_str, "type": type, "data": data }
	var h = HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(func(_r,_c,_headers,_b): h.queue_free())
	h.request(SERVER_URL + "/signal", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(req))

func _on_ice_candidate_created(media: String, index: int, cand_name: String):
	print("Lobby: Sending ICE candidate to server.")
	var req = { "room_id": _selected_room_id, "peer_id": peer_id_str, "type": "candidate", "data": {"media":media, "index":index, "name":cand_name} }
	var h = HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(func(_r,_c,_headers,_b): h.queue_free())
	h.request(SERVER_URL + "/signal", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(req))

var _last_ice_idx = 0

func _on_poll_timeout():
	var req = { "room_id": _selected_room_id, "peer_id": peer_id_str, "last_candidate_idx": _last_ice_idx }
	var h = HTTPRequest.new()
	add_child(h)
	h.request_completed.connect(_on_poll_response.bind(h))
	h.request(SERVER_URL + "/poll", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(req))

var _offer_received = false
var _answer_received = false

func _on_poll_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_req: HTTPRequest):
	http_req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200: return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK: return
	var data = json.get_data()
	
	if is_host:
		if data.has("client_joined") and data["client_joined"] and not _offer_received:
			print("Lobby: Client joined! Creating offer...")
			_offer_received = true
			webrtc_manager.create_offer()
		if data.has("answer") and data["answer"] != null and not _answer_received:
			print("Lobby: Received answer!")
			_answer_received = true
			webrtc_manager.set_remote_description("answer", data["answer"])
	else:
		if data.has("offer") and data["offer"] != null and not _offer_received:
			print("Lobby: Received offer! Creating answer...")
			_offer_received = true
			webrtc_manager.set_remote_description("offer", data["offer"])
			webrtc_manager.create_answer()
			
	var cands = data.get("candidates", [])
	for c in cands:
		webrtc_manager.add_ice_candidate(c["media"], int(c["index"]), c["name"])
		_last_ice_idx += 1

func _on_peer_connected(id: int):
	print("Lobby: WEBRTC CONNECTED to peer ", id)
	if poll_timer:
		poll_timer.stop()
	get_tree().change_scene_to_file("res://scenes/LanWaitingRoom.tscn")



func _host_and_wait() -> void:
	_setup_webrtc()
	var username = username_input.text.strip_edges()
	var err = webrtc_manager.host_webrtc_game(username)
	if err == OK:
		is_host = true
		peer_id_str = "1"
		status_label.text = "Waiting for players to join..."
		poll_timer.start()
	else:
		status_label.text = "Failed to start WebRTC server: Error %d" % err

func _join_and_wait(_ip: String, _port: int) -> void:
	_setup_webrtc()
	var username = username_input.text.strip_edges()
	var err = webrtc_manager.join_webrtc_game(username)
	if err == OK:
		is_host = false
		peer_id_str = "2"
		status_label.text = "Connecting via WebRTC..."
		poll_timer.start()
	else:
		status_label.text = "Failed to connect to WebRTC: Error %d" % err
