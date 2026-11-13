# Counting Sheep of SPLORR!! — design

The entry for Ultimate AI-Powered Game Jam #7 (themes DREAM, required, and STAGE, optional). Chosen by the user on November 13, 2026 from three pitches. The other two pitches were "The Crib of SPLORR!!" and "Stage Fright of SPLORR!!"; neither is built.

Genre: the dig-through-a-huge-pile incremental (the user's references: One Million Coins, Needle In A Haystack, Lost Bitcoin). There is a huge finite pile, you gather by hand, carry it to a deposit point, upgrade, then automate. Our pile is a million sheep. On top of that sit cribbage, for the scoring, and Connect Four, for the sheepfold.

## The user's decisions (November 13, 2026)

- **Card sheep.** Every sheep is a playing card: a value from Ace to King (face cards are black-faced sheep) and a suit, shown as the colour of its wool. Cribbage scoring is real, not decoration.
- **A full sheepfold costs Zzz to clear** (see "Clearing the fold").
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

A line plus the moon is scored as a five-card cribbage hand: fifteens (2 each), pairs (2 each), runs (1 per card), flush (4, or 5 when the moon matches the suit; a line is always a flush) and **his nobs** (1 for the Jack of the moon's suit). The impossible score of 19 is a joke for cribbage players; a nod to it is welcome, but it isn't the goal.

## Points, Zzz and sleep stages (STAGE)

- Every point scored moves **a peg along a 121-hole cribbage board** (a strip along the side of the screen) and is also earned as **Zzz**, the currency, times the stage's multiplier.
- **Each lap of the board is a sleep stage**: Drowsy, then light sleep (N1), N2, deep sleep (N3), then REM, which repeats from then on. Each stage deepens the night sky, raises the Zzz multiplier and may unlock a shop row. This is the STAGE theme: stages of sleep, and the stage the sheep jump onto. There's no reset or prestige.

## Clearing the fold (the user's choice: pay to clear)

When the fold is full, or whenever the player likes, a column can be cleared for Zzz from the shop. The sheep in it are counted but not scored. If the fold is full and the player can't afford the price, the clear takes all the Zzz they have instead (the user's decision), so they are never stuck.

## The shop

A nightstand tile in the corner. Walk into it and a menu opens: Up/Down to choose, Space to buy, Esc to leave (Bush Master's pattern). Rows (prices and amounts are Claude's placeholders):
- **Bigger armful**: carry one more sheep.
- **Slippers**: walk faster.
- **Count by twos, fives, tens, …**: each jump counts as that many sheep, as dream logic allows. This is how a million becomes reachable in an hour or two.
- **Sheepdog**: automation. A dog herds the nearest sheep to the fence and drops it in the column with the fewest sheep. More dogs and faster dogs follow.
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

Nice to have: a different sky and music per sleep stage, chain-clear celebrations, and a 19 Easter egg.

## Open (Claude's placeholders until the user says)

Every number (armful size, prices, the stage multiplier, how many sheep are in the pasture, dog speed), tuned so a run takes about two hours. Nothing else is open.
