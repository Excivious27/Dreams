# Steam store and library art plan

Built by `python3 tools/steam_capsules.py` from text-free masters + one swappable logo layer; checked by `python3 tools/steam_capsules_check.py` (check.sh). Outputs in docs/steam-store/art/ (docs/* never ships in a build), with previews at Steam's auto sizes in art/previews/ and art/contact_sheet.png. Prompts: docs/src/steam-capsule-prompts.md.

## Masters (rendered 2026-11-20, 10 images; picks)
| Master | File | Pick | Alternates kept |
|--------|------|------|-----------------|
| Wide key art, 3072x1024 | art/incoming/steam/key_wide.png | key_wide.png (crystal centred, trio on the rock) | key_wide-2.png |
| Tall key art (edit of the wide), 1024x1536 | art/incoming/steam/key_tall.png | key_tall.png | key_tall-2.png |
| Logo (transparent) | art/incoming/steam/logo-2.png | logo-2 (cleanest outline, crystal crown on the D) | logo.png, logo-3.png |
| App icon, 1024 | art/incoming/steam/icon.png | icon.png | icon-2.png |

One scene, two framings (wide for header/main/small/hero/background; tall for vertical and library capsule), so every capsule reads as one product. The composition sells both arcs: the cozy farm with Pip-Pip (crown) and Nova (wizard hat) at the crystal on the left/centre, the neon skyline and a long-coat crew on the bridge on the right; no weapons, no blood (PG-13 rule easily met). The farmer is seen from behind so the player character stays unspecified. The old title art (art/gen/ui/title_keyart, wordmarks) has DREAMS painted in and is refused by the composer (BAKED_TEXT).

## Assets and Valve rules (pass/fail)
Sizes from https://partner.steamgames.com/doc/store/assets/standard, /libraryassets, /community; rules from /rules (only artwork + game name/official subtitle; no review scores, awards, discount copy or other text; event text only through 1-month Artwork Overrides).

| Asset | Size | Logo | Grid x scale | Check |
|-------|------|------|--------------|-------|
| header_capsule.png | 920x430 | yes | 460x215 x2 | pass |
| small_capsule.png | 462x174 | yes, ~92% width over a dimmed crop (readable at 120x45 and 184x69, see previews) | x1 | pass |
| main_capsule.png | 1232x706 | yes | 616x353 x2 | pass |
| vertical_capsule.png | 748x896 | yes | 374x448 x2 | pass |
| page_background.png | 1438x810 (optional) | no (blurred, dark, ambient) | 719x405 x2 | pass |
| library_capsule.png | 600x900 | yes | 300x450 x2 | pass |
| library_header.png | 920x430 | yes | 460x215 x2 | pass |
| library_hero.png | 3840x1240 | **no text** (enforced) | 960x310 x4; focal trio + crystal inside the centred 1720x760 safe area | pass |
| library_logo.png | 1280 wide, transparent PNG | logotype only | - | pass |
| app_icon.jpg | 184x184 JPG | no | flattened on the icon's indigo, never black | pass |
| shortcut_icon.png | 512x512 PNG | no | opaque | pass |
| icon_256.ico | 256/64/32/16 ICO | no | for the Windows export preset application/icon (hook: P1) | pass |

Pixel look: each scene asset is BOX-downsampled to a native pixel grid and NEAREST-upscaled by an integer, so the chunky pixels stay crisp at every size (the check fails on any non-integer grid).

## Logo position in the library (Steamworks preview tool)
Library Assets > Hero > logo position: centred top, logo width about 40% of the hero (the top-centre sky of the hero is kept empty for it).

## Rename (NAME-CHECK.md)
Masters are text-free; the title lives only in the logo layer. After Tom picks: render logo_<slug>.png with prompt 3 (n=3), then `python3 tools/steam_capsules.py --logo art/incoming/steam/logo_<slug>.png`. Never put "(working title)" in any art.

## Overrides policy
Base capsules never carry event text (Next Fest, update names, sales). Seasonal or event versions go up as Steam Artwork Overrides (max one month, localised), made as a separate set later; the composer itself only ever stamps the logo layer.

## Web icon
web/icon_*.png stays unchanged (Decision note: the crowned-crystal icon could replace the web gem icon if Tom wants one icon everywhere).
