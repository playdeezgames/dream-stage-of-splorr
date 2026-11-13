# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The SPLORR!! entry for **Ultimate AI-Powered Game Jam #7** (https://itch.io/jam/ultimate-ai-powered-game-jam-7), joined November 13, 2026. The repo (public, `playdeezgames/dream-stage-of-splorr`) was created by the user that day with only a README. There is no code or concept yet. Do not pick one alone: pitch a few ideas and let the user choose.

The vault at `/home/yermom/git/bok-of-splorr/splorr/` is the shared body of knowledge for all SPLORR!! games and holds the standing rules. Read its `Home.md` first. The jam's details are in `Jams/Ultimate AI-Powered Game Jam 7.md`. Once there is a concept, create `Games/<title>.md` there with full frontmatter, link it from `Home.md`, and keep both up to date when facts change. `Gotchas.md` there has the wasm and Odin lessons.

## The jam's constraints (they shape every decision)

- **Theme DREAM is required** (the game must revolve around it). **STAGE is optional** but scores in "AI Direction & Adaptability"; the repo name suggests both. Say how both are used in the submission text.
- **72 hours: submissions close November 16, 2026 at 12:00 UTC** (4:00 AM PST). Assembly, logic and polish must happen inside the window (from November 13, 2026 12:00 UTC); no code from an older game may be ported in. Prepared boilerplate (the Odin wasm recipe) is allowed.
- Generative AI must be used for at least one major part (Claude Code writing the code meets this). Disclose the AI use on the page and in the game, as on every SPLORR!! game.
- Judged on enjoyment, theme fit, AI direction and **scope and completeness for 72 hours**: a finished small game beats a large unfinished one.
- After the deadline (rating, November 16 to 19) only bug fixes, balance numbers and small UI text changes are allowed; no new systems, levels or asset sets.

## Commands and architecture

None yet. The default stack is Odin compiled to `js_wasm32` on an HTML5 canvas (no WebGL), set up as in the vault's `Tech/Odin wasm recipe.md`, with the layout of `Tech/Release standard.md` from the start (`ITCH_DESCRIPTION.md`, `assets/cover.png` at 630x500, `assets/screenshots/`, `devlog/YYYYMMDD/`, `tools/ship.sh` and a one-line `shippit.sh` that pushes only with `--push`). `/home/yermom/git/bush-master-of-splorr` is a recent, complete example of that layout (`src/game/` pure rules with native tests, `src/web/` the thin `#+build js` layer, `web/index.html` the shim, `tools/test.sh`, `build.sh`, `serve.sh`, `pages.sh`). Replace this section with the real commands once they exist.

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Do neither unless the user says that word. The jam submission is an itch.io release: one ship a day through Coxswain (`ship_today` before, `ship_complete` after); scheduling is not permission.
- **GitHub Pages is the default**; the repo is already public, but enabling Pages is the user's call.
- itch.io embed: "Click to launch in fullscreen", never a fixed size. Footer back links and the "Send feedback" LootLocker link on the web page.
- **Public repo: no 1-Bit Kingdom art**, ever. Keep every licence record and credit.
- If the ROM font 8x8 turns up, ask the user before replacing it (DINOBYTE first, then Public Pixel).
- Anything an AI agent posts on itch.io says it was posted by an AI agent; publishing needs the user's yes each time.
- Do not describe or "fix" deliberate design as a problem once the user has decided it.
