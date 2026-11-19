# Fuzzy art audit (tools/fuzz_audit.py)

Ranked to-do of blurry/low-quality art: worst first per group, buildings first.
fuzz 0..100 (higher = fuzzier): soft alpha rim, little pixel detail under a 2x
shrink, mushy neighbour steps, painterly colour counts. Re-run after every fix:
`python3 tools/fuzz_audit.py` (rewrites this file).

How to fix an entry: re-render with the image tool (edit_image, old art as reference,
same footprint, crisp 16-bit pixel art, magenta bg) and slice in place (rm first), or
for mild cases run it through `tools/crispen.py` (see tools/slice_r13_c2_p7.py).
Code side: sprites placed with GameMap.building() and mine rocks use the
sharp-pixel material (`CrispArt`, shaders/sharp_pixel.gdshader) so phone-size
magnification of 2x-detail art stays crisp instead of bilinear-soft.

| group | images | fuzz >= 55 | worst |
|---|---|---|---|
| buildings | 114 | 1 | 59.0 |
| props | 2134 | 62 | 80.2 |
| nature | 241 | 0 | 50.0 |
| furniture | 805 | 3 | 63.3 |
| stations | 32 | 5 | 81.2 |
| enemies | 238 | 2 | 56.5 |
| characters | 2823 | 273 | 72.2 |
| animals | 430 | 45 | 72.2 |
| wildlife | 94 | 12 | 65.3 |
| tiles | 3676 | 125 | 85.0 |
| cliffs | 51 | 0 | 49.4 |
| ui | 1302 | 21 | 91.2 |
| items | 2419 | 30 | 70.5 |
| animals_ref | 14 | 0 | 38.2 |
| battle | 34 | 0 | 38.1 |
| body | 130 | 48 | 75.5 |
| crops | 858 | 30 | 73.6 |
| edges | 80 | 0 | 52.1 |
| emotes | 25 | 0 | 31.8 |
| faces | 16 | 0 | 43.3 |
| fx | 406 | 51 | 94.5 |
| hair | 24 | 2 | 68.5 |
| hats | 16 | 0 | 46.7 |
| hats_poses | 8 | 0 | 34.5 |
| helpers | 80 | 0 | 47.9 |
| icons_hair | 24 | 0 | 50.4 |
| mounts | 8 | 0 | 48.1 |
| portraits | 1159 | 360 | 76.1 |
| riding | 8 | 0 | 44.2 |
| stairs | 8 | 0 | 47.4 |
| toolanim | 64 | 2 | 56.8 |
| wear | 336 | 0 | 45.6 |

## buildings

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 59.0 | buildings/hq_1.png | 172x90 | 1.09 | 0.283 | 0.376 | 95.1 |
| 54.3 | buildings/hq_2.png | 181x158 | 1.15 | 0.324 | 0.403 | 92.3 |
| 54.3 | buildings/ward_3.png | 211x197 | 1.27 | 0.319 | 0.412 | 98.2 |
| 54.0 | buildings/hq_3.png | 194x158 | 1.14 | 0.325 | 0.407 | 94.1 |
| 53.6 | buildings/ward_1.png | 194x117 | 1.25 | 0.321 | 0.426 | 97.3 |
| 53.1 | buildings/ward_5.png | 202x186 | 1.4 | 0.322 | 0.434 | 98.5 |
| 51.2 | buildings/ward_4.png | 198x174 | 1.3 | 0.336 | 0.451 | 98.6 |
| 51.0 | buildings/hq_4.png | 204x124 | 1.2 | 0.344 | 0.44 | 95.5 |
| 50.9 | buildings/ward_6.png | 210x191 | 1.37 | 0.34 | 0.453 | 98.5 |
| 50.4 | buildings/hq_5.png | 215x157 | 1.19 | 0.361 | 0.441 | 95.0 |
| 50.1 | buildings/ward_2.png | 215x125 | 1.22 | 0.351 | 0.449 | 98.3 |
| 50.0 | buildings/hq_6.png | 210x181 | 1.15 | 0.368 | 0.462 | 95.0 |
| 31.6 | buildings/fence_post.png | 16x32 | 0.0 | 0.249 | 0.273 | 97.2 |
| 30.6 | buildings/lighthouse.png | 592x224 | 0.0 | 0.242 | 0.307 | 80.8 |
| 28.9 | buildings/gang_shop_mama_rosa_closed.png | 176x192 | 0.0 | 0.255 | 0.32 | 93.2 |
| 27.3 | buildings/gang_shop_deuce.png | 170x192 | 0.0 | 0.268 | 0.332 | 95.3 |
| 27.1 | buildings/moon_spire_big.png | 240x396 | 0.0 | 0.266 | 0.341 | 87.7 |
| 26.5 | buildings/gang_shop_halo.png | 168x192 | 0.0 | 0.281 | 0.325 | 89.0 |
| 26.3 | buildings/lighthouse_rust.png | 56x126 | 0.0 | 0.275 | 0.339 | 98.5 |
| 25.1 | buildings/galleon.png | 448x134 | 0.0 | 0.28 | 0.357 | 92.7 |
| 24.8 | buildings/gang_shop_mama_rosa.png | 151x192 | 0.0 | 0.289 | 0.346 | 96.5 |
| 24.3 | buildings/windmill2.png | 428x160 | 0.0 | 0.283 | 0.371 | 93.4 |
| 24.3 | buildings/fence_h.png | 32x23 | 0.0 | 0.286 | 0.366 | 96.4 |
| 23.8 | buildings/store_night.png | 192x163 | 0.0 | 0.292 | 0.364 | 89.3 |
| 23.8 | buildings/gang_shop_doc.png | 159x192 | 0.0 | 0.31 | 0.328 | 93.4 |
| 22.9 | buildings/great_tree.png | 280x508 | 0.0 | 0.29 | 0.387 | 76.5 |
| 22.6 | buildings/water_mill.png | 652x200 | 0.0 | 0.297 | 0.382 | 91.4 |
| 22.5 | buildings/fountain.png | 96x78 | 0.0 | 0.29 | 0.397 | 99.2 |
| 22.5 | buildings/gang_shop_specs.png | 155x192 | 0.0 | 0.312 | 0.353 | 94.0 |
| 21.9 | buildings/lighthouse_broken.png | 148x224 | 0.0 | 0.295 | 0.399 | 93.8 |
| 21.7 | buildings/gang_shop_specs_closed.png | 155x192 | 0.0 | 0.315 | 0.367 | 90.5 |
| 20.6 | buildings/gang_shop_deuce_closed.png | 173x192 | 0.0 | 0.321 | 0.38 | 86.8 |
| 20.5 | buildings/beach_hut.png | 144x117 | 0.0 | 0.316 | 0.391 | 96.3 |
| 20.1 | buildings/smith_night.png | 192x162 | 0.0 | 0.319 | 0.395 | 89.1 |
| 19.9 | buildings/hall_night.png | 238x216 | 0.0 | 0.326 | 0.386 | 91.3 |
| 19.8 | buildings/gang_shop_doc_closed.png | 158x192 | 0.0 | 0.335 | 0.371 | 87.5 |
| 19.3 | buildings/house_3_night.png | 386x201 | 0.0 | 0.331 | 0.388 | 91.1 |
| 19.2 | buildings/gang_shop_halo_closed.png | 168x192 | 0.0 | 0.335 | 0.386 | 80.7 |
| 19.1 | buildings/grain_elevator.png | 192x290 | 0.0 | 0.328 | 0.401 | 90.5 |
| 19.0 | buildings/mine_winch_house.png | 193x128 | 0.0 | 0.322 | 0.414 | 96.8 |

## props

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 80.2 | props/fest_fw_47.png | 114x134 | 0.48 | 0.093 | 0.103 | 86.5 |
| 71.3 | props/r_quarry_59.png | 80x64 | 1.11 | 0.157 | 0.144 | 24.7 |
| 70.1 | props/fest_fw_59.png | 100x103 | 0.35 | 0.108 | 0.139 | 65.9 |
| 69.5 | props/r_quarry_60.png | 76x74 | 1.28 | 0.171 | 0.157 | 24.4 |
| 69.0 | props/holo_table.png | 432x108 | 1.14 | 0.211 | 0.291 | 93.3 |
| 68.7 | props/r_quarry_56.png | 94x66 | 0.73 | 0.179 | 0.16 | 24.5 |
| 68.5 | props/fest_fw_61.png | 99x104 | 0.34 | 0.118 | 0.145 | 69.6 |
| 68.4 | props/r_quarry_57.png | 76x62 | 1.06 | 0.178 | 0.169 | 24.7 |
| 67.6 | props/bulb_on.png | 28x41 | 1.82 | 0.22 | 0.305 | 98.2 |
| 66.8 | props/r_highlands_28.png | 86x44 | 0.65 | 0.197 | 0.17 | 25.0 |
| 66.6 | props/teleporter2.png | 432x68 | 0.81 | 0.233 | 0.302 | 92.2 |
| 65.5 | props/r_highlands_22.png | 122x64 | 0.67 | 0.204 | 0.181 | 24.2 |
| 63.9 | props/bulb_off.png | 28x41 | 1.96 | 0.247 | 0.336 | 89.9 |
| 63.1 | props/fest_ss_30.png | 145x116 | 0.7 | 0.277 | 0.295 | 96.3 |
| 63.0 | props/r_marsh_30.png | 42x50 | 0.59 | 0.242 | 0.356 | 95.1 |
| 62.7 | props/r_highlands_24.png | 56x32 | 0.55 | 0.209 | 0.171 | 25.0 |
| 62.5 | props/fest_fw_50.png | 109x101 | 0.23 | 0.114 | 0.137 | 71.4 |
| 62.5 | props/r_highlands_27.png | 60x34 | 0.65 | 0.231 | 0.201 | 25.2 |
| 62.2 | props/r_highlands_31.png | 164x86 | 0.63 | 0.237 | 0.192 | 24.3 |
| 61.1 | props/r_highlands_32.png | 138x86 | 0.59 | 0.242 | 0.195 | 24.2 |
| 61.1 | props/r_highlands_36.png | 118x86 | 0.61 | 0.245 | 0.203 | 24.4 |
| 60.7 | props/enchant_table.png | 328x73 | 1.08 | 0.282 | 0.34 | 97.2 |
| 60.6 | props/r_highlands_33.png | 114x84 | 0.6 | 0.25 | 0.204 | 24.2 |
| 60.6 | props/hot_spring.png | 336x110 | 0.62 | 0.271 | 0.364 | 91.7 |
| 60.5 | props/veh_crystal_sled_up.png | 54x77 | 1.18 | 0.294 | 0.323 | 97.9 |
| 60.4 | props/veh_balloon_lit.png | 83x143 | 1.24 | 0.28 | 0.35 | 96.3 |
| 60.3 | props/r_marsh_28.png | 40x63 | 0.6 | 0.271 | 0.366 | 97.9 |
| 60.3 | props/r_highlands_23.png | 68x38 | 0.64 | 0.253 | 0.208 | 24.9 |
| 60.2 | props/r_marsh_32.png | 38x70 | 0.54 | 0.247 | 0.339 | 96.8 |
| 60.1 | props/veh_balloon.png | 83x143 | 1.19 | 0.284 | 0.35 | 97.1 |
| 60.1 | props/fest_ss_55.png | 62x87 | 0.77 | 0.573 | 0.223 | 91.3 |
| 59.8 | props/saddle_crystal.png | 125x143 | 0.56 | 0.27 | 0.327 | 96.8 |
| 59.8 | props/stable_75.png | 125x143 | 0.56 | 0.27 | 0.327 | 96.8 |
| 59.6 | props/r_marsh_35.png | 45x53 | 0.67 | 0.301 | 0.328 | 98.0 |
| 59.3 | props/fest_fw_49.png | 100x101 | 0.2 | 0.123 | 0.148 | 78.2 |
| 59.3 | props/r_highlands_35.png | 106x88 | 0.68 | 0.262 | 0.213 | 24.7 |
| 59.2 | props/fest_ss_20.png | 147x108 | 1.16 | 0.282 | 0.374 | 94.3 |
| 58.5 | props/veh_crystal_sled_down.png | 49x78 | 1.14 | 0.31 | 0.335 | 98.5 |
| 58.4 | props/st_pool_3.png | 227x93 | 1.2 | 0.292 | 0.373 | 96.8 |
| 58.2 | props/r_marsh_37.png | 37x63 | 0.61 | 0.302 | 0.359 | 99.0 |

## nature

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 50.0 | nature/sunflowers.png | 30x32 | 1.95 | 0.373 | 0.504 | 99.8 |
| 45.7 | nature/grass_tuft_frost.png | 120x94 | 0.4 | 0.281 | 0.412 | 97.9 |
| 41.9 | nature/ftree_plum_snow.png | 117x128 | 0.0 | 0.158 | 0.216 | 91.1 |
| 40.8 | nature/ftree_apple_snow.png | 113x128 | 0.0 | 0.166 | 0.225 | 92.1 |
| 40.5 | nature/pine_snow.png | 80x128 | 0.0 | 0.164 | 0.235 | 89.0 |
| 40.2 | nature/ftree_orange_snow.png | 117x128 | 0.0 | 0.171 | 0.228 | 93.6 |
| 39.6 | nature/oak_autumn.png | 88x128 | 0.0 | 0.173 | 0.24 | 81.7 |
| 37.7 | nature/oak.png | 89x128 | 0.0 | 0.19 | 0.247 | 90.0 |
| 37.5 | nature/grass_tuft_winter.png | 116x89 | 0.34 | 0.327 | 0.441 | 98.7 |
| 37.3 | nature/stump_snow.png | 36x34 | 0.0 | 0.19 | 0.258 | 94.8 |
| 37.0 | nature/tree_bare.png | 89x128 | 0.0 | 0.188 | 0.266 | 92.1 |
| 35.9 | nature/tree_bare_s.png | 56x89 | 0.0 | 0.193 | 0.285 | 95.4 |
| 35.1 | nature/rock_snow_l.png | 60x49 | 0.0 | 0.209 | 0.269 | 88.6 |
| 35.1 | nature/cloud_tree_b.png | 76x112 | 0.0 | 0.212 | 0.265 | 84.0 |
| 34.8 | nature/tree_red.png | 96x128 | 0.0 | 0.206 | 0.283 | 95.5 |
| 34.5 | nature/log_bench.png | 76x40 | 0.0 | 0.226 | 0.249 | 96.5 |
| 34.3 | nature/grass_tuft_fall.png | 108x84 | 0.3 | 0.331 | 0.458 | 98.8 |
| 34.3 | nature/rock_m.png | 48x39 | 0.0 | 0.214 | 0.278 | 90.1 |
| 33.7 | nature/ftree_plum_late.png | 114x128 | 0.0 | 0.212 | 0.295 | 98.3 |
| 33.2 | nature/ftree_plum_blossom.png | 113x128 | 0.0 | 0.222 | 0.289 | 97.5 |
| 32.7 | nature/pine.png | 80x130 | 0.0 | 0.216 | 0.308 | 89.7 |
| 32.6 | nature/tree_orange.png | 96x119 | 0.0 | 0.225 | 0.295 | 92.9 |
| 32.4 | nature/rock_l.png | 60x50 | 0.0 | 0.217 | 0.314 | 94.0 |
| 32.2 | nature/cloud_tree_c.png | 77x112 | 0.0 | 0.238 | 0.28 | 86.0 |
| 31.8 | nature/rock_snow_m.png | 48x40 | 0.0 | 0.232 | 0.299 | 91.5 |
| 31.4 | nature/stump_fall.png | 32x36 | 0.0 | 0.241 | 0.29 | 98.1 |
| 31.3 | nature/ftree_cherry_fall.png | 113x128 | 0.0 | 0.234 | 0.308 | 97.4 |
| 30.9 | nature/pine_snow_s.png | 56x87 | 0.0 | 0.235 | 0.315 | 93.3 |
| 30.8 | nature/orange_tree.png | 79x100 | 0.0 | 0.236 | 0.315 | 98.8 |
| 30.5 | nature/rock_snow_s.png | 28x24 | 0.0 | 0.244 | 0.305 | 95.3 |
| 30.4 | nature/rock_s.png | 28x22 | 0.0 | 0.23 | 0.334 | 97.8 |
| 30.4 | nature/big_snowpine_a.png | 64x128 | 0.0 | 0.239 | 0.318 | 90.7 |
| 30.4 | nature/apple_tree.png | 80x94 | 0.0 | 0.233 | 0.33 | 98.9 |
| 30.0 | nature/stump.png | 36x31 | 0.0 | 0.236 | 0.334 | 97.8 |
| 29.9 | nature/cloud_tree_a.png | 64x81 | 0.0 | 0.255 | 0.297 | 87.4 |
| 29.6 | nature/ftree_plum_shake.png | 508x128 | 0.0 | 0.241 | 0.332 | 96.2 |
| 29.6 | nature/ftree_apple_fruit.png | 110x128 | 0.0 | 0.242 | 0.329 | 98.4 |
| 29.5 | nature/berry_bush_snow.png | 40x39 | 0.0 | 0.239 | 0.337 | 95.5 |
| 29.4 | nature/big_snowpine_b.png | 64x128 | 0.0 | 0.247 | 0.325 | 92.2 |
| 29.3 | nature/ftree_orange_shake.png | 492x128 | 0.0 | 0.241 | 0.338 | 95.2 |

