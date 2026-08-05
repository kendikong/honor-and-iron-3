extends SceneTree
func _initialize() -> void:
    var f = FileAccess.open("user://temp_out3.txt", FileAccess.WRITE)
    f.store_line("START")
    var knight = DataLibrary.get_unit(&"knight")
    f.store_line("KNIGHT=" + str(knight))
    if knight != null:
        f.store_line("KNIGHT_ABILITIES=" + str(knight.abilities.size()))
    f.close()
    quit(0)
