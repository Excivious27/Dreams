# Dreams on Steam

Everything for the Steam release (CONDUCT S1, 2026-11). Assembled by `python3 tools/steam_handoff.py --write`
from the fragments in `docs/steam/` (one per S1 package) plus the generated Chrome brief at the end, which
comes from `steam/handoff.json`. Edit the fragments or the JSON, never this file directly.

The web/phone build is unchanged by all of this: nothing Steam loads on web.

Status words used below: **done** (in the repo and tested), **staged** (written and checked, waiting on
Tom's Steamworks account), **waiting on Tom** (a decision only he makes; never invented).

## Contents

- docs/steam/p1.md
- docs/steam/p2.md
- docs/steam/deck.md
- docs/steam/coop.md
- docs/steam/upload.md
- docs/steam/p6.md
- When Tom's Steamworks account is ready (generated)

<!-- fragment: docs/steam/p1.md -->
## Builds, GodotSteam and web safety (S1 P1)

### Desktop builds
- Export presets: **Linux** (`build/linux/Dreams.x86_64`) and **Windows Desktop** (`build/windows/Dreams.exe`), both x86_64 with the pack embedded. Windows exe icon `art/app/icon.ico` (from `web/icon_512.png`, `tools/make_app_icon.py`), file/product version 0.9.0.0, `application/config/version="0.9.0"` in project.godot.
- Both desktop presets exclude `server/*, steam/*, steam_appid.txt, *.vdf, web/*.py, web/*.js, .github/*, data/.gitkeep` and must NOT exclude `addons/godotsteam` (they ship it).
- CI: `.github/workflows/steam-builds.yml`, its own concurrency group (the web deploy never waits). On every game push to main (and on ci/** pre-merge runs that touch Steam/desktop files):
  1. `tools/stage_godotsteam.sh` copies the addon into `addons/godotsteam`, import;
  2. `tools/steam_load_probe.gd` proves the library loads and that init without a Steam client fails cleanly (`STEAM LOAD: ok ...` in the run summary);
  3. exports Linux + Windows; `build-info.json` {version, sha, run};
  4. Linux headless boot with `-- --boot-probe` (title ms, farm ms after a new game + 600 frames, Steam backend line), Windows headless boot on a windows-latest runner;
  5. `tools/desktop_build_report.py` checks each build (binary, Steam libs beside it, no steam_appid.txt / .pdb / console exe / .import / .gd, size ceiling 850 MB, first launch <= 9 s) and writes the summary table;
  6. artifacts (14 days, never committed): `dreams-linux-x64` (tar.gz, keeps the exec bit), `dreams-windows-x64` (folder), `desktop-reports`, `boot-windows`.
- Measured baseline (S1 audit, sandbox export): Linux 390.6 MB single file, Windows 417.0 MB exe, first launch about 2 s headless, title drawn within 3 s at 1280x800. Local headless boot probe of the project: title at 3.8 s, farm after 600 frames at 4.8 s. CI numbers: see the latest "Steam desktop builds" run summary. System requirements draft: 1 GB free disk.

### GodotSteam
- GodotSteam GDExtension **4.24-gde** (Godot 4.4+ plugin, Steamworks SDK 1.65, MIT) from Codeberg, pinned by sha256 `d4358888959a03f4df0c71aafbcdca8f34b8cb9d4522aa5c8454f0e9e3debbf7` in `tools/fetch_godotsteam.sh`. Only Linux x86_64 and Windows x86_64 libraries (debug + release) are kept, in `steam/godotsteam/` (about 18 MB, with VERSION, SHA256SUMS, license.md and a trimmed `.gdextension`).
- `steam/` has a `.gdignore`: the editor, every check.sh shard, the bots, the playtest and the Web export never see or load the addon. Only desktop exports stage it (`addons/godotsteam/` is gitignored). This keeps the web build byte-identical in behaviour and keeps CI free of GDExtension load errors.
- `SteamSvc` autoload (scripts/steam_service.gd) + `SteamApi` facade (scripts/steam_api.gd). Backend switch is automatic: "steam" when the library is present AND init succeeds, "local" otherwise (`SteamSvc.reason`: web, headless, ci, disabled, no_addon, no_app_id, init_failed ...). All calls are dynamic (`_s.call`), never the singleton's name, so the web build still parses.
- App ids: `APP_ID_RELEASE := 0` (staged). Until it is set, release builds stay local; debug builds (or `DREAMS_STEAM_TEST=1` / `-- --steam-test`) use test app **480** set through the environment in code. No `steam_appid.txt` is needed anywhere; `.gitignore`, the build report and the web guard all reject it.
- API for other packages: achievements (`unlock_achievement`, `is_achievement_unlocked`, `indicate_progress`), stats (`set_stat`, `get_stat`, `store_stats`; dirty stats are stored once per frame), rich presence (`set_rich_presence`, `clear_rich_presence`), `persona_name`, `is_on_deck`, on-screen keyboard (`show_floating_text_input(mode, rect)`, `show_gamepad_text_input(desc, preset, max)` + `SteamSvc.text_input_done`), and `call_steam(method, args)` / `connect_steam(signal, cb)` for lobbies and networking.

### Web build safety (proof it is unchanged)
- `tools/web_export_guard.py --static` (check.sh and deploy.yml): Web preset excludes `addons/godotsteam/*, steam/*, steam_appid.txt, server/*`, extensions and threads stay off; desktop presets as above; `steam/` and `server/` have `.gdignore`; `config/name` stays "Dreams" and no custom user dir (the user:// folder holds every phone/web save, so a store rename must never touch it); no committed addon or app-id file; singleton lint; Web preset options, project.godot [display]/[rendering] and the key [application] values equal `tools/web_baseline.json`.
- `--pck build/web/index.pck` (deploy.yml after the export, and the pre-merge `web-export` job in steam-builds.yml) reads the pack directory and fails on any Steam path. Verified on the live pack (44,473 files): the only finding was `server/package.json`, `server/package-lock.json`, `server/node_modules/ws/package.json`, which S1 now keeps out (server/.gdignore + exclude). That is the one intended change to the web pack.
- Tests: `tools/steam_service_test.gd` (absent no-ops, 480 gate, fake-backend routing, text input relay, stats batching) and the BootProbe block (boots to the title and plays 600 farm frames with backend=local), both in check.sh.

### Staged for Tom's Steamworks account (nothing else to flip)
1. Put the App ID into `APP_ID_RELEASE` in `scripts/steam_service.gd` (one constant). This turns on `restartAppIfNecessary` and real init in release builds; the backend switch stays automatic.
2. Steam Auto-Cloud: the save folder name stays "Dreams" forever (see above). Paths for P2's cloud table: Windows `%APPDATA%/Godot/app_userdata/Dreams`, Linux `~/.local/share/godot/app_userdata/Dreams`.
3. The upload pipeline (P5) consumes the `dreams-linux-x64` tarball (`chmod +x` before building the depot) and the `dreams-windows-x64` folder from the latest green steam-builds run, and must keep excluding steam_appid.txt.

<!-- fragment: docs/steam/p2.md -->
# Steam: achievements, stats, rich presence, cloud saves (S1 P2)

Built without a Steamworks account. Everything that needs Tom's account is in "Staged for the account" at the end.

## Backends

- `scripts/achievements.gd` (class `Achievements`) is the only place that unlocks. Data `data/achievements.json` from `tools/gen_achievements.py` (60 achievements, 17 stats, both arcs, every system). Every achievement is state-derived: `Achievements.scan()` re-checks the run, so old saves (and farms moved in with a save code) unlock retroactively. scan() runs from `GameState.save()`, before the flush, so achievement writes never cost an extra save write.
- Storage is account-wide on the device: SaveGame global `ach` = `{u: {id: day}, s: {stat: value}, end: bits, arcs: bits}`. Stats are only ever raised (Steam window rule); a newer save with less progress never lowers them.
- Local backend: always on (web, phone, desktop). Unlock toast "Achievement: <name>" + sfx `ach_unlock` (falls back to `levelup`) when a map HUD is up and no dialogue is open; skipped headless.
- Steam backend: through the `SteamService` autoload (P1). Achievements calls, only when the method exists: `set_achievement(api)`, `set_stat(name, value)`, `store_stats()`, `set_rich_presence(key, value)`, and reads `is_live()` (or a `live` property) and `overlay_enabled()` (Steam overlay on = no local toast). `Achievements.replay_to_steam()` pushes every local unlock and stat (call it once after SteamService initialises).
- Never fed to Steam: web, headless, env `DREAMS_NO_STEAM=1` (CI, bots, playtest). Never unlocked at all: `Campaign.bypass`, the character test map, runs with `run.test`. A co-op guest (`Net.visiting()`) only evaluates co-op achievements, because the guest's run holds the host's world while visiting.
- Title > Achievements: list of every achievement (unlocked first; hidden ones show "???" and a hint until unlocked; progress "3/12"); rows are focusable buttons so a pad scrolls; B or Back leaves (`scripts/achievement_screen.gd`).
- Save codes: "move everything" (DRMALL) codes carry the list; import merges (union of unlocks, max stats). Old codes still load.

## Achievement icons

- In game: `art/gen/ach/<icon>.png` (64 px) and `<icon>_locked.png`.
- Steam bulk upload: `docs/steam/achievements/<API>_ACHIEVED.png` and `<API>_UNACHIEVED.png`, 256x256 PNG (docs/ has .gdignore, so they never ship). Made by `tools/slice_achievements.py` from `art/incoming/s1p2/ach_sheet_1..5.png`.

## Rich presence

- `data/rich_presence.json` tokens (English) and scene map; `scripts/presence.gd` picks one (Menu, Farm with season and year, Home, Town, Mines, Region with a fixed region name, Hideout, Bowling, Arcade, Casino, Coop with `steam_player_group_size`). Never uses the player's typed farm, town or character names. Pushed on every scan (deduplicated).
- Localization file to upload (Steamworks > Rich Presence): `"lang" { "Language" "english" "Tokens" { "#Farm" "Tending the farm (%season%, year %year%)" ... } }` built from the tokens block, key `#` + token.

## Where saves live (current build, Godot default user dir from the project name "Dreams")

| Platform | Path | Notes |
|---|---|---|
| Web | browser localStorage key `dreams_save` + IDBFS `/userfs` | unchanged, never Steam |
| Windows | `%APPDATA%\Godot\app_userdata\Dreams\` | save.json, save.bak.json |
| Linux / Steam Deck native | `~/.local/share/godot/app_userdata/Dreams/` | Deck: /home/deck/... |
| Deck via Proton | `steamapps/compatdata/<AppID>/pfx/drive_c/users/steamuser/AppData/Roaming/Godot/app_userdata/Dreams/` | only if the Windows build runs |

Files: `save.json` (every slot, globals, achievements; sync it), `save.bak.json` (previous save; optional sync), never sync `save.tmp.json`, `save.bad*.json`, `logs/`, shader caches.
Sizes (S1 auditor measurement): about 30-70 KB per farm late game, under 0.5 MB worst case with three slots; `run.notes` is now capped at the newest 40 (it grew to 131 KB in a day-337 simulation).

Decision (S1 integration, 2026-11-20): keep Godot's default user folder, no custom_user_dir. config/name stays "Dreams" (web_export_guard locks it), so the save folder is app_userdata/Dreams on every platform and the Auto-Cloud rows below are final. No auditor showed a real need: the store title can change freely because the folder follows config/name, not the store name. Pin use_custom_user_dir (with a one-time save move) only if config/name ever has to change. Device-only settings (fullscreen, touch buttons, key/pad bindings, `net_token`) still live in save.json and would sync between PC and Deck; a later split to `user://device.json` is recommended (s1_05-04).

## Achievement and stat tables (enter in Steamworks > Stats & Achievements)

| API name | Name | Description | Hidden (Spoiler) | Arc | Progress stat |
|---|---|---|---|---|---|
| ACH_FIRST_HARVEST | First Sprout | Harvest your first crop. | no | both | - |
| ACH_HARVEST_500 | Bumper Crop | Harvest 500 crops. | no | both | crops_harvested (0..500) |
| ACH_GOLD_STAR | Gold Standard | Harvest a gold-star crop. | no | both | - |
| ACH_BEST_FRIENDS | Best of Friends | Reach 10 hearts with a villager. | no | both | - |
| ACH_BELOVED | Beloved | Reach 5 hearts with 10 different villagers. | no | both | friends_5 (0..10) |
| ACH_SWEETHEARTS | Sweethearts | Start dating someone special. | no | both | - |
| ACH_WEDDING_BELLS | Wedding Bells | Get married. | no | both | - |
| ACH_FIRST_VICTORY | First Victory | Win a campaign battle. | no | both | - |
| ACH_WAY_IS_OPEN | The Way Is Open | Win a whole campaign and open a new region. | no | both | - |
| ACH_SIX_FRONTS | Six Fronts | Win all six campaigns both stories share. | no | both | shared_campaigns (0..6) |
| ACH_CRYSTAL_COMMANDER | Crystal Commander | Win every campaign in the penguins' story, colonies included. | no | penguins | penguin_campaigns (0..8) |
| ACH_ARCADE_REGULAR | Arcade Regular | Play every arcade cabinet at least once. | no | both | - |
| ACH_JUMPER_CHAMPION | Block Jumper Champion | Clear all eight Block Jumper levels. | no | both | - |
| ACH_BREAKING_GROUND | Breaking Ground | Clear the land for the community farm. | no | both | - |
| ACH_MARKET_DAY | Market Day | Finish every stage of the community farm, up to the harvest market. | no | both | cf_stages (0..8) |
| ACH_HALL_OF_WONDERS | Hall of Wonders | Complete the museum. | no | both | - |
| ACH_MASTER_ANGLER | Master Angler | Catch every fish a rod can find. | no | both | - |
| ACH_LEGEND_OF_THE_LAKE | Legend of the Lake | Catch the legendary koi. | yes | both | - |
| ACH_FINDERS_KEEPERS | Finders Keepers | Open a hidden chest. | no | both | - |
| ACH_WAYFARERS_JOURNAL | The Wayfarer's Journal | Find every page of the Wayfarer's Journal. | no | both | - |
| ACH_OFF_THE_PATH | Off the Beaten Path | Find a hidden nook. | yes | both | - |
| ACH_HEART_OF_THE_MOUNTAIN | Heart of the Mountain | Reach the very bottom of the mine. | yes | both | - |
| ACH_NEW_ARRIVAL | New Arrival | Welcome your first farm animal. | no | both | - |
| ACH_GROWING_FAMILY | Growing Family | Have a baby born or an egg hatch on your ranch. | no | both | - |
| ACH_ONE_IN_A_MILLION | One in a Million | Raise a rare-coloured animal. | yes | both | - |
| ACH_BLUE_RIBBON | Blue Ribbon | Win first place at the fair's animal show. | no | both | - |
| ACH_MAKING_IT_HOME | Making It Home | Collect 25 different pieces of home decor. | no | both | decor_pieces (0..25) |
| ACH_MATCHING_SET | Matching Set | Complete a decor set from the catalogue. | no | both | - |
| ACH_THE_FARM_GOES_ON | The Farm Goes On | Finish the penguins' story. | no | penguins | - |
| ACH_LIGHTS_OF_THE_ISLES | Lights of the Isles | Wake all four merkitty colonies. | no | penguins | colonies_saved (0..4) |
| ACH_A_HEART_FOR_THE_KNIGHT | A Heart for the Knight | Choose mercy for the Crystal Knight. | yes | penguins | - |
| ACH_OVER_THE_MOON | Over the Moon | Bring the moon cow home. | yes | penguins | - |
| ACH_G_FIRST_CREW | Strength in Numbers | Recruit your first crew member. | no | gangsters | - |
| ACH_G_FULL_CREW | The Whole Family | Recruit all twelve crew members. | no | gangsters | crew_recruited (0..12) |
| ACH_G_LOYAL | Ride or Die | Finish a crew member's loyalty favour. | no | gangsters | - |
| ACH_G_ALL_LOYAL | Thick as Thieves | Finish every crew member's loyalty favour. | no | gangsters | loyalty_done (0..12) |
| ACH_G_FIRST_TURF | On the Map | Clear a district block and hold it. | no | gangsters | - |
| ACH_G_ALL_TURF | Every Block | Hold all four district blocks at once. | no | gangsters | turf_held (0..4) |
| ACH_G_ALL_HEISTS | Nobody Got Hurt | Pull off all three heists. | no | gangsters | heists_done (0..3) |
| ACH_G_SQUEAKY | Squeaky Clean | Wash $10,000 in face value at the laundromat in one save. | no | gangsters | - |
| ACH_G_GOOD_NEIGHBOUR | Good Neighbour | Turn down or give back every shop offered to you. | no | gangsters | - |
| ACH_G_GOING_HOME | Going Home | Send one of the Marked home. | no | gangsters | - |
| ACH_G_NONE_LEFT | Nobody Left Behind | Every one of the Marked went home. | no | gangsters | marked_home (0..10) |
| ACH_G_FIRST_LT | First Lieutenant | Beat a lieutenant in the Lieutenant Cities. | no | gangsters | - |
| ACH_G_ALL_LT | Up the Ladder | Beat all eight lieutenants. | no | gangsters | lieutenants_beaten (0..8) |
| ACH_G_TOP_FLOOR | Top Floor | Face the President and win. | yes | gangsters | - |
| ACH_G_WIRED | Wired | Build all three chrome stations. | no | gangsters | - |
| ACH_G_THE_HIVE | The Hive | Upgrade the Robotics Bench all the way. | no | gangsters | - |
| ACH_G_STREETS | Street by Street | Win all five city campaigns. | no | gangsters | gang_campaigns (0..5) |
| ACH_G_GILT | Gilt Edge | Reach Gilt City. | no | gangsters | - |
| ACH_G_CLEAN_BREAK | A Clean Break | End the story with no heat, every Marked home and every shop given back. | yes | gangsters | - |
| ACH_CO_TOGETHER | Better Together | Play together with a friend. | no | both | - |
| ACH_CO_HOST | Open House | Host a friend on your farm. | no | both | - |
| ACH_CO_FULL_HOUSE | Full House | Play with three friends at once. | no | both | - |
| ACH_CO_CROSSOVER | Two Stories, One Farm | Play together with a friend on the other path. | no | both | - |
| ACH_L_SECOND_SPRING | Second Spring | Reach spring of year two. | no | both | - |
| ACH_L_WIDE_WORLD | Wide World | Visit every far region your path can reach. | no | both | regions_seen (0..7) |
| ACH_L_TWO_PATHS | Two Paths | Finish the story on both paths. | no | both | arcs_finished (0..2) |
| ACH_L_EVERY_ENDING | Every Ending | See all five endings across your saves. | yes | both | endings_seen (0..5) |
| ACH_L_FORTUNE | Fortune | Earn 100,000 in one save. | no | both | - |

| Stat API name | Type | Min | Max | Increment only | Set by |
|---|---|---|---|---|---|
| crops_harvested | INT | 0 | 100000 | no (client only ever raises it) | Client |
| friends_5 | INT | 0 | 60 | no (client only ever raises it) | Client |
| shared_campaigns | INT | 0 | 6 | no (client only ever raises it) | Client |
| penguin_campaigns | INT | 0 | 8 | no (client only ever raises it) | Client |
| cf_stages | INT | 0 | 8 | no (client only ever raises it) | Client |
| decor_pieces | INT | 0 | 1000 | no (client only ever raises it) | Client |
| colonies_saved | INT | 0 | 4 | no (client only ever raises it) | Client |
| crew_recruited | INT | 0 | 12 | no (client only ever raises it) | Client |
| loyalty_done | INT | 0 | 12 | no (client only ever raises it) | Client |
| turf_held | INT | 0 | 4 | no (client only ever raises it) | Client |
| heists_done | INT | 0 | 3 | no (client only ever raises it) | Client |
| marked_home | INT | 0 | 10 | no (client only ever raises it) | Client |
| lieutenants_beaten | INT | 0 | 8 | no (client only ever raises it) | Client |
| gang_campaigns | INT | 0 | 5 | no (client only ever raises it) | Client |
| regions_seen | INT | 0 | 8 | no (client only ever raises it) | Client |
| arcs_finished | INT | 0 | 2 | no (client only ever raises it) | Client |
| endings_seen | INT | 0 | 5 | no (client only ever raises it) | Client |

## Staged for the account (Tom's Steamworks session, in order)

1. Stats & Achievements > Stats: add the 17 stats above (INT, min 0, max as listed, Set by Client). Publish.
2. Stats & Achievements > Achievements: add the 60 achievements (API name, display name, description, Hidden = the Spoiler column; progress stat where listed). Bulk-upload icons from `docs/steam/achievements/` (names already `<API>_ACHIEVED` / `_UNACHIEVED`). Publish.
3. Rich Presence: upload the English localization file built from `data/rich_presence.json` tokens.
4. App Admin > Steam Cloud: Byte quota per user 20000000, Number of files 10, enable Auto-Cloud. Root paths: Windows `WinAppDataRoaming` + subdirectory `Godot/app_userdata/Dreams`, pattern `save.json` (and `save.bak.json`), not recursive; Linux `LinuxHome` + `.local/share/godot/app_userdata/Dreams`, same patterns; add root overrides so Windows and Linux saves map onto each other (Deck native <-> Windows PC). Publish.
5. With the real App ID in SteamService (P1), run a desktop build with Steam open, unlock one achievement (e.g. harvest a crop), confirm it appears on the Steam profile, then reset it from the Steamworks admin page.

## Not done (follow-ups)

- Event hooks for instant unlocks inside battles/minigames: unlocks land at the next save (scene change, sleep), not at the exact moment. Fine for Steam; an exact-moment hook is one `Achievements.scan()` line at a call site.
- Hatch-without-parents babies count only when the animal record carries parents.

<!-- fragment: docs/steam/deck.md -->
## Steam Deck Verified checklist (S1 P3: screens, input, desktop window)

Against Valve's Deck compatibility criteria (partner.steamgames.com/doc/steamdeck/compat).
PASS = done and tested headless in check.sh; STAGED = code in place, needs a
Steam-launched build (GodotSteam + an App ID, app 480 first) to verify; FAIL = open.
Performance rows (1280x800 frame time, Linux) come from P4 (docs/steam/coop.md /
its perf section) and the Linux build from P1.

| # | Valve criterion | Status | How / test |
|---|---|---|---|
| 1 | Text legible: smallest glyph >= 9 px tall at 1280x800 | PASS | Runtime Deck floor: `DisplayMode.deck_min_font()` (size 8 at 1280x800; size 7 was 8.3 px cap). Controls are clamped as they enter the tree on the Deck, `Settings.font()` honours it, every drawn `draw_string` size 5-7 goes through `DisplayMode.df(n)`. `tools/deck_text_test.gd` replays the whole phone screen walk (title, HUD, dialogue, every menu tab, chest, craft, arcade, bowling, campaign, Rec Center, both arcs) as a Deck: 858 texts under 9 px before, 0 now, smallest cap 9.5 px. `tools/deck_font_scan.py` fails on any new unwrapped drawn size. Phones and PCs keep their exact sizes. |
| 2 | Default controller config gives access to all content | PASS (built-in) | Every screen already pad-driven (C9). New: text fields. `TextEntry` opens typing when A is pressed on a focused LineEdit/TextEdit or ScreenCursor lands on one (`ScreenCursor` now walks text fields): room code, server URL, save code, decor search, animal rename, title names. `tools/deck_input_test.gd`. |
| 3 | On-screen keyboard for text input | PASS built-in / STAGED Steam | Built-in `PadKeyboard` (d-pad/stick, A types, B deletes then closes, MENU done, taps work). Steam's floating keyboard first when SteamService offers `show_floating_keyboard(multiline, rect) -> bool` (calls ShowFloatingGamepadTextInput); verify on a Deck with app 480, then the real App ID. |
| 4 | Glyphs match the input in use; no keyboard/mouse glyphs with a pad | PASS (names) / STAGED (Steam Input types) | Deck family L1/R1/L2/R2/View/Menu (`InputSetup.PAD_NAMES["deck"]`, "Steam Deck"/virtual pad on the Deck). Steam Input type (PS/Switch pads arriving as "Steam Virtual Gamepad") through SteamService `input_type(device)`. Trackpad clicks (mouse emulation) and keys typed by a keyboard no longer flip prompts to keys on the Deck. Touch words in dialogue, dialogue choices, menu lines, char sheet, decor, title, epilogue, arcade how-to and hack terminal go through `PadInput.words` ("Pick a slot", "D-pad", "press A on it"). Dialogue Skip names MENU. Fullscreen row's F11 hint only for keyboard players. Button prompts are words, not icon glyphs (Valve accepts matching names; icon glyphs are polish, not done). |
| 5 | Boots into controller play with no settings change | PASS | Native desktop/Deck boot with a pad connected starts in pad mode (no touch overlay, pad words). Web/phones unchanged. |
| 6 | No OS dialogs that need a mouse | PASS | Save to / load from a file with a pad or on the Deck: backups go to `user://backups/` and `BackupPicker` lists them (A loads, B cancels). The OS file dialog stays for mouse/keyboard PCs. Steam Cloud covers moving saves once on (P2 docs/steam/p2.md). |
| 7 | Native 1280x800 / 16:10, fullscreen by default on the Deck | PASS | Deck detection now only from SteamDeck/SteamOS env or gamescope (no more guessing from a small screen: a 1080p laptop at 150% was forced fullscreen with touch buttons). The Deck starts fullscreen; the view widens to 768x480 at 1280x800. |
| 8 | Pauses for the Steam overlay / Quick Access | PASS focus loss / STAGED overlay | Focus loss and app suspend pause into the menu (own option "Pause when window inactive", default on, no longer tied to Sound in background). Steam overlay: SteamService connects `overlay_toggled` to `DisplayModeSvc.overlay_toggled(active)`. |
| 9 | Quit to desktop | PASS | Title > Quit and Menu > Options quit (C9). |

Desktop window extras (Steam PC players): hi-DPI aware on PC (`window/dpi/allow_hidpi.pc=true`, window sized by screen DPI; web keeps allow_hidpi off), minimum window 540x480, the windowed size/position/monitor remembered (`win_rect`), Options rows on native desktop only: Scaling smooth / pixel-perfect (whole-number scale, not on the Deck), Pause when window inactive, VSync, Frame rate cap (none/30/60/120). Alt+Enter no longer also presses A (confirmed a menu choice), Alt+Tab no longer cycles the tool.

Not done (P3): icon button glyphs (procedural PadGlyphs, s1_08-05); startup window flash: fixed in the S1 integration with a `steam_desktop` feature override (desktop presets only) opening the first window at 1280x800, the Deck panel size, so the Deck boot check still fills the screen; desktop windows are then sized by DisplayMode; a wider Deck panel column for list screens (s1_07-06, design job, not needed for Verified).

### When Tom's Steamworks account is ready (P3 items)
1. SteamService (P1) exposes `show_floating_keyboard(multiline: bool, rect: Rect2i) -> bool` (Steam.showFloatingGamepadTextInput, falling back to showGamepadTextInput) and calls `TextEntry.steam_dismissed()` on `floating_gamepad_text_input_dismissed` / `gamepad_text_input_dismissed`.
2. SteamService exposes `input_type(device: int) -> String` ("deck" / "ps" / "switch" / "xbox" / "") from Steam.getInputTypeForHandle.
3. SteamService connects `overlay_toggled(active, ...)` to `DisplayModeSvc.overlay_toggled(active)`.
4. On a Deck with app 480: type a room code (floating keyboard appears over the field), check PS/Switch pads show Cross/B names, Shift+Tab overlay pauses, trackpad clicks keep A/B prompts. Then the same with the real App ID, and submit for Deck review.

<!-- fragment: docs/steam/coop.md -->
## Co-op on Steam, Steam Input, Deck performance (S1 P4)

### How co-op works now
- One game layer, several wires. `NetNode` (scripts/net.gd) talks to a `NetTransport` (scripts/net_transport.gd). Every transport speaks the relay protocol from server/server.js, so farming, building, world deltas and puppets never know which wire they are on.
- `NetTransportWs`: the live relay over a WebSocket (wss://dreams-64-23-239-63.sslip.io). This is the web/phone transport and stays exactly as it was; desktop players can still use it with a room code to play with phone friends.
- `NetTransportSteam` (desktop builds with Steam running): GodotSteam lobbies plus Steam Networking Messages. Friends join by invite or from the friends list, not by typing a code. NetNode loads this file by path only when Steam is up, so the web build never parses any Steam code (`tools/net_web_safety_check.py` in check.sh enforces it; the file itself only calls a backend object, so it would even parse on web).
- `NetTransportLoop`: an in-memory twin of the relay for headless tests.
- `NetRelayRoom` (scripts/net_relay_room.gd) holds the relay's room rules once: ids, joined / peer_joined / peer_left / peer_scene, messages stamped with sender and host flag, 8 players, the host's late-join snapshot, the 30 s host grace, the guest guards (64 KB per frame, 120 messages a second). The Loop transport and the Steam lobby owner both run it.

### Steam mapping (relay -> Steam)
| Relay | Steam |
|---|---|
| room code (4 chars) | friends-only lobby (max 8); lobby data `dreams=1`, `proto`, `code` (the 4-char code shown in status text) |
| relay server | the lobby owner's game runs NetRelayRoom (star topology: guests only talk to the owner) |
| socket id | small int per SteamID (owner = 1, then join order) |
| host flag | stamped by the owner from the sender's Steam identity; a guest can never claim host |
| frame size / rate guards | same numbers, enforced by the owner |
| WebSocket frame | Steam message: channel 1 unreliable for position ticks without a look, channel 0 reliable for everything else; frames over 8 KB zstd-compressed, packets over 480 KB chunked (Steam's cap is 512 KB). A maxed farm world (~394 KB JSON) compresses to tens of KB. |
| host_save snapshot | not needed: the owner pushes the full world to each newcomer |
| host grace 30 s -> you_are_host | owner leaves the lobby -> guests wait 30 s -> everyone visiting goes home (their own farm back), same as the relay |
| token reconnect | SteamID is the identity; a dropped guest rejoins the same lobby (`reopen`) |
| strangers | session requests accepted only from current lobby members |
| `PROTO` build check | lobby data `proto`; owner answers `old_build` to a different build. The relay now does the same (`old_build` when a joiner's proto differs from the room creator's; old clients without proto count as 0). |

Rich presence while in a Steam lobby: `steam_display=#Status_Coop`, `players`, `steam_player_group=<lobby>`, `steam_player_group_size`, `connect=+connect_lobby <id>`; cleared on leave. The `#Status_Coop` token text belongs in the rich presence file (P2 owns steam/rich_presence_english.vdf): now in data/rich_presence.json (tools/gen_achievements.py): `"#Status_Coop" "Playing together (%players% players)"`; Presence (scripts/presence.gd) uses the same token and key.

### Tested without a Steam account
- `tools/net_steam_test.gd` (check.sh): a host NetNode on a lobby over `tools/fake_steam.gd` (an in-process stand-in for the GodotSteam calls), with raw guests: join, world push stamped host, fast-channel ticks, a guest's fake world stamped host:false and ignored, 70 KB guest frame dropped, 120 of 200 flood frames forwarded, a 1.5 MB world compressed + chunked and reassembled, an incompressible 1.6 MB blob in 4 chunks byte-for-byte, 5 s with the tree paused (co-op keeps going), a stranger refused, old build refused, the 9th player told the lobby is full, rich presence set and cleared, owner gone 10 s (still waiting) and 31 s (guest home on its own day). 33 checks.
- `tools/net_transport_test.gd` (check.sh): the same game layer over the relay twin. 19 checks.
- The WebSocket path was re-verified end to end after the split: `tools/net_e2e.sh` against a local relay (NET E2E: ok) and `node tools/relay_test.js` (RELAY TEST OK, with the new old_build case).
- App 480 (Spacewar) lets lobbies and messages work before the App ID exists, but CI has no Steam client and two Steam accounts are needed, so the two-machine smoke test is staged below, not CI.

### Done since (C17)
- Title > Play together has the Steam branch ("Host with Steam friends"); invites (`join_requested`), friends-list Join Game while running (`join_game_requested`, rich presence `connect`), and the `+connect_lobby` launch argument all land in `Net.on_join_requested`. SteamService is the autoload `/root/SteamSvc`; it pumps `run_callbacks()` and warms Steam Datagram Relay (`initRelayNetworkAccess`) at start. Persona names go through NameFilter.
- Transport hardening (C17 P6): guest join resent every 2 s, gives up after 15 s with words; owner holds session requests from members its lobby list hasn't caught up with (10 s); guest liveness 20 s / owner lets a silent guest go after 45 s; `network_messages_session_failed` / `steam_server_disconnected` close the link; a deliberate host leave sends guests home at once (a drop keeps the 30 s grace); a rejoin reuses its own seat (never "full"); only the host advertises `connect`; non-Dreams lobbies refused; EChatRoomEnterResponse shown as words; Back during "Starting a Steam lobby" leaves the late lobby.
- Still open: an in-game "Invite Steam friends" row (game menu, P5) and Steam-specific status/privacy text on the title (P5).

### Steam Input (controller config)
- Launch default, no code: Steamworks > Application > Steam Input: default configuration = the "Gamepad" template; Steam Input on for Xbox/PlayStation/Switch/generic pads, so every pad reaches the game as an Xbox layout and InputSetup.PAD_DEFAULTS apply one to one (A use/confirm, B back/run, X tool, Y check, Menu menu, View map, LB/RB toolbar, LT dodge, RT partner ability, L3 rally, R3 pup, d-pad/left stick move).
- Deck back grips (author once in Tom's session, then "Set as official"): L4 = Quests (journal), R4 = Map, L5 = Toolbar Back, R5 = Shift Toolbar, right stick unbound, right trackpad = mouse, gyro off.
- Staged file for when GodotSteam's Input API is wired: steam/input/game_actions_480.vdf, generated by `tools/gen_steam_input.py` from scripts/input_setup.gd (action names = InputSetup action ids; quick slots left out; journal offered for L4). `tools/steam_input_check.py` (check.sh) keeps it in step.
- The dead 'emote' action (Y key, nothing read it) was removed; old saved bindings for it are ignored.
- Not done: a raw-pad (non-Steam-Input) route to Quests, e.g. holding View; game_menu.gd belongs to the screens package.

### Deck performance and Linux behaviour
- Target 60 fps at 1280x800 (Deck native), floor 30 fps (Valve's Verified rule). Guard: `python3 tools/deck_perf_check.py` (both arcs, Deck view; CPU per frame from a headless run, draws/textures/load/cover from an opengl3 run under xvfb). Thresholds at the top of the script. Results: see the table below.
- Window on a screen with no window manager (bare X11, some gamescope setups): Godot said fullscreen but kept a 540x960 portrait window (measured before the fix: window 540x960, view 270x480). Now DisplayMode covers the screen a frame later when that happens (window 1280x800, wide view 768x480). `tools/deck_window_test.gd` (check.sh, xvfb) proves it.
- `tools/linux_boot_check.sh <binary>`: exported Linux build boot test (exit code, error lines, first-launch time; then an xvfb 1280x800 opengl3 run with SteamDeck=1 whose last Movie Maker frame must be 1280x800 and not flat). Needs the export (CI); wiring is a P1 hook.
- Linux build is about 390 MB (every song bundled). Not a blocker: Steam compresses depots. Store "Storage" line: 500 MB.
- Not done: physics interpolation (09-04: smooth motion at 40/45 Hz caps and the 90 Hz OLED). Turning it on project-wide changes how every moved node draws and needs a reset at every teleport (35 position-set sites); it needs a full visual pass, so it is left for its own package: `physics/common/physics_interpolation=true`, a `GameMap.teleport_player(pos)` helper calling `reset_physics_interpolation()`, and an interp test at Engine.max_fps 40.

### Deck Verified checklist rows (P4 items; P3 assembles the full table)
| Item | Status | Evidence |
|---|---|---|
| PERF: default config reaches 30 fps at 800p | PASS on evidence | deck_perf_check table below; Deck GPU is far above llvmpipe |
| DISPLAY-1: 1280x800 supported, fills the screen | PASS | DisplayMode is_deck fullscreen + WM-less fill (deck_window_test) |
| Linux build runs | PASS (CI) | exported binary boots headless, exit 0; xvfb opengl3 reaches the title (auditor run); linux_boot_check.sh for CI |
| INPUT-1: all content with the default config | PARTIAL -> staged | PAD_DEFAULTS cover every action; Quests via L4 grip in the official config (Tom's session) |
| Suspend/resume safe | PASS | game clock deltas clamped; pause on focus loss |
| Smooth at 40/90 Hz | NOT DONE | physics interpolation (see above) |

### When Tom's Steamworks account is ready (co-op and controller items, in order)
1. Put the real App ID in SteamService.APP_ID_RELEASE (debug and test builds use App 480 via pick_app_id).
2. Rename steam/input/game_actions_480.vdf to game_actions_<appid>.vdf (edit OUT in tools/gen_steam_input.py, rerun it).
3. Steamworks > Application > Steam Input: default = Gamepad template; enable Steam Input for all pad types; build the back-grip layer above; Configs > Set as official.
4. Steamworks > Community > Rich Presence: upload steam/rich_presence_english.vdf (with the #Status_Coop token).
5. Optional: nothing else in Steamworks is needed for lobbies or networking messages.
6. Two-account smoke test by a playtester with two Steam machines (Tom only reads the result): host invites from the overlay; friend joins from the friends list; cold start from an invite (+connect_lobby); owner quits -> friend goes home at once (owner's network pulled -> after 30 s); friends-list Join Game while Dreams is running; a join while the owner's lobby list is slow still gets in; the friend's network pulled -> back home within ~20 s; after the host leaves, a third friend can't join through a guest's presence; a Steam player joins a phone room by code.
7. Steamworks > Steam Deck compatibility: request the review (Valve gives the Verified badge).

<!-- fragment: docs/steam/upload.md -->
## Upload pipeline, Steamworks handoff and ratings (S1 P5)

### Done (in the repo, checked by check.sh)

- `steam/steam_config.json`: the one committed, non-secret upload config (`enabled:false`, `app_id:0`, depots 0 =
  app+1/app+2, `set_live:"beta"`, `preview:true`). While it says that, nothing uploads.
- `steam/templates/*.vdf.in`: SteamPipe app build + Windows/Linux depot templates. Every depot excludes
  `steam_appid.txt`, `*.pdb`, `*.console.exe`, `*.console.sh`, `*.debug`, `*.import`, `.DS_Store`, `*.log`, `.gitkeep`.
  `steam/.gdignore` keeps the folder out of every Godot export.
- `tools/gen_steam_vdf.py`: renders the templates into `build/steam/scripts/` (gitignored). Refuses SetLive
  "default" and app_id 0 (unless `--preview-dummy`, Spacewar 480/481/482). Build description: `Dreams <version>
  <sha> <date>` from `application/config/version` in project.godot (now "0.S1.0").
- `tools/steam_vdf_check.py`: `--templates` (check.sh), `--scripts/--content` (CI before steamcmd: exes present,
  Linux exe executable, no steam_appid.txt anywhere, Steam API libs once addons/godotsteam exists, GLIBC floor 2.31
  for Steam Linux Runtime 3.0), `--dry <content>` (would-upload list with sizes, no network).
- `.github/workflows/steam-upload.yml` (**staged, off**): gate job reads steam_config.json; the upload job runs only
  in the GitHub Environment `steam` (main only), exports Windows + Linux inside the job (no public artifact, keeps
  the +x bit), renders and checks the VDFs, then `tools/steam/upload.sh` (steamcmd with the cached login, never a
  password; masks the user name; fails fast with "run the steam-login workflow" when Steam Guard needs a new code;
  writes `STEAM: ok, BuildID N` and depot sizes to the job summary).
- `.github/workflows/steam-login.yml` (**staged**): two manual runs mint `STEAM_CONFIG_VDF` from the builder
  account's emailed Steam Guard code, using a fine-grained PAT; nobody runs steamcmd by hand.
- `tools/ci_deps_check.py --apt-missing --steam`: the ONE apt line for the Steam jobs (lib32gcc-s1, binutils, jq).
- `.gitignore`: `steam_appid.txt` anywhere.
- `steam/handoff.json` + `tools/steam_handoff.py`: every value the Steamworks session enters, the generated Chrome
  brief at the end of this file, the kit (`--kit`: 184x184 app icon flattened on the dark background, 512 shortcut
  icon, rich presence VDF from P2's data), `--set-ids` to record the ids after the session.
- Ratings: `docs/steam-store/ratings.md` (Content Survey + IARC answers with evidence, expected ratings),
  `docs/steam-store/ai-disclosure.md`, `docs/steam-store/privacy.md`, kept true by `tools/ratings_facts_check.py`.
- Game fixes behind the answers: beaten beasts run off instead of the defeat puff (Enemy.is_beast); beasts drop no animal parts (Pelt/Game Meat/Bone are now Shed Fur/Trail
  Rations/Old Antler, hill wolves drop wild herbs, traps are Bramble Brushes that comb shed fur, Rook's lodge has a
  woven rug, pelt rugs became pattern rugs; `tools/animal_rule_test.py`), wine descriptions no longer imply
  toasting (drink rule now checks descriptions), in-game credits name no family members and match the AI disclosure;
  Title > Sound and options > Credits and licences shows the credits, the Godot MIT notice and engine components,
  the symbol-font notice and GodotSteam's notice when the addon ships (scripts/licences.gd); the co-op page says what
  the relay sees (privacy).
- `scripts/name_filter.gd` (+ `tools/name_filter_test.gd`): all-ages name filter, hooked into new-game names,
  ranch animal renames and peers' name labels (received ranch deltas and the relay still to hook).
- `tools/ai_provenance.py`: the art/music/sound counts behind the AI disclosure (73 shipped audio files still lack a
  provenance row: mostly synthesized j_* jingles and older effects).

### Staged (waiting on Tom's Steamworks account)

App ID, depots, launch options, Linux runtime, beta branch, Steam Cloud rows, achievements and rich presence upload,
builder account, GitHub Environment + secrets, Steam Guard login, first preview and beta upload, store fields,
Content Survey, AI disclosure, pricing, review. All in the brief below, in order.

### Waiting on Tom (never invented)

- The casino decision (docs/steam-store/ratings.md: keep traditional = PEGI 18; fantastical reskin = PEGI 12; or off
  in Steam builds).
- Studio name for Developer/Publisher and the credits; base USD price and any launch discount; which inbox the
  builder Steam account uses (and a phone/Steam Mobile App for it before release).

### Notes

- Depot layout: two OS depots for the first release. Later option (decide before launch; changing depots after
  release forces a full re-download): `embed_pck=false`, a shared OS-All depot with Dreams.pck, small exe depots.
- Steam Cloud uses Godot's default user:// paths for config/name "Dreams". If the title ever changes config/name,
  pin `use_custom_user_dir` first (with a one-time save move) and re-render the Auto-Cloud rows.
- Rollback: SteamPipe > Builds, set the previous BuildID live on 'beta' (Chrome step; BuildIDs are in job summaries).
- Anonymous preview uploads are not possible (Steam requires a partner account with rights on the app), so the
  pre-account gate is the dry run: `python3 tools/steam_vdf_check.py --dry <content dir>`.

<!-- fragment: docs/steam/p6.md -->
## Store materials (P6: store text, capsule art, screenshots, trailer, name check)

Everything lives in docs/steam-store/ (README.md has the rules). Checks in check.sh: tools/store_text_check.py, tools/steam_capsules_check.py, tools/steam_shots_test.py.

| Item | State | Where |
|------|-------|-------|
| Short description (300-char limit; PRIMARY + 2 alternates, ALT B has no co-op claim) | done (draft; Tom picks wording) | short-description.md |
| Long description (BBCode) and 8 feature bullets | done (draft) | long-description.md, features.md |
| Claims gate (marketed systems -> inventory.csv) | done; page_ready: false while ranching core and co-op are rough | claims.md |
| Store counts generated from data (no hand-typed numbers) | done | tools/store_facts.py -> facts.json |
| Tags (ordered 20) and genres, researched against 6 comparable games | done (draft; Tom approves) | tags.md |
| Price comparison and recommendation ($19.99, 15% launch discount for 7 days; EA option $14.99) | staged for Tom | pricing.md |
| Languages, categories, developer fields (each with its gate) | staged | store-fields.md |
| System requirements | estimates until the desktop CI job writes build/metrics.json; rerun tools/store_sysreq.py | system-requirements.md |
| Capsule/library art at every size (12 assets) + icons | done (title-swappable logo layer) | ART-PLAN.md, art/ |
| Screenshots, 11 at 1920x1080 (8 all-ages) | done; 06 Neon and 08 mine are the weakest (map dressing / battle staging) | screenshots.md, screenshots/ |
| Trailer: script, beat list, capture + encode pipeline | built; the full 45 s cut runs in a CI manual job (hook: P1) | trailer.md, trailer_shots.json, tools/steam_trailer.sh |
| Name check: "Dreams" conflicts with Sony's live US mark DREAMS (class 9/41); 7 alternatives with checks | done; Tom decides | NAME-CHECK.md |

### When Tom's Steamworks account is ready (P6 steps, in order; P5 merges these into the master list)
1. **Title first.** Tom has picked a title from NAME-CHECK.md. Run the clearance lookups listed there (WIPO, EUIPO, UK IPO, USPTO, `python3 tools/steam_name_search.py "<title>"`). Then set `TITLE` in tools/store_facts.py, rerun it, render logo_<slug>.png and rerun tools/steam_capsules.py. Enter the same title in all three name fields: Store Basic Info, Steamworks General Application Settings, and every Package. No field may contain "(working title)". The name locks once the store page passes pre-release review.
2. Store page > Basic Info: developer/publisher (studio name, never a personal or store name), languages grid and categories from store-fields.md (tick each category only if its gate passed), genres and the 20 tags from tags.md (Tag Wizard).
3. Store page > Description: short description (PRIMARY, or ALT B while claims.md c11 co-op is gated), About This Game from long-description.md (render the tokens with facts.json; textless GIFs optional), system requirements from system-requirements.md (re-rendered from measured metrics).
4. Graphical Assets: upload header_capsule, small_capsule, main_capsule, vertical_capsule, page_background from docs/steam-store/art/. Community: app_icon.jpg (184), shortcut_icon.png (512).
5. Screenshots: upload the trailer first, then the screenshots in the order in screenshots.md; tick "suitable for all ages" on 01-05 and 09-11 (at least 4 are needed; the gangster shots 06-07 stay unticked).
6. Pricing: from pricing.md (default $19.99; accept Valve's regional recommendations); set the launch discount (15%, 7 days) before the release date.
7. Gate: "Submit store page for review" only when step 1 is done and claims.md says page_ready: true (or Tom accepts the rough rows and the copy is ALT B).
8. After the page is visible as Coming Soon: Library Assets: library_capsule, library_header, library_hero, library_logo; in the library preview tool set the logo position to centred top, width about 40% of the hero.

<!-- steam-handoff:begin (generated by tools/steam_handoff.py; do not edit) -->

## When Tom's Steamworks account is ready (one Chrome session, then timed follow-ups)

Run by Claude in Chrome in Tom's own signed-in browser, one step at a time. Tom only signs in, approves Steam Guard on his phone, answers the legal/tax/bank fields, picks the builder inbox, and taps any captcha. Every value below comes from `steam/handoff.json`; uploads come from the kit (`python3 tools/steam_handoff.py --kit`, published by the steam-kit workflow as a draft release so the play site never changes).

### Part A: the one session

- **A0. Sign in.** Open partner.steamgames.com in Tom's signed-in Chrome. If Steam Guard asks, guide Tom one tap at a time on his phone. Nothing is typed into the chat.
- **A1. Onboarding (only if not done).** NDA + Steam Distribution Agreement, pay the $100 app credit, identity/bank/tax interview. Tom answers the legal, bank and tax fields himself, guided one field at a time. Record the payment date as D0 in the ledger (the tax check takes 2-7 business days).
- **A2. Create the app.** Create the app from the app credit. Record App ID and the auto-created store package id in the ledger.
- **A3. Application basics.** App Admin > Application: name Dreams (working title; Tom picks the final title from docs/steam-store/ name check), type Game, supported OS Windows 64-bit, Linux + SteamOS. Developer/Publisher: WAITING ON TOM: studio name (no family names, no personal identity).
- **A4. Launch options.** Installation > General: Dreams.exe (Windows, 64-bit); Dreams.x86_64 (Linux + SteamOS, 64-bit).
- **A5. Depots.** SteamPipe > Depots: Dreams Windows (OS Windows, id APP_ID+1); Dreams Linux (OS Linux + SteamOS, id APP_ID+2). Add both depots to the store package and the developer comp package (Packages > Depots Included), otherwise Linux installs nothing. Record both depot ids.
- **A6. Linux runtime.** Installation > Linux Runtime (appears only after a Linux launch option exists): Steam Linux Runtime 3.0 (sniper) once the Linux CI boot test passes in the sniper container; otherwise leave 'none' and note it.
- **A7. Beta branch.** SteamPipe > Builds: create branch 'beta' (password optional, a Steamworks setting, never stored in the repo). Branch rules: beta: CI sets this live (SetLive beta); rc: release candidate (Part B); default: set live by hand in Steamworks only, never by CI.
- **A8. Steam Cloud.** Steam Cloud settings: byte quota 10485760, files per user 10, Save, Publish (unlocks Auto-Cloud). Auto-Cloud rows (root / subdirectory / pattern / OS, recursive off): WinAppDataRoaming / Godot/app_userdata/Dreams / save.json / Windows; WinAppDataRoaming / Godot/app_userdata/Dreams / save.bak.json / Windows; LinuxXdgDataHome / godot/app_userdata/Dreams / save.json / Linux; LinuxXdgDataHome / godot/app_userdata/Dreams / save.bak.json / Linux. Never sync: save.tmp.json, save.bad*.json, mcache/, logs/. Test with the Steam console 'testappcloudpaths <AppID>' + 'set_spew_level 4 4', play, quit, read cloud_log.txt, then reset both. Note: all save slots live in one save.json and sync together.
- **A9. Stats and achievements.** Stats tab first (progress stats: INT, set by client, increment only). Then Achievements > Bulk import/export: click Export on the empty tab, Claude reads the header row, maps the kit CSV to it, uploads achievements/ from the kit (256x256 colour + locked icons), Save imported data. API names are frozen once published.
- **A10. Rich presence.** Community > Rich Presence localization: upload rich_presence_english.vdf from the kit. Verify with the rich presence tester after the first beta build.
- **A11. Controller.** Steam Input: default configuration from P4's steam/input draft (docs/steam/coop.md or input notes); Deck uses the same. Do not tick Full Controller Support until the Deck checklist row passes.
- **A12. Builder account and permissions.** Create a new Steam account for uploads in Chrome (its inbox is one Tom picks; its password is generated in the browser with crypto.getRandomValues and typed straight into Steam and GitHub, never shown). partner.steamgames.com/pub/users: invite it; create group Builders (this app only; never 'Everyone'; never Manage Pricing & Discounts or financial rights) with only Edit App Metadata + Publish App Changes To Steam. Tom approves the invite (within 7 days). Setting builds live on a released app needs the builder account to have a phone number or the Steam Mobile App, and any security change starts a 3-day wait: if Tom chooses to add one, do it now so the wait never lands in launch week; otherwise CI keeps uploading only and branches are set live by hand.
- **A13. GitHub secrets.** github.com/Excivious27/Dreams/settings/environments: create Environment steam (deployment branches: main only); add secrets STEAM_USERNAME; STEAM_PASSWORD (temporary, deleted after steam-login); STEAM_SECRET_WRITER (fine-grained PAT: this repo only, Environments read and write, 90 days); STEAM_CONFIG_VDF (written by the steam-login workflow, never by hand). Create the PAT in the same session (github.com/settings/personal-access-tokens). Nothing is ever pasted into the chat.
- **A14. Mint the upload login.** Actions > 'Steam builder login' > Run (empty code): Steam emails a Guard code to the builder inbox. Read only that code in Chrome, run again with guard_code. The summary must say STEAM_CONFIG_VDF stored. Delete STEAM_PASSWORD.
- **A15. Record ids and enable uploads.** Claude runs `python3 tools/steam_handoff.py --set-ids <app> <win depot> <linux depot>`, sets enabled:true (preview stays true), commits and pushes. Not Tom.
- **A16. Publish Steamworks settings.** Publish tab: publish all pending changes (achievements, cloud and rich presence only take effect after Publish).
- **A17. First upload (preview, then beta).** Actions > 'Steam upload' > Run with preview on; then commit preview:false; the next main push uploads to 'beta'. Record the BuildID from the job summary. Tom installs the beta (Steam > Dreams > Properties > Betas) and launches it once.
- **A18. Store page.** Needs Tom's casino decision first (docs/steam-store/ratings.md, one question asked in the chat before this session). Store page fields, pasted only from the repo drafts, never new copy: Short description <- docs/steam-store/short-description.md; About This Game <- docs/steam-store/long-description.md; Tags <- docs/steam-store/tags.md; System requirements <- docs/steam-store/system-requirements.md; Content survey + IARC <- docs/steam-store/ratings.md; Generative AI disclosure <- docs/steam-store/ai-disclosure.md; Privacy policy (text for the Pages URL) <- docs/steam-store/privacy.md; Price <- docs/steam-store/pricing.md; Supported languages <- English: interface + subtitles (no full audio); Supported features <- Single-player; Steam Achievements; Steam Cloud; Family Sharing; Full controller support only after the Deck checklist row 'full controller play' passes; Online Co-op only after the Steam transport ships. Upload the kit's capsules, screenshots and the app/shortcut icons. Content survey answers and the Generative AI section exactly as docs/steam-store/ratings.md and ai-disclosure.md say (Part 'Content survey' there); do not enter any PEGI/USK rating unless a real board review happened. Open the German rating health check link and confirm Dreams shows a rating.
- **A19. Pricing.** Packages > store package > Pricing: USD base WAITING ON TOM, then 'Use recommended pricing' for every other currency, submit for approval. Launch discount: WAITING ON TOM (optional).
- **A20. Release date and review.** Release date field: 'Coming soon' (or a quarter), never earlier than the calendar below. Submit the Store Presence checklist for review (3-5 business days; submit at least 7 days before it should be public).
- **A21. Values ledger.** Write every value from this session into steam/handoff.json 'ledger' (no secrets), commit, update the Baton Steam row and PROJECT-MEMORY. Then create the Part B/C reminders as scheduled messages so Tom never tracks dates.

### Part B: after the store page is approved

- **B0. Coming soon.** When the store page is approved (~D0+7..9): publish Coming Soon at once (starts the 14-day clock; wishlists begin).
- **B1. Release candidate.** Upload the RC through CI to branch 'rc' (set_live 'rc' in steam_config.json), run the Deck checklist (docs/steam/deck.md) on it; continue only when every row passes.
- **B2. Build review.** Set the RC live on default by hand in Steamworks, complete the Game Build checklist, submit for build review.
- **B3. Deck review.** After build review passes: Technical Tools > Steam Hardware Compatibility Review on the default/RC branch. If the link is missing, note it in the Baton and retry weekly (scheduled). Re-review after fixes is requested from the same page.

### Part C: release

- **C0. Release.** On or after max(D0+30 days, coming-soon+14 days, build approved): Release App > Publish Now. Rollback of a bad beta: SteamPipe > Builds, set the previous BuildID live on 'beta' (BuildIDs are in the job summaries).

### Calendar

- D0 = the day the app credit is paid (not yet). Then: D0..D0+7 business days tax check; ~D0+2 Part A done and store submitted; ~D0+7..9 store approved, Coming Soon published; ~D0+10..20 Part B; release no earlier than max(D0+30, coming soon+14, build approved).

### Kit (file -> Steamworks field)

- `app_icon_184.jpg`: Community/Client assets: App icon (184x184 JPG, flattened on the game's dark background)
- `shortcut_icon_512.png`: Client assets: Shortcut icon (512x512 PNG)
- `achievements/`: Stats & Achievements > Bulk import (CSV + 256x256 icons, from P2's data/achievements.json)
- `rich_presence_english.vdf`: Community > Rich Presence localization (from P2's data/rich_presence.json)
- `capsules/`: Store page graphical assets (P6 renders, exact sizes)
- `screenshots/`: Store page screenshots (1920x1080, P6)

### Values recorded this session

| value | recorded |
|---|---|
| app_id | PLACEHOLDER |
| store_package_id | PLACEHOLDER |
| depot_windows | PLACEHOLDER |
| depot_linux | PLACEHOLDER |
| fee_paid_D0 | PLACEHOLDER |
| builder_account | PLACEHOLDER (name only, never the password) |
| achievements_published | PLACEHOLDER |
| rich_presence_uploaded | PLACEHOLDER |
| store_submitted | PLACEHOLDER |
| coming_soon_live | PLACEHOLDER |
| first_beta_buildid | PLACEHOLDER |

### Waiting on Tom (never invented)

- app.developer
- app.publisher
- price_usd
- launch_discount

<!-- steam-handoff:end -->