## furniture

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 63.3 | furniture/int_quarry_22.png | 104x155 | 0.52 | 0.225 | 0.282 | 93.5 |
| 56.4 | furniture/crystal_ball.png | 168x50 | 1.31 | 0.302 | 0.398 | 92.9 |
| 55.8 | furniture/int_quarry_14.png | 85x133 | 0.31 | 0.194 | 0.233 | 92.9 |
| 50.0 | furniture/bakery_oven.png | 164x47 | 0.85 | 0.408 | 0.506 | 96.3 |
| 49.9 | furniture/wall_plaster_face_1.png | 54x68 | 0.0 | 0.112 | 0.124 | 64.2 |
| 49.7 | furniture/wall_plaster_face_0.png | 54x68 | 0.0 | 0.114 | 0.126 | 64.5 |
| 49.1 | furniture/wall_plaster_face_2.png | 54x68 | 0.0 | 0.118 | 0.129 | 66.7 |
| 49.0 | furniture/counter_granite.png | 375x204 | 0.19 | 0.192 | 0.242 | 84.1 |
| 48.7 | furniture/walltop_plaster_back.png | 37x29 | 0.0 | 0.117 | 0.117 | 55.7 |
| 48.5 | furniture/int_quarry_13.png | 81x126 | 0.27 | 0.232 | 0.286 | 93.1 |
| 48.2 | furniture/walltop_plaster_front.png | 53x36 | 0.0 | 0.128 | 0.132 | 69.6 |
| 48.0 | furniture/walltop_plaster_br.png | 53x36 | 0.0 | 0.126 | 0.14 | 79.3 |
| 47.6 | furniture/walltop_plaster_bl.png | 53x36 | 0.0 | 0.126 | 0.148 | 80.0 |
| 47.2 | furniture/walltop_plaster_tl.png | 51x36 | 0.0 | 0.141 | 0.128 | 76.1 |
| 46.9 | furniture/int_school_02.png | 105x139 | 0.0 | 0.129 | 0.159 | 70.5 |
| 46.6 | furniture/crystal_cage.png | 420x155 | 0.32 | 0.259 | 0.334 | 92.0 |
| 46.1 | furniture/walltop_plaster_right.png | 53x36 | 0.0 | 0.159 | 0.118 | 70.2 |
| 46.1 | furniture/wall_plaster_corner_0.png | 62x72 | 0.0 | 0.132 | 0.171 | 72.7 |
| 45.8 | furniture/walltop_plaster_left.png | 54x37 | 0.0 | 0.15 | 0.126 | 57.0 |
| 45.5 | furniture/int_school_01.png | 462x129 | 0.0 | 0.117 | 0.126 | 44.5 |
| 45.5 | furniture/ore_case.png | 314x228 | 0.2 | 0.222 | 0.278 | 82.7 |
| 45.5 | furniture/int_quarry_09.png | 314x228 | 0.2 | 0.222 | 0.278 | 82.7 |
| 45.0 | furniture/counter_sel.png | 376x201 | 0.19 | 0.221 | 0.268 | 89.1 |
| 44.8 | furniture/int_quarry_21.png | 105x155 | 0.32 | 0.278 | 0.344 | 96.1 |
| 44.6 | furniture/int_quarry_20.png | 104x155 | 0.35 | 0.289 | 0.367 | 97.0 |
| 44.2 | furniture/poster_frame.png | 194x214 | 0.0 | 0.136 | 0.154 | 50.9 |
| 44.2 | furniture/coffee_pot.png | 340x133 | 0.18 | 0.221 | 0.279 | 85.8 |
| 44.2 | furniture/int_quarry_16.png | 194x214 | 0.0 | 0.136 | 0.154 | 50.9 |
| 43.8 | furniture/wall_plaster_side_r.png | 40x74 | 0.0 | 0.149 | 0.189 | 74.4 |
| 43.5 | furniture/wall_plaster_side_l.png | 38x73 | 0.0 | 0.151 | 0.192 | 82.1 |
| 43.4 | furniture/walltop_tile_left.png | 53x36 | 0.0 | 0.163 | 0.172 | 66.0 |
| 43.3 | furniture/walltop_plaster_door.png | 53x26 | 0.0 | 0.174 | 0.154 | 82.6 |
| 43.2 | furniture/counter_orla_closed.png | 376x210 | 0.01 | 0.157 | 0.195 | 77.0 |
| 42.5 | furniture/shop_bell.png | 126x119 | 0.01 | 0.166 | 0.194 | 93.1 |
| 42.5 | furniture/counter_granite_closed.png | 375x198 | 0.01 | 0.165 | 0.196 | 71.4 |
| 42.3 | furniture/walltop_tile_back.png | 37x29 | 0.0 | 0.17 | 0.183 | 72.7 |
| 42.2 | furniture/wall_wallpaper_face_1.png | 54x67 | 0.0 | 0.172 | 0.181 | 79.0 |
| 42.1 | furniture/wall_wallpaper_face_2.png | 54x67 | 0.0 | 0.174 | 0.179 | 80.2 |
| 42.1 | furniture/walltop_plaster_tr.png | 53x36 | 0.0 | 0.177 | 0.174 | 75.6 |
| 42.0 | furniture/counter_tam.png | 375x192 | 0.01 | 0.168 | 0.204 | 79.9 |

## stations

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 81.2 | stations/pop_gold.png | 356x89 | 0.65 | 0.128 | 0.175 | 89.2 |
| 70.2 | stations/pop_green.png | 348x89 | 0.6 | 0.206 | 0.27 | 95.1 |
| 70.0 | stations/pop_heart.png | 376x97 | 0.71 | 0.22 | 0.251 | 86.1 |
| 69.9 | stations/pop_crystal.png | 364x91 | 1.01 | 0.209 | 0.276 | 83.9 |
| 57.7 | stations/cauldron_4.png | 328x104 | 0.65 | 0.285 | 0.402 | 95.9 |
| 54.4 | stations/cauldron_1.png | 256x98 | 0.31 | 0.189 | 0.288 | 92.7 |
| 52.3 | stations/cauldron_2.png | 292x103 | 0.32 | 0.219 | 0.284 | 89.3 |
| 47.5 | stations/cauldron_3.png | 308x98 | 0.25 | 0.213 | 0.309 | 91.8 |
| 38.2 | stations/stove_1.png | 280x94 | 0.16 | 0.25 | 0.335 | 95.9 |
| 36.1 | stations/kiln.png | 344x113 | 0.18 | 0.276 | 0.351 | 95.6 |
| 35.6 | stations/stove_2.png | 300x99 | 0.15 | 0.283 | 0.309 | 93.4 |
| 35.0 | stations/loom_1.png | 316x80 | 0.03 | 0.231 | 0.27 | 96.3 |
| 34.6 | stations/mill_3.png | 328x110 | 0.01 | 0.207 | 0.292 | 89.5 |
| 34.5 | stations/cheese_press.png | 340x105 | 0.02 | 0.227 | 0.276 | 94.6 |
| 34.1 | stations/stove_3.png | 296x114 | 0.16 | 0.292 | 0.337 | 90.7 |
| 31.2 | stations/mill_1.png | 316x77 | 0.0 | 0.237 | 0.303 | 94.2 |
| 30.8 | stations/wheel_1.png | 348x89 | 0.05 | 0.259 | 0.332 | 97.5 |
| 30.3 | stations/wheel_2.png | 348x90 | 0.04 | 0.255 | 0.344 | 97.7 |
| 30.2 | stations/bench_4.png | 344x100 | 0.01 | 0.249 | 0.312 | 95.1 |
| 29.3 | stations/stove_4.png | 316x117 | 0.16 | 0.325 | 0.387 | 95.5 |
| 28.8 | stations/loom_2.png | 344x87 | 0.09 | 0.302 | 0.356 | 95.4 |
| 27.9 | stations/mill_2.png | 312x107 | 0.01 | 0.258 | 0.345 | 94.6 |
| 26.9 | stations/forge_2.png | 316x101 | 0.0 | 0.268 | 0.341 | 92.1 |
| 26.4 | stations/bench_3.png | 340x95 | 0.02 | 0.289 | 0.334 | 96.0 |
| 26.3 | stations/forge_4.png | 344x109 | 0.0 | 0.274 | 0.345 | 92.4 |
| 25.3 | stations/mill_4.png | 356x103 | 0.03 | 0.29 | 0.368 | 94.9 |
| 25.2 | stations/bench_1.png | 312x69 | 0.01 | 0.296 | 0.341 | 97.1 |
| 25.0 | stations/forge_1.png | 340x77 | 0.01 | 0.295 | 0.342 | 94.3 |
| 24.1 | stations/bench_2.png | 320x87 | 0.01 | 0.297 | 0.36 | 96.4 |
| 23.9 | stations/honey_extractor.png | 304x102 | 0.01 | 0.294 | 0.368 | 97.1 |
| 22.5 | stations/forge_3.png | 340x108 | 0.01 | 0.298 | 0.39 | 95.3 |
| 17.5 | stations/cider_press.png | 336x102 | 0.0 | 0.343 | 0.412 | 95.5 |

## enemies

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 56.5 | enemies/cboss_coral/attack.png | 420x96 | 1.33 | 0.301 | 0.398 | 94.0 |
| 55.6 | enemies/cboss_coral/hurt.png | 174x96 | 1.35 | 0.307 | 0.407 | 96.6 |
| 53.8 | enemies/cboss_coral/walk.png | 336x96 | 1.42 | 0.316 | 0.43 | 93.6 |
| 53.8 | enemies/cboss_coral/idle.png | 336x96 | 1.42 | 0.316 | 0.43 | 93.6 |
| 51.5 | enemies/dark_crystal/attack.png | 608x137 | 0.0 | 0.102 | 0.108 | 81.3 |
| 48.7 | enemies/ice_wisp/hurt.png | 142x70 | 0.3 | 0.222 | 0.334 | 93.9 |
| 46.7 | enemies/finargle/walk_down.png | 128x55 | 0.0 | 0.119 | 0.182 | 87.0 |
| 46.7 | enemies/finargle/walk_up.png | 124x59 | 0.0 | 0.118 | 0.184 | 86.4 |
| 44.7 | enemies/finargle/idle.png | 288x64 | 0.0 | 0.129 | 0.207 | 74.5 |
| 44.0 | enemies/finargle/walk.png | 272x61 | 0.0 | 0.14 | 0.203 | 76.8 |
| 43.7 | enemies/dark_crystal/hurt.png | 290x136 | 0.0 | 0.152 | 0.185 | 87.7 |
| 43.2 | enemies/ice_wisp/idle.png | 102x71 | 0.2 | 0.225 | 0.317 | 93.2 |
| 42.1 | enemies/finargle/hurt.png | 122x64 | 0.0 | 0.146 | 0.234 | 87.5 |
| 41.6 | enemies/ice_wisp/walk.png | 304x61 | 0.27 | 0.265 | 0.364 | 89.4 |
| 40.7 | enemies/wisp/attack.png | 260x42 | 0.0 | 0.173 | 0.213 | 95.9 |
| 40.2 | enemies/ice_wisp/attack.png | 324x83 | 0.26 | 0.274 | 0.366 | 89.8 |
| 40.0 | enemies/commander/attack.png | 452x171 | 0.0 | 0.167 | 0.241 | 93.9 |
| 39.5 | enemies/fennimore/walk.png | 236x90 | 0.0 | 0.163 | 0.258 | 88.1 |
| 39.2 | enemies/dark_crystal/idle.png | 568x125 | 0.0 | 0.187 | 0.22 | 82.9 |
| 38.8 | enemies/cboss_ember/smoke.png | 326x91 | 0.0 | 0.182 | 0.238 | 64.3 |
| 38.1 | enemies/finargle/attack.png | 264x64 | 0.0 | 0.178 | 0.261 | 82.1 |
| 38.0 | enemies/big_grump/attack.png | 780x108 | 0.0 | 0.187 | 0.248 | 62.8 |
| 37.9 | enemies/finargle_old/walk.png | 140x64 | 0.0 | 0.179 | 0.264 | 89.0 |
| 37.9 | enemies/big_grump/idle.png | 480x96 | 0.0 | 0.187 | 0.248 | 61.6 |
| 37.6 | enemies/finargle_old/hurt.png | 66x64 | 0.0 | 0.181 | 0.267 | 92.7 |
| 37.6 | enemies/finargle_old/idle.png | 136x64 | 0.0 | 0.181 | 0.268 | 86.8 |
| 37.6 | enemies/fennimore/idle.png | 272x90 | 0.0 | 0.179 | 0.272 | 85.0 |
| 37.2 | enemies/knight/attack.png | 280x64 | 0.0 | 0.194 | 0.25 | 92.6 |
| 36.7 | enemies/finargle/blink.png | 390x64 | 0.0 | 0.183 | 0.286 | 89.3 |
| 36.4 | enemies/big_grump/walk.png | 496x87 | 0.0 | 0.204 | 0.25 | 61.6 |
| 36.2 | enemies/commander/hurt.png | 206x105 | 0.0 | 0.193 | 0.277 | 96.7 |
| 36.0 | enemies/fennimore/hurt.png | 136x81 | 0.0 | 0.191 | 0.283 | 92.3 |
| 35.9 | enemies/finargle/faint.png | 146x51 | 0.0 | 0.202 | 0.266 | 76.1 |
| 35.5 | enemies/wisp/idle.png | 112x36 | 0.0 | 0.203 | 0.274 | 95.1 |
| 35.4 | enemies/commander/idle.png | 356x113 | 0.0 | 0.204 | 0.274 | 93.7 |
| 35.4 | enemies/ice_wisp/die.png | 328x57 | 0.35 | 0.399 | 0.53 | 97.0 |
| 35.3 | enemies/wisp/hurt.png | 62x38 | 0.0 | 0.204 | 0.276 | 97.4 |
| 35.3 | enemies/big_grump/hurt.png | 234x77 | 0.0 | 0.213 | 0.257 | 74.0 |
| 35.3 | enemies/fennimore/attack.png | 280x90 | 0.0 | 0.193 | 0.297 | 89.1 |
| 35.2 | enemies/ruin_warden/attack.png | 372x209 | 0.08 | 0.238 | 0.314 | 95.3 |

