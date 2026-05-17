# Wire Enemies/Bosses Report

## Summary
- monster: total=57 added=53 updated=0 manual=4 skipped=0 new_ext_resources=53
- boss: total=23 added=22 updated=0 manual=1 skipped=0 new_ext_resources=22

## Constants
- monster cell: 32px
- boss cell: 64px
- monster hframes/vframes distribution: 10x1=53
- boss hframes/vframes distribution: 12x1=22

## Monster scenes
- `scenes/enemies/enemy_egg.tscn` -> **manual** (no asset for slug `egg`)
- `scenes/enemies/enemy_fire.tscn` -> **manual** (no asset for slug `fire`)
- `scenes/enemies/enemy_projectile.tscn` -> **manual** (no asset for slug `projectile`)
- `scenes/enemies/enemy_water.tscn` -> **manual** (no asset for slug `water`)
- `scenes/enemies/m01_dokkaebibul.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m01_dokkaebibul/m01_dokkaebibul.png` frames=10x1
- `scenes/enemies/m02_dalgyalgwisin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m02_dalgyalgwisin/m02_dalgyalgwisin.png` frames=10x1
- `scenes/enemies/m03_mulgwisin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m03_mulgwisin/m03_mulgwisin.png` frames=10x1
- `scenes/enemies/m04_eodukshini.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m04_eodukshini/m04_eodukshini.png` frames=10x1
- `scenes/enemies/m05_geuseundae.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m05_geuseundae/m05_geuseundae.png` frames=10x1
- `scenes/enemies/m06_bitjarugwisin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m06_bitjarugwisin/m06_bitjarugwisin.png` frames=10x1
- `scenes/enemies/m07_songakshi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m07_songakshi/m07_songakshi.png` frames=10x1
- `scenes/enemies/m08_mongdalgwisin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m08_mongdalgwisin/m08_mongdalgwisin.png` frames=10x1
- `scenes/enemies/m09_duduri.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m09_duduri/m09_duduri.png` frames=10x1
- `scenes/enemies/m10_samdugu.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m10_samdugu/m10_samdugu.png` frames=10x1
- `scenes/enemies/m11_horangi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m11_horangi/m11_horangi.png` frames=10x1
- `scenes/enemies/m12_metdwaeji.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m12_metdwaeji/m12_metdwaeji.png` frames=10x1
- `scenes/enemies/m13_neoguri.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m13_neoguri/m13_neoguri.png` frames=10x1
- `scenes/enemies/m14_dukkeobi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m14_dukkeobi/m14_dukkeobi.png` frames=10x1
- `scenes/enemies/m15_geomi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m15_geomi/m15_geomi.png` frames=10x1
- `scenes/enemies/m16_noru.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m16_noru/m16_noru.png` frames=10x1
- `scenes/enemies/m17_namu.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m17_namu/m17_namu.png` frames=10x1
- `scenes/enemies/m18_deonggul.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m18_deonggul/m18_deonggul.png` frames=10x1
- `scenes/enemies/m19_kamagwi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m19_kamagwi/m19_kamagwi.png` frames=10x1
- `scenes/enemies/m20_cheonyeo_gwisin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m20_cheonyeo_gwisin/m20_cheonyeo_gwisin.png` frames=10x1
- `scenes/enemies/m21_jeoseung_gae.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m21_jeoseung_gae/m21_jeoseung_gae.png` frames=10x1
- `scenes/enemies/m22_mangryang.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m22_mangryang/m22_mangryang.png` frames=10x1
- `scenes/enemies/m23_gangshi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m23_gangshi/m23_gangshi.png` frames=10x1
- `scenes/enemies/m24_yagwang_gwi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m24_yagwang_gwi/m24_yagwang_gwi.png` frames=10x1
- `scenes/enemies/m25_baekgol_gwi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m25_baekgol_gwi/m25_baekgol_gwi.png` frames=10x1
- `scenes/enemies/m26_gaeksahon.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m26_gaeksahon/m26_gaeksahon.png` frames=10x1
- `scenes/enemies/m27_saseul_gwi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m27_saseul_gwi/m27_saseul_gwi.png` frames=10x1
- `scenes/enemies/m28_dochaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m28_dochaebi/m28_dochaebi.png` frames=10x1
- `scenes/enemies/m29_chasahon.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m29_chasahon/m29_chasahon.png` frames=10x1
- `scenes/enemies/m30_bulgasari.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m30_bulgasari/m30_bulgasari.png` frames=10x1
- `scenes/enemies/m31_yacha.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m31_yacha/m31_yacha.png` frames=10x1
- `scenes/enemies/m32_nachal.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m32_nachal/m32_nachal.png` frames=10x1
- `scenes/enemies/m33_cheonnyeo.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m33_cheonnyeo/m33_cheonnyeo.png` frames=10x1
- `scenes/enemies/m34_noegong.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m34_noegong/m34_noegong.png` frames=10x1
- `scenes/enemies/m35_pungbaek.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m35_pungbaek/m35_pungbaek.png` frames=10x1
- `scenes/enemies/m36_usa.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m36_usa/m36_usa.png` frames=10x1
- `scenes/enemies/m37_hak.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m37_hak/m37_hak.png` frames=10x1
- `scenes/enemies/m38_gareungbinga.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m38_gareungbinga/m38_gareungbinga.png` frames=10x1
- `scenes/enemies/m39_cheonma.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m39_cheonma/m39_cheonma.png` frames=10x1
- `scenes/enemies/m40_heukpung.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m40_heukpung/m40_heukpung.png` frames=10x1
- `scenes/enemies/m41_bihyeongrang_grimja.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m41_bihyeongrang_grimja/m41_bihyeongrang_grimja.png` frames=10x1
- `scenes/enemies/m42_heukmusa.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m42_heukmusa/m42_heukmusa.png` frames=10x1
- `scenes/enemies/m43_yeonggwi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m43_yeonggwi/m43_yeonggwi.png` frames=10x1
- `scenes/enemies/m44_grimja_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m44_grimja_dokkaebi/m44_grimja_dokkaebi.png` frames=10x1
- `scenes/enemies/m45_ohyeomdoen_shinmok_gaji.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m45_ohyeomdoen_shinmok_gaji/m45_ohyeomdoen_shinmok_gaji.png` frames=10x1
- `scenes/enemies/m46_heukryong_saekki.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m46_heukryong_saekki/m46_heukryong_saekki.png` frames=10x1
- `scenes/enemies/m47_geomeun_angae_jamyeong.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m47_geomeun_angae_jamyeong/m47_geomeun_angae_jamyeong.png` frames=10x1
- `scenes/enemies/m48_sijang_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m48_sijang_dokkaebi/m48_sijang_dokkaebi.png` frames=10x1
- `scenes/enemies/m49_geokkuro_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m49_geokkuro_dokkaebi/m49_geokkuro_dokkaebi.png` frames=10x1
- `scenes/enemies/m50_noreumkkun.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m50_noreumkkun/m50_noreumkkun.png` frames=10x1
- `scenes/enemies/m51_sulchwihan.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m51_sulchwihan/m51_sulchwihan.png` frames=10x1
- `scenes/enemies/m52_byeonjang.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m52_byeonjang/m52_byeonjang.png` frames=10x1
- `scenes/enemies/m53_ssireum.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/monsters/m53_ssireum/m53_ssireum.png` frames=10x1

