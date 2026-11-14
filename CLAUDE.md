# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The SPLORR!! entry for **Ultimate AI-Powered Game Jam #7** (https://itch.io/jam/ultimate-ai-powered-game-jam-7), joined November 13, 2026. The repo (public, `playdeezgames/dream-stage-of-splorr`) was created by the user that day. The game is **Counting Sheep of SPLORR!!**, chosen by the user on November 13, 2026: an incremental where card sheep jump a fence (scored as cribbage pegging) into a Connect Four sheepfold, and four in a row of one suit scores as a cribbage hand, all to count a million sheep. **`DESIGN.md` is the design and records the user's decisions; read it first and keep it current.** Numbers in it are Claude's placeholders; decisions marked as the user's are not.

The vault at `/home/yermom/git/bok-of-splorr/splorr/` is the shared body of knowledge for all SPLORR!! games and holds the standing rules. Read its `Home.md` first. The jam's details are in `Jams/Ultimate AI-Powered Game Jam 7.md`; this game's note is `Games/Counting Sheep of SPLORR!!.md`. When a fact changes, update that note and its `Home.md` row too. `Gotchas.md` there has the wasm and Odin lessons.

## The jam's constraints (they shape every decision)

- **Theme DREAM is required** (the game must revolve around it). **STAGE is optional** but scores in "AI Direction & Adaptability"; the repo name suggests both. Say how both are used in the submission text.
- **72 hours: submissions close November 16, 2026 at 12:00 UTC** (4:00 AM PST). Assembly, logic and polish must happen inside the window (from November 13, 2026 12:00 UTC); no code from an older game may be ported in. Prepared boilerplate (the Odin wasm recipe) is allowed.
- Generative AI must be used for at least one major part (Claude Code writing the code meets this). Disclose the AI use on the page and in the game, as on every SPLORR!! game.
- Judged on enjoyment, theme fit, AI direction and **scope and completeness for 72 hours**: a finished small game beats a large unfinished one.
- After the deadline (rating, November 16 to 19) only bug fixes, balance numbers and small UI text changes are allowed; no new systems, levels or asset sets.

## Commands

Odin is at `/home/yermom/ODIN/odin` (put it on `PATH`).

```bash
tools/test.sh                  # native tests (odin test, one thread), wasm checks of both packages, then a real wasm build
tools/build.sh [--size]        # wasm build into build/web (--size for shipping)
tools/serve.sh                 # build and serve on http://localhost:${PORT:-8000}/
tools/pages.sh                 # tests, size build, copy into docs/ for GitHub Pages; never commits or pushes
./shippit.sh [--push]          # tests, size build, zip; butler push to itch.io only with --push (only on the user's "ship")
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:PLAYTEST=true -o:speed -define:ODIN_TEST_NAMES=game.playtest_nights  # bot plays whole nights (about 2 minutes); -define:PLAYTEST_QUICK=true for summaries only; DOZE_TIME, COUNT_GROWTH, COUNT_PRICE, DOG_PRICE are #config for sweeps
tools/make_shots.sh            # render assets/screenshots/01-play, 02-clear, 03-shop, 04-end natively (dump_test.odin)
python3 -I tools/make_cover.py # assets/cover.png (630x500) from a natively rendered frame
python3 -I tools/gen_gfx.py    # regenerate src/game/gfx.odin and font.odin from art/counting-sheep.json and the DINOBYTE sheet
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.<test_name>  # one test
odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:DUMP_CLEAR=/path/clear.ppm -define:ODIN_TEST_NAMES=game.dump_clear  # render a frame natively (dump_test.odin; also DUMP_PLAY)
```

The browser pane's launch config `counting-sheep-web` (port 8771, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first.

## Architecture

Odin compiled to `js_wasm32`, a 384 by 216 software framebuffer of Sweetie-16 palette indices drawn to a canvas (no WebGL), as in the vault's `Tech/Odin wasm recipe.md`. Real time: odin.js calls `step` with the frame's seconds; `game.tick` clamps dt to 0.25 s.

