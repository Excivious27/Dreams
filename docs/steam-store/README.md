# docs/steam-store: Steam store drafts (working title)

Drafts for the Steam store page, made in CONDUCT S1 (no Steamworks account needed). Nothing here ships in a build (docs/* is excluded by every export preset and has a .gdignore).

- Title: the ONLY place the store title lives is `TITLE` in tools/store_facts.py (now "Dreams (working title)"). Every draft uses the `{title}` token; a literal "Dreams" in a field fails tools/store_text_check.py. A rename (NAME-CHECK.md) is a one-line change plus one logo render (ART-PLAN.md). The text "(working title)" must never reach Steam review.
- Numbers: never typed by hand. tools/store_facts.py writes facts.json from data/*.json (run by tools/regen_data.sh); drafts use tokens like `{crops_floor}`.
- Banned in short/long/bullets (allowed in content-descriptors.md and ai-disclosure.md only): casino, betting, slots, roulette, guns, shooting, killing, blood, gore, wine/ale/alcohol, "AI", other game titles, "best", "#1", awards, review quotes, prices, dates, links.
- Checks: `python3 tools/store_text_check.py` (text + claims gate), `python3 tools/steam_capsules_check.py` (art), `python3 tools/steam_shots_test.py` (screenshots). All run in check.sh.

| File | What |
|------|------|
| short-description.md | Short description (PRIMARY + 2 alternates) |
| long-description.md | About This Game (BBCode) |
| features.md | 8 feature bullets |
| claims.md | Claims gate (page_ready flag) |
| tags.md | Tag and genre research, ordered 20 tags |
| pricing.md | Price comparison and recommendation |
| store-fields.md | Languages, categories, developer fields |
| system-requirements.md | Min/recommended (staged, measured vs estimated) |
| NAME-CHECK.md | Title conflict check and alternatives |
| ART-PLAN.md | Capsule art plan, Valve rule checklist, picks |
| art/ | Built capsule/library/icon assets (tools/steam_capsules.py) |
| screenshots.md, screenshots/ | Store screenshot plan + captures (tools/steam_shots.gd) |
| trailer.md, trailer_shots.json | Trailer script and beat list |
| facts.json | Generated counts |