## characters

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 72.2 | characters/penguin_king/view_back.png | 72x94 | 1.16 | 0.194 | 0.251 | 86.2 |
| 72.0 | characters/penguin_king/idle_up.png | 144x94 | 1.17 | 0.194 | 0.254 | 83.3 |
| 71.9 | characters/mk_sable/view_back.png | 54x84 | 1.21 | 0.191 | 0.264 | 86.4 |
| 71.4 | characters/penguin_king/idle.png | 156x98 | 1.14 | 0.2 | 0.258 | 88.5 |
| 71.3 | characters/penguin_king/view_left.png | 78x98 | 1.15 | 0.201 | 0.258 | 92.2 |
| 71.3 | characters/penguin_king/view_right.png | 78x98 | 1.15 | 0.201 | 0.258 | 92.2 |
| 70.8 | characters/penguin_wizard/walk.png | 504x100 | 1.22 | 0.207 | 0.258 | 71.7 |
| 70.7 | characters/big_jim/walk_up.png | 144x90 | 1.14 | 0.202 | 0.27 | 68.8 |
| 70.6 | characters/penguin_king/run.png | 588x90 | 1.18 | 0.206 | 0.264 | 83.1 |
| 70.6 | characters/big_jim/idle_up.png | 144x90 | 1.09 | 0.202 | 0.272 | 69.6 |
| 70.4 | characters/mk_tomas/power.png | 840x88 | 1.13 | 0.209 | 0.264 | 69.0 |
| 70.3 | characters/mk_kit/walk_up.png | 232x92 | 1.18 | 0.204 | 0.274 | 88.5 |
| 70.1 | characters/mk_sable/idle_up.png | 112x89 | 1.14 | 0.214 | 0.26 | 81.3 |
| 70.1 | characters/penguin_king/walk.png | 624x92 | 1.19 | 0.213 | 0.263 | 72.6 |
| 69.8 | characters/mk_sable/walk_up.png | 232x90 | 1.19 | 0.21 | 0.274 | 74.7 |
| 69.6 | characters/mk_atlas/view_back.png | 84x94 | 1.05 | 0.214 | 0.272 | 93.6 |
| 69.5 | characters/penguin_king/view_front.png | 100x96 | 1.18 | 0.215 | 0.27 | 89.9 |
| 69.5 | characters/mk_bruno/view_back.png | 66x89 | 1.08 | 0.213 | 0.275 | 95.9 |
| 69.3 | characters/mk_bruno/hurt.png | 176x90 | 1.1 | 0.208 | 0.289 | 93.9 |
| 69.1 | characters/penguin_king/idle_down.png | 300x96 | 1.16 | 0.217 | 0.276 | 85.8 |
| 68.8 | characters/penguin_wizard/run.png | 432x90 | 1.12 | 0.217 | 0.285 | 83.4 |
| 68.6 | characters/penguin_wizard/view_left.png | 72x96 | 1.14 | 0.215 | 0.292 | 93.4 |
| 68.6 | characters/penguin_wizard/view_right.png | 72x96 | 1.14 | 0.215 | 0.292 | 93.4 |
| 68.3 | characters/mk_tomas/guard.png | 160x90 | 0.91 | 0.219 | 0.29 | 97.4 |
| 68.2 | characters/mk_bruno/walk_up.png | 264x91 | 1.09 | 0.222 | 0.287 | 90.9 |
| 68.1 | characters/mk_atlas/view_left.png | 60x92 | 1.03 | 0.219 | 0.294 | 95.4 |
| 68.1 | characters/mk_kit/view_back.png | 58x89 | 1.17 | 0.225 | 0.283 | 96.2 |
| 68.0 | characters/penguin_king/walk_down.png | 400x96 | 1.2 | 0.226 | 0.285 | 75.4 |
| 68.0 | characters/mk_bruno/walk.png | 296x86 | 1.12 | 0.218 | 0.298 | 92.8 |
| 68.0 | characters/mk_bruno/idle_up.png | 132x89 | 1.08 | 0.225 | 0.287 | 94.4 |
| 67.9 | characters/penguin_wizard/idle.png | 152x96 | 1.14 | 0.22 | 0.298 | 90.9 |
| 67.9 | characters/mk_kit/idle_up.png | 144x91 | 1.2 | 0.227 | 0.284 | 93.5 |
| 67.8 | characters/penguin_wizard/view_front.png | 80x96 | 1.1 | 0.223 | 0.294 | 90.4 |
| 67.5 | characters/penguin_wizard/walk_down.png | 320x96 | 1.21 | 0.23 | 0.289 | 76.9 |
| 67.5 | characters/mk_sable/walk.png | 248x86 | 1.18 | 0.224 | 0.3 | 85.3 |
| 67.4 | characters/penguin_king/walk_up.png | 384x95 | 1.17 | 0.237 | 0.277 | 70.4 |
| 67.4 | characters/mk_bruno/idle_side.png | 100x91 | 1.1 | 0.226 | 0.298 | 93.5 |
| 67.3 | characters/mk_tomas/attack.png | 348x87 | 1.13 | 0.232 | 0.289 | 94.0 |
| 67.2 | characters/penguin_wizard/idle_down.png | 246x96 | 1.1 | 0.226 | 0.302 | 86.1 |
| 67.1 | characters/mk_mei/guard.png | 176x83 | 1.12 | 0.234 | 0.289 | 95.8 |

## animals

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 72.2 | animals/dog_white/howl.png | 158x78 | 1.11 | 0.189 | 0.261 | 80.4 |
| 71.7 | animals/dog_white/bite.png | 384x74 | 1.12 | 0.194 | 0.262 | 71.2 |
| 70.6 | animals/cat_calico/sleep.png | 132x50 | 1.04 | 0.198 | 0.279 | 92.0 |
| 70.5 | animals/dog_white/bark2.png | 168x73 | 1.13 | 0.205 | 0.267 | 80.2 |
| 70.5 | animals/dog_corgi/howl.png | 142x74 | 1.07 | 0.2 | 0.279 | 86.0 |
| 70.2 | animals/dog_shepherd/sleep.png | 136x54 | 1.05 | 0.201 | 0.283 | 90.5 |
| 70.1 | animals/dog_shepherd/roll.png | 150x74 | 1.13 | 0.203 | 0.282 | 93.0 |
| 69.4 | animals/dog_corgi/sleep.png | 140x50 | 1.0 | 0.204 | 0.296 | 83.3 |
| 69.3 | animals/dog_white/hurt.png | 170x80 | 1.11 | 0.211 | 0.285 | 84.4 |
| 69.2 | animals/dog_white/limp.png | 324x65 | 1.11 | 0.217 | 0.274 | 74.7 |
| 68.5 | animals/dog_corgi/limp.png | 320x61 | 1.07 | 0.215 | 0.294 | 85.2 |
| 68.5 | animals/dog_corgi/hurt.png | 142x76 | 1.06 | 0.21 | 0.304 | 91.8 |
| 68.4 | animals/dog_shepherd/howl.png | 150x81 | 1.16 | 0.22 | 0.287 | 93.5 |
| 68.3 | animals/dog_white/guard.png | 156x63 | 1.12 | 0.222 | 0.285 | 83.1 |
| 68.3 | animals/dog_corgi/roll.png | 156x72 | 1.12 | 0.211 | 0.306 | 85.9 |
| 67.9 | animals/dog_shepherd/bark2.png | 158x78 | 1.12 | 0.216 | 0.305 | 94.5 |
| 67.7 | animals/dog_shepherd/limp.png | 316x70 | 1.11 | 0.219 | 0.305 | 90.6 |
| 67.7 | animals/dog_corgi/bark2.png | 158x70 | 1.12 | 0.215 | 0.311 | 90.5 |
| 67.4 | animals/dog_shepherd/bite.png | 340x79 | 1.1 | 0.226 | 0.299 | 90.3 |
| 67.2 | animals/cat_calico/roll.png | 140x72 | 1.18 | 0.223 | 0.309 | 90.1 |
| 67.2 | animals/dog_shepherd/dig.png | 492x82 | 1.15 | 0.219 | 0.316 | 90.6 |
| 66.8 | animals/dog_shepherd/guard.png | 144x71 | 1.13 | 0.227 | 0.308 | 94.4 |
| 66.0 | animals/dog_corgi/bite.png | 352x69 | 1.13 | 0.237 | 0.308 | 86.1 |
| 65.9 | animals/dog_shepherd/hurt.png | 154x81 | 1.14 | 0.237 | 0.31 | 95.3 |
| 65.9 | animals/dog_brown/howl.png | 134x77 | 1.1 | 0.239 | 0.307 | 88.0 |
| 65.6 | animals/dog_corgi/dig.png | 504x69 | 1.12 | 0.235 | 0.319 | 81.7 |
| 65.4 | animals/dog_corgi/fetch.png | 332x65 | 1.11 | 0.237 | 0.321 | 83.6 |
| 65.2 | animals/dog_brown/fetch.png | 320x61 | 1.13 | 0.247 | 0.308 | 81.5 |
| 65.1 | animals/dog_brown/roll.png | 152x62 | 1.1 | 0.236 | 0.33 | 91.3 |
| 64.9 | animals/dog_shepherd/beg.png | 118x90 | 1.11 | 0.238 | 0.332 | 93.8 |
| 64.9 | animals/dog_brown/limp.png | 296x62 | 1.13 | 0.241 | 0.327 | 85.7 |
| 64.7 | animals/dog_shepherd/fetch.png | 320x76 | 1.16 | 0.237 | 0.336 | 88.4 |
| 64.6 | animals/dog_brown/sleep.png | 144x49 | 1.02 | 0.246 | 0.322 | 89.3 |
| 64.6 | animals/dog_corgi/guard.png | 150x63 | 1.09 | 0.242 | 0.329 | 90.1 |
| 63.7 | animals/dog_brown/dig.png | 522x70 | 1.12 | 0.247 | 0.34 | 83.0 |
| 62.5 | animals/dog_brown/bite.png | 328x65 | 1.1 | 0.263 | 0.336 | 82.2 |
| 62.4 | animals/dog_corgi/beg.png | 122x85 | 1.11 | 0.26 | 0.344 | 88.8 |
| 62.2 | animals/dog_brown/beg.png | 116x78 | 1.06 | 0.258 | 0.355 | 91.8 |
| 62.2 | animals/cat_grey/roll.png | 136x70 | 1.19 | 0.255 | 0.358 | 91.9 |
| 61.9 | animals/dog_brown/hurt.png | 132x72 | 1.11 | 0.261 | 0.356 | 92.7 |

## wildlife

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 65.3 | wildlife/badger/idle.png | 44x29 | 1.06 | 0.253 | 0.292 | 97.3 |
| 60.1 | wildlife/fox/idle.png | 50x32 | 1.15 | 0.293 | 0.334 | 98.6 |
| 59.8 | wildlife/fox/walk.png | 224x32 | 1.22 | 0.292 | 0.341 | 91.3 |
| 59.4 | wildlife/otter/walk.png | 96x30 | 0.97 | 0.28 | 0.373 | 98.7 |
| 58.9 | wildlife/otter/idle.png | 58x29 | 1.06 | 0.295 | 0.354 | 98.9 |
| 57.8 | wildlife/goat/idle.png | 38x40 | 1.1 | 0.309 | 0.353 | 95.7 |
| 57.2 | wildlife/mouse/walk.png | 84x24 | 1.06 | 0.307 | 0.372 | 97.3 |
| 57.2 | wildlife/badger/walk.png | 72x29 | 1.05 | 0.308 | 0.371 | 97.7 |
| 57.1 | wildlife/beaver/idle.png | 58x31 | 1.07 | 0.307 | 0.373 | 98.2 |
| 56.9 | wildlife/mouse/idle.png | 40x24 | 1.09 | 0.307 | 0.377 | 97.9 |
| 56.1 | wildlife/frog/idle.png | 28x26 | 1.04 | 0.309 | 0.393 | 98.7 |
| 55.8 | wildlife/goat/walk.png | 76x41 | 1.08 | 0.324 | 0.37 | 95.3 |
| 54.7 | wildlife/beaver/walk.png | 72x31 | 0.94 | 0.323 | 0.397 | 98.8 |
| 54.4 | wildlife/squirrel/walk.png | 216x34 | 1.18 | 0.333 | 0.385 | 89.2 |
| 53.7 | wildlife/boar/idle.png | 36x28 | 1.12 | 0.329 | 0.407 | 98.6 |
| 53.0 | wildlife/deer/walk.png | 324x60 | 1.22 | 0.354 | 0.383 | 82.7 |
| 52.5 | wildlife/deer/idle.png | 264x65 | 1.18 | 0.359 | 0.394 | 83.4 |
| 52.4 | wildlife/frog/walk.png | 52x22 | 0.97 | 0.338 | 0.42 | 99.7 |
| 51.9 | wildlife/boar/walk.png | 80x29 | 1.1 | 0.354 | 0.408 | 97.2 |
| 51.2 | wildlife/squirrel/idle.png | 42x32 | 1.08 | 0.342 | 0.437 | 97.0 |
| 50.6 | wildlife/rabbit/walk.png | 84x38 | 1.05 | 0.39 | 0.437 | 97.2 |
| 50.3 | wildlife/raccoon/walk.png | 64x32 | 1.08 | 0.348 | 0.447 | 97.7 |
| 50.2 | wildlife/raccoon/idle.png | 50x31 | 1.11 | 0.371 | 0.445 | 98.7 |
| 50.0 | wildlife/snake/walk.png | 88x23 | 1.02 | 0.475 | 0.61 | 99.7 |
| 50.0 | wildlife/snake/idle.png | 40x25 | 1.05 | 0.512 | 0.568 | 99.2 |
| 50.0 | wildlife/rat/walk.png | 80x25 | 1.01 | 0.39 | 0.468 | 99.1 |
| 50.0 | wildlife/rat/idle.png | 40x23 | 1.08 | 0.386 | 0.458 | 99.1 |
| 50.0 | wildlife/hedgehog/walk.png | 64x23 | 0.96 | 0.419 | 0.499 | 98.9 |
| 50.0 | wildlife/hedgehog/idle.png | 30x26 | 1.09 | 0.365 | 0.461 | 99.6 |
| 50.0 | wildlife/cat_black/idle.png | 192x34 | 1.17 | 0.441 | 0.528 | 95.9 |
| 50.0 | wildlife/cat_grey/idle.png | 176x36 | 1.05 | 0.465 | 0.561 | 96.6 |
| 50.0 | wildlife/rabbit/idle.png | 42x37 | 0.98 | 0.419 | 0.455 | 99.1 |
| 50.0 | wildlife/cat_orange/idle.png | 184x33 | 1.06 | 0.433 | 0.477 | 96.9 |
| 50.0 | wildlife/turtle/walk.png | 156x26 | 1.05 | 0.425 | 0.519 | 95.3 |
| 50.0 | wildlife/turtle/idle.png | 52x25 | 1.02 | 0.446 | 0.54 | 98.3 |
| 25.5 | wildlife/firefly/walk.png | 54x25 | 0.0 | 0.276 | 0.357 | 98.4 |
| 25.5 | wildlife/firefly/idle.png | 54x25 | 0.0 | 0.276 | 0.357 | 98.4 |
| 24.7 | wildlife/hawk/idle.png | 70x59 | 0.0 | 0.286 | 0.356 | 99.1 |
| 24.5 | wildlife/duck/walk.png | 106x46 | 0.0 | 0.281 | 0.369 | 97.6 |
| 24.3 | wildlife/robin/walk.png | 74x35 | 0.0 | 0.291 | 0.355 | 98.3 |

