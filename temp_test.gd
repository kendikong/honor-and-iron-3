extends SceneTree
func _init():
	var r = preload('res://tests/sim_test_runner.gd').new()
	var res = r._test_run_available_next_turn()
	print('RESULT: ', res)
	quit()

