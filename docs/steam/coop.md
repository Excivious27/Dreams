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

### Not done here (hooks for other packages)
- Title > Play together Steam branch ("Host with Steam friends", "Invite friends", room-code block kept under "Phones and web (room code)") and the `join_requested` signal / `+connect_lobby` launch argument: needs SteamService (P1) and the title screen (P3). The game side is ready: `Net.steam_ready()`, `Net.host_steam()`, `Net.join_steam(lobby_id)`; invite overlay = `Steam.activateGameOverlayInviteDialog(lobby_id)` (lobby id = `Net.i().tr.lobby_id`).
- SteamService (P1) should expose `ready() -> bool` and `backend` (the Steam singleton) and pump `Steam.run_callbacks()` with `process_mode = PROCESS_MODE_ALWAYS` so callbacks keep flowing while menus pause the tree. NetNode finds it at /root/SteamService.
- conduct-ci.yml (P1): change the `netc` regex to `^scripts/net(_api|_transport[a-z_]*|_relay_room)?\.gd$` (ci_run.sh already changed), add `python3 tools/deck_perf_check.py` to a post-merge job, and call `bash tools/linux_boot_check.sh build/linux/Dreams.x86_64` in deploy.yml's Linux job instead of the inline grep.
- Web preset (P1): adding `scripts/net_transport_steam.gd, steam/*` to the Web exclude_filter is optional hygiene (the file has no Steam symbols).

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
1. Put the real App ID in SteamService.APP_ID (dev builds keep reading steam_appid.txt, which is never shipped).
2. Rename steam/input/game_actions_480.vdf to game_actions_<appid>.vdf (edit OUT in tools/gen_steam_input.py, rerun it).
3. Steamworks > Application > Steam Input: default = Gamepad template; enable Steam Input for all pad types; build the back-grip layer above; Configs > Set as official.
4. Steamworks > Community > Rich Presence: upload steam/rich_presence_english.vdf (with the #Status_Coop token).
5. Optional: nothing else in Steamworks is needed for lobbies or networking messages.
6. Two-account smoke test by a playtester with two Steam machines (Tom only reads the result): host invites from the overlay; friend joins from the friends list; cold start from an invite (+connect_lobby); owner quits -> friend goes home after 30 s; a Steam player joins a phone room by code.
7. Steamworks > Steam Deck compatibility: request the review (Valve gives the Verified badge).
