# steam/: staged SteamPipe upload files (S1)

Not shipped (steam/.gdignore). Nothing here is secret. Full guide and the Steamworks Chrome brief: docs/STEAM.md.

- steam_config.json: enabled/app_id/depots/branch. enabled:false + app_id 0 keeps the upload workflow off.
- templates/: app_build + depot VDF templates, rendered by tools/gen_steam_vdf.py into build/steam/scripts/.
- handoff.json: every value the Steamworks session enters; tools/steam_handoff.py renders docs/STEAM.md from it.

Never commit steam_appid.txt (gitignored; dev builds set SteamAppId=480 in the environment instead).
