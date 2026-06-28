extends Control

onready var icon := $Icon
onready var tween := $Tween
var _base_scale := Vector2(1, 1)

func _ready():
	_base_scale = rect_scale
	rect_pivot_offset = rect_size / 2
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")
	connect("gui_input", self, "_on_gui_input")

func _on_mouse_entered():
	tween.stop_all()
	tween.interpolate_property(self, "rect_scale", rect_scale, _base_scale * 1.02, 0.12, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(icon, "modulate:a", icon.modulate.a, 1.0, 0.12)
	tween.start()

func _on_mouse_exited():
	tween.stop_all()
	tween.interpolate_property(self, "rect_scale", rect_scale, _base_scale, 0.12, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(icon, "modulate:a", icon.modulate.a, 0.85, 0.12)
	tween.start()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tween.stop_all()
			tween.interpolate_property(self, "rect_scale", rect_scale, _base_scale * 0.98, 0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)
			tween.start()
		else:
			tween.stop_all()
			tween.interpolate_property(self, "rect_scale", rect_scale, _base_scale * 1.02, 0.12, Tween.TRANS_CUBIC, Tween.EASE_OUT)
			tween.start()
