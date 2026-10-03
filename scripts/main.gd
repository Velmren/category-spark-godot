extends Control

const TriviaImporter = preload("res://scripts/trivia_importer.gd")
const Style = preload("res://scripts/style.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const Hud = preload("res://scripts/hud.gd")
const TileButton = preload("res://scripts/tile_button.gd")
const Breakdown = preload("res://scripts/breakdown.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Strings = preload("res://scripts/strings.gd")

const SETTINGS := "user://settings.cfg"
# Language the hosting site (velmren.com) remembers for its visitors.
const SITE_LANGUAGE_KEY := "velmren.lang"

# The interface is laid out in design units; the window scales them to fit.
enum Shape { WIDE, SHORT, TALL }
const BLOCK_MARGIN := 8.0
const BASE_SIZE := {Shape.WIDE: Vector2i(1180, 720), Shape.SHORT: Vector2i(900, 440), Shape.TALL: Vector2i(390, 700)}

var questions: Array = []
var current_index := 0
var score := 0
var answer_locked := false
var selected_index := -1
var completed: Array[bool] = []
var motion_enabled := true
var sound_enabled := true
var language := "en"

var shape := Shape.WIDE
var world: Dictionary = Style.FINALE
var backdrop: Control
var stage: Control
var view: Control
var hud: Control
var sheet: Panel
var confetti: Control
var sfx: Node

var title_label: Label
var progress_label: Label
var score_label: Label
var sound_button: Button
var motion_button: Button
var category_label: Label
var question_label: Label
var answer_box: Control
var hint_label: Label
var verdict_label: Label
var feedback_label: Label
var next_button: TileButton
var result_score: Label
var result_note: Label
var breakdown: Control
var restart_button: TileButton

var _categories: Array = []
var _worlds := {}
var _sheet_open := false
var _sheet_height := 112.0
var _sheet_tween: Tween
var _result_tween: Tween
var _wipe_from := Vector2.ZERO
var _started := false
# Column width, free height and height taken by the answers in the last layout.
var _prompt_room: Array = [820.0, 500.0, 300.0]
# Languages offered by both the interface and the question file.
var _languages: Array = ["en"]

func _ready() -> void:
    _fit_window()
    get_window().size_changed.connect(_fit_window)
    _build_interface()
    var imported := TriviaImporter.load_file("res://data/questions.json")
    if not imported.ok:
        push_error(imported.error)
        _languages = Strings.LANGUAGES.duplicate()
        set_language(_pick_language(), false)
        _show_unavailable()
        return
    _languages = Strings.LANGUAGES.filter(func(code): return imported.data.languages.has(code))
    if _languages.is_empty():
        _languages = [imported.data.languages[0]]
    language = _pick_language()
    Style.language = language
    _categories = imported.data.categories
    var groups: Array = []
    for index in range(_categories.size()):
        var category: Dictionary = _categories[index]
        _worlds[category.id] = Style.world_for(index)
        groups.append(category.questions.size())
        for question in category.questions:
            questions.append(question)
    hud.groups = groups
    _apply_language_to_chrome()
    _restart_round()
    _started = true
    _prime_glyphs()

# ------------------------------------------------------------------ language

# A link or launch argument wins, then the player's saved choice, then the
# language the hosting site remembers, then the system or browser language.
func _pick_language() -> String:
    var asked := _asked_language()
    if _languages.has(asked):
        return asked
    var saved: String = _settings().get_value("game", "language", "")
    if _languages.has(saved):
        return saved
    if OS.has_feature("web"):
        var site = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % SITE_LANGUAGE_KEY, true)
        if typeof(site) == TYPE_STRING and _languages.has(site):
            return site
    var system := "ru" if OS.get_locale_language() in ["ru", "be"] else "en"
    return system if _languages.has(system) else _languages[0]

# ?lang=ru on the web, --lang=ru after "--" on the command line.
func _asked_language() -> String:
    if OS.has_feature("web"):
        var query = JavaScriptBridge.eval("new URLSearchParams(location.search).get('lang')||''", true)
        if typeof(query) == TYPE_STRING and query != "":
            return String(query).to_lower()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--lang="):
            return argument.trim_prefix("--lang=").to_lower()
    return ""

func _settings() -> ConfigFile:
    var settings := ConfigFile.new()
    settings.load(SETTINGS)
    return settings

# Switches every text on screen, keeping the round exactly where it is.
func set_language(next: String, remember := true) -> void:
    if not _languages.has(next):
        return
    language = next
    Style.language = next
    if remember:
        var settings := _settings()
        settings.set_value("game", "language", next)
        settings.save(SETTINGS)
    _apply_language_to_chrome()
    if _started:
        _build_view(false, false)
        _prime_glyphs()

func _apply_language_to_chrome() -> void:
    hud.refresh_fonts()
    hud.show_languages(language, _languages)
    hud.score_caption.text = _s("score")
    sound_button.text = _s("sound_on" if sound_enabled else "sound_off")
    motion_button.text = _s("motion_on" if motion_enabled else "motion_off")
    verdict_label.add_theme_font_override("font", Style.display())
    feedback_label.add_theme_font_override("font", Style.text(500))
    if answer_locked:
        _write_verdict()
    _apply_layout()

func _s(key: String) -> String:
    return Strings.get_text(language, key)

# Russian typesetting: a one- or two-letter word stays with the next one, so a
# line never ends on «в» or «и».
func _typeset(text: String) -> String:
    if language != "ru":
        return text
    return RegEx.create_from_string("(?<=^|\\s)([А-Яа-яЁё]{1,2})\\s").sub(text, "$1\u00a0", true)

# Picks the current language from a {language: text} value.
func _t(value) -> String:
    if typeof(value) == TYPE_DICTIONARY:
        return value.get(language, value.values()[0])
    return String(value)

# Picks the design size that suits the window's proportions.
func _fit_window() -> void:
    var window := get_window()
    var pixels := Vector2(window.size)
    var aspect := pixels.x / maxf(pixels.y, 1.0)
    shape = Shape.TALL if aspect < 0.85 else (Shape.SHORT if aspect > 1.9 else Shape.WIDE)
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    window.content_scale_size = BASE_SIZE[shape]

# Large glyphs are rasterised the first time they are drawn, which shows as a
# hitch in the middle of a round. Drawing every string once behind the backdrop
# while the game opens moves that cost to the start.
func _prime_glyphs() -> void:
    var primer := Control.new()
    primer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(primer)
    move_child(primer, 0)
    var tall := shape == Shape.TALL
    var short := shape == Shape.SHORT
    var jobs: Array = []
    for question in questions:
        var prompt := _t(question.prompt)
        jobs.append([Style.display(), _prompt_size(prompt, _prompt_room[0], _prompt_room[1], _prompt_room[2]), prompt])
        jobs.append([Style.text(700), 22 if tall else (20 if short else 27), " ".join(question.options.map(_t))])
    jobs.append([Style.display(), Style.display_size(30 if tall or short else 42), _s("correct") + _s("wrong")])
    jobs.append([Style.display(), Style.display_size(40 if tall else (38 if short else 64)), _s("perfect") + _s("good") + _s("low")])
    jobs.append([Style.DISPLAY, 128 if tall else (112 if short else 190), "0123456789 /"])
    jobs.append([Style.DISPLAY, 32 if tall or short else 38, "0123456789"])
    jobs.append([Style.text(500), 16 if tall else (17 if short else 20), _s("point") + _s("answer_is") + Strings.summary(language, 5, 3)])
    jobs.append([Style.text(700), 19 if tall else (20 if short else 23), _s("next") + _s("results") + _s("again")])
    primer.draw.connect(func():
        for job in jobs:
            primer.draw_string(job[0], Vector2(0, 200), job[2], HORIZONTAL_ALIGNMENT_LEFT, -1, job[1], Style.INK))
    await get_tree().process_frame
    await get_tree().process_frame
    primer.queue_free()

func _layer(node: Control) -> Control:
    node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(node)
    return node

func _label(parent: Node, font: Font, color: Color) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font", font)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

# Wrapped labels are clipped so that their size is ours to set; the margin keeps
# glyph overhang inside the clip.
func _wrap(label: Label) -> void:
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.clip_text = true
    var margin := StyleBoxEmpty.new()
    margin.set_content_margin_all(BLOCK_MARGIN)
    label.add_theme_stylebox_override("normal", margin)

func _place_block(label: Label, at: Vector2, extent: Vector2) -> void:
    label.position = at - Vector2.ONE * BLOCK_MARGIN
    label.size = extent + Vector2.ONE * BLOCK_MARGIN * 2.0

func _tile(parent: Node, caption: String) -> TileButton:
    var tile := TileButton.new()
    tile.caption = caption
    parent.add_child(tile)
    return tile

func _build_interface() -> void:
    backdrop = _layer(Backdrop.new())
    stage = _layer(Control.new())

    sheet = Panel.new()
    sheet.visible = false
    add_child(sheet)
    verdict_label = _label(sheet, Style.display(), Style.CORRECT_SOFT)
    feedback_label = _label(sheet, Style.text(500), Color("cfc8e2"))
    next_button = _tile(sheet, "")
    next_button.lip = Color("9d94b8")
    next_button.spark = Style.PAPER
    next_button.disabled = true
    next_button.pressed.connect(_next_question)

    hud = _layer(Hud.new())
    title_label = hud.title_label
    progress_label = hud.progress_label
    score_label = hud.score_label
    sound_button = hud.sound_button
    motion_button = hud.motion_button
    sound_button.pressed.connect(_toggle_sound)
    motion_button.pressed.connect(_toggle_motion)
    for button in hud.language_buttons:
        button.pressed.connect(func(): set_language(button.get_meta("language")))

    confetti = _layer(Confetti.new())
    sfx = Sfx.new()
    add_child(sfx)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and hud != null:
        _apply_layout()

func _is_done() -> bool:
    return not questions.is_empty() and current_index >= questions.size()

# ---------------------------------------------------------------- round flow

func _restart_round() -> void:
    if restart_button != null and restart_button.is_visible_in_tree():
        _wipe_from = restart_button.get_global_rect().get_center()
    current_index = 0
    score = 0
    completed.clear()
    confetti.clear()
    _show_question()

func _show_question() -> void:
    answer_locked = false
    selected_index = -1
    var done := _is_done()
    var target: Dictionary = Style.FINALE if done else _worlds[questions[current_index].category_id]
    var world_changed: bool = target.name != world.name
    var animated := motion_enabled and _started
    world = target
    _close_sheet()
    backdrop.show_world(world, _wipe_from, animated and world_changed)
    hud.show_world(world, animated and world_changed)
    hud.set_score(score, false)
    progress_label.text = "%d / %d" % [mini(current_index + 1, questions.size()), questions.size()]
    _refresh_marks()
    next_button.visible = not done
    next_button.disabled = true
    _build_view(animated, world_changed)
    if done:
        restart_button.grab_focus()
    if animated and world_changed:
        sfx.play("transition", 1.0, 0.0, -3.0)

# Fills a fresh view with the current question or the result. After a language
# switch it restores an answered question as it was, without animation.
func _build_view(animated: bool, world_changed: bool) -> void:
    var done := _is_done()
    var focused := get_viewport().gui_get_focus_owner()
    var had_focus := focused != null and (focused == restart_button or (answer_box != null and answer_box.is_ancestor_of(focused)))
    _open_view(done, animated)
    next_button.caption = _s("results") if current_index == questions.size() - 1 else _s("next")
    if done:
        category_label.text = _s("round_complete")
        question_label.text = _s("perfect") if score == questions.size() else (_s("good") if score >= 3 else _s("low"))
        result_score.text = "%d / %d" % [score, questions.size()]
        if had_focus:
            restart_button.grab_focus()
    else:
        var question: Dictionary = questions[current_index]
        category_label.text = _t(question.category_label).to_upper()
        question_label.text = _typeset(_t(question.prompt))
        for option_index in range(question.options.size()):
            var tile := _tile(answer_box, _t(question.options[option_index]))
            tile.key_hint = str(option_index + 1)
            tile.lip = world.lip
            tile.ground = world.bg
            tile.spark = world.ink
            tile.set_meta("option_index", option_index)
            tile.pressed.connect(_answer.bind(option_index))
            if answer_locked:
                tile.disabled = true
                tile.settle(_tile_state(option_index), false)
        if answer_locked:
            _write_verdict()
    _apply_layout()
    _enter_view(0.26 if world_changed else 0.08, animated, done)

func _tile_state(option_index: int) -> int:
    var question: Dictionary = questions[current_index]
    if option_index == question.correct_index:
        return TileButton.State.CORRECT
    if option_index == selected_index:
        return TileButton.State.WRONG
    return TileButton.State.DIM

func _write_verdict() -> void:
    var question: Dictionary = questions[current_index]
    var correct: bool = selected_index == question.correct_index
    verdict_label.text = _s("correct") if correct else _s("wrong")
    feedback_label.text = _s("point") if correct else _s("answer_is") % _t(question.options[question.correct_index])
    verdict_label.add_theme_color_override("font_color", Style.CORRECT_SOFT if correct else Style.WRONG_SOFT)

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
    _write_verdict()
    for i in range(answer_box.get_child_count()):
        var tile: TileButton = answer_box.get_child(i)
        tile.disabled = true
        tile.settle(_tile_state(i), motion_enabled, 0.32 if i == question.correct_index and not correct else 0.0)
    hud.set_score(score, correct and motion_enabled)
    _refresh_marks()
    backdrop.kick(correct and motion_enabled)
    sfx.play("select")
    sfx.play("correct" if correct else "wrong", 1.0, 0.12)
    next_button.disabled = false
    _apply_layout()
    _open_sheet()
    next_button.grab_focus()

func _next_question() -> void:
    if not answer_locked:
        return
    _wipe_from = next_button.get_global_rect().get_center()
    sfx.play("tap")
    current_index += 1
    _show_question()

func _refresh_marks() -> void:
    var marks: Array = []
    for index in range(questions.size()):
        if index < completed.size():
            marks.append(Hud.Mark.CORRECT if completed[index] else Hud.Mark.WRONG)
        elif index == current_index:
            marks.append(Hud.Mark.CURRENT)
        else:
            marks.append(Hud.Mark.PENDING)
    hud.set_marks(marks)

func _show_unavailable() -> void:
    _open_view(false, false)
    backdrop.show_world(world, Vector2.ZERO, false)
    hud.show_world(world, false)
    category_label.text = _s("unavailable")
    question_label.text = _s("unavailable_title")
    result_note.text = _s("unavailable_note")
    result_note.visible = true
    next_button.visible = false
    _apply_layout()

# --------------------------------------------------------------------- views

# Every question (and the result) gets a fresh view; the old one fades away.
func _open_view(done: bool, animated: bool) -> void:
    if view != null:
        _dismiss(view, animated)
    view = Control.new()
    view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(view)

    category_label = _label(view, Style.text(700, 1), world.chip_ink)
    var plate := StyleBoxFlat.new()
    plate.bg_color = world.chip
    plate.set_corner_radius_all(6)
    plate.content_margin_left = 14
    plate.content_margin_right = 14
    plate.content_margin_top = 6
    plate.content_margin_bottom = 5
    category_label.add_theme_stylebox_override("normal", plate)
    category_label.rotation_degrees = -2.0

    question_label = _label(view, Style.display(), world.ink)
    _wrap(question_label)
    answer_box = Control.new()
    answer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    answer_box.visible = not done
    view.add_child(answer_box)
    hint_label = _label(view, Style.text(600), Color(world.ink, 0.64))
    hint_label.text = _s("hint")
    hint_label.visible = not done

    result_score = _label(view, Style.DISPLAY, Style.SUN)
    result_score.visible = done
    result_note = _label(view, Style.text(500), Color("cfc8e2"))
    _wrap(result_note)
    result_note.visible = done
    breakdown = Breakdown.new()
    breakdown.visible = done
    view.add_child(breakdown)
    restart_button = _tile(view, _s("again"))
    restart_button.face = Style.SUN
    restart_button.lip = Color("c98a00")
    restart_button.spark = Style.PAPER
    restart_button.visible = done
    restart_button.pressed.connect(_restart_round)
    if done:
        var rows: Array = []
        var offset := 0
        for category in _categories:
            var count: int = category.questions.size()
            rows.append({"label": _t(category.label), "tint": _worlds[category.id].bg, "results": completed.slice(offset, offset + count)})
            offset += count
        breakdown.rows = rows

func _dismiss(old: Control, animated: bool) -> void:
    for button in old.find_children("*", "BaseButton", true, false):
        button.disabled = true
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not animated:
        old.queue_free()
        return
    var tween := old.create_tween()
    tween.tween_property(old, "modulate:a", 0.0, 0.14)
    tween.parallel().tween_property(old, "position:y", -12.0, 0.14)
    tween.tween_callback(old.queue_free)

func _enter_view(delay: float, animated: bool, done: bool) -> void:
    if _result_tween:
        _result_tween.kill()
    var tiles := answer_box.get_children()
    if not animated:
        for tile in tiles:
            tile.appear(0.0, false)
        if done:
            breakdown.shown = breakdown.total()
        return
    view.modulate.a = 0.0
    view.position.y = 16.0
    var tween := view.create_tween()
    tween.tween_interval(delay)
    tween.tween_property(view, "modulate:a", 1.0, 0.2)
    tween.parallel().tween_property(view, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    for i in range(tiles.size()):
        tiles[i].appear(delay + 0.07 + i * 0.055, true)
    if done:
        _celebrate(delay + 0.3)

# Result screen: the score lands, then one mark per question ticks in.
func _celebrate(delay: float) -> void:
    var total: int = breakdown.total()
    var step := 0.17
    result_score.pivot_offset = result_score.size * Vector2(0.2, 0.6)
    result_score.scale = Vector2.ONE * 0.6
    restart_button.appear(delay + total * step + 0.1, true)
    _result_tween = view.create_tween()
    _result_tween.tween_interval(delay)
    _result_tween.tween_property(result_score, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _result_tween.parallel().tween_property(breakdown, "shown", float(total), total * step).set_delay(0.15)
    var hits := 0
    for index in range(total):
        if completed[index]:
            sfx.play("tick", pow(2.0, hits * 2.0 / 12.0), delay + 0.15 + index * step)
            hits += 1
        else:
            sfx.play("select", 0.75, delay + 0.15 + index * step, -3.0)
    if score * 3 >= total * 2:
        _result_tween.tween_callback(_throw_confetti)

func _throw_confetti() -> void:
    if not _is_done():
        return
    sfx.play("finale")
    confetti.burst(result_score.get_global_rect().get_center() - global_position, 70 + score * 8)

# --------------------------------------------------------------------- sheet

func _open_sheet() -> void:
    _sheet_open = true
    var target := size.y - _sheet_height
    if _sheet_tween:
        _sheet_tween.kill()
    if not motion_enabled:
        sheet.visible = true
        sheet.position.y = target
        return
    if not sheet.visible:
        sheet.position.y = size.y
    sheet.visible = true
    _sheet_tween = create_tween()
    _sheet_tween.tween_property(sheet, "position:y", target, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_sheet() -> void:
    _sheet_open = false
    if _sheet_tween:
        _sheet_tween.kill()
    if not (motion_enabled and sheet.visible):
        sheet.visible = false
        return
    _sheet_tween = create_tween()
    _sheet_tween.tween_property(sheet, "position:y", size.y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _sheet_tween.tween_callback(sheet.hide)

# -------------------------------------------------------------------- layout

func _fit(label: Label, font_size: int) -> Vector2:
    label.add_theme_font_size_override("font_size", font_size)
    label.size = label.get_minimum_size()
    return label.size

# Height of a wrapped display block set with tight leading.
func _block_height(text: String, width: float, font_size: int) -> float:
    var font: Font = Style.display()
    var block := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
    var lines := maxi(1, roundi(block.y / font.get_height(font_size)))
    return block.y + (lines - 1) * Style.display_leading(font_size)

func _fit_block(label: Label, width: float, font_size: int) -> float:
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_constant_override("line_spacing", Style.display_leading(font_size))
    return _block_height(label.text, width, font_size)

# Largest display size at which a prompt and its answers fit the room.
func _prompt_size(text: String, column: float, room: float, taken: float) -> int:
    var font_size := Style.display_size(44 if shape == Shape.TALL else (46 if shape == Shape.SHORT else 80))
    var smallest := Style.display_size(28 if shape == Shape.TALL else (30 if shape == Shape.SHORT else 46))
    while taken + _block_height(text, column, font_size) > room and font_size > smallest:
        font_size -= 2
    return font_size

func _apply_layout() -> void:
    var tall := shape == Shape.TALL
    var short := shape == Shape.SHORT
    var bar_end: float = hud.arrange(shape, size, 22.0 if tall else (28.0 if short else 44.0))
    var side := 22.0
    var column := minf(size.x - 44.0, 480.0)
    if tall:
        side = (size.x - column) * 0.5
    elif short:
        side = clampf(size.x * 0.05, 28.0, 90.0)
        column = minf(760.0, size.x - side - 60.0)
    else:
        side = clampf(size.x * 0.086, 44.0, 150.0)
        column = clampf(size.x - side - 300.0, 640.0, 820.0)
    _sheet_height = 134.0 if tall else (78.0 if short else 112.0)
    _layout_sheet(side, column)
    if view == null:
        return
    var top := bar_end + (8.0 if tall or short else 26.0)
    if _is_done():
        _layout_result(side, column, top, size.y - (20.0 if tall else (14.0 if short else 36.0)))
    else:
        _layout_question(side, column, top, size.y - _sheet_height - (14.0 if tall else (8.0 if short else 22.0)))

func _layout_sheet(side: float, column: float) -> void:
    var tall := shape == Shape.TALL
    var short := shape == Shape.SHORT
    var plate := StyleBoxFlat.new()
    plate.bg_color = world.sheet
    sheet.add_theme_stylebox_override("panel", plate)
    # The spare height below hides the gap when the sheet overshoots on entry.
    sheet.size = Vector2(size.x, _sheet_height + 60.0)
    sheet.position.x = 0.0
    if _sheet_tween == null or not _sheet_tween.is_running():
        sheet.position.y = size.y - _sheet_height if _sheet_open else size.y
    var verdict := _fit(verdict_label, Style.display_size(30 if tall or short else 42))
    next_button.caption_size = 19 if tall else (20 if short else 23)
    var button := Vector2(column, 62.0) if tall else (Vector2(214.0, 56.0) if short else Vector2(256.0, 68.0))
    # The explanation shrinks rather than run into the button or off the screen.
    var room := (column if tall else size.x - side * 2.0 - button.x - 24.0) - verdict.x - 16.0
    var detail_size := 16 if tall else (17 if short else 20)
    var detail := _fit(feedback_label, detail_size)
    while detail.x > room and detail_size > 11:
        detail_size -= 1
        detail = _fit(feedback_label, detail_size)
    if tall:
        verdict_label.position = Vector2(side, 12.0)
        feedback_label.position = Vector2(side + verdict.x + 12.0, 12.0 + verdict.y * 0.56 - detail.y * 0.5)
        next_button.position = Vector2(side, 58.0)
        next_button.size = button
    else:
        var middle := _sheet_height * 0.5
        verdict_label.position = Vector2(side, middle - verdict.y * 0.5)
        feedback_label.position = Vector2(side + verdict.x + 18.0, middle - detail.y * 0.5 + 3.0)
        next_button.position = Vector2(size.x - side - button.x, middle - button.y * 0.5 - 1.0)
        next_button.size = button

func _layout_question(side: float, column: float, top: float, bottom: float) -> void:
    var tall := shape == Shape.TALL
    var short := shape == Shape.SHORT
    var chip := _fit(category_label, 13 if tall or short else 16)
    var chip_gap := 8.0 if tall else (5.0 if short else 10.0)
    var grid_gap := 20.0 if tall else (12.0 if short else 24.0)
    var columns := 1 if tall else 2
    var count := answer_box.get_child_count()
    var rows := ceili(float(count) / columns)
    var tile_height := 64.0 if tall else (58.0 if short else 91.0)
    var gap := Vector2(0, 12) if tall else (Vector2(14, 10) if short else Vector2(20, 18))
    var room := bottom - top
    var fixed := chip.y + chip_gap + grid_gap
    _prompt_room = [column, room, fixed + rows * tile_height + (rows - 1) * gap.y]
    var font_size := _prompt_size(question_label.text, column, room, _prompt_room[2])
    var text_height := _fit_block(question_label, column, font_size)
    while fixed + text_height + rows * tile_height + (rows - 1) * gap.y > room and tile_height > 52.0:
        tile_height -= 1.0
    var total := fixed + text_height + rows * tile_height + (rows - 1) * gap.y
    var y := top + maxf(0.0, room - total) * (0.4 if tall else 0.46)

    category_label.position = Vector2(side, y)
    category_label.pivot_offset = Vector2(0, chip.y * 0.5)
    y += chip.y + chip_gap
    _place_block(question_label, Vector2(side - 1.0, y), Vector2(column, text_height))
    y += text_height + grid_gap
    answer_box.position = Vector2(side, y)
    answer_box.size = Vector2(column, rows * tile_height + (rows - 1) * gap.y)
    var tile_width := (column - gap.x * (columns - 1)) / columns
    for i in range(count):
        var tile: TileButton = answer_box.get_child(i)
        tile.position = Vector2((i % columns) * (tile_width + gap.x), floorf(float(i) / columns) * (tile_height + gap.y))
        tile.size = Vector2(tile_width, tile_height)
        tile.caption_size = 22 if tall else (20 if short else 27)
    # The hint waits where the verdict sheet will rise.
    hint_label.visible = not tall and count > 0
    var hint := _fit(hint_label, 15 if short else 17)
    hint_label.position = Vector2(side, size.y - _sheet_height * 0.5 - hint.y * 0.5)
    backdrop.calm = Rect2(side - 24.0, top - 8.0, column + 48.0, bottom - top + 16.0)

func _layout_result(side: float, column: float, top: float, bottom: float) -> void:
    var tall := shape == Shape.TALL
    var short := shape == Shape.SHORT
    var chip := _fit(category_label, 13 if tall or short else 16)
    category_label.pivot_offset = Vector2(0, chip.y * 0.5)
    var headline := _fit_block(question_label, column, Style.display_size(40 if tall else (38 if short else 64)))
    var number := _fit(result_score, 128 if tall else (112 if short else 190))
    result_note.text = Strings.summary(language, score, _categories.size())
    result_note.add_theme_font_size_override("font_size", 16 if tall else (15 if short else 20))
    restart_button.caption_size = 20 if tall or short else 23
    breakdown.label_size = 19 if tall or short else 22
    breakdown.row_height = 44.0 if tall else (38.0 if short else 54.0)
    var list_height: float = breakdown.rows.size() * breakdown.row_height
    var room := bottom - top

    if tall:
        _stack_result(side, column, top, room, chip, headline, number, list_height)
        return

    var button := Vector2(230.0, 56.0) if short else Vector2(280.0, 70.0)
    var gap := 14.0 if short else 26.0
    var total := chip.y + 8.0 + headline + number.y + gap + button.y
    var y := top + maxf(0.0, room - total) * 0.42
    category_label.position = Vector2(side, y)
    y += chip.y + (4.0 if short else 10.0)
    _place_block(question_label, Vector2(side - 1.0, y), Vector2(column, headline))
    y += headline - (10.0 if short else 14.0)
    result_score.position = Vector2(side - 4.0, y)
    var list_width := minf(400.0, size.x - side * 2.0 - number.x - 90.0)
    var list_x := minf(side + number.x + 90.0, size.x - side - list_width - (40.0 if short else 240.0))
    list_x = maxf(list_x, side + number.x + 50.0)
    breakdown.size = Vector2(list_width, list_height)
    breakdown.position = Vector2(list_x, y + (number.y - list_height) * 0.5 - (8.0 if short else 0.0))
    _place_block(result_note, Vector2(list_x, breakdown.position.y + list_height + 8.0), Vector2(list_width + 60.0, 30.0))
    y += number.y + gap
    restart_button.position = Vector2(side, y)
    restart_button.size = button

func _stack_result(side: float, column: float, top: float, room: float, chip: Vector2, headline: float, number: Vector2, list_height: float) -> void:
    var button := Vector2(column, 62.0)
    var total := chip.y + 8.0 + headline + number.y + 6.0 + list_height + 14.0 + 24.0 + 22.0 + button.y
    var y := top + maxf(0.0, room - total) * 0.3
    category_label.position = Vector2(side, y)
    y += chip.y + 8.0
    _place_block(question_label, Vector2(side - 1.0, y), Vector2(column, headline))
    y += headline - 8.0
    result_score.position = Vector2(side - 3.0, y)
    y += number.y + 6.0
    breakdown.position = Vector2(side, y)
    breakdown.size = Vector2(column, list_height)
    y += list_height + 14.0
    _place_block(result_note, Vector2(side, y), Vector2(column, 24.0))
    y += 24.0 + 22.0
    restart_button.position = Vector2(side, y)
    restart_button.size = button

# --------------------------------------------------------------------- input

func _toggle_sound() -> void:
    sound_enabled = not sound_enabled
    sfx.enabled = sound_enabled
    if not sound_enabled:
        sfx.hush()
    sound_button.text = _s("sound_on" if sound_enabled else "sound_off")
    hud.dress_switch(sound_button, sound_enabled)
    _apply_layout()
    sfx.play("tap")

func _toggle_motion() -> void:
    motion_enabled = not motion_enabled
    motion_button.text = _s("motion_on" if motion_enabled else "motion_off")
    hud.dress_switch(motion_button, motion_enabled)
    backdrop.animate = motion_enabled
    hud.animate = motion_enabled
    if not motion_enabled:
        confetti.clear()
    _apply_layout()
    sfx.play("tap")

func _input(event: InputEvent) -> void:
    var keys: bool = event is InputEventKey and event.pressed
    if keys or event is InputEventMouseButton or event is InputEventScreenTouch:
        TileButton.keyboard_focus = keys

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode >= KEY_1 and event.keycode <= KEY_4:
            _answer(event.keycode - KEY_1)
            get_viewport().set_input_as_handled()
