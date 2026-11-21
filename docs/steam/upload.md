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
- Game fixes behind the answers: beasts drop no animal parts (Pelt/Game Meat/Bone are now Shed Fur/Trail
  Rations/Old Antler, hill wolves drop wild herbs, traps are Bramble Brushes that comb shed fur, Rook's lodge has a
  woven rug, pelt rugs became pattern rugs; `tools/animal_rule_test.py`), wine descriptions no longer imply
  toasting (drink rule now checks descriptions), in-game credits name no family members and match the AI disclosure.
- `scripts/name_filter.gd` (+ `tools/name_filter_test.gd`): all-ages name filter, ready for the co-op/title hooks.

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
