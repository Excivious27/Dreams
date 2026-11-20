# Steam Deck / Linux native build (C9 P4)

Dreams is phone-first (270x480 portrait). This page is the checklist for a
native Linux x86_64 build that runs on a Steam Deck (SteamOS) or any Linux PC.
Nothing here changes the phone/web build.

## What is in place
- **Export preset "Linux"** (export_presets.cfg preset.1): x86_64, pck embedded,
  every song bundled (native builds have no stream URL; `tools/music_stream.py`
  only edits the Web preset and fails if another preset excludes songs).
  Output `build/linux/Dreams.x86_64`.
- **CI**: the `linux` job in `.github/workflows/deploy.yml` exports it and starts
  it headless for a few seconds on every game push (never blocks the web deploy).
- **App icon**: `config/icon` = `res://web/icon_512.png` (window/taskbar, Deck desktop mode).
- **Deck detection**: `DisplayMode.is_deck()` (env `SteamDeck=1`, gamescope, or a
  landscape screen of 1280x800 or smaller).
  - Starts fullscreen at the panel's native 16:10 size (no shrunken 16:9 window).
  - Touch buttons on "auto" show on the Deck (touchscreen) and any touchscreen
    computer (`DisplayMode.touch_auto()`), same rule at launch and in Options.
  - The mouse cursor hides on touch or pad input and returns when the mouse moves.
- **Focus loss**: alt-tab, the Deck's Quick Access / Steam overlay or an Android
  suspend opens the game menu (pauses), unless "Sound in background" is on and
  only focus was lost (`DisplayMode.pause_for_focus`, signal `app_backgrounded`).
- **Game-time timers**: sleep spells, the pup's knocked-down window and turret
  hit cooldowns run on `PlayClock` (stops while paused), not the wall clock.
- **Controller**: pad bindings, prompts and cursor/focus navigation are the
  C9 P1/P2/P3 packages (`InputSetup` pad defaults, `PadInput`, `PadCursor`).
  Rumble comes from `Haptics` (joypad motors) like phone vibration.

## How to play on a Deck today
1. Copy `Dreams.x86_64` (from the `linux` CI job, or export locally with the
   "Linux" preset) to the Deck, Desktop Mode > Add a Non-Steam Game.
2. Game Mode: it opens fullscreen. Until the controller packages are merged,
   pick the Steam Input template **Keyboard (WASD) and Mouse** and map:
   A = Z (use), B = Shift (back/check), X = C, Y = F, Start = E (menu),
   Select = M (map), L1/R1 = Tab (cycle tool), R2 = V (dodge). The touchscreen
   pad also works.

## Not done yet (decide before a Steam release)
- **UI scale for 1280x800**: the 480-px-tall view scales 1.667x on the Deck, so
  menus are ~40% smaller physically than on a phone. A "Large UI" mode needs the
  view height lowered (layouts are 480 tall), so it is a design job, not a toggle.
- **Physics interpolation** for 40/45/90 Hz frame limits (player moves on the
  60 Hz physics tick, the camera per frame): turn on
  `physics/common/physics_interpolation` and reset it on every teleport
  (GameMap spawn, exits, Faint) together, then check with perf_probe at --max-fps 40.
- **Steam store art** (header 920x430, library 600x900, hero 3840x1240, logo) and
  a Steam Input official config (`game_actions_<appid>.vdf`): only with a Steam app id.

## Deck test checklist
- [ ] Launches fullscreen 1280x800, no letterbox, title readable.
- [ ] Touch buttons visible on first launch (auto); Options > Touch buttons off/on/auto stick after a restart.
- [ ] Mouse cursor hides while playing by touch or pad.
- [ ] Quick Access button mid-fight opens the game menu; foes asleep from a Sleep spell stay asleep while the menu is open.
- [ ] Every area has music offline (all songs bundled).
- [ ] Rumble on fishing bite, hits, level up (with a pad, Options > Vibration on).
- [ ] Save, quit from the menu, relaunch: the farm is there.
