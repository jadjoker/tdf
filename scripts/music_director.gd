extends Node

# Adaptive soundtrack: four loop-perfect stems (one shared tonality) playing
# in sync forever; the game states mix them. The music IS the murmuration:
#   base    — the void, always breathing underneath
#   warm    — the flock chord; swells with your murmuration's size
#   tension — the hunt; sharpens as enemies close in
#   boss    — Sovereign dread pulse
# Call set_target(stem, 0..1) — volumes glide, never snap.

const STEMS := {
	"base": preload("res://assets/music/stem_base.wav"),
	"warm": preload("res://assets/music/stem_warm.wav"),
	"tension": preload("res://assets/music/stem_tension.wav"),
	"boss": preload("res://assets/music/stem_boss.wav"),
}

const MASTER_DB := -10.0   # soundtrack sits under the SFX
const GLIDE := 1.6         # volume approach rate

var _players: Dictionary = {}
var _targets: Dictionary = {}
var _levels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps breathing through pause
	for stem_name in STEMS:
		var stream: AudioStreamWAV = STEMS[stem_name].duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2   # 16-bit mono: 2 bytes/frame
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_players[stem_name] = p
		_targets[stem_name] = 0.0
		_levels[stem_name] = 0.0


func set_target(stem_name: String, linear: float) -> void:
	_targets[stem_name] = clampf(linear, 0.0, 1.0)


func _process(delta: float) -> void:
	for stem_name in _players:
		var lvl: float = _levels[stem_name]
		lvl = lerpf(lvl, _targets[stem_name], 1.0 - exp(-GLIDE * delta))
		_levels[stem_name] = lvl
		_players[stem_name].volume_db = linear_to_db(maxf(lvl, 0.001)) + MASTER_DB
