extends Control

const TriviaImporter = preload("res://scripts/trivia_importer.gd")
const DISPLAY_FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const INK = Color("edf5ff")
const MUTED = Color("a6bad1")
const CYAN = Color("37dfff")
const GREEN = Color("b6f36b")
const RED = Color("ff9baf")

var questions: Array = []
var current_index := 0
var score := 0
var answer_locked := false
var selected_index := -1
var category_label: Label
var progress_label: Label
var question_label: Label
var feedback_label: Label
var score_label: Label
var answer_box: GridContainer
var next_button: Button
var restart_button: Button
var title_label: Label
var subtitle: Label
var footer: Label
var card: Panel
var result_score: Label
var result_note: Label
var progress_bar: ProgressBar
var motion_button: Button
var motion_enabled := true
var transition: Tween
var completed: Array[bool] = []

func _ready() -> void:
    _build_interface()
    var imported := TriviaImporter.load_file("res://data/questions.json")
    if not imported.ok:
        category_label.text = "QUESTIONS UNAVAILABLE"
        question_label.text = "The question set could not be opened."
        feedback_label.text = "Restore data/questions.json and reopen the game."
        next_button.visible = false
        push_error(imported.error)
        _apply_layout()
        return
    for category in imported.data.categories:
        for question in category.questions:
            questions.append(question)
    _restart_round()

func _label(parent: Node, text: String, font_size: int, color: Color, center := false) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    if center:
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func _style(fill: Color, border: Color, radius := 10, width := 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _button(parent: Node, text: String, primary := false) -> Button:
    var button := Button.new()
    button.text = text
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color("071423") if primary else INK)
    button.add_theme_color_override("font_hover_color", Color("071423") if primary else CYAN)
    button.add_theme_color_override("font_pressed_color", Color("071423") if primary else CYAN)
    button.add_theme_color_override("font_focus_color", Color("071423") if primary else CYAN)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_stylebox_override("normal", _style(CYAN if primary else Color("132338"), CYAN if primary else Color("365470")))
    button.add_theme_stylebox_override("hover", _style(Color("80edff") if primary else Color("17354b"), CYAN, 10, 2))
    button.add_theme_stylebox_override("pressed", _style(Color("21bedf") if primary else Color("20435a"), CYAN, 10, 2))
    button.add_theme_stylebox_override("disabled", _style(Color("102034"), Color("294359")))
    var focus := _style(Color(0, 0, 0, 0), Color("ffffff"), 10, 2)
    focus.expand_margin_left = 3
    focus.expand_margin_right = 3
    focus.expand_margin_top = 3
    focus.expand_margin_bottom = 3
    button.add_theme_stylebox_override("focus", focus)
    parent.add_child(button)
    return button

func _build_interface() -> void:
    title_label = _label(self, "CATEGORY SPARK", 46, CYAN, true)
    title_label.add_theme_font_override("font", DISPLAY_FONT)
    title_label.add_theme_color_override("font_shadow_color", Color("104f76"))
    title_label.add_theme_constant_override("shadow_offset_y", 3)
    title_label.add_theme_constant_override("outline_size", 1)
    title_label.add_theme_color_override("font_outline_color", Color("167da0"))
    subtitle = _label(self, "Six questions. Three categories. One spark.", 14, MUTED, true)
    progress_label = _label(self, "", 16, INK)
    score_label = _label(self, "", 16, INK)
    score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    progress_bar = ProgressBar.new()
    progress_bar.show_percentage = false
    progress_bar.max_value = 6
    progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bar_background := _style(Color("182b40"), Color("182b40"), 2, 0)
    bar_background.content_margin_top = 0
    bar_background.content_margin_bottom = 0
    progress_bar.add_theme_stylebox_override("background", bar_background)
    var bar_fill := _style(CYAN, CYAN, 2, 0)
    bar_fill.content_margin_top = 0
    bar_fill.content_margin_bottom = 0
    progress_bar.add_theme_stylebox_override("fill", bar_fill)
    add_child(progress_bar)
    card = Panel.new()
    var style := _style(Color("0c192a"), Color("29465f"), 18)
    style.shadow_color = Color(0, 0, 0, 0.3)
    style.shadow_size = 18
    style.shadow_offset = Vector2(0, 8)
    card.add_theme_stylebox_override("panel", style)
    add_child(card)
    category_label = _label(card, "", 13, CYAN, true)
    question_label = _label(card, "", 25, INK, true)
    question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    answer_box = GridContainer.new()
    answer_box.columns = 1
    answer_box.add_theme_constant_override("h_separation", 12)
    answer_box.add_theme_constant_override("v_separation", 8)
    card.add_child(answer_box)
    feedback_label = _label(card, "Choose an answer to see how you did.", 15, MUTED, true)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    next_button = _button(card, "Next question  →", true)
    next_button.pressed.connect(_next_question)
    restart_button = _button(card, "Play again  ↻", true)
    restart_button.pressed.connect(_restart_round)
    result_score = _label(card, "", 82, GREEN, true)
    result_score.add_theme_font_override("font", DISPLAY_FONT)
    result_note = _label(card, "", 16, MUTED, true)
    result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer = _label(self, "Pick your answer · Keep the spark", 13, MUTED, true)
    motion_button = _button(self, "Motion: on")
    motion_button.add_theme_font_size_override("font_size", 12)
    motion_button.pressed.connect(func():
        motion_enabled = not motion_enabled
        motion_button.text = "Motion: on" if motion_enabled else "Motion: off"
        if transition and transition.is_running():
            transition.kill()
        card.modulate.a = 1.0
    )
    _apply_layout()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and card != null:
        _apply_layout()
        queue_redraw()

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
    control.position = Vector2(x, y)
    control.size = Vector2(w, h)

