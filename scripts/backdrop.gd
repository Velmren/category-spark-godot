extends Control
# Flat animated scene behind the game. Each world has its own motif: a speaker
# for sound, browser windows for the web, a ringed planet for space. A change of
# world is a circle of the new colour growing from the button that caused it.

const Style = preload("res://scripts/style.gd")

const CURSOR := [Vector2(0, 0), Vector2(0, 36), Vector2(9, 28), Vector2(16, 43), Vector2(23, 40), Vector2(16, 26), Vector2(28, 26)]
const TICKS := [[Vector2(5, 12), Vector2(3, 4)], [Vector2(13, 16), Vector2(20, 7)], [Vector2(17, 24), Vector2(26, 22)]]

var world: Dictionary = Style.FINALE
var animate := true
# Area kept free of small details: the question block set by the layout.
var calm := Rect2()

var _incoming: Dictionary = {}
var _wipe_origin := Vector2.ZERO
var _wipe := 0.0
var _slide := 1.0
var _kick := 0.0
var _clock := 0.0
var _tween: Tween
var _kick_tween: Tween
var _box := StyleBoxFlat.new()
var _base := Transform2D.IDENTITY
var _stars: Array[Vector2] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _box.corner_detail = 12
    var random := RandomNumberGenerator.new()
    random.seed = 7
    for i in range(46):
        _stars.append(Vector2(random.randf(), random.randf()))

func _process(delta: float) -> void:
    if animate:
        _clock += delta
    queue_redraw()

func show_world(target: Dictionary, origin: Vector2, animated: bool) -> void:
    if _tween:
        _tween.kill()
    if not _incoming.is_empty():
        world = _incoming
        _incoming = {}
    _wipe = 0.0
    _slide = 1.0
    if target.name == world.name:
        return
    if not animated:
        world = target
        return
    _incoming = target
    _wipe_origin = origin
    _tween = create_tween()
    _tween.tween_property(self, "_wipe", 1.0, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    _tween.tween_callback(_land)
    _tween.tween_property(self, "_slide", 1.0, 0.55).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _land() -> void:
    world = _incoming
    _incoming = {}
    _wipe = 0.0
    _slide = 0.0

# A short push through the motif when an answer lands.
func kick(animated: bool) -> void:
    if not animated:
        return
    if _kick_tween:
        _kick_tween.kill()
    _kick = 1.0
    _kick_tween = create_tween()
    _kick_tween.tween_property(self, "_kick", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), world.bg)
    var tall := size.x < size.y * 0.85
    var unit := clampf(size.y / 720.0, 0.6, 1.3) * (0.6 if tall else 1.0)
    match world.name:
        "sound":
            _frame(Vector2(size.x + 8.0, size.y * 0.33) if tall else Vector2(size.x - 150.0 * unit, size.y * 0.46), unit)
            _draw_sound(world, tall, 5)
        "web":
            _frame(Vector2(size.x - 96.0, size.y * 0.3) if tall else Vector2(size.x - 150.0 * unit, size.y * 0.47), unit)
            _draw_web(world, tall)
        "space":
            _draw_stars(world)
            _frame(Vector2(size.x - 38.0, size.y * 0.31) if tall else Vector2(size.x - 235.0 * unit, size.y * 0.43), unit)
            _draw_space(world)
        _:
            _draw_finale(tall, unit)
    draw_set_transform_matrix(Transform2D.IDENTITY)
    if not _incoming.is_empty():
        var reach := 0.0
        for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
            reach = maxf(reach, _wipe_origin.distance_to(corner))
        # A hand-built circle: the built-in one shows its corners at this size.
        var rim := PackedVector2Array()
        for step in range(180):
            rim.append(_wipe_origin + Vector2.from_angle(TAU * step / 180.0) * (reach * _wipe + 1.0))
        draw_colored_polygon(rim, _incoming.bg)
        rim.append(rim[0])
        draw_polyline(rim, _incoming.bg, 2.0, true)

# Sets the motif's local frame: origin at `anchor`, drawn in 720p units.
func _frame(anchor: Vector2, unit: float, settle := true) -> void:
    var offset := Vector2((1.0 - _slide) * 300.0 * unit, 0.0) if settle else Vector2.ZERO
    _base = Transform2D(0.0, Vector2.ONE * unit, 0.0, anchor + offset)
    draw_set_transform_matrix(_base)

