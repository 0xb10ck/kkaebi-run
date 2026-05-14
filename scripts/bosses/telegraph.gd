class_name Telegraph
extends Node2D

# §5.2 — 보스 패턴 텔레그래프 일반화. 0→1 채워지는 alpha 트윈으로 위협 영역 표시.

@export var vfx_kind: StringName = &"red_circle"  # &"red_circle"|&"red_line"|&"red_cone"|&"red_vignette"
@export var duration_s: float = 1.0
@export var radius_px: float = 80.0
@export var length_px: float = 0.0
@export var angle_deg: float = 60.0
@export var follow_target: Node2D

signal expired

const TELEGRAPH_COLOR: Color = Color(1.0, 0.2, 0.2, 0.45)

var _elapsed: float = 0.0
var _active: bool = false
var _expired_emitted: bool = false


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if is_instance_valid(follow_target):
		global_position = follow_target.global_position
	queue_redraw()
	if _elapsed >= duration_s and not _expired_emitted:
		_expired_emitted = true
		expired.emit()
		_active = false


func start() -> void:
	_elapsed = 0.0
	_active = true
	_expired_emitted = false
	queue_redraw()


func cancel() -> void:
	_active = false
	_expired_emitted = true
	queue_redraw()


func _draw() -> void:
	if not _active and not _expired_emitted:
		return
	var alpha: float = 0.0
	if duration_s > 0.0:
		alpha = clamp(_elapsed / duration_s, 0.0, 1.0)
	var col: Color = TELEGRAPH_COLOR
	col.a = TELEGRAPH_COLOR.a * (0.35 + 0.65 * alpha)
	match String(vfx_kind):
		"red_circle":
			draw_circle(Vector2.ZERO, radius_px, col)
		"red_line":
			var half: float = max(length_px * 0.5, 1.0)
			draw_rect(Rect2(-half, -radius_px * 0.5, length_px, radius_px), col)
		"red_cone":
			_draw_cone(col)
		"red_vignette":
			draw_rect(Rect2(-2000.0, -2000.0, 4000.0, 4000.0), col)
		_:
			draw_circle(Vector2.ZERO, radius_px, col)


func _draw_cone(col: Color) -> void:
	var half_rad: float = deg_to_rad(angle_deg) * 0.5
	var steps: int = 18
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in steps + 1:
		var a: float = -half_rad + (deg_to_rad(angle_deg) * float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * radius_px)
	draw_colored_polygon(pts, col)
