extends Control
# Paper confetti for a good round: flat rounded pieces thrown up from one point.

const Style = preload("res://scripts/style.gd")

const GRAVITY := 980.0
const TINTS := [Color("ffb81f"), Color("2f5bea"), Color("ffffff"), Color("5fe0a6"), Color("ff8ac2")]

var _pieces: Array = []
var _random := RandomNumberGenerator.new()
var _chip: ImageTexture

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # One white chip with a clear border; filtering softens its edges when it turns.
    var image := Image.create(16, 24, false, Image.FORMAT_RGBA8)
    image.fill(Color(1, 1, 1, 0))
    image.fill_rect(Rect2i(2, 2, 12, 20), Color.WHITE)
    _chip = ImageTexture.create_from_image(image)
    set_process(false)

func burst(origin: Vector2, count: int) -> void:
    _random.seed = 20261003
    for i in range(count):
        var angle := _random.randf_range(-PI * 0.92, -PI * 0.08)
        var speed := _random.randf_range(360.0, 980.0)
        _pieces.append({
            "at": origin + Vector2(_random.randf_range(-40.0, 40.0), _random.randf_range(-10.0, 10.0)),
            "speed": Vector2.from_angle(angle) * speed,
            "turn": _random.randf_range(0.0, TAU),
            "spin": _random.randf_range(-9.0, 9.0),
            "extent": Vector2(_random.randf_range(7.0, 12.0), _random.randf_range(12.0, 20.0)),
            "tint": TINTS[i % TINTS.size()],
            "sway": _random.randf_range(0.0, TAU),
        })
    set_process(true)

func clear() -> void:
    _pieces.clear()
    set_process(false)
    queue_redraw()

func _process(delta: float) -> void:
    var kept: Array = []
    for piece in _pieces:
        piece.speed.y += GRAVITY * delta
        piece.speed *= pow(0.42, delta)
        piece.sway += delta * 5.0
        piece.at += (piece.speed + Vector2(sin(piece.sway) * 60.0, 0.0)) * delta
        piece.turn += piece.spin * delta
        if piece.at.y < size.y + 40.0:
            kept.append(piece)
    _pieces = kept
    if _pieces.is_empty():
        set_process(false)
    queue_redraw()

func _draw() -> void:
    for piece in _pieces:
        # Squashing one axis with the sway reads as the piece tumbling.
        var flip := 0.35 + 0.65 * absf(cos(piece.sway))
        draw_set_transform(piece.at, piece.turn, Vector2(1.0, flip))
        var extent: Vector2 = piece.extent * Vector2(16.0 / 12.0, 24.0 / 20.0)
        draw_texture_rect(_chip, Rect2(-extent * 0.5, extent), false, piece.tint)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
