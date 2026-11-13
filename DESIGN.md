# Counting Sheep of SPLORR!! — design

The entry for Ultimate AI-Powered Game Jam #7 (themes DREAM, required, and STAGE, optional). Chosen by the user on November 13, 2026 from three pitches. The other two pitches were "The Crib of SPLORR!!" and "Stage Fright of SPLORR!!"; neither is built.

Genre: the dig-through-a-huge-pile incremental (the user's references: One Million Coins, Needle In A Haystack, Lost Bitcoin). There is a huge finite pile, you gather by hand, carry it to a deposit point, upgrade, then automate. Our pile is a million sheep. On top of that sit cribbage, for the scoring, and Connect Four, for the sheepfold.

## The user's decisions (November 13, 2026)

- **Card sheep.** Every sheep is a playing card: a value from Ace to King (face cards are black-faced sheep) and a suit, shown as the colour of its wool. Cribbage scoring is real, not decoration.
- **A full sheepfold costs Zzz to clear** (see "Clearing the fold").
- **Sheep doze off in the fold** (chosen November 13, 2026, after a simulation showed more than about four dogs clog the fold): a sheep left in the fold 45 seconds dozes off and floats away unscored, and the sheep above drop. The fold always drains, so lines are a race against the clock.
- **The game ends at the millionth sheep counted**: the dreamer falls asleep. That's the win and the end screen.
- **Controls are Bush Master's set**: arrows/WASD, Space (OK), Esc (Cancel), gamepad d-pad/A/B, touch pads. No mouse clicks, no extra keys (F for the feedback form is the vault's rule).

Taken one at a time later the same day:
- **A clear you can't afford takes all yer Zzz** (even zero), so a full fold never leaves the player stuck.
- **The moon's card changes each sleep stage** (each lap of the board), so lines can be planned around it.
- **The player is the insomniac in pyjamas** (and nightcap), counting their own sheep.
- **All art is Claude-made in the Anvil**: sheep, insomniac, fence, moon, nightstand, sheepdog. One look, all AI-made.
- **After the millionth sheep: the totals, then a new night.** The end screen leads to a fresh start (upgrades reset), and the finished night's totals are kept as bests to beat.
- **A run to the millionth sheep should take about two hours** (like One Million Coins). Every number is tuned to that; the numbers themselves are still Claude's.

## The loop

1. **The pasture** (the lower part of the screen) holds the flock: a few dozen sheep wandering at a time, drawn from the million. A counter shows the total left ("999,812 sheep to count").
2. **Gather.** Walk into a sheep to pick it up. Yer armful holds a few at first and grows with upgrades. The sheep held show as cards in the HUD, in order.
3. **The fence** runs along the top of the pasture, with **the sheepfold**, a 7-by-6 Connect Four rack, above it. At the fence, Left/Right picks a column and Space sends the first sheep held over the fence.
4. **The jump counts.** Each sheep that jumps the fence is counted, toward the million, and **pegged**, scored like cribbage's pegging play (below).
5. **It lands** in the chosen column and falls to the lowest empty row, as in Connect Four.
6. **Four in a row of one suit** (across, down or diagonal) is a **line**. The line scores as a **cribbage hand**: the four sheep plus **the moon as the cut card** (the moon shows a card and changes each sleep stage). Then the four sheep fall asleep and float off as Zzz, and the sheep above them drop down. Chain clears score again.

### Pegging (each jump)

Kept close to real cribbage pegging so cribbage players recognise it:
- Each jump adds the sheep's value (Ace 1, face cards 10) to the **running count**.
- The count hitting exactly 15 scores 2. Hitting exactly 31 scores 2, and the count resets to 0.
- A sheep that would take the count past 31 is a "go": 1 point, and the count starts again from that sheep's value.
- A pair with the sheep before scores 2, three of a kind 6, four of a kind 12. A run of 3 or more among the last sheep (in any order) scores 1 per sheep.
- The running count and the last few sheep show by the fence.

### Hands (each line cleared)

A line plus the moon is scored as a five-card cribbage hand (a line of five or more: its best four, plus a point for each extra sheep): fifteens (2 each), pairs (2 each), runs (1 per card), flush (4, or 5 when the moon matches the suit; a line is always a flush) and **his nobs** (1 for the Jack of the moon's suit). The impossible score of 19 is a joke for cribbage players; a nod to it is welcome, but it isn't the goal.

## Points, Zzz and sleep stages (STAGE)

- Every point scored moves **a peg along a 121-hole cribbage board** (a strip along the side of the screen) and is also earned as **Zzz**, the currency, times the stage's multiplier.
- **Each lap of the board is a sleep stage**: Drowsy, then light sleep (N1), N2, deep sleep (N3), then REM, which repeats from then on. Each stage deepens the night sky, raises the Zzz multiplier and may unlock a shop row. This is the STAGE theme: stages of sleep, and the stage the sheep jump onto. There's no reset or prestige.

## Clearing the fold (the user's choice: pay to clear)

When the fold is full, or whenever the player likes, a column can be cleared for Zzz from the shop. The sheep in it are counted but not scored. If the fold is full and the player can't afford the price, the clear takes all the Zzz they have instead (the user's decision), so they are never stuck.

