# Store screenshots (1920x1080, tools/steam_shots.gd)

Re-shoot all: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tools/steam_shots.gd -- docs/steam-store/screenshots` (one name to redo a single shot). Each shot is a full scripted state (SHOTS table in the tool): fresh run, no touch pad, tips seen, goal line blank, dialogue/banners/toasts cleared, HUD kept (Steam allows UI). JPG (q92) per shot (PNG=1 also writes PNGs); tools/steam_shots_test.py checks size, count, arcs and all-ages flags.

Upload order (Steamworks Chrome brief): trailer first, then 01, 04, 02, 03, 05, 06, 07, 09, 10, 11, 08. Tick "suitable for all ages" on the rows marked yes (at least 4 needed; gangster-arc shots are left unticked).

| file | what it sells | arc | all-ages | notes |
|------|---------------|-----|----------|-------|
| 01_farm_summer | the built-up farm: tier-3 house, coop, barn, greenhouse, ripe rows | penguins | yes | cam 10:16, 09:00, day 40 |
| 02_town_dusk | a living town with lit windows and lamps | penguins | yes | cam 40:30, 19:00 (framed east of x=34, s1_15-04) |
| 03_community_market | the community farm the town builds together (stage 8) | penguins | yes | 11:00 |
| 04_gloamwood | big-region exploration: Gloamwood lanterns at dusk | penguins | yes | cam 21:24, 18:30 |
| 05_beach | fishing at the beach | penguins | yes | casting |
| 06_neon_night | the gangster story's neon city | gangsters | no | WEAK: east of the map is bare (s1_15-11); swap out once Neon is dressed |
| 07_hideout_crew | the Hideout and crew life | gangsters | no | 18:00 |
| 08_mine_fight | the mines | penguins | yes | floor 1 shows rocks and ore; foes rarely on screen: replace with a staged fight when battle staging lands |
| 09_home_interior | decorating the farmhouse | penguins | yes | interior zoom 2 |
| 10_rec_center | the Rec Center (bowling and arcade) | penguins | yes | interior zoom (fits the room) |
| 11_farm_winter | seasons: the farm under snow | penguins | yes | day 92, snow |

Rules: never use full-screen minigames (arcade/casino are a 270-px column on desktop) as store shots; never use the gangster arc in the cosy town; no marketing text on shots.