func _shape(center: Vector2, extent: Vector2, angle: float, color: Color, radius: float) -> void:
    draw_set_transform_matrix(_base * Transform2D(angle, center))
    _box.bg_color = color
    _box.set_corner_radius_all(int(radius))
    draw_style_box(_box, Rect2(-extent * 0.5, extent))
    draw_set_transform_matrix(_base)

func _disc(center: Vector2, radius: float, color: Color) -> void:
    draw_circle(center, radius, color, true, -1.0, true)

func _draw_sound(tones: Dictionary, tall: bool, ring_limit: int) -> void:
    var spacing := 88.0
    var phase := fmod(_clock * 13.0, spacing) + _kick * 14.0
    # Waves leave the speaker and thin out to nothing a few rings later.
    var reach := spacing * ring_limit
    for ring in range(ring_limit + 1):
        var radius := phase + ring * spacing
        var width := 34.0 * clampf((reach - radius) / (spacing * 1.4), 0.0, 1.0)
        if radius < 34.0 or width < 1.0:
            continue
        draw_arc(Vector2.ZERO, radius, 0.0, TAU, clampi(int(radius * 0.4), 40, 128), tones.deep, width, true)
    var beat := pow(1.0 - fmod(_clock, 0.66) / 0.66, 3.0) if animate else 0.0
    _disc(Vector2.ZERO, 46.0 * (1.0 + 0.06 * beat + 0.16 * _kick), tones.lip if tall else tones.ink)
    if not tall:
        _shape(Vector2(-112, -238), Vector2(26, 62), deg_to_rad(18.0 + 3.0 * sin(_clock * 1.3)), tones.soft, 13.0)

func _draw_web(tones: Dictionary, tall: bool) -> void:
    var drift := sin(_clock * 0.5) * 6.0
    # Back window.
    var back := Transform2D(deg_to_rad(-7.0), Vector2(46, -150 + drift))
    _shape(back.origin, Vector2(470, 300), back.get_rotation(), tones.deep, 26.0)
    for i in range(3):
        _disc(back * Vector2(-200 + i * 26, -116), 8.0, tones.bg)
    # Front window.
    var front := Transform2D(deg_to_rad(4.0), Vector2(-14, 58 - drift))
    var pane: Color = tones.bg.lerp(tones.soft, 0.55) if tall else tones.soft
    _shape(front.origin, Vector2(500, 340), front.get_rotation(), pane, 26.0)
    for i in range(3):
        _disc(front * Vector2(-216 + i * 26, -136), 8.0, tones.bg)
    if tall:
        return
    var pale: Color = tones.soft.lerp(Style.PAPER, 0.42)
    draw_set_transform_matrix(_base * front)
    var typing := clampf(fmod(_clock, 5.0) / 2.6, 0.0, 1.0) if animate else 1.0
    var lines := [330.0, 392.0, 250.0 * typing]
    for i in range(lines.size()):
        if lines[i] > 16.0:
            _box.bg_color = pale
            _box.set_corner_radius_all(9)
            draw_style_box(_box, Rect2(-216, -86 + i * 40, lines[i], 18))
    if fmod(_clock, 1.0) < 0.55 or not animate:
        draw_rect(Rect2(-216 + maxf(lines[2], 0.0) + 8.0, -10, 5, 26), Style.PAPER)
    # A link being clicked.
    var cycle := fmod(_clock, 5.0) if animate else 2.0
    var press := clampf(1.0 - absf(cycle - 1.9) / 0.12, 0.0, 1.0) + _kick
    var link := Vector2(-76, 92)
    var squash := 1.0 - 0.06 * minf(press, 1.0)
    _box.bg_color = tones.chip
    _box.set_corner_radius_all(24)
    draw_style_box(_box, Rect2(link - Vector2(85, 24) * squash, Vector2(170, 48) * squash))
    _box.bg_color = Color(tones.chip_ink, 0.85)
    _box.set_corner_radius_all(5)
    draw_style_box(_box, Rect2(link - Vector2(46, 5), Vector2(92, 10)))
    var after := cycle - 1.9
    if animate and after > 0.0 and after < 0.45:
        var head := ease(minf(after / 0.24, 1.0), 0.4)
        var tail := ease(clampf((after - 0.12) / 0.33, 0.0, 1.0), 2.0)
        for tick in TICKS:
            var direction: Vector2 = (tick[1] - tick[0]).normalized()
            var start: Vector2 = link + Vector2(62, -50) + tick[0]
            Style.stroke(self, start + direction * 18.0 * tail, start + direction * (4.0 + 16.0 * head), Style.PAPER, 6.0)
    var rest := Vector2(118, 104)
    var travel := smoothstep(0.5, 1.7, cycle) - smoothstep(2.6, 3.9, cycle)
    var tip := rest.lerp(link + Vector2(30, 6), travel)
    var arrow := PackedVector2Array()
    for point in CURSOR:
        arrow.append(tip + point * (1.25 - 0.1 * minf(press, 1.0)))
    draw_colored_polygon(arrow, Style.PAPER)
    arrow.append(arrow[0])
    draw_polyline(arrow, Style.INK, 3.5, true)
    draw_set_transform_matrix(_base)

