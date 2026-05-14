class_name CutsceneRegistry
extends RefCounted

# §5.3 — 보스 컷인 인스턴스화 헬퍼. 자동로드 아님 — 정적 함수.

const _PATHS: Dictionary = {
	# id (StringName) -> PackedScene 경로. 풀 데이터 도입 후 채워진다.
}


static func spawn(_id: StringName) -> Node:
	# .tres에 intro_cutscene_id가 비어 있거나 등록 전이면 null 반환 → BossBase가 즉시 idle 전환.
	if not _PATHS.has(_id):
		return null
	var scene: PackedScene = load(String(_PATHS[_id]))
	if scene == null:
		return null
	return scene.instantiate()