## Boss scenes
- `scenes/bosses/b01_dokkaebibul_daejang.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b01_dokkaebibul_daejang/b01_dokkaebibul_daejang.png` frames=12x1
- `scenes/bosses/b02_gumiho.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b02_gumiho/b02_gumiho.png` frames=12x1
- `scenes/bosses/b03_jeoseung_saja.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b03_jeoseung_saja/b03_jeoseung_saja.png` frames=12x1
- `scenes/bosses/b04_cheondung_janggun.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b04_cheondung_janggun/b04_cheondung_janggun.png` frames=12x1
- `scenes/bosses/b05_heuk_ryong.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b05_heuk_ryong/b05_heuk_ryong.png` frames=12x1
- `scenes/bosses/b06_daewang_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b06_daewang_dokkaebi/b06_daewang_dokkaebi.png` frames=12x1
- `scenes/bosses/boss_arena.tscn` -> **manual** (no asset for slug `arena`)
- `scenes/bosses/boss_chagwishin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb03_chagwishin/mb03_chagwishin.png` frames=12x1
- `scenes/bosses/boss_cheondung_janggun.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b04_cheondung_janggun/b04_cheondung_janggun.png` frames=12x1
- `scenes/bosses/boss_daewang_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b06_daewang_dokkaebi/b06_daewang_dokkaebi.png` frames=12x1
- `scenes/bosses/boss_dokkaebibul_daejang.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b01_dokkaebibul_daejang/b01_dokkaebibul_daejang.png` frames=12x1
- `scenes/bosses/boss_geomeun_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb05_geomeun_dokkaebi/mb05_geomeun_dokkaebi.png` frames=12x1
- `scenes/bosses/boss_geumdwaeji.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb04_geumdwaeji/mb04_geumdwaeji.png` frames=12x1
- `scenes/bosses/boss_gumiho.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b02_gumiho/b02_gumiho.png` frames=12x1
- `scenes/bosses/boss_heuk_ryong.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b05_heuk_ryong/b05_heuk_ryong.png` frames=12x1
- `scenes/bosses/boss_imugi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb02_imugi/mb02_imugi.png` frames=12x1
- `scenes/bosses/boss_jangsanbeom.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb01_jangsanbeom/mb01_jangsanbeom.png` frames=12x1
- `scenes/bosses/boss_jeoseung_saja.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/b03_jeoseung_saja/b03_jeoseung_saja.png` frames=12x1
- `scenes/bosses/mb01_jangsanbeom.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb01_jangsanbeom/mb01_jangsanbeom.png` frames=12x1
- `scenes/bosses/mb02_imugi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb02_imugi/mb02_imugi.png` frames=12x1
- `scenes/bosses/mb03_chagwishin.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb03_chagwishin/mb03_chagwishin.png` frames=12x1
- `scenes/bosses/mb04_geumdwaeji.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb04_geumdwaeji/mb04_geumdwaeji.png` frames=12x1
- `scenes/bosses/mb05_geomeun_dokkaebi.tscn` -> **added** Sprite2D name=`Sprite` texture=`assets/sprites/bosses/mb05_geomeun_dokkaebi/mb05_geomeun_dokkaebi.png` frames=12x1

## Missing monster assets (4)
- scenes/enemies/enemy_egg.tscn
- scenes/enemies/enemy_fire.tscn
- scenes/enemies/enemy_projectile.tscn
- scenes/enemies/enemy_water.tscn

## Missing boss assets (1)
- scenes/bosses/boss_arena.tscn