- `src/game/` is the pure rules package (no `core:os`, no `core:fmt`; its own splitmix64 RNG in `Game`, so tests are deterministic with a seed). `game.odin` holds the tuning constants at the top (Claude's placeholders), `Card`/`Suit` (rank 0 is no card), the pasture grid, the fold (`fold[col][row]`, row 0 at the bottom; a sheep sent from pasture row 0 under column `px - FOLD_FIRST_COL` drops to `landing_row`), `command`, `tick` and the `Sound` queue. The fold takes a sent sheep at once; `jumps` are only for drawing the arc. Lines (four or more of a suit in a row; a sheep in the air does not count) are found by `find_lines` when a jump lands. `resolve_lines` clears them into `sleepers` (drawing only), and `collapse` drops the sheep above (setting `fall` pixel offsets for drawing and re-aiming jumps in the air). `recheck_t` then runs the chain check; `chain` resets when a check finds nothing. `scoring.odin` is pure cribbage: `peg` (the running count in `Game.pegging`, called from `send_sheep`), `score_hand` (four cards plus the cut) and `score_line` (best four of a longer line, plus a point per extra sheep), called from `resolve_lines` with `g.moon` as the cut. `economy.odin` holds Zzz, laps and stages (`add_points` is the only way points are scored), `count_sheep_in` (count-by and the millionth sheep, which records `bests` and sets `finished`), `new_night`, the nightstand `Shop` (`shop_command`, `price`, `buy`, `buy_clear`) and the price constants. While the shop is open or the night is finished, `command` goes there instead of walking. `dogs.odin` is the sheepdogs: each `dog_step` either fetches (`pick_sheep_for`, scored on a `planning_fold` that includes other dogs' carried sheep) or carries to its committed `plan` pen and calls `send_card` (shared with `send_sheep`); `run_needed` makes dogs pickier as the fold fills and `dog_put_down` returns a sheep that would clog it. `save.odin` saves the whole `Game` as raw bytes behind a header (bump `SAVE_VERSION` whenever `Game`'s layout changes: old saves are then ignored, not migrated) and `save_is_sane` checks every count and card before a load is accepted. `menu.odin` is the Esc menu (sound, start over with a confirm). `doze` (in `game.odin`) removes sheep older than `DOZE_TIME` from the fold, unscored, via the per-cell `age`. `render.odin` lays out the screen (sky and fold on top, fence, pasture, the right panel, the bottom "in arms" strip) and draws card sheep by colour swap: wool (colour 12 in the sprite) becomes the suit colour, face cards get a black face. `screen.odin` is the framebuffer, palette, sprite blit with `Remap`, text and `commas`.
- **Art** is drawn by Claude in the Anvil (world `counting-sheep.json` in `~/anvil-worlds/`, exported to `art/counting-sheep.json`; tileset `sheep`, 16x16). After changing it, export again and run `tools/gen_gfx.py`; the `Gfx` enum follows its `NAMES` list. Never hand-edit `gfx.odin` or `font.odin`.
- `src/web/web.odin` (`package main`, `#+build js`) is the thin browser layer, imported as `tggd:game` (`-collection:tggd=src`). `web/index.html` maps arrows/WASD, Space (OK), Esc (Cancel), the gamepad and the touch pads to `platform_command` (the `Command` order must match), plays the `SOUNDS` table (must follow the `Sound` enum order), and opens the LootLocker feedback form on F (`web/lootlocker.js` is the vault's kit, unchanged; no LootLocker game set up yet).
- Progress against the build order is in `DESIGN.md`.

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Do neither unless the user says that word. **The jam submission is not scheduled in Coxswain** and does not count against one ship a day (the user, November 14, 2026): the jam's deadline decides. The page is up (https://thegrumpygamedev.itch.io/counting-sheep-of-splorr) and the entry was submitted on November 14, 2026; after the deadline only bug fixes, balance tweaks and small text changes. The itch build was uploaded in the dashboard, not by butler, so the first `shippit.sh --push` creates the `html` channel; remove the old dashboard upload then.
- **GitHub Pages is live** since November 13, 2026 (the user's go-ahead) at https://playdeezgames.github.io/dream-stage-of-splorr/, served from `main` `/docs`. To update it: `tools/pages.sh`, commit `docs/`, push (each push needs the user's go-ahead).
- itch.io embed: "Click to launch in fullscreen", never a fixed size. Footer back links and the "Send feedback" LootLocker link on the web page.
- **Public repo: no 1-Bit Kingdom art**, ever. Keep every licence record and credit.
- If the ROM font 8x8 turns up, ask the user before replacing it (DINOBYTE first, then Public Pixel).
- Anything an AI agent posts on itch.io says it was posted by an AI agent; publishing needs the user's yes each time.
- Do not describe or "fix" deliberate design as a problem once the user has decided it.
