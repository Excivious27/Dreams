# Guide #1: What I need next

**Where the game is:** both story openings, farm with farming/fishing/sell box,
house and sleep, a town with 5 people and 3 shops, the meadow fight and first boss,
the mine, skills, day/night, placeholder music. Everything is drawn with placeholder
shapes until your art arrives, and every name below (Maple, Gideon, Wren, Alder, Sal,
"Dreamhollow", the crops) is a stand-in you can replace. Your notes are saved in
`docs/DESIGN.md`; what exists is listed in `docs/STATUS.md`.

Answer what you can, in any order, right in chat. Short answers are fine. Skip
anything you haven't decided; I'll use a placeholder and flag it. The items are in
order of how much they unblock.

## A. The starter town (unblocks the next build)
1. **Town name** (default I'm using: Dreamhollow). Is the town the same in both arcs?
2. **Setting**: season/climate, coastal or inland, forest/mountain/desert? One sentence.
3. **6 to 8 starter NPCs**: name, job (general store owner, blacksmith, etc.), one line of
   personality. Which ones are friends you can level up with?
4. **Shops at launch**: general store, weapons, potions... anything else?
5. **Your plot**: how big (small / Stardew-sized / huge)? Pond, river, or neither? Is the
   house there from day one?

## B. The daily loop
6. **Day length and energy**: a clock like Stardew (day ends, you sleep)? Energy bar?
7. **First tools**: hoe, watering can, axe, pickaxe, fishing rod, sword... which are
   yours on day one?
8. **First 5 crops** and what they sell for in crystals (rough numbers are fine).
9. **Trading**: everything has a trade value. Is bartering with NPCs a mini-game, a
   slider, or just "offer X for Y"?

## C. The penguin arc, first hour
10. What are the **penguins like**? Size (dog-sized? kid-sized?), colors, anything that
    makes them "Too Powerful" at a glance. Same for **Big Jim** and the **Light Crystal**
    (does the Light Crystal float? glow? have a face?).
11. The **Meow Pow Wow**: list the abilities you already know of (even 3 or 4), and
    which one you start with.
12. The **Grumps**: what do grunt enemies look like, and what's the first boss?
13. How does the arc **open**: a crash-landed crystal? a dream? the penguins arrive in
    town?

## D. The gangster arc, first hour
14. The **president's gang** name, and the president's name and look.
15. Who is the **first gangster** you meet, what's their ability, and what region do
    they control?
16. How does this arc **open**: do you arrive in town on the run? Who gave you the plot?
17. Can you still make friends and be "good" here, or is every choice shades of grey?

## E. The connection
18. One paragraph, spoilers welcome: **how do the two arcs connect?** (I only need
    enough to plant early hints.)

## F. Music and sound
19. **Mood per area**: title screen, farm (day), town, mines, combat, penguin story
    beats, gangster story beats. A word or two each (cozy, eerie, upbeat chiptune,
    orchestral...).
20. **Style**: chiptune (8-bit/16-bit), lo-fi, orchestral, acoustic, or a mix?
21. **Source**: pick one.
    - You generate tracks with an AI music tool (Suno, Udio, etc.) and upload `.ogg` or
      `.mp3` to `audio/incoming/`. I'll write the prompts (next guide).
    - I use free CC0 music from OpenGameArt/Kenney and we swap later.
    - A musician you know.
22. **Sound effects**: same question. (Kenney's CC0 packs are a fast start.)

## G. Platform decisions (no rush, but they shape the code)
23. **Multiplayer**: web on GitHub Pages can't host co-op by itself. Options:
    (a) build single-player now, co-op later via a native Android build;
    (b) add a small relay server (costs a few dollars a month);
    (c) local "pass-the-phone" co-op first. Which direction?
24. **Save slots**: one run per device, or several?
25. **Controls**: are the D-pad and buttons comfortable, or should I try a floating
    joystick where your thumb lands?

## H. Art direction (feeds the ChatGPT prompts)
26. Look at `docs/ART-PROMPTS.md`. Pick a **palette mood** (bright & saturated, soft
    pastel, moody dusk) and tell me the first thing you want generated.

---
When you've answered, I'll update `docs/DESIGN.md`, build the next slice, and send
Guide #2.
