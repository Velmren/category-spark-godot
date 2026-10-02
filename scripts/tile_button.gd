extends Button
# Chunky push button drawn by hand: a face that sinks into its lip when pressed
# and carries the answer states (correct, wrong, dimmed).

const Style = preload("res://scripts/style.gd")

enum State { IDLE, CORRECT, WRONG, DIM }

const LIP := 7.0
const CHECK := [Vector2(9, 17.5), Vector2(14.5, 23), Vector2(25, 11.5)]
const CROSS_A := [Vector2(11, 11), Vector2(23, 23)]
const CROSS_B := [Vector2(23, 11), Vector2(11, 23)]
# Spark ticks around a correct answer: anchor on the face (0..1) plus direction in degrees.
const TICKS := [
    [Vector2(0, 0.42), 215.0], [Vector2(0, 0.42), 180.0], [Vector2(0, 0.42), 145.0],
    [Vector2(1, 0.0), 312.0], [Vector2(1, 0.0), 350.0],
]

# Focus rings are drawn only while the player is using the keyboard.
static var keyboard_focus := false

var caption := "": set = set_caption
var key_hint := ""
var caption_size := 27
var face := Style.PAPER
var lip := Color("d98c00")
var ink := Style.INK
var ground := Style.PAPER
var spark := Style.INK
var state := State.IDLE

var pop := 1.0
var shake := 0.0
var mark := 1.0
var burst := 1.0
var reveal := 1.0

var _depth := 0.0
# True while a delayed state change is pending, so the tile is not dimmed early.
var _waiting := false
var _look: Array = []
var _was_live := true
var _box := StyleBoxFlat.new()
var _edge := StyleBoxFlat.new()
var _tween: Tween
var _reveal_tween: Tween

func _init() -> void:
    flat = true
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for item in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
        add_theme_stylebox_override(item, StyleBoxEmpty.new())
    _box.corner_detail = 12
    _edge.draw_center = false
    _edge.corner_detail = 12

func set_caption(value: String) -> void:
    caption = value
    queue_redraw()

# Redraws only while something on the tile is moving or its look has changed.
func _process(delta: float) -> void:
    var target := _target_depth()
    var look := [get_draw_mode(), has_focus() and keyboard_focus, state, disabled]
    var live := not is_equal_approx(_depth, target) or look != _look
    live = live or (_tween != null and _tween.is_running()) or (_reveal_tween != null and _reveal_tween.is_running())
    _depth = target if absf(_depth - target) < 0.05 else lerpf(_depth, target, minf(1.0, delta * 26.0))
    _look = look
    modulate.a = clampf(reveal * 1.6, 0.0, 1.0)
    if live or _was_live:
        queue_redraw()
    _was_live = live

func _target_depth() -> float:
    match state:
        State.CORRECT:
            return -3.0
        State.WRONG:
            return LIP - 3.0
        State.DIM:
            return 4.0
    if disabled:
        return 0.0 if _waiting else 4.0
    match get_draw_mode():
        DRAW_PRESSED, DRAW_HOVER_PRESSED:
            return LIP - 1.0
        DRAW_HOVER:
            return -2.0
    return 0.0

