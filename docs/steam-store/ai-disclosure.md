# Dreams: Steam Generative AI disclosure draft (S1 P5, 2026-11-20)

Status: **staged**. Entered by Claude in Chrome in the Steamworks session (Content Survey > AI Generated Content).
Must say the same as the in-game credits (tools/gen_epilogue.py CREDITS); `python3 tools/ratings_facts_check.py`
compares the key phrases and checks that the game makes no runtime AI calls.

## Pre-Generated content: tick the box, paste this

Dreams was made by a small family team working with AI tools. The character, world, item and interface art was
generated with OpenAI image models from our own prompts and designs, then cut, cleaned, palette-matched and
assembled into the game by hand and by script; the store artwork was made the same way. The music was generated
with ACE Music from our own prompts and lyrics. Most sound effects are human-made CC0 recordings, credited in the
game. Dialogue, quests and item text were written with Anthropic's Claude from our own story outline and reviewed
by us. Every AI-generated asset is checked for originality: no real brands, no copyrighted characters and no
imitation of other games' art.

## Live-Generated content: leave unticked

None. The game makes no calls to AI services while you play; nothing is generated at runtime.

## Short public version (store page AI disclosure box)

Art, music and in-game writing were made with generative AI tools (OpenAI image models, ACE Music, Anthropic's
Claude) from our own designs and story, then finished and reviewed by hand. Nothing is generated while you play.

## Notes

- Code written with Claude's help is an efficiency tool, not player-facing content; Valve's disclosure covers
  content players consume, so it is optional to mention.
- The provenance counts behind this text: art/gen/manifest.json (sliced art), audio/ACE_LOG.json (songs),
  audio/CC0_USED.json (sound effects), docs/AUDIO-CREDITS.md.
