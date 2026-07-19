extends Control

@onready var icon := $Icon
var _base_scale := Vector2(1, 1)

func _ready():
	_base_scale = scale
	pivot_offset = size / 2
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_mouse_entered():
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", _base_scale * 1.02, 0.12)
	tween.tween_property(icon, "modulate:a", 1.0, 0.12)

func _on_mouse_exited():
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", _base_scale, 0.12)
	tween.tween_property(icon, "modulate:a", 0.85, 0.12)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(self, "scale", _base_scale * 0.98, 0.08)
		else:
			var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(self, "scale", _base_scale * 1.02, 0.12)