## tiles

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 85.0 | tiles/ruinfloor_deco_6.png | 30x32 | 1.39 | 0.091 | 0.163 | 98.8 |
| 81.7 | tiles/track_fill_37.png | 32x32 | 0.75 | 0.119 | 0.183 | 87.6 |
| 80.7 | tiles/terrace_fill_36.png | 32x32 | 0.61 | 0.13 | 0.183 | 81.9 |
| 80.3 | tiles/path2_dirt_deco_2.png | 32x30 | 0.45 | 0.059 | 0.139 | 97.7 |
| 79.7 | tiles/river_fill_9.png | 32x32 | 0.63 | 0.134 | 0.198 | 91.9 |
| 79.6 | tiles/bog_fill_21.png | 32x32 | 0.68 | 0.141 | 0.188 | 72.8 |
| 78.9 | tiles/path2_dirt_deco_0.png | 32x29 | 0.49 | 0.081 | 0.171 | 97.8 |
| 78.5 | tiles/bog_fill_28.png | 32x32 | 0.68 | 0.151 | 0.193 | 79.1 |
| 78.4 | tiles/river_fill_8.png | 32x32 | 0.53 | 0.118 | 0.172 | 87.7 |
| 78.3 | tiles/bog_fill_20.png | 32x32 | 1.07 | 0.158 | 0.182 | 70.3 |
| 77.9 | tiles/snowpatch_deco_5.png | 25x32 | 0.56 | 0.127 | 0.198 | 88.1 |
| 77.8 | tiles/snowpatch_deco_10.png | 25x32 | 0.58 | 0.151 | 0.179 | 78.8 |
| 76.4 | tiles/bog_fill_10.png | 32x32 | 0.52 | 0.131 | 0.158 | 58.2 |
| 76.4 | tiles/terrace_fill_2.png | 32x32 | 0.8 | 0.161 | 0.22 | 89.3 |
| 76.2 | tiles/river_fill_12.png | 32x32 | 0.56 | 0.139 | 0.209 | 87.8 |
| 75.9 | tiles/bog_fill_9.png | 32x32 | 0.55 | 0.155 | 0.185 | 70.4 |
| 75.7 | tiles/bog_fill_27.png | 32x32 | 0.67 | 0.175 | 0.21 | 76.3 |
| 75.4 | tiles/snowpatch_fill_26.png | 32x32 | 0.6 | 0.157 | 0.251 | 94.2 |
| 75.3 | tiles/ruinfloor_fill_28.png | 32x32 | 0.63 | 0.163 | 0.242 | 94.9 |
| 75.2 | tiles/track_fill_2.png | 32x32 | 0.58 | 0.157 | 0.231 | 69.5 |
| 75.0 | tiles/snowpatch_fill_1.png | 32x32 | 0.64 | 0.195 | 0.187 | 62.7 |
| 75.0 | tiles/snowpatch_deco_6.png | 25x32 | 0.69 | 0.164 | 0.245 | 98.2 |
| 74.8 | tiles/river_fill_17.png | 32x32 | 0.53 | 0.144 | 0.202 | 90.3 |
| 74.7 | tiles/snowpatch_deco_9.png | 25x32 | 0.84 | 0.202 | 0.179 | 83.3 |
| 74.4 | tiles/snowpatch_deco_4.png | 25x32 | 1.53 | 0.116 | 0.352 | 97.7 |
| 74.3 | tiles/bog_fill_22.png | 32x32 | 0.45 | 0.117 | 0.159 | 69.2 |
| 73.5 | tiles/track_deco_34.png | 32x32 | 1.22 | 0.165 | 0.277 | 99.5 |
| 73.4 | tiles/river_fill_21.png | 32x32 | 0.57 | 0.158 | 0.258 | 97.1 |
| 73.0 | tiles/path2_cobble_fill_2.png | 32x32 | 0.87 | 0.18 | 0.26 | 95.5 |
| 72.9 | tiles/bog_fill_2.png | 32x32 | 0.59 | 0.203 | 0.15 | 49.2 |
| 72.2 | tiles/track_deco_35.png | 32x31 | 1.16 | 0.178 | 0.283 | 99.7 |
| 71.5 | tiles/river_fill_18.png | 32x32 | 0.48 | 0.147 | 0.202 | 95.1 |
| 71.5 | tiles/terrace_fill_29.png | 32x32 | 0.66 | 0.189 | 0.277 | 97.8 |
| 71.5 | tiles/ruinfloor_fill_0.png | 32x32 | 0.81 | 0.189 | 0.276 | 89.2 |
| 71.4 | tiles/river_fill_7.png | 32x32 | 0.45 | 0.125 | 0.201 | 88.5 |
| 70.7 | tiles/river_fill_19.png | 32x32 | 0.59 | 0.199 | 0.257 | 95.0 |
| 70.0 | tiles/ruinfloor_deco_5.png | 30x32 | 0.9 | 0.214 | 0.263 | 97.0 |
| 69.9 | tiles/terrace_fill_20.png | 32x32 | 0.55 | 0.182 | 0.258 | 78.0 |
| 69.7 | tiles/river_fill_13.png | 32x32 | 0.4 | 0.122 | 0.189 | 81.2 |
| 69.6 | tiles/river_fill_36.png | 32x32 | 0.43 | 0.13 | 0.207 | 99.1 |

## cliffs

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 49.4 | cliffs/snow_outer_l.png | 118x144 | 0.0 | 0.103 | 0.152 | 82.5 |
| 49.4 | cliffs/snow_inner_l.png | 118x143 | 0.0 | 0.106 | 0.148 | 79.3 |
| 49.0 | cliffs/snow_inner_r.png | 119x143 | 0.0 | 0.11 | 0.147 | 77.0 |
| 47.9 | cliffs/snow_strip.png | 721x137 | 0.0 | 0.114 | 0.155 | 58.3 |
| 47.8 | cliffs/snow_outer_r.png | 116x144 | 0.0 | 0.113 | 0.169 | 86.7 |
| 47.5 | cliffs/cave_crystal_wall.png | 734x145 | 0.0 | 0.119 | 0.164 | 70.0 |
| 47.3 | cliffs/cave_ice_outer_l.png | 103x124 | 0.0 | 0.124 | 0.159 | 86.0 |
| 46.9 | cliffs/cave_ice_inner_l.png | 114x123 | 0.0 | 0.125 | 0.166 | 87.4 |
| 46.7 | cliffs/cave_ice_inner_r.png | 115x123 | 0.0 | 0.129 | 0.164 | 84.8 |
| 46.7 | cliffs/cave_ice_outer_r.png | 107x124 | 0.0 | 0.13 | 0.162 | 84.2 |
| 46.1 | cliffs/cave_earth_inner_l.png | 114x120 | 0.0 | 0.129 | 0.177 | 86.1 |
| 45.9 | cliffs/cave_stone_inner_l.png | 114x120 | 0.0 | 0.131 | 0.178 | 80.8 |
| 45.8 | cliffs/cave_crystal_outer_r.png | 127x132 | 0.0 | 0.132 | 0.178 | 89.3 |
| 45.6 | cliffs/cave_ice_wall.png | 765x131 | 0.0 | 0.136 | 0.174 | 64.9 |
| 44.7 | cliffs/cave_stone_inner_r.png | 115x120 | 0.0 | 0.141 | 0.184 | 83.7 |
| 44.6 | cliffs/cave_crystal_inner_l.png | 127x132 | 0.0 | 0.141 | 0.187 | 90.2 |
| 44.6 | cliffs/cave_earth_inner_r.png | 115x120 | 0.0 | 0.141 | 0.188 | 85.7 |
| 44.6 | cliffs/cave_crystal_outer_l.png | 121x134 | 0.0 | 0.142 | 0.186 | 94.2 |
| 44.6 | cliffs/snow_tall.png | 721x239 | 0.0 | 0.119 | 0.16 | 47.7 |
| 44.6 | cliffs/cave_earth_wall.png | 765x128 | 0.0 | 0.137 | 0.187 | 58.6 |
| 44.4 | cliffs/snow_side_r.png | 50x140 | 0.0 | 0.136 | 0.201 | 95.4 |
| 44.2 | cliffs/cave_earth_outer_r.png | 106x121 | 0.0 | 0.143 | 0.192 | 86.8 |
| 44.0 | cliffs/cave_crystal_inner_r.png | 120x134 | 0.0 | 0.145 | 0.192 | 93.9 |
| 43.7 | cliffs/cave_stone_outer_r.png | 106x121 | 0.0 | 0.148 | 0.194 | 85.1 |
| 43.0 | cliffs/snow_side_l.png | 51x140 | 0.0 | 0.149 | 0.207 | 95.2 |
| 42.4 | cliffs/cave_lava_wall.png | 732x140 | 0.0 | 0.155 | 0.211 | 71.5 |
| 42.2 | cliffs/cave_stone_outer_l.png | 103x121 | 0.0 | 0.16 | 0.205 | 87.3 |
| 42.0 | cliffs/cave_earth_outer_l.png | 103x121 | 0.0 | 0.162 | 0.206 | 90.6 |
| 41.7 | cliffs/cave_stone_wall.png | 765x126 | 0.0 | 0.143 | 0.19 | 49.7 |
| 40.8 | cliffs/cave_lava_outer_r.png | 127x136 | 0.0 | 0.171 | 0.215 | 93.8 |
| 40.2 | cliffs/sand_inner_l.png | 121x143 | 0.0 | 0.171 | 0.229 | 89.1 |
| 40.1 | cliffs/cave_lava_outer_l.png | 121x136 | 0.0 | 0.175 | 0.223 | 93.4 |
| 39.7 | cliffs/cave_lava_inner_r.png | 121x136 | 0.0 | 0.178 | 0.226 | 94.0 |
| 39.5 | cliffs/cave_lava_inner_l.png | 127x136 | 0.0 | 0.179 | 0.229 | 95.1 |
| 39.4 | cliffs/sand_inner_r.png | 123x141 | 0.0 | 0.178 | 0.232 | 88.7 |
| 39.2 | cliffs/sand_strip.png | 799x120 | 0.0 | 0.178 | 0.237 | 67.0 |
| 39.1 | cliffs/sand_outer_l.png | 116x142 | 0.0 | 0.177 | 0.242 | 90.7 |
| 38.6 | cliffs/sand_corner_a.png | 110x149 | 0.0 | 0.18 | 0.247 | 90.2 |
| 38.5 | cliffs/sand_corner_b.png | 111x150 | 0.0 | 0.183 | 0.244 | 87.7 |
| 38.1 | cliffs/sand_outer_r.png | 119x143 | 0.0 | 0.186 | 0.246 | 91.2 |

## ui

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 91.2 | ui/menu_31.png | 52x68 | 1.05 | 0.07 | 0.064 | 64.8 |
| 90.3 | ui/menu_41.png | 65x57 | 0.63 | 0.054 | 0.049 | 48.5 |
| 89.6 | ui/menu_35.png | 49x69 | 0.65 | 0.079 | 0.055 | 55.1 |
| 88.1 | ui/menu_33.png | 66x51 | 0.42 | 0.009 | 0.008 | 58.6 |
| 83.7 | ui/hud2_85.png | 186x195 | 0.69 | 0.114 | 0.148 | 64.1 |
| 79.8 | ui/menu_40.png | 73x54 | 0.57 | 0.1 | 0.097 | 38.1 |
| 79.7 | ui/hud2_81.png | 161x163 | 0.65 | 0.146 | 0.175 | 76.8 |
| 68.8 | ui/menu_34.png | 49x54 | 0.22 | 0.056 | 0.05 | 51.5 |
| 67.2 | ui/start_gem_a.png | 379x122 | 0.66 | 0.25 | 0.255 | 80.9 |
| 66.0 | ui/hud2_66.png | 56x64 | 0.66 | 0.223 | 0.336 | 94.1 |
| 64.9 | ui/start_gem_b.png | 367x135 | 1.12 | 0.27 | 0.269 | 76.8 |
| 64.6 | ui/menu_37.png | 50x52 | 0.24 | 0.079 | 0.077 | 43.4 |
| 63.9 | ui/hud2_72.png | 134x136 | 0.45 | 0.194 | 0.24 | 84.3 |
| 61.9 | ui/menu_04.png | 561x282 | 0.42 | 0.179 | 0.207 | 47.2 |
| 60.8 | ui/hud2_06.png | 126x115 | 0.33 | 0.163 | 0.208 | 84.2 |
| 60.8 | ui/menu_39.png | 63x37 | 0.2 | 0.105 | 0.065 | 43.8 |
| 60.8 | ui/heart2_gold.png | 126x115 | 0.33 | 0.163 | 0.208 | 84.2 |
| 60.6 | ui/panel_sanctuary.png | 515x346 | 0.39 | 0.189 | 0.246 | 91.1 |
| 60.2 | ui/hud2_49.png | 311x232 | 0.23 | 0.129 | 0.16 | 76.4 |
| 60.2 | ui/xp_bars.png | 311x232 | 0.23 | 0.129 | 0.16 | 76.4 |
| 56.8 | ui/wordmark_glow.png | 1495x414 | 0.12 | 0.044 | 0.049 | 22.1 |
| 54.9 | ui/wordmark_small.png | 751x199 | 0.11 | 0.081 | 0.1 | 39.6 |
| 53.4 | ui/panel2_fill.png | 79x74 | 0.23 | 0.099 | 0.119 | 14.9 |
| 53.4 | ui/menu_26.png | 79x74 | 0.23 | 0.099 | 0.119 | 14.9 |
| 52.2 | ui/card_dark_crystal.png | 768x354 | 0.26 | 0.166 | 0.197 | 40.0 |
| 51.0 | ui/cut_star.png | 500x303 | 0.0 | 0.099 | 0.125 | 63.2 |
| 50.5 | ui/heart2_winged.png | 192x114 | 0.17 | 0.163 | 0.233 | 90.0 |
| 50.5 | ui/hud2_08.png | 192x114 | 0.17 | 0.163 | 0.233 | 90.0 |
| 49.8 | ui/crew_sign_doc.png | 88x96 | 0.0 | 0.107 | 0.135 | 88.5 |
| 48.9 | ui/season2_spring.png | 281x245 | 0.0 | 0.116 | 0.144 | 60.1 |
| 48.9 | ui/hud2_44.png | 281x245 | 0.0 | 0.116 | 0.144 | 60.1 |
| 48.6 | ui/ending_quiet_mountain.png | 372x244 | 0.0 | 0.111 | 0.154 | 63.1 |
| 48.6 | ui/card_lt_lucia.png | 381x200 | 0.0 | 0.107 | 0.14 | 55.8 |
| 48.5 | ui/title_keyart.png | 1536x690 | 0.0 | 0.114 | 0.151 | 66.5 |
| 48.2 | ui/cut_letter.png | 267x177 | 0.0 | 0.119 | 0.15 | 73.3 |
| 47.2 | ui/title_portrait.png | 941x1672 | 0.0 | 0.068 | 0.085 | 27.2 |
| 47.1 | ui/wx_leaves.png | 108x92 | 0.01 | 0.118 | 0.184 | 98.4 |
| 47.1 | ui/hud2_39.png | 108x92 | 0.01 | 0.118 | 0.184 | 98.4 |
| 47.0 | ui/heart2_container.png | 111x99 | 0.5 | 0.335 | 0.409 | 86.2 |
| 47.0 | ui/hud2_05.png | 111x99 | 0.5 | 0.335 | 0.409 | 86.2 |

## items

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 70.5 | items/egg.png | 27x32 | 1.08 | 0.259 | 0.165 | 90.0 |
| 69.6 | items/apple_q1.png | 32x27 | 1.13 | 0.21 | 0.279 | 99.2 |
| 66.6 | items/apple_q2.png | 32x30 | 1.16 | 0.215 | 0.336 | 99.8 |
| 66.4 | items/apple_q3.png | 32x31 | 1.34 | 0.244 | 0.285 | 99.8 |
| 66.0 | items/corn_bread.png | 32x30 | 0.96 | 0.236 | 0.31 | 98.1 |
| 65.6 | items/glow_cap.png | 31x32 | 1.42 | 0.268 | 0.257 | 98.6 |
| 64.7 | items/bog_iron.png | 32x32 | 0.86 | 0.244 | 0.325 | 99.6 |
| 63.5 | items/hammer_silver.png | 21x32 | 1.08 | 0.303 | 0.236 | 98.0 |
| 63.1 | items/hood.png | 32x31 | 1.24 | 0.262 | 0.325 | 98.4 |
| 62.1 | items/hammer_steel.png | 22x32 | 1.2 | 0.297 | 0.28 | 98.1 |
| 61.3 | items/earmuffs.png | 32x23 | 1.13 | 0.345 | 0.207 | 96.6 |
| 60.8 | items/spring_salt.png | 28x32 | 0.88 | 0.265 | 0.372 | 99.3 |
| 60.4 | items/cap.png | 32x26 | 1.14 | 0.277 | 0.356 | 99.5 |
| 59.6 | items/beanie.png | 32x31 | 1.02 | 0.295 | 0.341 | 99.4 |
| 59.3 | items/heart_fruit.png | 25x32 | 1.03 | 0.282 | 0.373 | 99.5 |
| 59.3 | items/hammer_iron.png | 21x32 | 1.12 | 0.315 | 0.308 | 98.5 |
| 58.4 | items/candy.png | 32x31 | 1.61 | 0.299 | 0.359 | 97.8 |
| 57.7 | items/hammer_gold.png | 22x32 | 1.25 | 0.34 | 0.295 | 99.7 |
| 57.2 | items/cheese.png | 32x30 | 0.93 | 0.324 | 0.339 | 97.3 |
| 56.8 | items/snow_pea_seed.png | 30x32 | 0.72 | 0.294 | 0.404 | 99.4 |
| 56.6 | items/gift_box.png | 32x26 | 1.13 | 0.313 | 0.373 | 94.8 |
| 56.4 | items/eagle_feather.png | 32x31 | 1.01 | 0.313 | 0.378 | 99.1 |
| 56.3 | items/coffee.png | 29x32 | 1.19 | 0.338 | 0.331 | 97.9 |
| 56.2 | items/apple_q4.png | 26x32 | 1.03 | 0.314 | 0.379 | 99.5 |
| 56.1 | items/axe_wood.png | 17x32 | 1.24 | 0.404 | 0.314 | 100.0 |
| 55.8 | items/river_pearl.png | 32x26 | 1.24 | 0.405 | 0.32 | 98.6 |
| 55.8 | items/hay_bale.png | 32x22 | 1.32 | 0.304 | 0.409 | 99.1 |
| 55.6 | items/hammer_wood.png | 21x32 | 1.09 | 0.35 | 0.325 | 98.5 |
| 55.2 | items/hammer_copper.png | 22x32 | 1.22 | 0.354 | 0.333 | 98.9 |
| 55.1 | items/scythe_silver.png | 19x32 | 1.18 | 0.444 | 0.335 | 99.6 |
| 54.9 | items/can_copper.png | 32x30 | 1.13 | 0.3 | 0.435 | 99.3 |
| 54.9 | items/cake.png | 29x32 | 0.9 | 0.316 | 0.405 | 100.0 |
| 54.8 | items/pelt.png | 32x30 | 1.19 | 0.306 | 0.428 | 98.3 |
| 54.7 | items/sword_iron.png | 14x32 | 1.18 | 0.388 | 0.344 | 100.0 |
| 54.6 | items/scythe_steel.png | 19x32 | 1.12 | 0.491 | 0.345 | 100.0 |
| 54.5 | items/sword_copper.png | 13x32 | 1.55 | 0.345 | 0.359 | 99.5 |
| 54.4 | items/hardwood.png | 32x28 | 1.01 | 0.311 | 0.428 | 98.6 |
| 54.2 | items/axe_copper.png | 18x32 | 1.21 | 0.366 | 0.356 | 100.0 |
| 54.0 | items/milk.png | 25x32 | 0.95 | 0.348 | 0.364 | 94.0 |
| 53.8 | items/scythe_crystal.png | 19x32 | 1.2 | 0.423 | 0.365 | 100.0 |

