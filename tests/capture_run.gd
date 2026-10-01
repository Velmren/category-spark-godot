extends SceneTree

# Sends real mouse/keyboard events to a rendered Godot viewport, never paints UI.
var failed := false
var recording := false
var scene: Control
var output_dir: String

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    print("CAPTURE_CHECK ", label, " => ", "PASS" if condition else "FAIL")
    failed = failed or not condition

func _run() -> void:
    output_dir = OS.get_environment("CATEGORY_SPARK_CAPTURE_DIR")
    recording = OS.get_environment("CATEGORY_SPARK_RECORD") == "1"
    var width := int(OS.get_environment("CATEGORY_SPARK_WIDTH"))
    var height := int(OS.get_environment("CATEGORY_SPARK_HEIGHT"))
    if output_dir.is_empty() or width <= 0 or height <= 0:
        push_error("Capture directory and dimensions are required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output_dir)
    root.size = Vector2i(width, height)
    scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await _pause(1.0)
    await _capture("start")
    var planned_score := 0
    for index in range(6):
        _check(scene.current_index == index and not scene.answer_locked, "question %d ready" % (index + 1))
        await _capture("question-%02d" % (index + 1))
        var correct_option: int = scene.questions[index].correct_index
        var option := (correct_option + 1) % 4 if index == 1 else correct_option
        var button: Button = scene.answer_box.get_child(option)
        var motion := InputEventMouseMotion.new()
        motion.position = button.get_global_rect().get_center()
        root.push_input(motion)
        await _pause(0.55)
        if index == 0:
            await _capture("selected")
        await _click(button)
        await _pause(1.25)
        if option == correct_option:
            planned_score += 1
        _check(scene.answer_locked and scene.score == planned_score, "answer %d accepted once" % (index + 1))
        await _capture("feedback-%02d" % (index + 1))
        if index == 0:
            await _capture("correct")
            await _capture("feedback")
        if index == 1:
            await _capture("incorrect")
        await _click(scene.next_button)
        await _pause(0.75)
    _check(scene.current_index == 6 and scene.score == 5 and scene.restart_button.visible, "mixed round result 5/6")
    await _pause(1.5)
    await _capture("result")
    await _click(scene.restart_button)
    await _pause(1.0)
    _check(scene.current_index == 0 and scene.score == 0 and not scene.answer_locked, "restart resets")
    await _capture("restart")
    # Verify native keyboard focus and activate an answer using Space.
    var first: Button = scene.answer_box.get_child(0)
    first.grab_focus()
    await _pause(0.2)
    await _capture("keyboard-focus")
    await _key(KEY_SPACE)
    await _pause(0.3)
    _check(scene.score == 1 and scene.answer_locked, "Space activates focused answer")
    await _key(KEY_ENTER)
    await _pause(0.3)
    _check(scene.current_index == 1 and not scene.answer_locked, "Enter advances focused next button")
    await _key(KEY_1)
    await _pause(0.1)
    _check(scene.answer_locked and scene.selected_index == 0, "number key chooses an answer")
    var locked_score: int = scene.score
    await _key(KEY_2)
    _check(scene.score == locked_score, "number keys cannot score twice")
    if scene.motion_button.visible:
        await _click(scene.motion_button)
        _check(not scene.motion_enabled, "motion can be disabled")
    print("CAPTURE_RUN ", width, "x", height, " failed=", failed)
    quit(1 if failed else 0)

func _click(button: Button) -> void:
    if not button.is_visible_in_tree() or button.disabled:
        _check(false, "active click target " + button.text)
        return
    var center := button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = center
    root.push_input(motion)
    await process_frame
    for pressed in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = center
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event)
        await process_frame

func _key(code: Key) -> void:
    for pressed in [true, false]:
        var event := InputEventKey.new()
        event.keycode = code
        event.pressed = pressed
        root.push_input(event)
        await process_frame

func _pause(seconds: float) -> void:
    if recording:
        for i in int(seconds * 30):
            await process_frame
    else:
        await create_timer(minf(seconds, 0.25)).timeout

func _capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    var viewport_image := root.get_texture().get_image()
    var status := viewport_image.save_png(output_dir.path_join(label + ".png"))
    _check(status == OK, "saved " + label)
    var controls: Array[Control] = [scene.title_label, scene.progress_label, scene.question_label, scene.feedback_label, scene.score_label, scene.result_score, scene.result_note, scene.next_button, scene.restart_button]
    for child in scene.answer_box.get_children():
        controls.append(child)
    for control in controls:
        if not control.is_visible_in_tree():
            continue
        var rect := control.get_global_rect()
        var within := rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= root.size.x + 0.1 and rect.end.y <= root.size.y + 0.1
        if not within:
            _check(false, "%s outside viewport %s" % [control.name, rect])
        if control is Button:
            _check(rect.size.y >= 44, "target height " + control.text)


    var action: Button = scene.restart_button if scene.restart_button.is_visible_in_tree() else scene.next_button
    for label_control in [scene.question_label, scene.feedback_label, scene.result_score, scene.result_note]:
        if label_control.is_visible_in_tree():
            _check(not label_control.get_global_rect().intersects(action.get_global_rect()), "text does not overlap action")