func _apply_layout() -> void:
    var compact := size.x < 600
    var short := size.y < 500 and not compact
    var cw: float = minf(size.x - (36 if compact else 80), 680 if not short else 740)
    var ch: float = 276 if short else 468
    var cx := (size.x - cw) / 2.0
    var cy: float = 94 if short else maxf(124, (size.y - ch) / 2.0 + 40)
    if compact:
        cy = maxf(188, (size.y - ch) / 2.0 + 36)
    _place(title_label, 16, 12 if short else (38 if compact else 20), size.x - 32, 48 if short else 58)
    title_label.add_theme_font_size_override("font_size", 34 if short else (37 if compact else 48))
    _place(subtitle, 16, 63 if short else (100 if compact else 78), size.x - 32, 24)
    subtitle.visible = not short
    _place(progress_label, cx, cy - 40, cw / 2, 28)
    _place(score_label, cx + cw / 2, cy - 40, cw / 2, 28)
    _place(progress_bar, cx, cy - 7, cw, 3)
    _place(card, cx, cy, cw, ch)
    var pad: float = 18 if compact else 28
    var iw := cw - pad * 2
    _place(category_label, pad, 10 if short else 17, iw, 24)
    _place(question_label, pad, 34 if short else 47, iw, 50 if short else 65)
    question_label.add_theme_font_size_override("font_size", 20 if short else (21 if compact else 25))
    answer_box.columns = 2 if short else 1
    _place(answer_box, pad, 91 if short else 124, iw, 108 if short else 224)
    for button in answer_box.get_children():
        button.custom_minimum_size = Vector2(0, 50)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 16 if compact or short else 18)
    _place(feedback_label, pad, 205 if short else 352, iw - (212 if short else 0), 54 if short else 48)
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if short else HORIZONTAL_ALIGNMENT_CENTER
    _place(next_button, cw - pad - 188 if short else pad, 215 if short else 408, 188 if short else iw, 44)
    _place(footer, cx, cy + ch + 14, cw, 24)
    footer.visible = size.y > 650
    _place(motion_button, size.x - 122, size.y - 62 if compact else 18, 104, 44)
    motion_button.visible = not short
    var done := current_index >= questions.size() and not questions.is_empty()
    _place(result_score, pad, 90 if short else 118, iw, 86 if short else 120)
    result_note.autowrap_mode = TextServer.AUTOWRAP_OFF if short else TextServer.AUTOWRAP_WORD_SMART
    if done:
        result_note.text = "%d correct answers across three categories." % score if short else "%d correct answers across three categories.\nReady for another round?" % score
    _place(result_note, pad, 168 if short else 243, iw, 32 if short else 70)
    _place(restart_button, (cw - minf(iw, 300)) / 2, 220 if short else 344, minf(iw, 300), 44 if short else 52)
    result_score.add_theme_font_size_override("font_size", 70 if short else 90)
    if done:
        result_note.text = "%d correct answers across three categories." % score if short else "%d correct answers across three categories.\nReady for another round?" % score
        _place(question_label, pad, 37 if short else 58, iw, 52)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("07101f"))
    # Quiet radial light and a sparse star field; all drawn by the engine.
    for i in range(30, 0, -1):
        draw_circle(Vector2(size.x * 0.5, size.y * 0.32), float(i) * 18, Color(0.02, 0.22, 0.34, 0.008))
    for i in range(38):
        var point := Vector2(fmod(float(i * 137 + 41), size.x), fmod(float(i * 83 + 23), size.y))
        draw_circle(point, 1.0 if i % 3 else 1.5, Color(0.33, 0.66, 0.83, 0.13))
    draw_line(Vector2(24, 16), Vector2(size.x - 24, 16), Color("142b40"))

