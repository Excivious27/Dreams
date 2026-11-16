# New Game: Setup Brief (phone-only, Godot 4)

**For:** the Claude Code session on Tom's Team Claude account
**Repo:** a brand-new GitHub repository for this game only, separate from The General Store repo
**Assets provided:** `reference/character_pack.zip` (5 custom pixel-art characters, ready to use)

---

## 1. Goal

Tom is building a **brand-new 2D game in Godot 4** (latest stable 4.x, GDScript). **He will describe the game himself.** Do not carry over any story, maps or systems from earlier projects. The only thing carried over is the character art in this pack.

Every push should automatically build a **web version on GitHub Pages**, so Tom can play the newest build from a link on his phone.

**Tom works only from his phone. He never uses a computer for this project.**

---

## 2. One-time setup (Tom, on his phone)

Walk Tom through these **one step at a time**. Wait for "done" before giving the next step.

1. **Create the repo** at github.com on mobile: **New repository** under Tom's **personal account** (not the store's organization), initialized with a README. Ask Tom for the game's name, and use it for the repo name.
   - **Visibility:** GitHub Pages is free for **public** repos. **Private** repos need a paid plan (GitHub Pro, about $4/month) to use Pages. Ask Tom which he wants. A repo's visibility affects only that repo.
2. **Upload the files:** in the repo, **Add file → Upload files**. Put `BRIEF.md` and `character_pack.zip` into a folder named `reference/`, then commit.
3. **Turn on Pages:** repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
4. **Connect Claude:** open Claude Code on the Team account (claude.ai/code or the Claude app) and connect GitHub. When GitHub asks which repositories to allow, choose **Only select repositories →** the new game repo. **Do not grant access to the store repo.** If Team admin settings block Claude Code or GitHub, Tom enables them as owner.
5. **Start a session** on the repo and send: *"Read reference/BRIEF.md and follow it."*

---

## 3. First tasks for Claude Code

1. **Unzip** `reference/character_pack.zip` into `art/characters/`, and commit.
2. **Set up the environment:** download the **Godot 4.x stable Linux binary and matching export templates** from `github.com/godotengine/godot/releases`, then verify with `godot --headless --version`. If the network blocks the download, tell Tom the exact domain to allow.
3. **Create the project scaffold:**
   - Phone-first: **portrait** layout, pixel-perfect (nearest-neighbor filtering, stretch mode `canvas_items`, aspect `keep`).
   - On-screen touch controls: a virtual D-pad plus **A**, **B** and **MENU** buttons. Keyboard also works.
   - Folders: `/scenes`, `/scripts`, `/data`, `/art`, `/audio`, `/docs`.
   - Saves go to `user://`.
4. **Set up web export and auto-deploy:**
   - Add a **"Web"** export preset with **Thread Support OFF** (single-threaded, so it runs on GitHub Pages). Output to `build/web/index.html`.
   - Add `.github/workflows/deploy.yml`, triggered on push to `main`. It should: download and cache Godot plus templates, run `godot --headless --export-release "Web" build/web/index.html`, upload with `actions/upload-pages-artifact`, then deploy with `actions/deploy-pages`.
5. **Build a character test scene:** load all five characters as `SpriteFrames`. Let Tom switch between them and walk each one around a simple test map with the D-pad, so he can see every animation on his phone.
6. **Report back:** push, confirm the deploy passed, and send Tom the link (`https://<username>.github.io/<repo>/`). Then **ask Tom to describe the game he wants to build.**

**Before every push:** run `godot --headless --path . --import` plus a smoke test that loads every scene. Never push a build that fails.

---

## 4. Character pack: what's inside

Five characters (folder names are neutral; Tom will give them names):

| Folder | Character |
|---|---|
| `man` | Man in a grey beanie, beige sweater, brown pants |
| `woman` | Woman with long wavy hair, floral kimono, denim shorts |
| `son` | Blond boy, grey patterned tee, navy joggers, drumsticks |
| `girl` | Girl with a blonde ponytail, purple glasses, black cat sweater, pink pants |
| `dog` | Black-and-tan fluffy puppy with a green collar |

Each character folder contains:

- **`frames/`**: full-resolution, background-removed PNG frames (the best quality, so scale these down in Godot as needed):
  - `idle_0`–`idle_3`: facing the camera
  - `walk_0`–`walk_3`, `run_0`–`run_3`, `attack_0`–`attack_3`: these **face RIGHT**, so flip them horizontally for left
  - `dog` also has `play_0`–`play_3`
  - `view_front`, `view_right`, `view_back`, `view_left`: standing poses for all four directions
- **`strips/`**: the same animations pre-scaled into horizontal sprite strips, anchored bottom-center. The cell size and frame order are in `characters.json`. There are three sizes:
  - `map_small`: about 26px-tall people at 2x detail
  - `map_large`: about 38px tall
  - `battle_medium`: about 52px tall
- **`characters.json`**: the file list for each animation, plus the strip cell sizes and frame order.

**Known gaps (ask Tom before filling them):**
- There are no walking-toward-camera or walking-away frames. For up/down movement, use the front/back view with a small bob until better art arrives.
- The woman's final attack frame lost part of its pink magic crescent during background removal.
- Tom may upload more art (ChatGPT sprite/tile sheets) to `art/incoming/`. Slice those, remove backgrounds and glow halos, and wire them in. Never delete Tom's uploads.

---

## 5. Working with Tom

- Short, phone-friendly replies. End every update with **the play link, what changed, and what to test**. Ask at most one question at a time, and put it last.
- Keep `docs/STATUS.md` current: what's done, what's next, known issues, and the link.
- Never ask Tom to run commands, install anything or use a computer.
- Use original characters and creatures only: no copyrighted characters, logos or brand art.
