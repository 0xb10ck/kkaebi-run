class_name SaveStore
extends RefCounted

# §7.4 — user://save.json 직렬화/역직렬화 + 마이그레이션.
# 데스크톱은 OS 파일, 웹은 Godot의 자동 IndexedDB(/userfs/) 매핑을 사용.

const PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.backup.json"
const CURRENT_VERSION: int = 2


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return default_data()
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("SaveStore: failed to open save file, falling back to defaults")
		return _try_backup_or_default()
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveStore: save.json corrupt, falling back to backup")
		return _try_backup_or_default()
	var d: Dictionary = parsed
	d = _migrate(d)
	return d


static func _try_backup_or_default() -> Dictionary:
	if FileAccess.file_exists(BACKUP_PATH):
		var f: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if f != null:
			var t: String = f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(t)
			if typeof(parsed) == TYPE_DICTIONARY:
				return _migrate(parsed)
	return default_data()


static func save_data(d: Dictionary) -> bool:
	# 1) 백업 (직전 저장본 보관)
	if FileAccess.file_exists(PATH):
		var prev: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if prev != null:
			var prev_text: String = prev.get_as_text()
			prev.close()
			var bk: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bk != null:
				bk.store_string(prev_text)
				bk.close()
	# 2) 본 저장
	var ok: bool = _atomic_write(PATH, JSON.stringify(d))
	if not ok:
		return false
	# 3) 웹 빌드는 IndexedDB로 flush
	_web_flush()
	return true


static func _atomic_write(path: String, data: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(data)
	f.close()
	return true


static func _web_flush() -> void:
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var js: Object = Engine.get_singleton("JavaScriptBridge")
	if js and js.has_method("eval"):
		js.call("eval", "FS.syncfs(false, function(e){})")


static func _migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	while v < CURRENT_VERSION:
		match v:
			0:
				d = _migrate_0_to_1(d)
			1:
				d = _migrate_1_to_2(d)
			_:
				break
		v = int(d.get("version", v + 1))
	return d


static func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	# Phase1 빌드에는 save.json이 없었음 → 신규 기본값으로.
	d["version"] = 1
	d["meta"] = default_data()["meta"]
	return d


static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var m: Dictionary = d.get("meta", {})
	var ups: Dictionary = m.get("upgrades", {})
	ups["luck"] = ups.get("luck", 0)
	ups["choice_extra"] = ups.get("choice_extra", 0)
	m["upgrades"] = ups
	m["codex"] = m.get("codex", _default_codex())
	m["challenges"] = m.get("challenges", _default_challenges())
	d["meta"] = m
	d["version"] = 2
	return d


static func default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"saved_at": 0,
		"build": "0.2.0",
		"platform": _platform_tag(),
		"meta": {
			"version": CURRENT_VERSION,
			"saved_at": 0,
			"currency": {"dokkaebi_orbs": 0, "shinmok_leaves": 0, "myth_shards": 0},
			"shinmok": {"stage": 1},
			"upgrades": {
				"max_hp": 0, "attack": 0, "move_speed": 0,
				"xp_gain": 0, "gold_gain": 0,
				"revive": 0, "choice_extra": 0, "luck": 0,
			},
			"characters": {
				"unlocked": ["ttukttaki"],
				"affinity": {"ttukttaki": 0},
				"affinity_nodes": {"ttukttaki": []},
			},
			"codex": _default_codex(),
			"achievements": {},
			"challenges": _default_challenges(),
			"stats": _default_stats(),
		},
		"settings": {
			"bgm_volume": 0.8,
			"se_volume": 1.0,
			"language": "ko",
			"input_mode": "touch_or_keyboard",
			"screen_shake": 1.0,
		},
	}


static func _default_codex() -> Dictionary:
	return {"monsters": {}, "relics": {}, "places": {}}


static func _default_challenges() -> Dictionary:
	return {
		"daily_seed_day": -1, "daily_active": [], "daily_progress": {},
		"weekly_seed_week": -1, "weekly_active": [], "weekly_progress": {},
	}


static func _default_stats() -> Dictionary:
	return {
		"total_kills": 0, "total_bosses_defeated": 0, "total_runs": 0,
		"total_clears": 0, "total_deaths": 0, "total_gold_earned": 0,
		"play_time_seconds": 0.0,
	}


static func _platform_tag() -> String:
	return "web" if OS.has_feature("web") else "desktop"
