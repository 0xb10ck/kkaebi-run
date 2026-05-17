# Wire Report

## QA Regression Summary (t2)

- Godot:            `4.6.2.stable.official.71f334935` (`/Applications/Godot.app/Contents/MacOS/Godot`)
- QA cycles run:    1
- Final result:     **PASS 12 / FAIL 0** (no regression vs baseline)
- Auto-reverted:    _none — wire.py produced 0 scene mutations in t1, so there was nothing to roll back_
- New ext_resource: 0 across 0 changed scenes (Nodes wired: 0)
- Outstanding:      _none in this scope_ (no novel errors detected; outstanding.md not emitted)

Per-module results (cycle 1):

| module | result | errors |
|---|---|---|
| load_gd | PASS | 0 |
| load_tscn | PASS | 0 |
| load_tres | PASS | 0 |
| autoloads | PASS | 0 |
| chapter | PASS | 0 |
| boss | PASS | 0 |
| skill | PASS | 0 |
| character | PASS | 0 |
| env_event | PASS | 0 |
| ui | PASS | 0 |
| meta | PASS | 0 |
| integration | PASS | 0 |

Note: because the prior wire pass in t1 changed no `.tscn` files (every wirable target was either absent or already wired — see Manual / missing list below), the rollback / wire-rule-narrowing / re-run loop short-circuited at cycle 1. No retries were necessary.

---

## Wiring Statistics (t1 carry-over)

- Scenes inspected:    0
- Scenes changed:      0
- Nodes wired:         0
- New ext_resource:    0
- Manual / missing:    115

## Changed scenes

_none — every node either lacked a wirable target or was already wired._

## Manual / missing items

