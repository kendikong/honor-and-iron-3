extends SceneTree
func _initialize() -> void:
    DataLibrary._ensure_init()
    var dict_size = DataLibrary._all_units_dict.size()
    var player_size = DataLibrary._player_units.size()
    var f = FileAccess.open("user://temp_out6.txt", FileAccess.WRITE)
    f.store_line("Dict size: " + str(dict_size))
    f.store_line("Player size: " + str(player_size))
    f.close()
    quit(0)