## animals_ref

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 38.2 | animals_ref/sheep.png | 60x51 | 0.0 | 0.199 | 0.219 | 84.1 |
| 33.0 | animals_ref/horse.png | 90x58 | 0.0 | 0.226 | 0.286 | 93.9 |
| 30.8 | animals_ref/pig.png | 60x42 | 0.0 | 0.253 | 0.281 | 87.0 |
| 28.6 | animals_ref/cow.png | 72x54 | 0.0 | 0.26 | 0.317 | 96.2 |
| 26.2 | animals_ref/goat.png | 49x52 | 0.0 | 0.286 | 0.322 | 93.3 |
| 26.2 | animals_ref/chicken.png | 40x46 | 0.0 | 0.281 | 0.332 | 95.6 |
| 24.7 | animals_ref/kid.png | 38x37 | 0.0 | 0.301 | 0.327 | 95.5 |
| 24.0 | animals_ref/lamb.png | 38x35 | 0.0 | 0.304 | 0.335 | 96.4 |
| 21.7 | animals_ref/rooster.png | 49x52 | 0.0 | 0.305 | 0.385 | 98.7 |
| 19.8 | animals_ref/foal.png | 46x45 | 0.0 | 0.338 | 0.364 | 98.2 |
| 18.0 | animals_ref/piglet.png | 35x27 | 0.0 | 0.368 | 0.383 | 98.1 |
| 16.3 | animals_ref/chick.png | 28x25 | 0.0 | 0.404 | 0.42 | 100.0 |
| 16.1 | animals_ref/duck.png | 44x41 | 0.0 | 0.364 | 0.424 | 98.5 |
| 15.0 | animals_ref/calf.png | 44x40 | 0.0 | 0.364 | 0.472 | 98.6 |

## battle

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 38.1 | battle/flag_neutral_1.png | 104x174 | 0.0 | 0.187 | 0.244 | 84.6 |
| 37.3 | battle/flag_ally_2.png | 109x174 | 0.0 | 0.196 | 0.244 | 92.2 |
| 37.3 | battle/flag_neutral_2.png | 107x174 | 0.0 | 0.196 | 0.245 | 86.0 |
| 37.0 | battle/flag_ally_3.png | 111x174 | 0.0 | 0.197 | 0.249 | 95.1 |
| 36.9 | battle/ring_5.png | 153x148 | 0.0 | 0.191 | 0.263 | 88.0 |
| 36.6 | battle/flag_neutral_0.png | 88x174 | 0.0 | 0.199 | 0.256 | 84.7 |
| 36.5 | battle/flag_ally_1.png | 105x174 | 0.0 | 0.204 | 0.247 | 94.1 |
| 36.5 | battle/ring_6.png | 153x149 | 0.0 | 0.197 | 0.261 | 85.7 |
| 36.5 | battle/ring_7.png | 152x149 | 0.0 | 0.196 | 0.263 | 80.5 |
| 36.4 | battle/flag_neutral_3.png | 111x174 | 0.0 | 0.202 | 0.252 | 86.5 |
| 36.1 | battle/ring_4.png | 151x147 | 0.0 | 0.195 | 0.274 | 88.3 |
| 34.9 | battle/flag_ally_0.png | 89x174 | 0.0 | 0.218 | 0.255 | 92.8 |
| 34.8 | battle/ring_2.png | 150x142 | 0.0 | 0.198 | 0.299 | 90.9 |
| 34.4 | battle/ring_3.png | 152x147 | 0.0 | 0.202 | 0.297 | 88.0 |
| 34.3 | battle/pylon_anim/fire.png | 384x303 | 0.0 | 0.22 | 0.266 | 88.5 |
| 33.5 | battle/spire_1.png | 214x128 | 0.0 | 0.219 | 0.285 | 96.7 |
| 33.2 | battle/ring_1.png | 137x142 | 0.0 | 0.207 | 0.317 | 92.8 |
| 32.9 | battle/flag_enemy_1.png | 106x174 | 0.0 | 0.224 | 0.291 | 94.2 |
| 32.8 | battle/spire_2.png | 261x184 | 0.0 | 0.229 | 0.284 | 97.0 |
| 32.3 | battle/flag_enemy_2.png | 110x174 | 0.0 | 0.23 | 0.292 | 93.2 |
| 32.2 | battle/spire_3.png | 283x267 | 0.0 | 0.237 | 0.28 | 93.3 |
| 31.8 | battle/pylon_anim/idle.png | 384x204 | 0.0 | 0.233 | 0.298 | 92.3 |
| 30.9 | battle/turret.png | 147x149 | 0.0 | 0.246 | 0.292 | 92.6 |
| 30.7 | battle/flag_enemy_3.png | 113x174 | 0.0 | 0.243 | 0.302 | 95.1 |
| 30.2 | battle/flag_enemy_0.png | 89x174 | 0.0 | 0.251 | 0.3 | 93.6 |
| 29.7 | battle/bay_3.png | 421x274 | 0.0 | 0.259 | 0.295 | 82.5 |
| 29.2 | battle/pylon.png | 96x204 | 0.0 | 0.252 | 0.321 | 97.3 |
| 29.2 | battle/pylon_anim/lv3.png | 210x195 | 0.0 | 0.256 | 0.313 | 94.1 |
| 28.8 | battle/bay_2.png | 328x205 | 0.0 | 0.261 | 0.311 | 87.4 |
| 27.9 | battle/bay_1.png | 308x199 | 0.0 | 0.267 | 0.321 | 91.6 |
| 27.8 | battle/pylon_anim/cracked.png | 180x191 | 0.0 | 0.267 | 0.323 | 96.3 |
| 25.2 | battle/pylon_anim/hurt.png | 208x203 | 0.0 | 0.283 | 0.351 | 95.1 |
| 24.5 | battle/pylon_anim/lv2.png | 174x186 | 0.0 | 0.285 | 0.363 | 96.2 |
| 15.0 | battle/ring_0.png | 137x135 | 0.0 | 1.055 | 0.588 | 87.5 |

## body

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 75.5 | body/outfit_penguin.png | 1536x96 | 0.95 | 0.169 | 0.226 | 73.7 |
| 74.4 | body/act_attack_2.png | 96x96 | 0.95 | 0.178 | 0.233 | 92.7 |
| 74.3 | body/outfit_fisher.png | 1536x96 | 0.97 | 0.182 | 0.228 | 75.1 |
| 73.8 | body/outfit_merchant.png | 1536x96 | 0.98 | 0.184 | 0.235 | 73.1 |
| 72.4 | body/armor_leather.png | 1536x96 | 1.02 | 0.189 | 0.256 | 80.3 |
| 72.0 | body/outfit_miner.png | 1536x96 | 1.01 | 0.196 | 0.253 | 80.3 |
| 71.6 | body/outfit_farmer.png | 1536x96 | 0.98 | 0.198 | 0.257 | 78.3 |
| 70.9 | body/outfit_scholar.png | 1536x96 | 1.01 | 0.206 | 0.259 | 75.9 |
| 70.0 | body/outfit_forester.png | 1536x96 | 1.0 | 0.207 | 0.276 | 74.7 |
| 69.7 | body/outfit_neon.png | 1536x96 | 0.96 | 0.214 | 0.27 | 75.1 |
| 69.7 | body/armor_gold.png | 1536x96 | 1.04 | 0.205 | 0.288 | 85.9 |
| 68.7 | body/armor_copper.png | 1536x96 | 1.04 | 0.214 | 0.293 | 84.5 |
| 68.3 | body/act_eat.png | 96x96 | 0.89 | 0.219 | 0.29 | 90.5 |
| 68.2 | body/armor_iron.png | 1536x96 | 1.04 | 0.217 | 0.299 | 79.8 |
| 67.7 | body/outfit_forester_life.png | 1536x96 | 0.84 | 0.224 | 0.297 | 82.1 |
| 67.2 | body/outfit_miner_act.png | 1536x96 | 0.83 | 0.23 | 0.296 | 79.4 |
| 66.9 | body/outfit_merchant_life.png | 1536x96 | 0.96 | 0.229 | 0.303 | 83.4 |
| 66.8 | body/armor_steel.png | 1536x96 | 1.05 | 0.227 | 0.309 | 84.8 |
| 66.2 | body/armor_silver.png | 1536x96 | 1.01 | 0.231 | 0.317 | 86.5 |
| 66.1 | body/outfit_penguin_life.png | 1536x96 | 0.88 | 0.233 | 0.312 | 84.1 |
| 66.1 | body/armor_moon.png | 1536x96 | 1.07 | 0.23 | 0.319 | 87.4 |
| 65.9 | body/armor_crystal.png | 1536x96 | 1.11 | 0.231 | 0.321 | 91.9 |
| 65.1 | body/armor_steel_life.png | 1536x96 | 0.66 | 0.239 | 0.325 | 82.7 |
| 65.0 | body/outfit_forester_act.png | 1536x96 | 0.5 | 0.203 | 0.264 | 74.4 |
| 64.9 | body/act_ride_2.png | 96x96 | 1.0 | 0.245 | 0.318 | 96.3 |
| 64.8 | body/act_carry_2.png | 96x96 | 0.87 | 0.248 | 0.312 | 97.2 |
| 64.8 | body/armor_leather_life.png | 1536x96 | 0.57 | 0.231 | 0.309 | 78.5 |
| 64.7 | body/outfit_miner_life.png | 1536x96 | 0.84 | 0.244 | 0.324 | 83.3 |
| 64.4 | body/armor_moon_life.png | 1536x96 | 0.69 | 0.244 | 0.329 | 85.1 |
| 64.2 | body/armor_copper_life.png | 1536x96 | 0.59 | 0.241 | 0.326 | 81.4 |
| 64.2 | body/act_ride_1.png | 96x96 | 0.9 | 0.254 | 0.316 | 95.3 |
| 63.6 | body/armor_gold_life.png | 1536x96 | 0.6 | 0.248 | 0.335 | 83.6 |
| 63.4 | body/armor_iron_life.png | 1536x96 | 0.57 | 0.239 | 0.329 | 80.1 |
| 63.3 | body/act_carry_1.png | 96x96 | 0.81 | 0.264 | 0.318 | 96.3 |
| 63.2 | body/outfit_penguin_act.png | 1536x96 | 0.4 | 0.178 | 0.22 | 69.5 |
| 62.9 | body/act_attack_3.png | 96x96 | 0.92 | 0.261 | 0.332 | 92.3 |
| 62.7 | body/outfit_farmer_life.png | 1536x96 | 0.83 | 0.259 | 0.339 | 87.0 |
| 62.5 | body/act_sleep.png | 96x96 | 0.91 | 0.267 | 0.328 | 93.4 |
| 62.3 | body/act_hurt.png | 96x96 | 0.97 | 0.261 | 0.345 | 92.7 |
| 62.2 | body/outfit_fisher_life.png | 1536x96 | 0.84 | 0.263 | 0.343 | 87.0 |

## crops

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 73.6 | crops/soulleaf_ready.png | 71x98 | 1.27 | 0.182 | 0.242 | 96.7 |
| 73.2 | crops/lumiflora_ready.png | 70x93 | 1.22 | 0.191 | 0.234 | 98.2 |
| 71.1 | crops/ethereal_corn_ready.png | 62x100 | 1.23 | 0.192 | 0.281 | 96.9 |
| 70.4 | crops/ethereal_corn_seed.png | 42x24 | 1.08 | 0.202 | 0.277 | 99.4 |
| 70.2 | crops/dreamflower_ready.png | 106x114 | 0.46 | 0.147 | 0.206 | 88.5 |
| 69.2 | crops/ethereal_corn_mature.png | 58x97 | 1.21 | 0.21 | 0.287 | 99.5 |
| 68.9 | crops/lumiflora_mature.png | 59x79 | 1.28 | 0.221 | 0.274 | 99.2 |
| 67.8 | crops/wishfruit_ready.png | 118x116 | 0.42 | 0.15 | 0.204 | 96.8 |
| 67.4 | crops/soulleaf_seed.png | 42x28 | 1.05 | 0.217 | 0.315 | 99.4 |
| 66.7 | crops/lumiflora_seed.png | 42x27 | 1.01 | 0.229 | 0.307 | 99.9 |
| 65.9 | crops/soulleaf_sprout.png | 42x45 | 1.12 | 0.231 | 0.322 | 99.7 |
| 65.8 | crops/worldseed_ready.png | 72x93 | 1.28 | 0.236 | 0.315 | 99.3 |
| 65.0 | crops/soulleaf_mature.png | 64x86 | 1.24 | 0.246 | 0.314 | 99.2 |
| 63.8 | crops/worldseed_seed.png | 40x26 | 0.98 | 0.235 | 0.361 | 99.7 |
| 63.3 | crops/lumiflora_growing.png | 53x69 | 1.24 | 0.26 | 0.324 | 99.8 |
| 62.7 | crops/ethereal_corn_growing.png | 53x85 | 1.23 | 0.265 | 0.328 | 99.6 |
| 62.6 | crops/soulleaf_growing.png | 55x76 | 1.24 | 0.263 | 0.334 | 99.5 |
| 61.7 | crops/prism_tomato_seed.png | 41x27 | 1.08 | 0.273 | 0.336 | 99.4 |
| 61.0 | crops/prism_tomato_ready.png | 72x99 | 1.39 | 0.262 | 0.371 | 99.7 |
| 60.2 | crops/cotton_star.png | 102x73 | 0.39 | 0.191 | 0.256 | 97.7 |
| 60.2 | crops/prism_tomato_mature.png | 60x92 | 1.29 | 0.267 | 0.381 | 99.9 |
| 59.9 | crops/soulleaf_young.png | 49x57 | 1.19 | 0.275 | 0.371 | 99.3 |
| 59.3 | crops/dreamfruit_ready.png | 108x106 | 0.31 | 0.161 | 0.228 | 98.4 |
| 58.7 | crops/lumiflora_sprout.png | 40x41 | 1.14 | 0.278 | 0.392 | 100.0 |
| 58.2 | crops/ethereal_corn_young.png | 50x66 | 1.18 | 0.285 | 0.39 | 99.3 |
| 58.1 | crops/lumiflora_young.png | 48x52 | 1.21 | 0.282 | 0.401 | 99.7 |
| 57.2 | crops/ethereal_corn_sprout.png | 40x44 | 1.17 | 0.288 | 0.408 | 99.5 |
| 56.5 | crops/wishfruit_mature.png | 114x106 | 0.35 | 0.197 | 0.268 | 97.4 |
| 56.4 | crops/moon_melon_winter.png | 116x66 | 0.2 | 0.134 | 0.198 | 96.0 |
| 55.6 | crops/worldseed_mature.png | 54x78 | 1.18 | 0.3 | 0.42 | 99.5 |
| 54.9 | crops/sweet_potato_mature.png | 116x103 | 0.35 | 0.206 | 0.29 | 97.3 |
| 54.7 | crops/mint_ready.png | 104x107 | 0.25 | 0.172 | 0.225 | 99.0 |
| 54.6 | crops/prism_tomato_young.png | 50x69 | 1.25 | 0.307 | 0.429 | 99.7 |
| 54.5 | crops/worldseed_sprout.png | 39x36 | 1.08 | 0.312 | 0.421 | 99.6 |
| 54.4 | crops/prism_tomato_sprout.png | 43x48 | 1.17 | 0.317 | 0.415 | 99.6 |
| 54.2 | crops/snow_pea_winter.png | 83x64 | 0.23 | 0.167 | 0.227 | 97.6 |
| 54.1 | crops/turmeric_mature.png | 113x110 | 0.3 | 0.197 | 0.265 | 98.7 |
| 53.6 | crops/moonflower_ready.png | 113x116 | 0.34 | 0.215 | 0.284 | 94.8 |
| 53.2 | crops/worldseed_young.png | 41x50 | 1.16 | 0.319 | 0.436 | 99.7 |
| 53.1 | crops/prism_tomato_growing.png | 58x87 | 1.28 | 0.323 | 0.432 | 99.7 |