| kind | scene | node | asset | action | note |
|---|---|---|---|---|---|
| character | `—` | `—` | `res://assets/sprites/characters/barami/barami.png` | `missing_scene` | no character scene for barami |
| character | `—` | `—` | `res://assets/sprites/characters/byeolee/byeolee.png` | `missing_scene` | no character scene for byeolee |
| character | `—` | `—` | `res://assets/sprites/characters/dolsoe/dolsoe.png` | `missing_scene` | no character scene for dolsoe |
| character | `—` | `—` | `res://assets/sprites/characters/geurimja/geurimja.png` | `missing_scene` | no character scene for geurimja |
| character | `—` | `—` | `res://assets/sprites/characters/hwalee/hwalee.png` | `missing_scene` | no character scene for hwalee |
| character | `—` | `—` | `res://assets/sprites/characters/ttukttaki/ttukttaki.png` | `missing_scene` | no character scene for ttukttaki |
| monster | `res://scenes/enemies/m01_dokkaebibul.tscn` | `—` | `res://assets/sprites/monsters/m01_dokkaebibul/m01_dokkaebibul.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m02_dalgyalgwisin.tscn` | `—` | `res://assets/sprites/monsters/m02_dalgyalgwisin/m02_dalgyalgwisin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m03_mulgwisin.tscn` | `—` | `res://assets/sprites/monsters/m03_mulgwisin/m03_mulgwisin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m04_eodukshini.tscn` | `—` | `res://assets/sprites/monsters/m04_eodukshini/m04_eodukshini.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m05_geuseundae.tscn` | `—` | `res://assets/sprites/monsters/m05_geuseundae/m05_geuseundae.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m06_bitjarugwisin.tscn` | `—` | `res://assets/sprites/monsters/m06_bitjarugwisin/m06_bitjarugwisin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m07_songakshi.tscn` | `—` | `res://assets/sprites/monsters/m07_songakshi/m07_songakshi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m08_mongdalgwisin.tscn` | `—` | `res://assets/sprites/monsters/m08_mongdalgwisin/m08_mongdalgwisin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m09_duduri.tscn` | `—` | `res://assets/sprites/monsters/m09_duduri/m09_duduri.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m10_samdugu.tscn` | `—` | `res://assets/sprites/monsters/m10_samdugu/m10_samdugu.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m11_horangi.tscn` | `—` | `res://assets/sprites/monsters/m11_horangi/m11_horangi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m12_metdwaeji.tscn` | `—` | `res://assets/sprites/monsters/m12_metdwaeji/m12_metdwaeji.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m13_neoguri.tscn` | `—` | `res://assets/sprites/monsters/m13_neoguri/m13_neoguri.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m14_dukkeobi.tscn` | `—` | `res://assets/sprites/monsters/m14_dukkeobi/m14_dukkeobi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m15_geomi.tscn` | `—` | `res://assets/sprites/monsters/m15_geomi/m15_geomi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m16_noru.tscn` | `—` | `res://assets/sprites/monsters/m16_noru/m16_noru.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m17_namu.tscn` | `—` | `res://assets/sprites/monsters/m17_namu/m17_namu.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m18_deonggul.tscn` | `—` | `res://assets/sprites/monsters/m18_deonggul/m18_deonggul.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m19_kamagwi.tscn` | `—` | `res://assets/sprites/monsters/m19_kamagwi/m19_kamagwi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m20_cheonyeo_gwisin.tscn` | `—` | `res://assets/sprites/monsters/m20_cheonyeo_gwisin/m20_cheonyeo_gwisin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m21_jeoseung_gae.tscn` | `—` | `res://assets/sprites/monsters/m21_jeoseung_gae/m21_jeoseung_gae.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m22_mangryang.tscn` | `—` | `res://assets/sprites/monsters/m22_mangryang/m22_mangryang.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m23_gangshi.tscn` | `—` | `res://assets/sprites/monsters/m23_gangshi/m23_gangshi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m24_yagwang_gwi.tscn` | `—` | `res://assets/sprites/monsters/m24_yagwang_gwi/m24_yagwang_gwi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m25_baekgol_gwi.tscn` | `—` | `res://assets/sprites/monsters/m25_baekgol_gwi/m25_baekgol_gwi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m26_gaeksahon.tscn` | `—` | `res://assets/sprites/monsters/m26_gaeksahon/m26_gaeksahon.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m27_saseul_gwi.tscn` | `—` | `res://assets/sprites/monsters/m27_saseul_gwi/m27_saseul_gwi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m28_dochaebi.tscn` | `—` | `res://assets/sprites/monsters/m28_dochaebi/m28_dochaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m29_chasahon.tscn` | `—` | `res://assets/sprites/monsters/m29_chasahon/m29_chasahon.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m30_bulgasari.tscn` | `—` | `res://assets/sprites/monsters/m30_bulgasari/m30_bulgasari.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m31_yacha.tscn` | `—` | `res://assets/sprites/monsters/m31_yacha/m31_yacha.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m32_nachal.tscn` | `—` | `res://assets/sprites/monsters/m32_nachal/m32_nachal.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m33_cheonnyeo.tscn` | `—` | `res://assets/sprites/monsters/m33_cheonnyeo/m33_cheonnyeo.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m34_noegong.tscn` | `—` | `res://assets/sprites/monsters/m34_noegong/m34_noegong.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m35_pungbaek.tscn` | `—` | `res://assets/sprites/monsters/m35_pungbaek/m35_pungbaek.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m36_usa.tscn` | `—` | `res://assets/sprites/monsters/m36_usa/m36_usa.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m37_hak.tscn` | `—` | `res://assets/sprites/monsters/m37_hak/m37_hak.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m38_gareungbinga.tscn` | `—` | `res://assets/sprites/monsters/m38_gareungbinga/m38_gareungbinga.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m39_cheonma.tscn` | `—` | `res://assets/sprites/monsters/m39_cheonma/m39_cheonma.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m40_heukpung.tscn` | `—` | `res://assets/sprites/monsters/m40_heukpung/m40_heukpung.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m41_bihyeongrang_grimja.tscn` | `—` | `res://assets/sprites/monsters/m41_bihyeongrang_grimja/m41_bihyeongrang_grimja.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m42_heukmusa.tscn` | `—` | `res://assets/sprites/monsters/m42_heukmusa/m42_heukmusa.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m43_yeonggwi.tscn` | `—` | `res://assets/sprites/monsters/m43_yeonggwi/m43_yeonggwi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m44_grimja_dokkaebi.tscn` | `—` | `res://assets/sprites/monsters/m44_grimja_dokkaebi/m44_grimja_dokkaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m45_ohyeomdoen_shinmok_gaji.tscn` | `—` | `res://assets/sprites/monsters/m45_ohyeomdoen_shinmok_gaji/m45_ohyeomdoen_shinmok_gaji.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m46_heukryong_saekki.tscn` | `—` | `res://assets/sprites/monsters/m46_heukryong_saekki/m46_heukryong_saekki.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m47_geomeun_angae_jamyeong.tscn` | `—` | `res://assets/sprites/monsters/m47_geomeun_angae_jamyeong/m47_geomeun_angae_jamyeong.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m48_sijang_dokkaebi.tscn` | `—` | `res://assets/sprites/monsters/m48_sijang_dokkaebi/m48_sijang_dokkaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m49_geokkuro_dokkaebi.tscn` | `—` | `res://assets/sprites/monsters/m49_geokkuro_dokkaebi/m49_geokkuro_dokkaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m50_noreumkkun.tscn` | `—` | `res://assets/sprites/monsters/m50_noreumkkun/m50_noreumkkun.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m51_sulchwihan.tscn` | `—` | `res://assets/sprites/monsters/m51_sulchwihan/m51_sulchwihan.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m52_byeonjang.tscn` | `—` | `res://assets/sprites/monsters/m52_byeonjang/m52_byeonjang.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| monster | `res://scenes/enemies/m53_ssireum.tscn` | `—` | `res://assets/sprites/monsters/m53_ssireum/m53_ssireum.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b01_dokkaebibul_daejang.tscn` | `—` | `res://assets/sprites/bosses/b01_dokkaebibul_daejang/b01_dokkaebibul_daejang.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b02_gumiho.tscn` | `—` | `res://assets/sprites/bosses/b02_gumiho/b02_gumiho.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b03_jeoseung_saja.tscn` | `—` | `res://assets/sprites/bosses/b03_jeoseung_saja/b03_jeoseung_saja.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b04_cheondung_janggun.tscn` | `—` | `res://assets/sprites/bosses/b04_cheondung_janggun/b04_cheondung_janggun.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b05_heuk_ryong.tscn` | `—` | `res://assets/sprites/bosses/b05_heuk_ryong/b05_heuk_ryong.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/b06_daewang_dokkaebi.tscn` | `—` | `res://assets/sprites/bosses/b06_daewang_dokkaebi/b06_daewang_dokkaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/mb01_jangsanbeom.tscn` | `—` | `res://assets/sprites/bosses/mb01_jangsanbeom/mb01_jangsanbeom.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/mb02_imugi.tscn` | `—` | `res://assets/sprites/bosses/mb02_imugi/mb02_imugi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/mb03_chagwishin.tscn` | `—` | `res://assets/sprites/bosses/mb03_chagwishin/mb03_chagwishin.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/mb04_geumdwaeji.tscn` | `—` | `res://assets/sprites/bosses/mb04_geumdwaeji/mb04_geumdwaeji.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| boss | `res://scenes/bosses/mb05_geomeun_dokkaebi.tscn` | `—` | `res://assets/sprites/bosses/mb05_geomeun_dokkaebi/mb05_geomeun_dokkaebi.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/dagger_storm.tscn` | `—` | `res://assets/sprites/effects/dagger_storm/dagger_storm.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/dagger_throw.tscn` | `—` | `res://assets/sprites/effects/dagger_throw/dagger_throw.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/dragon_king_wrath.tscn` | `—` | `res://assets/sprites/effects/dragon_king_wrath/dragon_king_wrath.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/dragon_palace_wave.tscn` | `—` | `res://assets/sprites/effects/dragon_palace_wave/dragon_palace_wave.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/earth_wall.tscn` | `—` | `res://assets/sprites/effects/earth_wall/earth_wall.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/earthquake.tscn` | `—` | `res://assets/sprites/effects/earthquake/earthquake.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/fire_orb.tscn` | `—` | `res://assets/sprites/effects/fire_orb/fire_orb.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/flame_barrier.tscn` | `—` | `res://assets/sprites/effects/flame_barrier/flame_barrier.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/flame_breath.tscn` | `—` | `res://assets/sprites/effects/flame_breath/flame_breath.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/flint_burst.tscn` | `—` | `res://assets/sprites/effects/flint_burst/flint_burst.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/forest_wrath.tscn` | `—` | `res://assets/sprites/effects/forest_wrath/forest_wrath.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/frost_ring.tscn` | `—` | `res://assets/sprites/effects/frost_ring/frost_ring.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/geumgang_bulgwe.tscn` | `—` | `res://assets/sprites/effects/geumgang_bulgwe/geumgang_bulgwe.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/gold_shield.tscn` | `—` | `res://assets/sprites/effects/gold_shield/gold_shield.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/ice_age.tscn` | `—` | `res://assets/sprites/effects/ice_age/ice_age.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/landslide.tscn` | `—` | `res://assets/sprites/effects/landslide/landslide.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/metal_chain.tscn` | `—` | `res://assets/sprites/effects/metal_chain/metal_chain.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/mist_veil.tscn` | `—` | `res://assets/sprites/effects/mist_veil/mist_veil.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/phoenix_descent.tscn` | `—` | `res://assets/sprites/effects/phoenix_descent/phoenix_descent.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/rock_throw.tscn` | `—` | `res://assets/sprites/effects/rock_throw/rock_throw.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/samaejinhwa.tscn` | `—` | `res://assets/sprites/effects/samaejinhwa/samaejinhwa.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/sand_storm.tscn` | `—` | `res://assets/sprites/effects/sand_storm/sand_storm.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/seed_burst.tscn` | `—` | `res://assets/sprites/effects/seed_burst/seed_burst.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/sinmok_blessing.tscn` | `—` | `res://assets/sprites/effects/sinmok_blessing/sinmok_blessing.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/thorn_trap.tscn` | `—` | `res://assets/sprites/effects/thorn_trap/thorn_trap.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/thorn_vine.tscn` | `—` | `res://assets/sprites/effects/thorn_vine/thorn_vine.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/thousand_swords.tscn` | `—` | `res://assets/sprites/effects/thousand_swords/thousand_swords.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/vine_whip.tscn` | `—` | `res://assets/sprites/effects/vine_whip/vine_whip.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/water_drop.tscn` | `—` | `res://assets/sprites/effects/water_drop/water_drop.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| effect | `res://scenes/skills/world_tree_blessing.tscn` | `—` | `res://assets/sprites/effects/world_tree_blessing/world_tree_blessing.png` | `manual_add_node` | no Sprite2D/AnimatedSprite2D in scene |
| ui | `res://scenes/main_menu/main_menu.tscn` | `Background` | `res://assets/ui/main_menu_bg.png` | `manual_replace_node` | node Background is ColorRect, expected TextureRect |
| ui | `res://scenes/main_menu/main_menu.tscn` | `Logo` | `res://assets/ui/logo.png` | `manual_add_node` | node Logo not present in main_menu/main_menu.tscn |
| ui | `res://scenes/main_menu/main_menu.tscn` | `Buttons/StartButton` | `res://assets/ui/button_normal.png` | `manual_replace_node` | node Buttons/StartButton is Button, expected Button |
| ui | `res://scenes/main_menu/main_menu.tscn` | `Buttons/StartButton` | `res://assets/ui/button_hover.png` | `manual_replace_node` | node Buttons/StartButton is Button, expected Button |
| ui | `res://scenes/main_menu/main_menu.tscn` | `Buttons/StartButton` | `res://assets/ui/button_pressed.png` | `manual_replace_node` | node Buttons/StartButton is Button, expected Button |
| ui | `res://scenes/ui/pause_menu.tscn` | `Panel` | `res://assets/ui/panel_frame.png` | `manual_replace_node` | node Panel is Panel, expected NinePatchRect |
| ui | `res://scenes/ui/hud.tscn` | `HPBarFrame` | `res://assets/ui/hp_bar_frame.png` | `manual_add_node` | node HPBarFrame not present in ui/hud.tscn |
| ui | `res://scenes/ui/hud.tscn` | `HPBarFill` | `res://assets/ui/hp_bar_fill.png` | `manual_replace_node` | node HPBarFill is ColorRect, expected TextureRect |
| ui | `res://scenes/ui/hud.tscn` | `SkillIconFrame` | `res://assets/ui/skill_icon_frame.png` | `manual_add_node` | node SkillIconFrame not present in ui/hud.tscn |
| ui | `res://scenes/ui/level_up_panel.tscn` | `Background` | `res://assets/ui/level_up_bg.png` | `manual_replace_node` | node Background is ColorRect, expected TextureRect |
| tileset | `—` | `—` | `res://assets/tilesets/ch01_dumeong/ch01_dumeong_tiles.png` | `missing_scene` | no chapter run scene for ch01_dumeong |
| tileset | `—` | `—` | `res://assets/tilesets/ch02_sinryeong/ch02_sinryeong_tiles.png` | `missing_scene` | no chapter run scene for ch02_sinryeong |
| tileset | `—` | `—` | `res://assets/tilesets/ch03_hwangcheon/ch03_hwangcheon_tiles.png` | `missing_scene` | no chapter run scene for ch03_hwangcheon |
| tileset | `—` | `—` | `res://assets/tilesets/ch04_cheonsang/ch04_cheonsang_tiles.png` | `missing_scene` | no chapter run scene for ch04_cheonsang |
| tileset | `—` | `—` | `res://assets/tilesets/ch05_sinmok_heart/ch05_sinmok_heart_tiles.png` | `missing_scene` | no chapter run scene for ch05_sinmok_heart |

