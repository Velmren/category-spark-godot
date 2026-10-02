extends Node
# Plays the short interface sounds from a small pool of players.

const STREAMS := {
    "tap": preload("res://assets/sfx/tap.wav"),
    "select": preload("res://assets/sfx/select.wav"),
    "correct": preload("res://assets/sfx/correct.wav"),
    "wrong": preload("res://assets/sfx/wrong.wav"),
    "tick": preload("res://assets/sfx/tick.wav"),
    "transition": preload("res://assets/sfx/transition.wav"),
    "finale": preload("res://assets/sfx/finale.wav"),
}

var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
    for i in range(6):
        var player := AudioStreamPlayer.new()
        add_child(player)
        _players.append(player)

func play(sound: String, pitch := 1.0, delay := 0.0, volume_db := 0.0) -> void:
    if not enabled:
        return
    if delay > 0.0:
        await get_tree().create_timer(delay).timeout
        if not enabled:
            return
    var player := _players[_next]
    _next = (_next + 1) % _players.size()
    player.stream = STREAMS[sound]
    player.pitch_scale = pitch
    player.volume_db = volume_db
    player.play()

func hush() -> void:
    for player in _players:
        player.stop()