## edges

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 52.1 | edges/grass_snow_inner_tr.png | 123x80 | 0.0 | 0.087 | 0.121 | 71.5 |
| 51.1 | edges/grass_snow_inner_tl.png | 119x80 | 0.0 | 0.093 | 0.133 | 77.2 |
| 51.1 | edges/grass_snow_strip.png | 454x174 | 0.0 | 0.084 | 0.12 | 54.5 |
| 48.4 | edges/snow_ice_outer_tl.png | 119x194 | 0.0 | 0.114 | 0.154 | 65.9 |
| 47.8 | edges/sand_wetsand_inner_tl.png | 120x85 | 0.0 | 0.117 | 0.161 | 82.1 |
| 47.8 | edges/snow_ice_inner_tr.png | 118x194 | 0.0 | 0.116 | 0.164 | 68.9 |
| 47.7 | edges/sand_sea_outer_tl.png | 119x192 | 0.0 | 0.119 | 0.16 | 69.2 |
| 47.7 | edges/sand_wetsand_inner_tr.png | 121x85 | 0.0 | 0.119 | 0.16 | 77.9 |
| 47.5 | edges/snow_ice_inner_tl.png | 119x194 | 0.0 | 0.122 | 0.158 | 66.0 |
| 47.5 | edges/snow_ice_outer_tr.png | 118x194 | 0.0 | 0.119 | 0.164 | 69.7 |
| 47.2 | edges/sand_wetsand_strip.png | 455x188 | 0.0 | 0.083 | 0.119 | 38.5 |
| 47.2 | edges/coral_sea_strip.png | 456x173 | 0.0 | 0.098 | 0.133 | 46.1 |
| 46.8 | edges/sand_wetsand_outer_tl.png | 120x89 | 0.0 | 0.123 | 0.174 | 77.4 |
| 46.7 | edges/sand_sea_outer_tr.png | 119x192 | 0.0 | 0.126 | 0.17 | 72.2 |
| 46.4 | edges/sand_sea_inner_tl.png | 120x192 | 0.0 | 0.127 | 0.172 | 74.4 |
| 46.1 | edges/sand_sea_inner_tr.png | 119x192 | 0.0 | 0.13 | 0.173 | 72.9 |
| 46.0 | edges/grass_sand_strip.png | 454x179 | 0.0 | 0.128 | 0.18 | 62.8 |
| 46.0 | edges/coral_sea_inner_tr.png | 122x80 | 0.0 | 0.131 | 0.175 | 75.2 |
| 45.9 | edges/coral_sea_inner_tl.png | 119x80 | 0.0 | 0.131 | 0.177 | 81.2 |
| 45.8 | edges/grass_sand_inner_tr.png | 124x79 | 0.0 | 0.128 | 0.184 | 88.3 |
| 45.8 | edges/grass_sand_inner_tl.png | 120x79 | 0.0 | 0.128 | 0.185 | 89.8 |
| 45.2 | edges/snow_ice_strip.png | 520x193 | 0.0 | 0.115 | 0.15 | 46.6 |
| 45.2 | edges/sand_wetsand_outer_tr.png | 120x89 | 0.0 | 0.133 | 0.188 | 77.0 |
| 44.6 | edges/sand_sea_strip.png | 521x192 | 0.0 | 0.111 | 0.146 | 42.2 |
| 42.7 | edges/grass_snow_outer_tr.png | 124x82 | 0.0 | 0.148 | 0.215 | 94.9 |
| 42.0 | edges/grass_snow_outer_tl.png | 120x83 | 0.0 | 0.156 | 0.216 | 93.7 |
| 41.4 | edges/coral_sea_outer_tl.png | 119x82 | 0.0 | 0.16 | 0.223 | 88.0 |
| 40.8 | edges/dirt_pavement_outer_tl.png | 120x88 | 0.0 | 0.159 | 0.237 | 87.1 |
| 40.5 | edges/coral_sea_outer_tr.png | 120x82 | 0.0 | 0.164 | 0.235 | 87.7 |
| 40.4 | edges/dirt_pavement_outer_tr.png | 123x88 | 0.0 | 0.164 | 0.237 | 87.5 |
| 39.7 | edges/ash_lava_inner_tr.png | 124x79 | 0.0 | 0.169 | 0.244 | 90.9 |
| 39.3 | edges/bog_bogwater_inner_tl.png | 119x193 | 0.0 | 0.179 | 0.235 | 72.0 |
| 39.1 | edges/grass_sand_outer_tl.png | 120x88 | 0.0 | 0.171 | 0.253 | 95.7 |
| 39.0 | edges/bog_bogwater_strip.png | 520x193 | 0.0 | 0.177 | 0.244 | 60.2 |
| 38.4 | edges/ash_lava_inner_tl.png | 120x79 | 0.0 | 0.179 | 0.252 | 93.0 |
| 38.3 | edges/ash_lava_strip.png | 456x169 | 0.0 | 0.164 | 0.236 | 51.8 |
| 38.2 | edges/grass_forest_outer_tl.png | 120x84 | 0.0 | 0.178 | 0.258 | 95.6 |
| 37.9 | edges/bog_bogwater_inner_tr.png | 117x193 | 0.0 | 0.188 | 0.248 | 74.7 |
| 37.8 | edges/bog_bogwater_outer_tl.png | 119x193 | 0.0 | 0.188 | 0.25 | 77.6 |
| 37.5 | edges/dirt_pavement_inner_tl.png | 120x80 | 0.0 | 0.183 | 0.265 | 77.7 |

## emotes

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 31.8 | emotes/bubble_c.png | 50x40 | 0.0 | 0.208 | 0.193 | 33.2 |
| 31.4 | emotes/talk.png | 192x38 | 0.0 | 0.2 | 0.222 | 33.6 |
| 31.3 | emotes/bubble_b.png | 50x40 | 0.0 | 0.212 | 0.196 | 33.0 |
| 31.3 | emotes/bubble_a.png | 50x40 | 0.0 | 0.206 | 0.199 | 31.2 |
| 30.8 | emotes/think.png | 168x42 | 0.0 | 0.235 | 0.268 | 51.5 |
| 30.2 | emotes/bubble_think.png | 49x40 | 0.0 | 0.224 | 0.211 | 35.2 |
| 29.6 | emotes/surprise.png | 168x42 | 0.0 | 0.258 | 0.296 | 59.6 |
| 29.4 | emotes/sweat.png | 168x42 | 0.0 | 0.252 | 0.315 | 61.3 |
| 28.7 | emotes/heart.png | 168x42 | 0.0 | 0.259 | 0.316 | 67.5 |
| 27.6 | emotes/music.png | 168x42 | 0.0 | 0.262 | 0.291 | 52.0 |
| 26.7 | emotes/confused.png | 168x42 | 0.0 | 0.276 | 0.308 | 56.2 |
| 26.3 | emotes/sleep.png | 168x42 | 0.0 | 0.284 | 0.324 | 61.4 |
| 25.8 | emotes/idea.png | 168x42 | 0.0 | 0.281 | 0.34 | 65.8 |
| 23.7 | emotes/heart_broken.png | 168x42 | 0.0 | 0.294 | 0.363 | 72.8 |
| 22.1 | emotes/coin.png | 168x43 | 0.0 | 0.312 | 0.362 | 66.2 |
| 20.4 | emotes/angry.png | 168x41 | 0.0 | 0.333 | 0.361 | 63.3 |
| 20.4 | emotes/bubble_dots.png | 456x40 | 0.0 | 0.336 | 0.34 | 57.3 |
| 20.0 | emotes/star.png | 168x43 | 0.0 | 0.331 | 0.373 | 62.7 |
| 19.5 | emotes/skull.png | 168x42 | 0.0 | 0.327 | 0.394 | 64.2 |
| 19.3 | emotes/cry.png | 168x42 | 0.0 | 0.337 | 0.38 | 70.2 |
| 17.7 | emotes/laugh.png | 168x42 | 0.0 | 0.339 | 0.409 | 71.1 |
| 17.5 | emotes/gift.png | 168x42 | 0.0 | 0.338 | 0.417 | 78.0 |
| 15.0 | emotes/hero_laugh.png | 532x48 | 0.0 | 0.418 | 0.519 | 95.2 |
| 15.0 | emotes/hero_nod.png | 80x48 | 0.0 | 0.396 | 0.5 | 97.4 |
| 15.0 | emotes/hero_wave.png | 264x48 | 0.0 | 0.389 | 0.493 | 96.4 |

## faces

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 43.3 | faces/face_6.png | 82x77 | 0.0 | 0.158 | 0.184 | 68.1 |
| 43.3 | faces/face_1.png | 82x77 | 0.0 | 0.162 | 0.177 | 72.1 |
| 43.2 | faces/face_0.png | 82x77 | 0.0 | 0.163 | 0.175 | 72.9 |
| 42.4 | faces/face_10.png | 83x77 | 0.02 | 0.179 | 0.19 | 71.4 |
| 42.4 | faces/face_15.png | 84x77 | 0.0 | 0.166 | 0.189 | 72.5 |
| 42.1 | faces/face_14.png | 84x77 | 0.0 | 0.171 | 0.19 | 70.5 |
| 41.5 | faces/face_5.png | 84x77 | 0.0 | 0.175 | 0.191 | 69.4 |
| 41.5 | faces/face_13.png | 84x77 | 0.0 | 0.174 | 0.193 | 69.8 |
| 41.4 | faces/face_11.png | 81x77 | 0.0 | 0.18 | 0.185 | 71.5 |
| 40.9 | faces/face_12.png | 81x77 | 0.0 | 0.181 | 0.196 | 70.0 |
| 40.8 | faces/face_7.png | 77x77 | 0.0 | 0.179 | 0.2 | 72.9 |
| 40.0 | faces/face_9.png | 81x77 | 0.0 | 0.191 | 0.194 | 70.7 |
| 39.7 | faces/face_8.png | 83x77 | 0.0 | 0.191 | 0.199 | 70.2 |
| 39.6 | faces/face_4.png | 82x77 | 0.0 | 0.192 | 0.202 | 70.1 |
| 39.3 | faces/face_2.png | 83x77 | 0.0 | 0.2 | 0.198 | 70.6 |
| 39.2 | faces/face_3.png | 82x77 | 0.0 | 0.194 | 0.207 | 71.0 |

## fx

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 94.5 | fx/aurora2.png | 2048x128 | 1.54 | 0.034 | 0.058 | 68.8 |
| 90.3 | fx/rainbow.png | 535x168 | 1.5 | 0.066 | 0.089 | 59.8 |
| 89.7 | fx/wx_156.png | 535x168 | 1.12 | 0.068 | 0.09 | 58.0 |
| 89.1 | fx/aurora.png | 1044x128 | 0.8 | 0.068 | 0.114 | 76.7 |
| 87.2 | fx/cloud_shadow_2.png | 315x114 | 1.16 | 0.082 | 0.103 | 55.1 |
| 86.3 | fx/cloud_shadow_1.png | 200x99 | 1.31 | 0.098 | 0.119 | 61.6 |
| 82.8 | fx/cloud_shadow_0.png | 150x84 | 1.4 | 0.117 | 0.161 | 63.1 |
| 82.7 | fx/wx_157.png | 201x141 | 1.15 | 0.122 | 0.154 | 60.7 |
| 81.8 | fx/godrays_a.png | 201x141 | 1.5 | 0.129 | 0.161 | 60.8 |
| 81.3 | fx/levelup2.png | 744x195 | 0.61 | 0.132 | 0.166 | 60.3 |
| 81.0 | fx/stink_cloud.png | 416x64 | 1.23 | 0.125 | 0.187 | 81.5 |
| 80.4 | fx/wx_145.png | 141x79 | 0.82 | 0.14 | 0.172 | 88.1 |
| 80.2 | fx/wx_38.png | 753x121 | 0.64 | 0.065 | 0.088 | 18.9 |
| 79.8 | fx/wx_159.png | 169x103 | 1.51 | 0.146 | 0.172 | 63.6 |
| 79.4 | fx/godrays_b.png | 169x103 | 1.77 | 0.152 | 0.172 | 63.0 |
| 79.3 | fx/gift_dark_burst.png | 768x55 | 1.34 | 0.141 | 0.193 | 89.8 |
| 79.3 | fx/wx_144.png | 145x77 | 0.89 | 0.149 | 0.178 | 89.8 |
| 79.0 | fx/gift_shade.png | 768x64 | 1.3 | 0.137 | 0.208 | 84.2 |
| 75.9 | fx/wx_02.png | 746x93 | 1.46 | 0.167 | 0.196 | 55.9 |
| 75.6 | fx/cloud_shadow.png | 1024x160 | 1.99 | 0.08 | 0.074 | 2.8 |
| 73.3 | fx/gift_gale.png | 768x45 | 1.17 | 0.188 | 0.238 | 89.6 |
| 72.9 | fx/wx_146.png | 150x86 | 0.57 | 0.168 | 0.243 | 88.4 |
| 72.2 | fx/cy_blackout.png | 768x62 | 1.24 | 0.188 | 0.263 | 85.1 |
| 71.3 | fx/wx_123.png | 378x77 | 1.72 | 0.198 | 0.265 | 79.9 |
| 70.2 | fx/catship_loop.png | 354x96 | 1.14 | 0.21 | 0.266 | 93.9 |
| 69.7 | fx/wx_44.png | 42x41 | 0.56 | 0.168 | 0.298 | 98.3 |
| 68.9 | fx/tail_shimmer.png | 354x96 | 1.17 | 0.206 | 0.301 | 92.6 |
| 67.4 | fx/cy_scramble.png | 768x64 | 1.18 | 0.24 | 0.27 | 94.0 |
| 67.3 | fx/lightning_flash.png | 744x114 | 0.2 | 0.039 | 0.058 | 45.4 |
| 67.3 | fx/wx_01.png | 755x136 | 0.2 | 0.039 | 0.058 | 45.4 |
| 64.7 | fx/grumpship_loop.png | 312x96 | 1.12 | 0.241 | 0.329 | 93.7 |
| 64.7 | fx/st_steam.png | 144x43 | 1.2 | 0.241 | 0.331 | 73.6 |
| 64.5 | fx/st_sparks.png | 244x80 | 1.13 | 0.266 | 0.286 | 86.0 |
| 63.5 | fx/gift_guard.png | 768x47 | 1.19 | 0.26 | 0.32 | 87.5 |
| 62.6 | fx/cy_drone_scan.png | 768x50 | 1.21 | 0.27 | 0.321 | 93.0 |
| 62.5 | fx/merkitty_a.png | 180x64 | 1.18 | 0.252 | 0.358 | 97.8 |
| 62.2 | fx/wx_25.png | 53x37 | 0.64 | 0.349 | 0.178 | 100.0 |
| 61.9 | fx/gift_splinter.png | 768x64 | 1.1 | 1.539 | 0.182 | 82.2 |
| 61.0 | fx/st_smoke.png | 280x91 | 1.19 | 0.276 | 0.344 | 91.9 |
| 60.9 | fx/gift_yield.png | 768x64 | 1.24 | 0.272 | 0.355 | 97.1 |

