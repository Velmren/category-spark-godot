extends Control
# Top bar: the wordmark with its spark, one progress pip per question grouped by
# category, the score and the sound and motion switches.

const Style = preload("res://scripts/style.gd")

enum Mark { PENDING, CURRENT, CORRECT, WRONG }

const TICKS := [[Vector2(5, 12), Vector2(3, 4)], [Vector2(13, 16), Vector2(20, 7)], [Vector2(17, 24), Vector2(26, 22)]]

var title_label: Label
var progress_label: Label
var score_caption: Label
var score_label: Label
var sound_button: Button
var motion_button: Button

var ink := Style.INK: set = set_ink
var world: Dictionary = Style.FINALE
var groups: Array = []
var marks: Array = []
var animate := true

var _pip := Vector2(30, 12)
var _pip_gap := 7.0
var _group_gap := 22.0
var _pips_at := Vector2.ZERO
var _spark_at := Vector2.ZERO
var _spark_unit := 1.0
var _swell: Array = []
var _clock := 0.0
var _was_flicking := false
var _ink_tween: Tween
var _score_tween: Tween
var _box := StyleBoxFlat.new()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_label = _label("Category Spark", Style.DISPLAY)
    progress_label = _label("", Style.text(700))
    score_caption = _label("Score", Style.text(700))
    score_label = _label("0", Style.DISPLAY)
    sound_button = _switch()
    motion_button = _switch()
    set_ink(ink)

func _label(text: String, font: Font) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font", font)
    add_child(label)
    return label

func _switch() -> Button:
    var button := Button.new()
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_override("font", Style.text(600))
    button.set_meta("on", true)
    add_child(button)
    return button

func _process(delta: float) -> void:
    if animate:
        _clock += delta
    # The spark flicks for half a second at the start of every beat.
    var flicking := animate and fmod(_clock, 6.0) < 0.5
    var changed := flicking or _was_flicking
    _was_flicking = flicking
    for i in range(_swell.size()):
        var target := 1.0 if i < marks.size() and marks[i] == Mark.CURRENT else 0.0
        if not is_equal_approx(_swell[i], target):
            _swell[i] = move_toward(_swell[i], target, delta * 7.0) if animate else target
            changed = true
    if changed:
        queue_redraw()

func set_ink(value: Color) -> void:
    ink = value
    if title_label == null:
        return
    title_label.add_theme_color_override("font_color", ink)
    score_label.add_theme_color_override("font_color", ink)
    score_caption.add_theme_color_override("font_color", ink)
    progress_label.add_theme_color_override("font_color", Color(ink, 0.72))
    dress_switch(sound_button, sound_button.get_meta("on"))
    dress_switch(motion_button, motion_button.get_meta("on"))
    queue_redraw()

func show_world(target: Dictionary, animated: bool) -> void:
    world = target
    if _ink_tween:
        _ink_tween.kill()
    if animated and ink != target.ink:
        _ink_tween = create_tween()
        _ink_tween.tween_property(self, "ink", target.ink, 0.3).set_delay(0.12)
    else:
        ink = target.ink

func set_marks(next: Array) -> void:
    marks = next
    while _swell.size() < marks.size():
        _swell.append(0.0)
    queue_redraw()