## The shop

A nightstand tile in the corner. Walk into it and a menu opens: Up/Down to choose, Space to buy, Esc to leave (Bush Master's pattern). Rows (prices and amounts are Claude's placeholders):
- **Bigger armful**: carry one more sheep.
- ~~Slippers: walk faster.~~ Replaced by **Greener grass** (+2 sheep wandering the pasture, five times) on November 13, 2026: the insomniac moves a tile per key press, so walking speed would buy nothing. Claude's change, the user's to undo.
- **Count by twos, fives, tens, …**: each jump counts as that many sheep, as dream logic allows. This is how a million becomes reachable in an hour or two.
- **Sheepdog**: automation. A dog fetches a sheep and sends it over the fence into the pen where it makes the longest run (see the step 5 note). More dogs and dog speed follow.
- **Clear a column** (above).

## Ending

Counting the 1,000,000th sheep: the dreamer falls asleep. An end screen shows the night's totals (sheep counted, points, best hand, sleep stage reached, time taken), then offers a new night: a fresh start with upgrades reset, keeping the bests to beat.

## Scope for 72 hours (deadline November 16, 2026 12:00 UTC)

Must have, in order:
1. Walking, gathering, the fence, the jump and the count.
2. Connect Four drops and same-suit line clears.
3. Pegging, then hand scoring with the moon, plus native tests for both scoring functions.
4. The pegboard and Zzz, the shop, sleep stages, clearing a column, and the millionth-sheep ending.
5. Sheepdogs.
6. Saves, sound, the release layout and the cover.

