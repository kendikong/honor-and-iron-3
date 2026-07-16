extends SceneTree

func _init():
	print("--- SNAPSHOT PREVIEW ---")
	var root = Node2D.new()
	var viewport = SubViewport.new()
	viewport.size = Vector2i(385, 140)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	root.add_child(viewport)
	
	var preview = CharacterPreview.new()
	preview.position = Vector2(192.5, 100.0)
	viewport.add_child(preview)
	
	var profile = CharacterGenProfile.new()
	var catalog = LpcCatalog.load_from_disk()
	
	# We must process a frame to let shaders and sprites update?
	# In a script without a main loop, SubViewport might not render immediately.
	# We can use a small timer or manual update.
	
	preview.roll_and_apply(catalog, profile)
	preview.set_action("walk")
	
	# wait for 2 frames
	await create_timer(0.1).timeout
	await create_timer(0.1).timeout
	
	var img = viewport.get_texture().get_image()
	img.save_png("tools/preview_snapshot.png")
	
	print("Saved to tools/preview_snapshot.png")
	print("--- END TEST ---")
	quit()
