extends Control
# Result screen list: one row per category with a mark for every question.

const Style = preload("res://scripts/style.gd")

const CHECK := [Vector2(8, 15.5), Vector2(13, 20.5), Vector2(22, 10)]
const CROSS_A := [Vector2(10, 10), Vector2(20, 20)]
const CROSS_B := [Vector2(20, 10), Vector2(10, 20)]

# Each row: {"label": String, "tint": Color, "results": Array of bool}
var rows: Array = []
var row_height := 50.0
var label_size := 22
# How many marks have been revealed; the fraction animates the newest one.
var shown := 0.0: set = set_shown

var _box := StyleBoxFlat.new()
var _edge := StyleBoxFlat.new()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _edge.draw_center = false
    _edge.set_border_width_all(2)

func set_shown(value: float) -> void:
    shown = value
    queue_redraw()

func total() -> int:
    var count := 0
    for row in rows:
        count += row.results.size()
    return count

func _draw() -> void:
    var font := Style.text(700)
    var mark_size := minf(30.0, row_height - 12.0)
    var index := 0
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        var middle := i * row_height + row_height * 0.5
        var swatch := Rect2(0, middle - 11.0, 22, 22)
        _box.bg_color = row.tint
        _box.set_corner_radius_all(7)
        draw_style_box(_box, swatch)
        _edge.border_color = Color(Style.PAPER, 0.3)
        _edge.set_corner_radius_all(7)
        draw_style_box(_edge, swatch)
        var baseline := middle + (font.get_ascent(label_size) - font.get_descent(label_size)) * 0.5
        draw_string(font, Vector2(36, baseline), row.label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Style.PAPER)
        var count: int = row.results.size()
        for n in range(count):
            var center := Vector2(size.x - (count - n - 0.5) * (mark_size + 8.0) + 4.0, middle)
            var progress := clampf(shown - index, 0.0, 1.0)
            _draw_mark(center, mark_size, row.results[n], progress)
            index += 1

func _draw_mark(center: Vector2, extent: float, correct: bool, progress: float) -> void:
    var unit := extent / 30.0
    if progress <= 0.0:
        _edge.border_color = Color(Style.PAPER, 0.22)
        _edge.set_corner_radius_all(int(9 * unit))
        draw_style_box(_edge, Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent))
        return
    var grown := extent * lerpf(0.5, 1.0, ease(progress, 0.3)) * (1.0 + 0.18 * sin(progress * PI))
    var corner := center - Vector2.ONE * grown * 0.5
    _box.bg_color = Style.CORRECT if correct else Style.WRONG
    _box.set_corner_radius_all(int(9 * unit * grown / extent))
    draw_style_box(_box, Rect2(corner, Vector2.ONE * grown))
    var scale := grown / 30.0
    if correct:
        Style.stroke_path(self, _points(CHECK, corner, scale), progress * 1.4, Style.PAPER, 3.6 * scale)
    else:
        Style.stroke_path(self, _points(CROSS_A, corner, scale), progress * 2.0, Style.PAPER, 3.6 * scale)
        Style.stroke_path(self, _points(CROSS_B, corner, scale), progress * 2.0 - 0.6, Style.PAPER, 3.6 * scale)

func _points(source: Array, offset: Vector2, scale: float) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in source:
        result.append(offset + point * scale)
    return result
