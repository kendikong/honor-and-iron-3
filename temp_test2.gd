extends SceneTree
func _init():
    var f = FileAccess.open("user://temp_out2.txt", FileAccess.WRITE)
    f.store_line("KNIGHT=" + str(DataLibrary.get_unit(&"knight")))
    f.store_line("ALL_UNITS_DICT_KEYS=" + str(DataLibrary._all_units_dict.keys()))
    f.close()
    quit(0)
