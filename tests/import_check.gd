extends SceneTree

const TriviaImporter = preload("res://scripts/trivia_importer.gd")

func _init() -> void:
    var checks := [
        {"path": "res://data/questions.json", "want_ok": true, "want_error": ""},
        {"path": "res://tests/duplicate-id.json", "want_ok": false, "want_error": "DUPLICATE_QUESTION_ID:same-id"},
        {"path": "res://tests/missing-field.json", "want_ok": false, "want_error": "MISSING_QUESTION_FIELD:prompt"}
    ]
    var failed := false
    for check in checks:
        var result := TriviaImporter.load_file(check.path)
        var passed: bool = result.ok == check.want_ok and (check.want_error == "" or result.error == check.want_error)
        print("IMPORT_CHECK ", check.path, " => ", "PASS" if passed else "FAIL", " (", result.error, ")")
        failed = failed or not passed
    quit(1 if failed else 0)
