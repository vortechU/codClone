extends Node

var save_path = "user://savegame.save" # "user://" saves to the computer's AppData folder

func save_score(score: int) -> void:
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_var(score)
    file.close()

func load_score() -> int:
    if FileAccess.file_exists(save_path):
        var file = FileAccess.open(save_path, FileAccess.READ)
        var saved_score = file.get_var()
        file.close()
        return saved_score
    return 0 # Return 0 if no save file exists  