---

## Asset ↔ Scene Matching Summary (t3 final)

Tally derived from `tools/wire_assets/inventory.json` (115 records) cross-checked with t1 wire pass output (0 scenes mutated, 0 ext_resource added) and t2 QA result (12/12 PASS, no regression). The wire pass found no pre-wired matches either, so for this snapshot **connected = 0 / unconnected = 115** — i.e. every art asset is still waiting for a manual node-level connection in its scene.

### Connected vs unconnected (overall)

| status | count |
|---|---:|
| connected (auto-wired or pre-wired) | 0 |
| unconnected (manual follow-up required) | 115 |
| **total inventory** | **115** |

### Per-category breakdown

| category | connected | unconnected | total | dominant gap |
|---|---:|---:|---:|---|
| monster  | 0 | 53 | 53 | scene exists, needs `Sprite2D`/`AnimatedSprite2D` node (`manual_add_node`) |
| effect   | 0 | 30 | 30 | scene exists, needs sprite node (`manual_add_node`) |
| boss     | 0 | 11 | 11 | scene exists, needs sprite node (`manual_add_node`) |
| ui       | 0 | 10 | 10 | 7× wrong node type (`manual_replace_node`), 3× missing node (`manual_add_node`) |
| character| 0 | 6  | 6  | no character scene yet (`missing_scene`) |
| tileset  | 0 | 5  | 5  | no chapter run scene yet (`missing_scene`) |
| **TOTAL**| **0** | **115** | **115** | — |

