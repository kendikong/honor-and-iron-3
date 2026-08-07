extends SceneTree
func _init():
	var H = load('res://tests/bruiser_qa_harness.gd')
	var cfg = H.with_upgraded_ability(H.bruiser_with_ability(&'bruiser_suplex'), &'bruiser_suplex')
	var board = H.make_plain_board(Vector2i(10, 8))
	H.place_bruiser(board, 1, Vector2i(3, 3), cfg)
	H.place_dummy(board, 2, Vector2i(3, 4))
	var skill = H.ability_on_unit(H.unit_on_board(board, 1), &'bruiser_suplex')
	var plan = load('res://core/state/timeline.gd').new()
	plan.add(H.plan_ability(1, skill, Vector2i(3, 4), 2))
	var result = H.simulate_plan(board, plan)
	for e in result.events:
		if e is SimEvent:
			print(e.primary_type, ' ', e.data)
	quit()
