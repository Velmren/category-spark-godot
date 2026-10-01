extends SceneTree

var failed := false

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    print("GAMEPLAY_CHECK ", label, " => ", "PASS" if condition else "FAIL")
    failed = failed or not condition

func _run() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await process_frame

    _check(scene.questions.size() == 6, "six questions loaded")
    _check(scene.current_index == 0 and scene.score == 0 and not scene.answer_locked, "initial state")
    _check(scene.answer_box.get_child_count() == 4 and scene.next_button.disabled, "first question controls")

    scene._answer(0)
    _check(scene.answer_locked and scene.score == 1, "first answer locks and scores")
    _check(not scene.next_button.disabled, "advance enabled after answer")
    scene._answer(1)
    _check(scene.score == 1, "second answer attempt ignored")

    scene._next_question()
    await process_frame
    _check(scene.current_index == 1 and not scene.answer_locked and scene.next_button.disabled, "advance resets answer state")

    while scene.current_index < scene.questions.size():
        scene._answer(scene.questions[scene.current_index].correct_index)
        scene._next_question()
        await process_frame

    _check(scene.current_index == 6 and scene.score == 6, "six-question round completes")
    _check(scene.restart_button.visible and not scene.next_button.visible and scene.result_score.text == "6 / 6", "result screen")

    scene._restart_round()
    await process_frame
    _check(scene.current_index == 0 and scene.score == 0 and not scene.answer_locked, "restart resets round")
    _check(not scene.restart_button.visible and scene.next_button.disabled and scene.answer_box.get_child_count() == 4, "restart restores first question")

    scene._answer(1)
    _check(scene.score == 0 and scene.feedback_label.text == "Not quite. The answer is Hertz.", "incorrect answer feedback")
    _check(scene.answer_locked and not scene.next_button.disabled, "incorrect answer can advance")

    scene.queue_free()
    await process_frame
    quit(1 if failed else 0)