func set_score(value: int, bump: bool) -> void:
    score_label.text = str(value)
    if _score_tween:
        _score_tween.kill()
    score_label.scale = Vector2.ONE
    if bump:
        score_label.pivot_offset = score_label.size * Vector2(0.5, 0.6)
        _score_tween = create_tween()
        _score_tween.tween_property(score_label, "scale", Vector2.ONE * 1.45, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func dress_switch(button: Button, on: bool) -> void:
    button.set_meta("on", on)
    var text_color := ink if on else Color(ink, 0.62)
    for item in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        button.add_theme_color_override(item, text_color)
    button.add_theme_stylebox_override("normal", _pill(Color(ink, 0.12 if on else 0.0), Color(ink, 0.0 if on else 0.32)))
    button.add_theme_stylebox_override("hover", _pill(Color(ink, 0.2 if on else 0.08), Color(ink, 0.0 if on else 0.5)))
    button.add_theme_stylebox_override("pressed", _pill(Color(ink, 0.28), Color(ink, 0.0)))
    var ring := _pill(Color(ink, 0.0), ink)
    ring.set_border_width_all(3)
    ring.set_expand_margin_all(3)
    button.add_theme_stylebox_override("focus", ring)

func _pill(fill: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 13
    style.content_margin_right = 13
    return style

func _fit(label: Label, font_size: int) -> Vector2:
    label.add_theme_font_size_override("font_size", font_size)
    label.size = label.get_minimum_size()
    return label.size

# Shape values follow main.gd: 0 wide, 1 short, 2 tall.
func arrange(shape: int, area: Vector2, side: float) -> void:
    var tall := shape == 2
    var short := shape == 1
    var title_size := 23 if tall else (27 if short else 33)
    var bar_top := 12.0 if tall else (10.0 if short else 26.0)
    var bar_height := 44.0 if tall or short else 48.0
    var middle := bar_top + bar_height * 0.5

    var title := _fit(title_label, title_size)
    title_label.position = Vector2(side, middle - title.y * 0.5)
    _spark_unit = title_size / 33.0
    _spark_at = title_label.position + Vector2(title.x - 3.0 * _spark_unit, title.y * 0.5 - 30.0 * _spark_unit)

    var switch_size := 13 if tall else (14 if short else 15)
    var switch_height := 40.0 if shape == 0 else 44.0
    for button in [sound_button, motion_button]:
        button.add_theme_font_size_override("font_size", switch_size)
        for item in ["normal", "hover", "pressed"]:
            var pill: StyleBoxFlat = button.get_theme_stylebox(item)
            pill.content_margin_left = 10.0 if tall else 13.0
            pill.content_margin_right = pill.content_margin_left
        button.size = Vector2(button.get_minimum_size().x, switch_height)

    _pip = Vector2(22, 10) if tall else (Vector2(24, 10) if short else Vector2(30, 12))
    _pip_gap = 5.0 if tall else 7.0
    _group_gap = 12.0 if tall else (16.0 if short else 22.0)
    var pips_width := _pips_width()
    var number := _fit(score_label, 32 if tall or short else 38)
    var caption := _fit(score_caption, 17 if tall or short else 20)
    _fit(progress_label, 15 if tall else 17)
    progress_label.visible = not short

    if tall:
        motion_button.position = Vector2(area.x - side - motion_button.size.x, middle - switch_height * 0.5)
        sound_button.position = Vector2(motion_button.position.x - 8.0 - sound_button.size.x, motion_button.position.y)
        var row := bar_top + bar_height + 26.0
        _pips_at = Vector2(side, row - _pip.y * 0.5)
        progress_label.position = Vector2(side + pips_width + 12.0, row - progress_label.size.y * 0.5)
        score_label.position = Vector2(area.x - side - number.x, row - number.y * 0.5)
        score_caption.position = Vector2(score_label.position.x - 7.0 - caption.x, row - caption.y * 0.5 + 2.0)
    else:
        score_label.position = Vector2(area.x - side - number.x, middle - number.y * 0.5)
        score_caption.position = Vector2(score_label.position.x - 8.0 - caption.x, middle - caption.y * 0.5 + 3.0)
        motion_button.position = Vector2(score_caption.position.x - 26.0 - motion_button.size.x, middle - switch_height * 0.5)
        sound_button.position = Vector2(motion_button.position.x - 8.0 - sound_button.size.x, motion_button.position.y)
        _pips_at = Vector2((area.x - pips_width) * 0.5, middle - _pip.y * 0.5)
        progress_label.position = Vector2(_pips_at.x + pips_width + 14.0, middle - progress_label.size.y * 0.5)
    queue_redraw()

func _pips_width() -> float:
    var total := 0
    for count in groups:
        total += count
    return total * _pip.x + maxf(0.0, total - groups.size()) * _pip_gap + maxf(0.0, groups.size() - 1.0) * _group_gap

func _draw() -> void:
    # Spark: three ticks flying off the end of the wordmark.
    var flick := 0.0
    var beat := fmod(_clock, 6.0)
    if animate and beat < 0.5:
        flick = sin(beat / 0.5 * PI)
    for tick in TICKS:
        var direction: Vector2 = (tick[1] - tick[0]).normalized()
        var from: Vector2 = _spark_at + (tick[0] + direction * 3.0 * flick) * _spark_unit
        var to: Vector2 = _spark_at + (tick[1] + direction * 7.0 * flick) * _spark_unit
        Style.stroke(self, from, to, world.chip, 5.0 * _spark_unit)

    var x := _pips_at.x
    var index := 0
    for count in groups:
        for i in range(count):
            var state: int = marks[index] if index < marks.size() else Mark.PENDING
            var color := Color(ink, 0.24)
            match state:
                Mark.CURRENT:
                    color = world.chip
                Mark.CORRECT:
                    color = world.good
                Mark.WRONG:
                    color = world.bad
            var swell: float = _swell[index] if index < _swell.size() else 0.0
            var rect := Rect2(Vector2(x, _pips_at.y), _pip).grow_individual(0.0, 2.0 * swell, 0.0, 2.0 * swell)
            _box.bg_color = color
            _box.set_corner_radius_all(int(rect.size.y * 0.5))
            draw_style_box(_box, rect)
            x += _pip.x + _pip_gap
            index += 1
        x += _group_gap - _pip_gap
