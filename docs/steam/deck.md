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