### Unconnected — by suggested action

| action | count | meaning |
|---|---:|---|
| `manual_add_node` | 97 | scene file exists, but no sprite/texture node to bind the art to |
| `manual_replace_node` | 7 | node exists but has the wrong type (e.g. `ColorRect` where `TextureRect` is required) |
| `missing_scene` | 11 | no target scene at all (6 characters + 5 chapter run scenes) |

### Why connected = 0

- t1's `wire.py` is intentionally conservative: it only wires when it can locate an existing `Sprite2D`/`AnimatedSprite2D`/`TextureRect`/`NinePatchRect` of the correct type whose name follows the convention. Every current target failed that pre-check, so it wired nothing and mutated no `.tscn`.
- This is deliberate — it keeps t2's QA regression count at 0 and leaves all art binding work as an explicit, reviewable manual list rather than a silent, possibly-wrong auto-edit.

### Recommended next step (out of t3 scope)

1. Add a `scaffold_nodes.py` companion tool that, *only* when explicitly invoked, inserts the missing `Sprite2D`/`TextureRect`/`NinePatchRect` nodes referenced under `manual_add_node`/`manual_replace_node` above — keeping a backup + headless-QA gate identical to t1/t2.
2. Author the 11 missing scenes (6 character scenes + 5 chapter run scenes) and re-run `inventory.py` → `wire.py` → QA loop; expect the connected count to climb directly from those re-runs.