## hair

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 68.5 | hair/flower_braid_c.png | 1536x96 | 0.71 | 0.207 | 0.309 | 67.7 |
| 67.3 | hair/bow_c.png | 1536x96 | 0.83 | 0.219 | 0.313 | 73.9 |
| 50.0 | hair/layered.png | 1536x96 | 0.31 | 0.22 | 0.314 | 59.3 |
| 49.1 | hair/braid_c.png | 1536x96 | 0.29 | 0.218 | 0.321 | 72.3 |
| 37.1 | hair/bob_b.png | 1536x96 | 0.01 | 0.187 | 0.279 | 64.4 |
| 36.6 | hair/wild_b.png | 1536x96 | 0.01 | 0.191 | 0.284 | 62.6 |
| 36.2 | hair/shaggy_b.png | 1536x96 | 0.01 | 0.19 | 0.287 | 65.4 |
| 35.8 | hair/wavy_b.png | 1536x96 | 0.01 | 0.196 | 0.292 | 62.5 |
| 35.4 | hair/spiky_b.png | 1536x96 | 0.01 | 0.199 | 0.296 | 66.1 |
| 35.3 | hair/ponytail_c.png | 1536x96 | 0.09 | 0.235 | 0.331 | 66.5 |
| 35.1 | hair/shaggy.png | 1536x96 | 0.01 | 0.206 | 0.285 | 61.4 |
| 34.5 | hair/ponytail_b.png | 1536x96 | 0.01 | 0.209 | 0.303 | 63.2 |
| 34.4 | hair/braid.png | 1536x96 | 0.07 | 0.234 | 0.33 | 65.7 |
| 34.1 | hair/bun_b.png | 1536x96 | 0.01 | 0.212 | 0.305 | 69.4 |
| 33.9 | hair/pigtails_b.png | 1536x96 | 0.01 | 0.212 | 0.306 | 67.3 |
| 33.7 | hair/long_wavy.png | 1536x96 | 0.01 | 0.213 | 0.299 | 58.6 |
| 33.6 | hair/layered_c.png | 1536x96 | 0.0 | 0.212 | 0.305 | 64.7 |
| 33.5 | hair/shaggy_c.png | 1536x96 | 0.01 | 0.214 | 0.307 | 65.7 |
| 33.4 | hair/spiky.png | 1536x96 | 0.01 | 0.221 | 0.304 | 64.2 |
| 32.7 | hair/buns.png | 1536x96 | 0.01 | 0.226 | 0.305 | 67.0 |
| 31.9 | hair/ponytail.png | 1536x96 | 0.01 | 0.23 | 0.313 | 69.6 |
| 31.3 | hair/spiky_c.png | 1536x96 | 0.01 | 0.23 | 0.33 | 65.5 |
| 29.2 | hair/buns_c.png | 1536x96 | 0.01 | 0.246 | 0.344 | 71.5 |
| 28.7 | hair/headband.png | 1536x96 | 0.01 | 0.253 | 0.345 | 71.7 |

## hats

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 46.7 | hats/witch.png | 1536x96 | 0.25 | 0.227 | 0.309 | 84.3 |
| 43.0 | hats/earmuffs.png | 1536x96 | 0.01 | 0.157 | 0.208 | 79.0 |
| 42.9 | hats/hood.png | 1536x96 | 0.02 | 0.16 | 0.21 | 62.3 |
| 40.1 | hats/cap.png | 1536x96 | 0.01 | 0.173 | 0.235 | 81.4 |
| 39.6 | hats/beanie.png | 1536x96 | 0.01 | 0.17 | 0.252 | 81.0 |
| 35.6 | hats/knight.png | 1536x96 | 0.01 | 0.203 | 0.279 | 69.4 |
| 34.2 | hats/tophat.png | 1536x96 | 0.01 | 0.213 | 0.238 | 51.0 |
| 34.0 | hats/straw.png | 1536x96 | 0.01 | 0.211 | 0.302 | 82.1 |
| 30.2 | hats/bandana.png | 1536x96 | 0.01 | 0.245 | 0.321 | 83.0 |
| 29.9 | hats/flatcap.png | 1536x96 | 0.01 | 0.242 | 0.328 | 66.5 |
| 29.6 | hats/flower_crown.png | 1536x96 | 0.02 | 0.248 | 0.344 | 95.6 |
| 28.8 | hats/crystal_crown.png | 1536x96 | 0.01 | 0.247 | 0.354 | 91.0 |
| 28.6 | hats/cowboy.png | 1536x96 | 0.0 | 0.249 | 0.344 | 77.4 |
| 27.4 | hats/kerchief.png | 1536x96 | 0.01 | 0.257 | 0.369 | 82.6 |
| 26.1 | hats/goggles.png | 1536x96 | 0.01 | 0.279 | 0.357 | 90.0 |
| 26.1 | hats/halo.png | 1536x96 | 0.07 | 0.302 | 0.389 | 80.8 |

## hats_poses

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 34.5 | hats_poses/aurora_hood.png | 608x39 | 0.0 | 0.223 | 0.256 | 95.0 |
| 25.4 | hats_poses/fedora.png | 576x30 | 0.0 | 0.283 | 0.345 | 61.0 |
| 20.6 | hats_poses/moon_helm.png | 576x40 | 0.0 | 0.307 | 0.407 | 90.9 |
| 20.4 | hats_poses/snow_goggles.png | 576x30 | 0.0 | 0.295 | 0.433 | 96.3 |
| 15.6 | hats_poses/crystal_helm.png | 576x41 | 0.0 | 0.377 | 0.437 | 93.2 |
| 15.0 | hats_poses/gold_helm.png | 576x47 | 0.0 | 0.372 | 0.46 | 95.2 |
| 15.0 | hats_poses/silver_helm.png | 640x44 | 0.0 | 0.448 | 0.556 | 91.5 |
| 15.0 | hats_poses/shades.png | 544x16 | 0.0 | 0.35 | 0.478 | 89.1 |

## helpers

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 47.9 | helpers/shade_crystal_act_2.png | 119x105 | 0.0 | 0.131 | 0.133 | 84.9 |
| 46.0 | helpers/shade_crystal_act_1.png | 119x100 | 0.0 | 0.139 | 0.16 | 82.9 |
| 44.7 | helpers/shade_crystal_idle_2.png | 89x104 | 0.0 | 0.145 | 0.178 | 92.9 |
| 44.3 | helpers/shade_crystal_act_0.png | 95x102 | 0.0 | 0.151 | 0.173 | 87.8 |
| 43.5 | helpers/shade_crystal_idle_0.png | 87x100 | 0.0 | 0.157 | 0.18 | 92.5 |
| 43.3 | helpers/shade_drone_act_3.png | 163x91 | 0.0 | 0.157 | 0.184 | 84.8 |
| 43.2 | helpers/shade_crystal_hurt_1.png | 94x98 | 0.0 | 0.154 | 0.193 | 92.9 |
| 42.8 | helpers/shade_crystal_act_3.png | 130x101 | 0.0 | 0.16 | 0.19 | 71.3 |
| 42.2 | helpers/shade_crystal_hurt_0.png | 99x112 | 0.0 | 0.166 | 0.192 | 91.5 |
| 42.0 | helpers/shade_crystal_idle_3.png | 85x105 | 0.0 | 0.175 | 0.18 | 92.2 |
| 41.7 | helpers/shade_crystal_idle_1.png | 91x99 | 0.0 | 0.177 | 0.183 | 92.8 |
| 39.1 | helpers/shade_drone_act_2.png | 133x91 | 0.0 | 0.188 | 0.22 | 89.8 |
| 39.0 | helpers/striker_crystal_act_3.png | 144x80 | 0.0 | 0.18 | 0.238 | 94.1 |
| 38.2 | helpers/healer_crystal_act_2.png | 141x103 | 0.0 | 0.193 | 0.231 | 95.9 |
| 38.2 | helpers/warden_crystal_act_1.png | 112x97 | 0.0 | 0.192 | 0.233 | 90.4 |
| 38.0 | helpers/healer_crystal_act_0.png | 102x102 | 0.0 | 0.188 | 0.244 | 95.4 |
| 37.7 | helpers/shade_drone_hurt_1.png | 108x91 | 0.0 | 0.197 | 0.235 | 96.4 |
| 37.7 | helpers/warden_crystal_act_2.png | 116x101 | 0.0 | 0.196 | 0.235 | 92.1 |
| 37.3 | helpers/shade_drone_hurt_0.png | 114x101 | 0.0 | 0.206 | 0.225 | 96.0 |
| 37.3 | helpers/healer_crystal_act_3.png | 128x96 | 0.0 | 0.197 | 0.244 | 95.0 |
| 37.0 | helpers/striker_crystal_act_1.png | 125x98 | 0.0 | 0.197 | 0.25 | 96.4 |
| 37.0 | helpers/warden_crystal_idle_0.png | 89x104 | 0.0 | 0.2 | 0.243 | 93.4 |
| 37.0 | helpers/healer_crystal_act_1.png | 124x99 | 0.0 | 0.202 | 0.241 | 94.3 |
| 36.8 | helpers/warden_crystal_idle_1.png | 94x97 | 0.0 | 0.199 | 0.249 | 94.2 |
| 36.5 | helpers/healer_crystal_idle_3.png | 86x105 | 0.0 | 0.202 | 0.251 | 97.2 |
| 36.5 | helpers/warden_crystal_hurt_1.png | 97x98 | 0.0 | 0.202 | 0.251 | 93.6 |
| 36.4 | helpers/healer_crystal_idle_1.png | 96x101 | 0.0 | 0.203 | 0.251 | 95.8 |
| 36.4 | helpers/striker_crystal_act_2.png | 151x100 | 0.0 | 0.201 | 0.256 | 96.8 |
| 36.4 | helpers/warden_crystal_act_0.png | 101x100 | 0.0 | 0.205 | 0.248 | 92.8 |
| 36.3 | helpers/warden_crystal_idle_2.png | 91x104 | 0.0 | 0.204 | 0.252 | 94.2 |
| 36.0 | helpers/warden_crystal_idle_3.png | 83x103 | 0.0 | 0.211 | 0.246 | 93.2 |
| 35.8 | helpers/healer_crystal_idle_0.png | 89x105 | 0.0 | 0.211 | 0.25 | 96.3 |
| 35.7 | helpers/shade_drone_act_1.png | 128x84 | 0.0 | 0.206 | 0.261 | 96.2 |
| 35.4 | helpers/healer_crystal_idle_2.png | 90x105 | 0.0 | 0.213 | 0.255 | 96.4 |
| 35.2 | helpers/healer_crystal_hurt_0.png | 91x112 | 0.0 | 0.209 | 0.266 | 94.4 |
| 35.1 | helpers/healer_crystal_hurt_1.png | 97x97 | 0.0 | 0.216 | 0.257 | 96.2 |
| 35.0 | helpers/warden_crystal_hurt_0.png | 92x112 | 0.0 | 0.209 | 0.272 | 94.6 |
| 34.0 | helpers/healer_drone_act_3.png | 111x89 | 0.0 | 0.226 | 0.262 | 97.3 |
| 33.9 | helpers/shade_drone_act_0.png | 106x84 | 0.0 | 0.219 | 0.277 | 94.9 |
| 33.8 | helpers/warden_crystal_act_3.png | 122x108 | 0.0 | 0.219 | 0.279 | 87.1 |

## icons_hair

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 50.4 | icons_hair/layered_c.png | 32x31 | 1.48 | 0.345 | 0.47 | 99.2 |
| 50.0 | icons_hair/bob_b.png | 32x25 | 1.31 | 0.447 | 0.549 | 99.0 |
| 50.0 | icons_hair/buns_c.png | 31x32 | 1.28 | 0.374 | 0.558 | 98.6 |
| 50.0 | icons_hair/spiky.png | 32x26 | 1.39 | 0.429 | 0.625 | 99.8 |
| 50.0 | icons_hair/buns.png | 32x26 | 1.29 | 0.403 | 0.562 | 99.4 |
| 50.0 | icons_hair/shaggy_b.png | 32x30 | 1.41 | 0.445 | 0.603 | 99.0 |
| 50.0 | icons_hair/ponytail_b.png | 24x32 | 1.35 | 0.443 | 0.65 | 99.8 |
| 50.0 | icons_hair/bow_c.png | 28x32 | 1.54 | 0.426 | 0.63 | 99.8 |
| 50.0 | icons_hair/shaggy.png | 32x27 | 1.4 | 0.429 | 0.554 | 99.6 |
| 50.0 | icons_hair/spiky_c.png | 32x30 | 1.5 | 0.419 | 0.56 | 99.0 |
| 50.0 | icons_hair/flower_braid_c.png | 29x32 | 1.41 | 0.453 | 0.618 | 99.4 |
| 50.0 | icons_hair/spiky_b.png | 32x30 | 1.46 | 0.381 | 0.568 | 99.1 |
| 50.0 | icons_hair/layered.png | 31x32 | 1.46 | 0.47 | 0.663 | 99.4 |
| 50.0 | icons_hair/ponytail_c.png | 26x32 | 1.38 | 0.448 | 0.636 | 98.6 |
| 50.0 | icons_hair/braid_c.png | 23x32 | 1.49 | 0.417 | 0.568 | 100.0 |
| 50.0 | icons_hair/wild_b.png | 30x32 | 1.48 | 0.392 | 0.56 | 99.2 |
| 50.0 | icons_hair/wavy_b.png | 28x32 | 1.43 | 0.46 | 0.63 | 99.2 |
| 50.0 | icons_hair/ponytail.png | 28x32 | 1.26 | 0.48 | 0.613 | 99.4 |
| 50.0 | icons_hair/braid.png | 31x32 | 1.3 | 0.45 | 0.583 | 98.9 |
| 50.0 | icons_hair/bun_b.png | 25x32 | 1.39 | 0.501 | 0.668 | 98.8 |
| 50.0 | icons_hair/shaggy_c.png | 32x30 | 1.42 | 0.379 | 0.547 | 99.4 |
| 50.0 | icons_hair/pigtails_b.png | 22x32 | 1.37 | 0.364 | 0.528 | 98.8 |
| 50.0 | icons_hair/long_wavy.png | 32x31 | 1.31 | 0.426 | 0.575 | 98.1 |
| 50.0 | icons_hair/headband.png | 31x32 | 1.49 | 0.46 | 0.632 | 99.4 |

## mounts

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 48.1 | mounts/llama_ridden.png | 1904x112 | 0.22 | 0.206 | 0.269 | 83.9 |
| 38.1 | mounts/horse.png | 1904x112 | 0.01 | 0.187 | 0.254 | 72.4 |
| 36.0 | mounts/donkey.png | 1904x112 | 0.01 | 0.202 | 0.27 | 70.0 |
| 34.1 | mounts/llama.png | 1904x112 | 0.04 | 0.233 | 0.299 | 76.9 |
| 33.8 | mounts/rider_horse.png | 1904x112 | 0.0 | 0.22 | 0.283 | 89.5 |
| 33.7 | mounts/rider_donkey.png | 1904x112 | 0.01 | 0.222 | 0.282 | 89.9 |
| 26.6 | mounts/saddle_donkey.png | 1904x112 | 0.0 | 0.27 | 0.349 | 88.2 |
| 24.6 | mounts/saddle_horse.png | 1904x112 | 0.0 | 0.285 | 0.364 | 86.7 |

