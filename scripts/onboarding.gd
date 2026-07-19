extends Node

# First-flight onboarding: three prompts taught by DOING, each dismissed by
# the action it teaches. Never shown again after the player's first kill
# (persisted as settings/onboarded). Phase1 only spawns this when needed.

const UIS = preload("res://scripts/ui_style.gd")
const GS = preload("res://scripts/game_settings.gd")

var _phase: Node = null
var _label: Label = null
var _step: int = 0
var _start_pos: Vector2 = Vector2.INF
var _alpha: float = 0.0

const STEPS := [
	"WASD  ·  stick  ·  hold + drag   —   fly",
	"sweep up the dim strays — they are your flock",
	"whip THROUGH enemies — speed is damage",
]


func _ready() -> void:
	_phase = get_parent()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIS.outline(_label, 6)
	_label.size = Vector2(900.0, 30.0)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_label.position += Vector2(0.0, 130.0)   # lower third, under the player
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	layer.add_child(_label)


func _process(delta: float) -> void:
	if _step >= STEPS.size():
		_alpha = maxf(_alpha - delta * 2.0, 0.0)
		_label.modulate.a = _alpha
		if _alpha <= 0.0:
			queue_free()
		return

	_label.text = STEPS[_step]
	_alpha = minf(_alpha + delta * 1.5, 0.9)
	_label.modulate = Color(UIS.MINT.r * 0.6 + 0.4, UIS.MINT.g * 0.4 + 0.6, UIS.MINT.b * 0.4 + 0.6, _alpha)

	match _step:
		0:
			# Dismissed by flying a real distance
			if _phase.player != null:
				if _start_pos == Vector2.INF:
					_start_pos = _phase.player.global_position
				elif _start_pos.distance_to(_phase.player.global_position) > 220.0:
					_advance()
		1:
			# Dismissed by the first recruit
			if _phase.collected_count > 0:
				_advance()
		2:
			# Dismissed by the first kill — and never shown again
			if _phase.kills > 0:
				GS.save_setting("onboarded", true)
				_advance()


func _advance() -> void:
	_step += 1
	_alpha = 0.0
