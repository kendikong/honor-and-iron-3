extends SceneTree

func _init():
	print("--- TEST WALK UP ---")
	var frames = LpcSheetFrames.get_lazy_frames("body/bodies/female/", "", "")
	LpcSheetFrames.ensure_animation(frames, "walk_up")
	print("Has walk_up: ", frames.has_animation("walk_up"))
	if frames.has_animation("walk_up"):
		print("Frame count: ", frames.get_frame_count("walk_up"))
		var tex = frames.get_frame_texture("walk_up", 0) as AtlasTexture
		if tex:
			print("Atlas region: ", tex.region)
			print("Atlas texture size: ", tex.atlas.get_size())
	print("--- END TEST ---")
	quit()