# Fade and rise into place; used when a question is dealt.
func appear(delay: float, animated: bool) -> void:
    if _reveal_tween:
        _reveal_tween.kill()
    if not animated:
        reveal = 1.0
        return
    reveal = 0.0
    _reveal_tween = create_tween()
    _reveal_tween.tween_interval(delay)
    _reveal_tween.tween_property(self, "reveal", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func settle(next: State, animated: bool, delay := 0.0) -> void:
    if _tween:
        _tween.kill()
    _waiting = false
    if not animated:
        state = next
        pop = 1.0
        shake = 0.0
        mark = 1.0
        burst = 1.0
        queue_redraw()
        return
    _tween = create_tween()
    if delay > 0.0:
        _waiting = true
        _tween.tween_interval(delay)
    _tween.tween_callback(_enter.bind(next))
    match next:
        State.CORRECT:
            _tween.tween_property(self, "pop", 1.035, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            _tween.parallel().tween_property(self, "mark", 1.0, 0.24).set_delay(0.04)
            _tween.parallel().tween_property(self, "burst", 1.0, 0.46)
            _tween.tween_property(self, "pop", 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        State.WRONG:
            _tween.tween_method(_wobble, 0.0, 1.0, 0.4)
            _tween.parallel().tween_property(self, "mark", 1.0, 0.22)

func _enter(next: State) -> void:
    _waiting = false
    state = next
    if next == State.CORRECT:
        mark = 0.0
        burst = 0.0
    elif next == State.WRONG:
        mark = 0.0

func _wobble(progress: float) -> void:
    shake = sin(progress * TAU * 3.0) * 10.0 * (1.0 - progress)

func _fill(rect: Rect2, color: Color, radius: float) -> void:
    _box.bg_color = color
    _box.set_corner_radius_all(int(radius))
    draw_style_box(_box, rect)

func _outline(rect: Rect2, color: Color, radius: float, width: int) -> void:
    _edge.border_color = color
    _edge.set_border_width_all(width)
    _edge.set_corner_radius_all(int(radius))
    draw_style_box(_edge, rect)

func _draw() -> void:
    var body := Vector2(size.x, size.y - LIP)
    var radius := minf(16.0, body.y * 0.5)
    var origin := size * 0.5
    var shown := clampf(reveal, 0.0, 1.2)
    draw_set_transform(origin + Vector2(shake, (1.0 - shown) * 22.0), 0.0, Vector2.ONE * pop * lerpf(0.92, 1.0, shown))

    var face_color := face
    var lip_color := lip
    var text_color := ink
    var dimmed := state == State.DIM or (disabled and state == State.IDLE and not _waiting)
    match state:
        State.CORRECT:
            face_color = Style.CORRECT
            lip_color = Style.CORRECT_DEEP
            text_color = Style.PAPER
        State.WRONG:
            face_color = Style.WRONG
            lip_color = Style.WRONG_DEEP
            text_color = Style.PAPER
    if dimmed:
        face_color = face.lerp(ground, 0.56)
        text_color = Color(ink, 0.5)

    var corner := -origin
    _fill(Rect2(corner + Vector2(0, LIP), body), lip_color, radius)
    var top := corner + Vector2(0, _depth)
    _fill(Rect2(top, body), face_color, radius)

    if has_focus() and keyboard_focus:
        _outline(Rect2(top, body).grow(5.0), spark, radius + 5.0, 3)

    var font := Style.text(700)
    var text_left := 22.0
    var text_room := body.x - 44.0
    if key_hint != "":
        var cap := clampf(body.y * 0.42, 26.0, 34.0)
        var cap_rect := Rect2(top + Vector2(18, (body.y - cap) * 0.5), Vector2(cap, cap))
        _draw_cap(cap_rect, face_color, dimmed)
        text_left = 18.0 + cap + 15.0
        text_room = body.x - text_left - 18.0

    var font_size := caption_size
    while font_size > 13 and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text_room:
        font_size -= 1
    var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var baseline := top.y + body.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
    var text_x := top.x + (text_left if key_hint != "" else (body.x - text_width) * 0.5)
    draw_string(font, Vector2(text_x, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

    if state == State.CORRECT and burst < 1.0:
        _draw_burst(Rect2(top, body))

func _draw_cap(rect: Rect2, face_color: Color, dimmed: bool) -> void:
    var unit := rect.size.x / 34.0
    if state == State.CORRECT or state == State.WRONG:
        _fill(rect, Style.PAPER, 8.0 * unit)
        if state == State.CORRECT:
            Style.stroke_path(self, _scaled(CHECK, rect.position, unit), mark, face_color, 4.2 * unit)
        else:
            Style.stroke_path(self, _scaled(CROSS_A, rect.position, unit), mark * 2.0, face_color, 4.2 * unit)
            Style.stroke_path(self, _scaled(CROSS_B, rect.position, unit), mark * 2.0 - 1.0, face_color, 4.2 * unit)
        return
    var hovered := not disabled and get_draw_mode() in [DRAW_HOVER, DRAW_PRESSED, DRAW_HOVER_PRESSED]
    var number_color := Color(ink, 0.32 if dimmed else 0.62)
    if hovered:
        _fill(rect, ink, 8.0 * unit)
        number_color = face
    else:
        _outline(rect, Color(ink, 0.16 if dimmed else 0.28), 8.0 * unit, 2)
    var font := Style.text(700)
    var font_size := int(round(17.0 * unit))
    var width := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var baseline := rect.position.y + rect.size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
    draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, baseline), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, number_color)

func _scaled(points: Array, offset: Vector2, unit: float) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in points:
        result.append(offset + point * unit)
    return result

func _draw_burst(rect: Rect2) -> void:
    var head := ease(minf(burst * 1.9, 1.0), 0.35)
    var tail := ease(clampf((burst - 0.3) / 0.7, 0.0, 1.0), 2.2)
    for tick in TICKS:
        # Rays start a little way out from a point just inside the face, so they never meet.
        var anchor: Vector2 = rect.position + rect.size * tick[0] + Vector2(6.0 if tick[0].x == 0.0 else -8.0, 6.0 if tick[0].y == 0.0 else 0.0)
        var direction := Vector2.from_angle(deg_to_rad(tick[1]))
        Style.stroke(self, anchor + direction * (22.0 + 24.0 * tail), anchor + direction * (24.0 + 24.0 * head), spark, 6.0)