func _draw_stars(tones: Dictionary) -> void:
    draw_set_transform_matrix(Transform2D.IDENTITY)
    var tints := [Style.PAPER, tones.chip, tones.soft.lerp(Style.PAPER, 0.4)]
    for i in range(_stars.size()):
        var spot: Vector2 = _stars[i] * size
        # Stars stay out from under the top bar and the question.
        if spot.y < 96.0 or calm.has_point(spot):
            continue
        var twinkle := 0.75 + 0.25 * sin(_clock * (0.9 + (i % 5) * 0.23) + i * 1.7)
        _disc(spot, (2.0 + (i % 3) * 1.3) * twinkle, tints[i % 3])

func _draw_space(tones: Dictionary) -> void:
    var tilt := deg_to_rad(-18.0)
    var bob := sin(_clock * 0.6) * 5.0 - _kick * 10.0
    var center := Vector2(0, bob)
    var back := PackedVector2Array()
    var front := PackedVector2Array()
    for step in range(49):
        var angle := PI * step / 48.0
        front.append(center + Vector2(cos(angle) * 330.0, sin(angle) * 72.0).rotated(tilt))
        back.append(center + Vector2(cos(angle + PI) * 330.0, sin(angle + PI) * 72.0).rotated(tilt))
    var moons := [[430.0, 130.0, 15.0, 0.0, 20.0, tones.moon], [545.0, 176.0, 24.0, 2.2, 12.0, tones.chip]]
    for moon in moons:
        _moon(moon, center, tilt, false)
    draw_polyline(back, tones.soft, 24.0, true)
    _disc(center, 190.0, tones.deep)
    for crater in [[Vector2(-78, -70), 34.0], [Vector2(52, 96), 22.0], [Vector2(96, -104), 15.0]]:
        _disc(center + crater[0], crater[1], tones.deep.lerp(tones.bg, 0.45))
    draw_polyline(front, tones.soft, 24.0, true)
    for moon in moons:
        _moon(moon, center, tilt, true)

func _moon(moon: Array, center: Vector2, tilt: float, in_front: bool) -> void:
    var angle: float = _clock * TAU / moon[2] + moon[3]
    if (sin(angle) > 0.0) != in_front:
        return
    _disc(center + Vector2(cos(angle) * moon[0], sin(angle) * moon[1]).rotated(tilt), moon[4], moon[5])

# The result screen quotes all three motifs tone on tone.
func _draw_finale(tall: bool, unit: float) -> void:
    var tones := Style.FINALE.duplicate()
    tones.ink = tones.soft
    tones.lip = tones.soft
    tones.chip = tones.soft
    _frame(Vector2(size.x * (0.92 if tall else 0.1), size.y + 30.0 * unit), unit * 0.9)
    _draw_sound(tones, tall, 4)
    _frame(Vector2(size.x - (30.0 if tall else 200.0 * unit), size.y * (0.16 if tall else 0.24)), unit * 0.72)
    _draw_space(tones)
