# Trailer: 45 s gameplay trailer (script and shot list)

Built by `bash tools/steam_trailer.sh` (CI manual job; heavy, ~1 GB of raw capture): tools/steam_trailer.gd plays the beats in trailer_shots.json under Godot Movie Maker at 30 fps (scene loads between beats are cut using the recorded segments), an end card is drawn from the library hero and logo, audio/music/title.ogg runs under the whole cut with a 2 s fade-out over the kept game sfx, and the encode meets Steam's spec (H.264/AAC mp4, 1920x1080, 30 fps, 5-12 Mbps, faststart). tools/steam_trailer_test.py checks it with ffprobe. A text-free thumbnail is written from 0:04.

Rules (https://partner.steamgames.com/doc/store/trailer): open on gameplay (viewers decide in under 10 s), player perspective with the HUD, understandable muted, no voice-over; the first trailer feeds Steam's auto micro-trailers. No on-screen copy except the end card (logo + "Coming soon to Steam").

| Time | Beat | What |
|------|------|------|
| 0-3 | b01_gloam_open | Gloamwood at dusk, walk across the lanterns (open on the most striking place, no logo first) |
| 3-7 | b02_farm_work | Farm morning, ripe rows, watering |
| 7-10 | b03_ranch | Coop and barn, animals in the pens |
| 10-13 | b04_town_dusk | Town at dusk, walk past the market stalls |
| 13-16 | b05_market_day | Community farm stage 8, market day |
| 16-19 | b06_fishing | Beach: cast |
| 19-22 | b07_mine | Mine: pickaxe, ore |
| 22-26 | b08_penguin_battle | Penguin-arc battlefield, the team and foes (no blood) |
| 26-28 | b09_neon | Hard cut: the gangster story, Neon at night |
| 28-31 | b10_hideout | The Hideout and crew |
| 31-34 | b11_gang_battle | Gangster battlefield (foes are knocked out, never killed) |
| 34-37 | b12_rec_night | Rec Center at night (the room, not a minigame column) |
| 37-41 | b13-b16 | Seasons montage, 1 s each: spring farm, summer beach, fall orchard, winter farm snow |
| 41-44 | b17_pullback | Farm overview at sunset, camera zoom 0.6, HUD hidden for this beat only |
| 44-46 | end card | Library logo on the hero art, "Coming soon to Steam" |

A 15 s social teaser: beats b01, b02, b09-b10, end card (cut from the same capture).
Known weak beats until other work lands: Neon's east is bare (s1_15-11); battle beats show foes only if the battlefield spawns them at rest (stage a muster when battle staging is added).