Progress:
- November 13, 2026: **step 1 done**. The insomniac walks a 20 by 5 pasture. Walking into a sheep picks it up (armful 3). At the fence, under one of the fold's 7 columns, Space or walking north sends the first sheep held over the fence, counted as it jumps. It lands at the bottom of the column (so the Connect Four drop half of step 2 is in), and a full column refuses. Sheep wander, and new ones wander in up to 10 at a time. Suit colours: spades white, hearts orange, diamonds cyan, clubs lime. 12 native tests. Sprites: sheep, insomniac, fence, fold cell, grass, all drawn in the Anvil. No saves yet.
- November 13, 2026: **step 2 done**. Four or more sheep of one suit in a row (across, down or either diagonal) make a line; a run of five or more is one line. Lines are checked when a sheep lands (a sheep still in the air does not count). Every line clears at once: the sheep fall asleep and float off with a "z", the sheep above drop down (a sheep in the air is re-aimed), and 0.4 s later the fold is checked again, so drops chain. The panel counts lines and the top chain. Not scored yet (step 3). Open for step 3: how a line of five or more scores as a cribbage hand, which needs exactly four sheep plus the moon. 24 native tests.
- November 13, 2026: **step 3 done**. Every jump is pegged (`scoring.odin`): the running count shows by the fence with the calls (fifteen 2, thirty-one 2 and a fresh count, a go for 1 that starts the count with the sheep that went over, pairs 2/6/12, runs of 3 or more in any order). Every line scores as a cribbage hand with the moon as the cut (fifteens, pairs, runs with doubles, flush 4 or 5, his nobs). **A line of five or more scores its best four plus a point for each extra sheep (the user's choice, November 13, 2026).** Each line's points float up off the fold and the notice says "Hand for N". The moon (a new Anvil sprite drawn at 2x, showing its card) is random for now; it changes each sleep stage in step 4. Points total on the panel. 33 native tests, including the 29 hand.
- November 13, 2026: **step 4 done** (`economy.odin`). Points earn Zzz at the stage multiplier (x1 drowsy, then one more for each lap) and peg a 121-hole board under the moon (three rows of 40 and the last hole). A full lap goes a stage deeper (Drowsy, then N1, N2, N3, REM over and over, counted in cycles) and brings a new moon; every line in one clear keeps the moon it was made under. The nightstand in the pasture's bottom-right corner opens the shop: Bigger armful (3 to 12; 30 Zzz, then x1.6), Greener grass (10 to 20 sheep; 40, x1.8), Count by (1, 2, 3, 5, 8, 12, 20, 30, 50, 75, 100, 150, 250, 400, 600, 1000; 60, x1.9), Clear a pen (Left/Right pick the pen; 15 x the multiplier; with the fold full and too few Zzz it takes all of them; not while a sheep is in the air; the cleared sheep are not scored), Leave. A row short of Zzz flashes red. The millionth sheep ends the night: a screen of the night's totals and the bests of all nights, then Space for a new night (everything resets but the bests). The prices came from a rough pacing model (about two hours before sheepdogs, which step 5 will speed up; retune then). 48 native tests.
- November 13, 2026: **step 5 done** (`dogs.odin`). Sheepdogs (up to 8, 150 Zzz then x2.8) and dog speed (2 tiles a second, +0.5 a level, six levels, 150 then x2.8) at the nightstand. A good dog fetches the sheep whose suit makes the longest run in the fold (nearest among equals), commits to that pen, and plans around the sheep other dogs are carrying. As the fold fills it gets pickier (any sheep while it is half empty, a run of 2 until three quarters full, then 3) and puts back a sheep that would only clog it. Dogs' sheep are counted and pegged like the insomniac's. **Sheep doze off after 45 s in the fold** (the user's choice; nodding off with a "z" in their last 10 s). Measured over ten simulated minutes with dogs alone: 1 dog about 175 sheep, 4 dogs about 650, 8 dogs about 1,150, the fold never full, about 2.5 points a sheep. **Claude's changes:** the Zzz multiplier now rises once per sleep cycle (four laps), not every lap, because laps came so fast with dogs that income ran away; count-by prices now 150, x3.0. The pacing model (with measured dog rates) puts the millionth sheep at about two hours, the last purchase about 25 minutes before the end. 60 native tests.
- November 13, 2026: **step 6 done; every must-have step is built.** Saves (`save.odin`): the whole night as raw bytes behind a header (magic, version 1, size), saved in localStorage every 3 s and when the page hides; a save from another build, or one that fails the field-by-field check, is ignored and a fresh night starts. The Esc menu in the pasture (`menu.odin`, Bush Master's pattern): Carry on, Sound on/off (kept across nights and saves), Start over (a red "START OVER?" with No first; the bests stay). "Start over" also under the screen (a browser confirm). Release standard in place: `ITCH_DESCRIPTION.md` (a draft, not approved), `assets/cover.png` and four screenshots rendered from the game (`tools/make_cover.py`, `tools/make_shots.sh`), `assets/CREDITS.md`, `devlog/20261113/devlog.md` (a draft, not posted); the release audit is all OK. 64 native tests.

## Playtest (November 13, 2026, by Claude at the user's request)

A bot (`src/game/playtest_test.odin`, off unless `-define:PLAYTEST=true`) plays whole nights through `command`, one key press every 0.2 s, in three styles: careful (picks sheep and pens to make lines), lazy (nearest sheep, emptiest pen) and relaxed (careful until the first dog, then only shops). Plus a short live session in the browser.

Found and fixed:
- **End-of-night soft-lock (bug):** new sheep stopped wandering in once the sheep in yer arms and the pasture could cover the rest, so a player holding sheep near the end left the dogs nothing to fetch and the night never ended. Sheep now wander in until the millionth is counted.
- **Too long, with dead stretches:** careful play took 3:00, lazy 3:35, and the last 30 to 50 minutes had nothing to buy. Count-by prices now grow x1.8 (were x3.0): careful 1:58, lazy 2:22, relaxed 2:28; the longest wait between purchases 12 to 16 minutes.
- **A slow, walking-only start:** the first sheepdog came at 10 minutes (careful) or 18 (lazy). It now costs 60 Zzz (was 150): 3.5 and 7 minutes.
- **Stages flew by:** late on, a new stage (new moon, notice, chime) came every 20 seconds, so planning around the moon was pointless. A lap of the board now takes 121 holes worth the multiplier each (121 points drowsy, 242 in cycle 1, and so on), so stages stay 2 to 3 minutes apart; about 45 stages a night.
- **Sheep in the way:** wandering sheep blocked the path to the fence once yer arms were full. Walking into one with full arms now swaps places with it.

Measured but left alone:
- **Dozing hits careless play hardest:** a lazy player's first ten minutes doze off 206 of 293 sheep (16 lines); a careful player's 73 of 346 (47 lines). A trial where sheep doze only once the fold is half full helped careful play and not lazy play, and changed no finish time, so the user's rule stands. Longer doze times (75, 90 s) made the fold fill and cost more clears.
- **Walking is about 90% of a hands-on player's key presses.** After the first dog a player can stop and let the dogs work and still finish about 25 minutes later than a careful player.
- **Hands above 29 happen** (31 to 33 seen): the sheep are drawn from an endless deck, so a line can hold the same card more than once. Left as dream logic.

Nice to have: a different sky and music per sleep stage, chain-clear celebrations, and a 19 Easter egg.

## Open (Claude's placeholders until the user says)

Every number (armful size, prices, the stage multiplier, how many sheep are in the pasture, dog speed), tuned so a run takes about two hours. Nothing else is open.