## portraits

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 76.1 | portraits/face/beard_short.png | 76x96 | 0.82 | 0.167 | 0.217 | 81.9 |
| 75.1 | portraits/eyes/eyes_9.png | 86x96 | 0.83 | 0.176 | 0.222 | 74.8 |
| 75.0 | portraits/face/sunglasses.png | 72x96 | 0.87 | 0.177 | 0.222 | 82.4 |
| 74.8 | portraits/eyes/eyes_10.png | 86x96 | 0.82 | 0.179 | 0.222 | 74.3 |
| 74.8 | portraits/eyes/eyes_7.png | 86x96 | 0.81 | 0.179 | 0.223 | 74.6 |
| 74.7 | portraits/eyes/eyes_8.png | 86x96 | 0.84 | 0.179 | 0.223 | 74.7 |
| 74.3 | portraits/eyes/eyes_6.png | 85x96 | 0.82 | 0.185 | 0.222 | 72.6 |
| 74.3 | portraits/eyes/eyes_11.png | 86x96 | 0.87 | 0.183 | 0.224 | 74.2 |
| 74.1 | portraits/eyes/eyes_24.png | 78x96 | 0.87 | 0.183 | 0.229 | 74.1 |
| 74.0 | portraits/eyes/eyes_38.png | 78x96 | 0.85 | 0.184 | 0.23 | 72.8 |
| 73.9 | portraits/eyes/eyes_42.png | 80x96 | 0.87 | 0.184 | 0.231 | 72.8 |
| 73.9 | portraits/eyes/eyes_18.png | 82x96 | 1.05 | 0.186 | 0.229 | 72.7 |
| 73.8 | portraits/eyes/eyes_36.png | 79x96 | 0.84 | 0.189 | 0.226 | 71.1 |
| 73.5 | portraits/eyes/eyes_45.png | 78x96 | 0.84 | 0.186 | 0.237 | 75.4 |
| 73.4 | portraits/eyes/eyes_47.png | 80x96 | 0.85 | 0.186 | 0.239 | 74.3 |
| 73.3 | portraits/face/beard_long.png | 77x96 | 0.89 | 0.192 | 0.23 | 80.4 |
| 73.3 | portraits/eyes/eyes_23.png | 84x96 | 1.04 | 0.191 | 0.233 | 73.4 |
| 73.3 | portraits/eyes/eyes_20.png | 83x96 | 1.01 | 0.192 | 0.231 | 75.1 |
| 73.2 | portraits/eyes/eyes_0.png | 84x96 | 0.85 | 0.192 | 0.234 | 76.2 |
| 73.2 | portraits/eyes/eyes_21.png | 82x96 | 0.99 | 0.193 | 0.231 | 74.8 |
| 73.2 | portraits/eyes/eyes_40.png | 78x96 | 0.87 | 0.191 | 0.234 | 71.8 |
| 73.1 | portraits/eyes/eyes_46.png | 80x96 | 0.85 | 0.19 | 0.24 | 73.5 |
| 73.1 | portraits/eyes/eyes_44.png | 79x96 | 0.85 | 0.192 | 0.236 | 74.5 |
| 73.1 | portraits/eyes/eyes_43.png | 79x96 | 0.87 | 0.193 | 0.233 | 73.4 |
| 73.1 | portraits/eyes/eyes_19.png | 83x96 | 1.03 | 0.193 | 0.233 | 71.9 |
| 72.9 | portraits/face/blush.png | 76x96 | 0.88 | 0.19 | 0.242 | 78.6 |
| 72.9 | portraits/eyes/eyes_39.png | 79x96 | 0.9 | 0.194 | 0.234 | 72.2 |
| 72.9 | portraits/eyes/eyes_3.png | 84x96 | 1.03 | 0.19 | 0.243 | 74.7 |
| 72.9 | portraits/hero_dark_broad/neutral.png | 96x90 | 1.13 | 0.195 | 0.233 | 75.9 |
| 72.8 | portraits/eyes/eyes_14.png | 80x96 | 1.07 | 0.191 | 0.243 | 75.8 |
| 72.7 | portraits/face/earrings_a.png | 78x96 | 0.85 | 0.192 | 0.244 | 77.6 |
| 72.7 | portraits/face/scar.png | 77x96 | 0.85 | 0.198 | 0.233 | 81.0 |
| 72.7 | portraits/eyes/eyes_22.png | 83x96 | 1.06 | 0.197 | 0.234 | 73.4 |
| 72.7 | portraits/eyes/eyes_41.png | 78x96 | 0.88 | 0.195 | 0.238 | 73.3 |
| 72.7 | portraits/eyes/eyes_25.png | 79x96 | 0.9 | 0.194 | 0.241 | 74.7 |
| 72.5 | portraits/face/face_paint_b.png | 75x96 | 0.99 | 0.2 | 0.233 | 77.3 |
| 72.5 | portraits/eyes/eyes_12.png | 81x96 | 1.0 | 0.2 | 0.234 | 72.8 |
| 72.5 | portraits/eyes/eyes_17.png | 82x96 | 1.09 | 0.195 | 0.243 | 75.7 |
| 72.5 | portraits/hero_dark_slim/tired.png | 89x96 | 1.03 | 0.206 | 0.219 | 72.0 |
| 72.4 | portraits/face/face_paint_a.png | 78x96 | 0.9 | 0.196 | 0.241 | 78.7 |

## riding

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 44.2 | riding/mount_misc.png | 1280x128 | 0.12 | 0.19 | 0.259 | 78.5 |
| 37.6 | riding/horse_updown.png | 1280x128 | 0.04 | 0.206 | 0.271 | 82.7 |
| 36.1 | riding/horse_side.png | 1280x128 | 0.0 | 0.198 | 0.271 | 79.2 |
| 34.4 | riding/donkey_side.png | 1280x128 | 0.0 | 0.209 | 0.291 | 80.9 |
| 34.4 | riding/llama_side.png | 1280x128 | 0.0 | 0.212 | 0.286 | 79.8 |
| 34.1 | riding/llama_updown.png | 1280x128 | 0.01 | 0.219 | 0.285 | 83.5 |
| 33.2 | riding/donkey_updown.png | 1280x128 | 0.0 | 0.224 | 0.288 | 82.7 |
| 32.6 | riding/stable_items.png | 1280x128 | 0.0 | 0.223 | 0.304 | 88.9 |

## stairs

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 47.4 | stairs/stair_snow.png | 350x369 | 0.0 | 0.114 | 0.149 | 55.2 |
| 43.8 | stairs/stair_crystal.png | 350x381 | 0.0 | 0.147 | 0.195 | 84.3 |
| 41.2 | stairs/stair_stone_wide.png | 396x350 | 0.0 | 0.163 | 0.221 | 74.9 |
| 40.7 | stairs/ramp_dirt_wide.png | 398x349 | 0.0 | 0.164 | 0.232 | 75.3 |
| 40.6 | stairs/ramp_dirt.png | 297x350 | 0.0 | 0.164 | 0.233 | 81.3 |
| 40.3 | stairs/stair_stone.png | 300x349 | 0.0 | 0.171 | 0.226 | 80.7 |
| 38.4 | stairs/stair_wood.png | 322x380 | 0.0 | 0.185 | 0.241 | 79.8 |
| 33.2 | stairs/stair_iron.png | 376x390 | 0.0 | 0.225 | 0.282 | 65.2 |

## toolanim

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 56.8 | toolanim/sword_moon.png | 1536x96 | 0.45 | 0.23 | 0.33 | 94.2 |
| 55.2 | toolanim/sword_crystal.png | 1536x96 | 0.36 | 0.212 | 0.288 | 91.7 |
| 54.0 | toolanim/sword_steel.png | 1536x96 | 0.33 | 0.205 | 0.286 | 90.4 |
| 51.7 | toolanim/rod_iron.png | 1536x96 | 0.46 | 0.267 | 0.392 | 91.6 |
| 50.9 | toolanim/sword_iron.png | 1536x96 | 0.22 | 0.18 | 0.264 | 89.0 |
| 50.9 | toolanim/rod_copper.png | 1536x96 | 0.46 | 0.273 | 0.398 | 92.8 |
| 50.6 | toolanim/sword_copper.png | 1536x96 | 0.17 | 0.167 | 0.228 | 93.7 |
| 50.6 | toolanim/sword_wood.png | 1536x96 | 0.19 | 0.175 | 0.231 | 92.7 |
| 49.5 | toolanim/scythe_crystal.png | 1536x96 | 0.2 | 0.179 | 0.264 | 94.0 |
| 49.5 | toolanim/hammer_wood.png | 1536x96 | 0.17 | 0.171 | 0.245 | 87.8 |
| 49.4 | toolanim/rod_steel.png | 1536x96 | 0.45 | 0.279 | 0.403 | 93.1 |
| 48.7 | toolanim/rod_gold.png | 1536x96 | 0.46 | 0.286 | 0.418 | 94.3 |
| 47.5 | toolanim/sword_gold.png | 1536x96 | 0.21 | 0.204 | 0.281 | 92.8 |
| 47.4 | toolanim/hammer_crystal.png | 1536x96 | 0.15 | 0.172 | 0.255 | 87.5 |
| 47.1 | toolanim/rod_silver.png | 1536x96 | 0.46 | 0.303 | 0.428 | 90.1 |
| 47.1 | toolanim/rod_wood.png | 1536x96 | 0.45 | 0.293 | 0.424 | 91.6 |
| 46.3 | toolanim/scythe_moon.png | 1536x96 | 0.21 | 0.204 | 0.308 | 90.5 |
| 45.5 | toolanim/hammer_moon.png | 1536x96 | 0.14 | 0.184 | 0.273 | 87.3 |
| 45.3 | toolanim/hammer_silver.png | 1536x96 | 0.06 | 0.157 | 0.219 | 77.0 |
| 44.6 | toolanim/rod_crystal.png | 1536x96 | 0.38 | 0.285 | 0.408 | 95.8 |
| 43.6 | toolanim/scythe_silver.png | 1536x96 | 0.1 | 0.184 | 0.265 | 90.0 |
| 43.6 | toolanim/hammer_iron.png | 1536x96 | 0.06 | 0.165 | 0.24 | 79.1 |
| 43.6 | toolanim/hammer_steel.png | 1536x96 | 0.05 | 0.163 | 0.23 | 80.2 |
| 43.2 | toolanim/hammer_gold.png | 1536x96 | 0.05 | 0.166 | 0.24 | 82.9 |
| 43.2 | toolanim/scythe_steel.png | 1536x96 | 0.12 | 0.19 | 0.279 | 90.4 |
| 43.1 | toolanim/scythe_gold.png | 1536x96 | 0.15 | 0.208 | 0.293 | 89.3 |
| 42.9 | toolanim/sword_silver.png | 1536x96 | 0.16 | 0.213 | 0.289 | 84.7 |
| 41.5 | toolanim/hammer_copper.png | 1536x96 | 0.06 | 0.182 | 0.253 | 82.5 |
| 41.0 | toolanim/rod_moon.png | 1536x96 | 0.31 | 0.278 | 0.405 | 94.9 |
| 40.6 | toolanim/scythe_iron.png | 1536x96 | 0.11 | 0.202 | 0.301 | 88.2 |
| 37.4 | toolanim/scythe_wood.png | 1536x96 | 0.1 | 0.224 | 0.323 | 90.2 |
| 36.5 | toolanim/scythe_copper.png | 1536x96 | 0.09 | 0.226 | 0.33 | 89.1 |
| 34.8 | toolanim/axe_silver.png | 1536x96 | 0.01 | 0.208 | 0.291 | 80.4 |
| 34.6 | toolanim/axe_iron.png | 1536x96 | 0.01 | 0.208 | 0.297 | 87.1 |
| 34.1 | toolanim/axe_crystal.png | 1536x96 | 0.01 | 0.215 | 0.297 | 90.5 |
| 33.7 | toolanim/hoe_silver.png | 1536x96 | 0.02 | 0.213 | 0.316 | 88.5 |
| 33.6 | toolanim/axe_steel.png | 1536x96 | 0.01 | 0.218 | 0.304 | 85.1 |
| 32.7 | toolanim/axe_copper.png | 1536x96 | 0.01 | 0.22 | 0.315 | 89.8 |
| 32.1 | toolanim/axe_wood.png | 1536x96 | 0.01 | 0.228 | 0.319 | 88.9 |
| 32.0 | toolanim/axe_gold.png | 1536x96 | 0.01 | 0.225 | 0.32 | 88.6 |

## wear

| fuzz | file | size | soft rim | detail | grad | colours/100px |
|---|---|---|---|---|---|---|
| 45.6 | wear/iron_cape/view_back.png | 96x96 | 0.0 | 0.137 | 0.174 | 65.7 |
| 43.2 | wear/gold_belt/view_back.png | 96x96 | 0.0 | 0.15 | 0.208 | 91.6 |
| 42.3 | wear/copper_helm/view_back.png | 96x96 | 0.0 | 0.146 | 0.228 | 94.7 |
| 42.2 | wear/iron_cape/walk_down.png | 384x96 | 0.0 | 0.161 | 0.202 | 64.8 |
| 41.7 | wear/copper_cape/view_back.png | 96x96 | 0.0 | 0.156 | 0.223 | 91.5 |
| 41.7 | wear/iron_cape/walk.png | 384x96 | 0.0 | 0.166 | 0.205 | 71.4 |
| 41.2 | wear/iron_cape/idle.png | 96x96 | 0.0 | 0.171 | 0.207 | 79.7 |
| 40.9 | wear/copper_cape/walk.png | 384x96 | 0.0 | 0.161 | 0.233 | 89.6 |
| 40.8 | wear/copper_cape/walk_up.png | 384x96 | 0.0 | 0.162 | 0.232 | 85.8 |
| 40.6 | wear/steel_cape/run.png | 96x96 | 0.0 | 0.158 | 0.245 | 95.7 |
| 40.5 | wear/copper_helm/idle.png | 96x96 | 0.0 | 0.156 | 0.252 | 97.8 |
| 40.3 | wear/iron_cape/view_right.png | 96x96 | 0.0 | 0.174 | 0.219 | 83.7 |
| 40.2 | wear/steel_cape/idle.png | 96x96 | 0.0 | 0.167 | 0.236 | 95.2 |
| 40.1 | wear/iron_cape/walk_up.png | 384x96 | 0.0 | 0.177 | 0.221 | 75.6 |
| 40.1 | wear/steel_cape/view_back.png | 96x96 | 0.0 | 0.162 | 0.247 | 94.3 |
| 39.9 | wear/copper_cape/view_right.png | 96x96 | 0.0 | 0.177 | 0.224 | 95.4 |
| 39.9 | wear/steel_cape/view_right.png | 96x96 | 0.0 | 0.171 | 0.236 | 96.7 |
| 39.7 | wear/gold_belt/walk_up.png | 384x96 | 0.0 | 0.177 | 0.229 | 86.7 |
| 39.5 | wear/copper_helm/walk.png | 384x96 | 0.0 | 0.168 | 0.249 | 95.1 |
| 39.5 | wear/leather_helm/view_back.png | 96x96 | 0.0 | 0.168 | 0.256 | 89.7 |
| 39.5 | wear/leather_helm/walk_up.png | 384x96 | 0.0 | 0.17 | 0.247 | 81.4 |
| 39.3 | wear/copper_cape/run.png | 96x96 | 0.0 | 0.169 | 0.253 | 95.8 |
| 39.3 | wear/copper_helm/walk_up.png | 384x96 | 0.0 | 0.168 | 0.255 | 94.9 |
| 39.1 | wear/leather_helm/idle.png | 96x96 | 0.0 | 0.178 | 0.241 | 86.6 |
| 38.7 | wear/copper_legs/walk_up.png | 384x96 | 0.0 | 0.179 | 0.246 | 86.7 |
| 38.7 | wear/gold_legs/walk_up.png | 384x96 | 0.0 | 0.177 | 0.257 | 94.2 |
| 38.7 | wear/copper_helm/run.png | 96x96 | 0.0 | 0.173 | 0.259 | 98.4 |
| 38.7 | wear/leather_chest/walk_up.png | 384x96 | 0.0 | 0.188 | 0.234 | 85.2 |
| 38.6 | wear/silver_legs/walk_up.png | 384x96 | 0.0 | 0.177 | 0.254 | 89.4 |
| 38.4 | wear/steel_cape/walk_down.png | 384x96 | 0.0 | 0.181 | 0.253 | 93.9 |
| 38.3 | wear/leather_helm/view_right.png | 96x96 | 0.0 | 0.182 | 0.256 | 91.0 |
| 38.2 | wear/leather_helm/walk_down.png | 384x96 | 0.0 | 0.184 | 0.251 | 77.8 |
| 37.8 | wear/copper_legs/view_back.png | 96x96 | 0.0 | 0.185 | 0.255 | 93.0 |
| 37.8 | wear/iron_cape/run.png | 96x96 | 0.01 | 0.189 | 0.26 | 86.2 |
| 37.8 | wear/silver_legs/view_back.png | 96x96 | 0.0 | 0.178 | 0.269 | 94.9 |
| 37.7 | wear/leather_cape/walk_up.png | 384x96 | 0.0 | 0.179 | 0.272 | 74.0 |
| 37.6 | wear/steel_chest/idle.png | 96x96 | 0.0 | 0.183 | 0.268 | 96.5 |
| 37.6 | wear/leather_helm/walk.png | 384x96 | 0.0 | 0.188 | 0.258 | 82.3 |
| 37.5 | wear/iron_chest/view_back.png | 96x96 | 0.0 | 0.186 | 0.265 | 92.1 |
| 37.5 | wear/gold_helm/view_back.png | 96x96 | 0.01 | 0.181 | 0.282 | 96.8 |
