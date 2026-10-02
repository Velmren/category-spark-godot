extends RefCounted
# Shared colours and fonts. Every category plays in its own "world": a flat
# background colour with two tone-on-tone shades and an accent.

const INK := Color("23163a")
const PAPER := Color("ffffff")
const SUN := Color("ffb81f")
const CORRECT := Color("14a36b")
const CORRECT_DEEP := Color("0b7a4e")
const CORRECT_SOFT := Color("5fe0a6")
const WRONG := Color("e5484d")
const WRONG_DEEP := Color("a92a30")
const WRONG_SOFT := Color("ff9da0")

const WORLDS := [
    {
        "name": "sound", "bg": Color("ffb81f"), "deep": Color("f59c00"), "soft": Color("ffd166"),
        "ink": Color("23163a"), "chip": Color("23163a"), "chip_ink": Color("ffb81f"),
        "lip": Color("d98c00"), "sheet": Color("23163a"), "good": Color("0c8a58"), "bad": Color("d2353b"),
    },
    {
        "name": "web", "bg": Color("2f5bea"), "deep": Color("2448c8"), "soft": Color("5c83f7"),
        "ink": Color("ffffff"), "chip": Color("ffd23f"), "chip_ink": Color("23163a"),
        "lip": Color("1a379f"), "sheet": Color("23163a"), "good": Color("6ff0b4"), "bad": Color("ffa3a6"),
    },
    {
        "name": "space", "bg": Color("2b1f5e"), "deep": Color("3a2c7c"), "soft": Color("5546a8"),
        "ink": Color("ffffff"), "chip": Color("ffd95a"), "chip_ink": Color("23163a"),
        "lip": Color("17103a"), "sheet": Color("17103a"), "good": Color("5fe0a6"), "bad": Color("ff9da0"),
        "moon": Color("9488dc"),
    },
]

const FINALE := {
    "name": "finale", "bg": Color("23163a"), "deep": Color("2f2050"), "soft": Color("3d2b66"),
    "ink": Color("ffffff"), "chip": Color("ffb81f"), "chip_ink": Color("23163a"),
    "lip": Color("120a22"), "sheet": Color("23163a"), "good": Color("5fe0a6"), "bad": Color("ff9da0"),
    "moon": Color("3d2b66"),
}

const DISPLAY := preload("res://assets/fonts/LondrinaSolid-Black.ttf")
const TEXT_BASE := preload("res://assets/fonts/Gabarito-Variable.ttf")

static var _text_fonts := {}

# Gabarito is a variable font; each weight (and optional tracking) is cached once.
static func text(weight: int, tracking := 0) -> Font:
    var key := Vector2i(weight, tracking)
    if not _text_fonts.has(key):
        var variation := FontVariation.new()
        variation.base_font = TEXT_BASE
        variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
        variation.spacing_glyph = tracking
        _text_fonts[key] = variation
    return _text_fonts[key]

static func world_for(index: int) -> Dictionary:
    return WORLDS[index % WORLDS.size()]

# Round-capped stroke; the engine's lines end square.
static func stroke(item: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float) -> void:
    item.draw_line(from, to, color, width, true)
    item.draw_circle(from, width * 0.5, color, true, -1.0, true)
    item.draw_circle(to, width * 0.5, color, true, -1.0, true)

# Draws the first `progress` share of a round-capped path.
static func stroke_path(item: CanvasItem, points: PackedVector2Array, progress: float, color: Color, width: float) -> void:
    var total := 0.0
    for i in range(points.size() - 1):
        total += points[i].distance_to(points[i + 1])
    var left := total * clampf(progress, 0.0, 1.0)
    for i in range(points.size() - 1):
        if left <= 0.0:
            return
        var span := points[i].distance_to(points[i + 1])
        var end := points[i].lerp(points[i + 1], minf(1.0, left / span))
        stroke(item, points[i], end, color, width)
        left -= span
