extends SceneTree

func _init():
	var file = FileAccess.open("res://resources/character/lpc_catalog.json", FileAccess.READ)
	if not file:
		print("Failed to open file")
		quit()
		return
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		print("JSON Parse Error: ", json.get_error_message(), " in ", content.left(50))
		quit()
		return
	
	var data = json.data
	if not data["body_types"].has("skeleton"):
		data["body_types"].append("skeleton")
	if not data["body_types"].has("zombie"):
		data["body_types"].append("zombie")
		
	var body_items = data["slots"]["body"]["items"]
	var body_slot = null
	for item in body_items:
		if item["id"] == "body":
			body_slot = item
			break
			
	if body_slot != null:
		body_slot["paths"]["skeleton"] = "body/bodies/skeleton/"
		body_slot["paths"]["zombie"] = "body/bodies/zombie/"
		if not body_slot["required_body_types"].has("skeleton"):
			body_slot["required_body_types"].append("skeleton")
		if not body_slot["required_body_types"].has("zombie"):
			body_slot["required_body_types"].append("zombie")
			
	file = FileAccess.open("res://resources/character/lpc_catalog.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Done updating catalog!")
	quit()
