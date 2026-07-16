extends SceneTree

func _init():
	print("--- TEST PIXELS ---")
	var frames = LpcSheetFrames.get_lazy_frames("body/bodies/female/", "", "")
	LpcSheetFrames.ensure_animation(frames, "walk_up")
	
	if frames.has_animation("walk_up"):
		var tex = frames.get_frame_texture("walk_up", 0) as AtlasTexture
		if tex:
			print("Atlas size: ", tex.atlas.get_size())
	print("--- END TEST ---")
	quit()
