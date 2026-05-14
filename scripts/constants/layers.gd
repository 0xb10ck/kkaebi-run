class_name Layers
extends RefCounted

# 충돌 레이어 비트 (project.godot [layer_names] 와 일치)
# 1=player, 2=player_attack, 3=enemy, 4=exp_gem,
# 5=enemy_attack, 6=environment, 7=projectile_player, 8=projectile_enemy
const PLAYER: int = 1 << 0
const PLAYER_ATTACK: int = 1 << 1
const ENEMY: int = 1 << 2
const EXP_GEM: int = 1 << 3
const ENEMY_ATTACK: int = 1 << 4
const ENVIRONMENT: int = 1 << 5
const PROJECTILE_PLAYER: int = 1 << 6
const PROJECTILE_ENEMY: int = 1 << 7
