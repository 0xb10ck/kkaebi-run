class_name Ids
extends RefCounted

# 빈번하게 비교되는 StringName 상수. 매직 문자열 격리용.

# 자동저장 사유
const SAVE_AUTOSAVE: StringName = &"autosave"
const SAVE_MANUAL: StringName = &"manual"
const SAVE_QUIT: StringName = &"quit"

# 런 종료 사유
const RUN_DEATH: StringName = &"death"
const RUN_CLEAR: StringName = &"clear"
const RUN_ABANDON: StringName = &"abandon"

# 부활 소스
const REVIVE_META: StringName = &"meta_revive"
const REVIVE_ITEM: StringName = &"item"

# 영구 강화 키
const UPG_MAX_HP: StringName = &"max_hp"
const UPG_ATTACK: StringName = &"attack"
const UPG_MOVE_SPEED: StringName = &"move_speed"
const UPG_XP_GAIN: StringName = &"xp_gain"
const UPG_GOLD_GAIN: StringName = &"gold_gain"
const UPG_REVIVE: StringName = &"revive"
const UPG_CHOICE_EXTRA: StringName = &"choice_extra"
const UPG_LUCK: StringName = &"luck"

const ALL_UPGRADE_KEYS: Array[StringName] = [
	&"max_hp", &"attack", &"move_speed",
	&"xp_gain", &"gold_gain",
	&"revive", &"choice_extra", &"luck",
]
