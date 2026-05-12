class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name_ko: String = ""

# 스탯
@export var hp: int = 1
@export var move_speed: float = 80.0
@export var contact_damage: int = 4
@export var hitbox_radius: float = 12.0

# 보상
@export var exp_value: int = 1
@export var gold_drop_chance: float = 0.0
@export var gold_drop_amount: int = 0

# 시각 (Phase 1은 ColorRect 플레이스홀더)
@export var sprite_size: Vector2i = Vector2i(24, 24)
@export var placeholder_color: Color = Color.WHITE
@export var sprite_texture: Texture2D

# 특수 효과 (물귀신용)
@export var on_contact_effect: StringName = &""
@export var slow_factor: float = 0.0
@export var slow_duration: float = 0.0

# 군집 스폰 (달걀귀신용)
@export var group_size: int = 1
@export var group_spacing_px: float = 30.0
