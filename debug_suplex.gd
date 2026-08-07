class_name DebugSuplex extends SceneTree
func _init():
	var failures: Array[String] = []
	var ab = preload('res://tests/qa_test_helpers.gd').factory_ability(&'bruiser_suplex')
	var cfg = preload('res://tests/qa_test_helpers.gd').with_upgraded_ability(preload('res://tests/qa_test_helpers.gd').bruiser_with_ability(&'bruiser_suplex'), &'bruiser_suplex')
	var board = preload('res://tests/qa_test_helpers.gd').make_plain_board(Vector2i(10, 8))
	preload('res://tests/qa_test_helpers.gd').place_bruiser(board, 1, Vector2i(3, 3), cfg)
	preload('res://tests/qa_test_helpers.gd').place_dummy(board, 2, Vector2i(3, 4))
	var plan = preload('res://core/state/timeline.gd').new()
	plan.add(preload('res://tests/qa_test_helpers.gd').plan_ability(1, ab, Vector2i(3, 4), 2))
	var result = preload('res://tests/qa_test_helpers.gd').simulate_plan(board, plan)
	for e in result.events:
		print(e.primary_type, ' ', e.data)
	quit()
