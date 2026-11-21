# Dreams on Steam

Everything for the Steam release (CONDUCT S1, 2026-11). Assembled by `python3 tools/steam_handoff.py --write`
from the fragments in `docs/steam/` (one per S1 package) plus the generated Chrome brief at the end, which
comes from `steam/handoff.json`. Edit the fragments or the JSON, never this file directly.

The web/phone build is unchanged by all of this: nothing Steam loads on web.

Status words used below: **done** (in the repo and tested), **staged** (written and checked, waiting on
Tom's Steamworks account), **waiting on Tom** (a decision only he makes; never invented).

## Contents

- docs/steam/upload.md
- When Tom's Steamworks account is ready (generated)

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
- **A18. Store page.** Needs Tom's casino decision first (docs/steam-store/ratings.md, one question asked in the chat before this session). Store page fields, pasted only from the repo drafts, never new copy: Short description <- docs/steam-store/short.txt; About This Game <- docs/steam-store/long.md; Tags <- docs/steam-store/tags.md; System requirements <- docs/steam-store/sysreq.md; Content survey + IARC <- docs/steam-store/ratings.md; Generative AI disclosure <- docs/steam-store/ai-disclosure.md; Privacy policy (text for the Pages URL) <- docs/steam-store/privacy.md; Price <- docs/steam-store/pricing.md; Supported languages <- English: interface + subtitles (no full audio); Supported features <- Single-player; Steam Achievements; Steam Cloud; Family Sharing; Full controller support only after the Deck checklist row 'full controller play' passes; Online Co-op only after the Steam transport ships. Upload the kit's capsules, screenshots and the app/shortcut icons. Content survey answers and the Generative AI section exactly as docs/steam-store/ratings.md and ai-disclosure.md say (Part 'Content survey' there); do not enter any PEGI/USK rating unless a real board review happened. Open the German rating health check link and confirm Dreams shows a rating.
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
