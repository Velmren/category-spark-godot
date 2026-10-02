extends SceneTree

# Plays a full round in a rendered window with real mouse and keyboard events,
# checks that every control stays inside the window and saves the viewport.
# Run it with --audio-driver Dummy to keep the sound effects off the speakers.
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
    root.borderless = true
    root.position = Vector2i.ZERO
    root.size = Vector2i(width, height)
    scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    await _pause(1.2)
    _check(root.get_texture().get_image().get_size() == Vector2i(width, height), "window renders %dx%d pixels" % [width, height])
    await _capture("start")
    var planned_score := 0
    for index in range(6):
        _check(scene.current_index == index and not scene.answer_locked, "question %d ready" % (index + 1))
        await _capture("question-%02d" % (index + 1))
        var correct_option: int = scene.questions[index].correct_index
        var option := (correct_option + 1) % 4 if index == 1 else correct_option
        var button: Button = scene.answer_box.get_child(option)
        var motion := InputEventMouseMotion.new()
        motion.position = _pixels(button.get_global_rect().get_center())
        root.push_input(motion)
        await _pause(0.5)
        if index == 0:
            await _capture("selected")
        await _click(button)
        if index == 0:
            await _pause(0.2)
            await _capture("spark")
        await _pause(1.3)
        if option == correct_option:
            planned_score += 1
        _check(scene.answer_locked and scene.score == planned_score, "answer %d accepted once" % (index + 1))
        _check(scene.sheet.visible and scene.sheet.get_global_rect().position.y < scene.size.y - 40.0, "verdict sheet is up")
        await _capture("feedback-%02d" % (index + 1))
        if index == 0:
            await _capture("correct")
        if index == 1:
            await _capture("incorrect")
        await _click(scene.next_button)
        if index == 1 and recording:
            await _pause(0.3)
            await _capture("wipe")
            await _pause(1.0)
        else:
            await _pause(1.3)
    _check(scene.current_index == 6 and scene.score == 5 and scene.restart_button.visible, "mixed round result 5/6")
    await _pause(2.6)
    await _capture("result")
    await _click(scene.restart_button)
    await _pause(1.3)
    _check(scene.current_index == 0 and scene.score == 0 and not scene.answer_locked, "restart resets")
    await _capture("restart")
    if recording:
        # A recording ends with the fresh round; the keyboard pass runs in the plain checks.
        await _pause(1.0)
        print("CAPTURE_RUN ", width, "x", height, " failed=", failed)
        quit(1 if failed else 0)
        return
    # Keyboard: Tab reaches the first answer, Space answers, Enter advances.
    await _key(KEY_TAB)
    var first: Button = scene.answer_box.get_child(0)
    first.grab_focus()
    await _pause(0.3)
    await _capture("keyboard-focus")
    await _key(KEY_SPACE)
    await _pause(0.9)
    _check(scene.score == 1 and scene.answer_locked, "Space activates focused answer")
    await _key(KEY_ENTER)
    await _pause(0.9)
    _check(scene.current_index == 1 and not scene.answer_locked, "Enter advances focused next button")
    await _key(KEY_1)
    await _pause(0.4)
    _check(scene.answer_locked and scene.selected_index == 0, "number key chooses an answer")
    var locked_score: int = scene.score
    await _key(KEY_2)
    _check(scene.score == locked_score, "number keys cannot score twice")
    await _click(scene.motion_button)
    _check(not scene.motion_enabled, "motion can be disabled")
    await _click(scene.sound_button)
    _check(not scene.sound_enabled, "sound can be disabled")
    await _click(scene.next_button)
    await _pause(0.3)
    _check(scene.current_index == 2 and scene.view.modulate.a == 1.0, "without motion the next question is shown at once")
    await _capture("motion-off")
    scene.sfx.hush()
    await process_frame
    print("CAPTURE_RUN ", width, "x", height, " failed=", failed)
    quit(1 if failed else 0)

# Controls report design units; input events and the window use pixels.
func _pixels(point: Vector2) -> Vector2:
    return root.get_final_transform() * point

func _click(button: Button) -> void:
    if not button.is_visible_in_tree() or button.disabled:
        _check(false, "active click target")
        return
    var center := _pixels(button.get_global_rect().get_center())
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
        for i in int(seconds * 60):
            await process_frame
    else:
        await create_timer(seconds).timeout

func _capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    var viewport_image := root.get_texture().get_image()
    var status := viewport_image.save_png(output_dir.path_join(label + ".png"))
    _check(status == OK, "saved " + label)
    var controls := {
        "title": scene.title_label, "progress": scene.progress_label, "score": scene.score_label,
        "sound switch": scene.sound_button, "motion switch": scene.motion_button,
        "category": scene.category_label, "question": scene.question_label,
        "verdict": scene.verdict_label, "feedback": scene.feedback_label, "next": scene.next_button,
        "result score": scene.result_score, "result note": scene.result_note,
        "breakdown": scene.breakdown, "restart": scene.restart_button,
    }
    for child in scene.answer_box.get_children():
        controls["answer " + child.key_hint] = child
    var area := Rect2(Vector2.ZERO, scene.size).grow(0.5)
    var pixel_scale: float = root.get_final_transform().get_scale().y
    var shown := {}
    for title in controls:
        var control: Control = controls[title]
        if not control.is_visible_in_tree():
            continue
        shown[title] = control
        var rect := control.get_global_rect()
        if not area.encloses(rect):
            _check(false, "%s outside window %s" % [title, rect])
        if control is Button:
            var smallest := 28.0 if title.ends_with("switch") else 40.0
            if rect.size.y * pixel_scale < smallest:
                _check(false, "%s is only %.0f px high" % [title, rect.size.y * pixel_scale])
    # Text and buttons that are on screen together must not sit on top of each other.
    for title in ["category", "question", "result score", "result note", "verdict", "feedback"]:
        if not shown.has(title):
            continue
        for other in shown:
            if shown[other] is Button and not other.ends_with("switch"):
                if shown[title].get_global_rect().grow(-2.0).intersects(shown[other].get_global_rect()):
                    _check(false, "%s overlaps %s" % [title, other])
