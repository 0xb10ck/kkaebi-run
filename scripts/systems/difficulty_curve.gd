class_name DifficultyCurve
extends RefCounted


static func multipliers(elapsed: float) -> Dictionary:
	var hp_mult := 1.0 + floor(elapsed / 30.0) * 0.10
	var speed_mult := 1.0 + floor(elapsed / 60.0) * 0.05
	var damage_mult := 1.0 + floor(elapsed / 90.0) * 0.10
	return {
		"hp": hp_mult,
		"speed": speed_mult,
		"damage": damage_mult,
	}
