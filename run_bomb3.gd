extends SceneTree

func _init() -> void:
    var runner = load("res://tests/sim_test_runner.gd").new()
    var result = runner._test_bomber_explodes()
    var f = FileAccess.open("res://run_bomb_result.txt", FileAccess.WRITE)
    f.store_string(str(result))
    f.close()
    print("FINISHED")
    quit()
