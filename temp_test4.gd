extends SceneTree
func _initialize() -> void:
    var f = FileAccess.open("user://temp_out4.txt", FileAccess.WRITE)
    f.store_line("PLAYER_UNITS_COUNT=" + str(DataLibrary.get_all_player_units().size()))
    f.store_line("ALL_UNITS_DICT_KEYS=" + str(DataLibrary._all_units_dict.keys()))
    f.close()
    quit(0)