func _restart_round() -> void:
    current_index = 0
    score = 0
    completed.clear()
    _show_question()

func _show_question() -> void:
    if transition and transition.is_running():
        transition.kill()
    card.modulate.a = 1.0
    for child in answer_box.get_children():
        answer_box.remove_child(child)
        child.queue_free()
    answer_locked = false
    selected_index = -1
    var done := current_index >= questions.size()
    answer_box.visible = not done
    next_button.visible = not done
    restart_button.visible = done
    result_score.visible = done
    result_note.visible = done
    feedback_label.visible = not done
    next_button.disabled = true
    score_label.text = "Score: %d" % score
    progress_label.text = "%d / %d" % [mini(current_index + 1, questions.size()), questions.size()]
    progress_bar.value = current_index
    if done:
        category_label.text = "ROUND COMPLETE"
        question_label.text = "Perfect spark!" if score == questions.size() else ("Nicely played!" if score >= 3 else "Keep the spark alive")
        result_score.text = "%d / %d" % [score, questions.size()]
        result_note.text = "%d correct answers across three categories." % score if size.y < 500 else "%d correct answers across three categories.\nReady for another round?" % score
        restart_button.grab_focus()
    else:
        var question: Dictionary = questions[current_index]
        category_label.text = String(question.category_label).to_upper()
        question_label.text = question.prompt
        feedback_label.text = "Choose an answer to see how you did."
        feedback_label.add_theme_color_override("font_color", MUTED)
        next_button.text = "See results  →" if current_index == questions.size() - 1 else "Next question  →"
        for option_index in range(question.options.size()):
            var button := _button(answer_box, question.options[option_index])
            button.pressed.connect(_answer.bind(option_index))
            button.set_meta("option_index", option_index)
    _apply_layout()
    if motion_enabled:
        card.modulate.a = 0.35
        transition = create_tween()
        transition.tween_property(card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _answer(option_index: int) -> void:
    if answer_locked or current_index >= questions.size():
        return
    var question: Dictionary = questions[current_index]
    if option_index < 0 or option_index >= question.options.size():
        return
    answer_locked = true
    selected_index = option_index
    var correct: bool = option_index == question.correct_index
    completed.append(correct)
    if correct:
        score += 1
        feedback_label.text = "Correct!  +1 point"
        feedback_label.add_theme_color_override("font_color", GREEN)
    else:
        feedback_label.text = "Not quite. The answer is %s." % question.options[question.correct_index]
        feedback_label.add_theme_color_override("font_color", RED)
    for i in range(answer_box.get_child_count()):
        var button: Button = answer_box.get_child(i)
        button.disabled = true
        if i == question.correct_index:
            button.text = "✓  " + question.options[i]
            button.add_theme_stylebox_override("disabled", _style(Color("203727"), GREEN, 10, 2))
            button.add_theme_color_override("font_disabled_color", GREEN)
        elif i == option_index:
            button.text = "×  " + question.options[i]
            button.add_theme_stylebox_override("disabled", _style(Color("3c2335"), RED, 10, 2))
            button.add_theme_color_override("font_disabled_color", RED)
    score_label.text = "Score: %d" % score
    progress_bar.value = current_index + 1
    next_button.disabled = false
    next_button.grab_focus()

func _next_question() -> void:
    if not answer_locked:
        return
    current_index += 1
    _show_question()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode >= KEY_1 and event.keycode <= KEY_4:
            _answer(event.keycode - KEY_1)
            get_viewport().set_input_as_handled()
