package game

// The rules of Counting Sheep of SPLORR!! (see DESIGN.md). Pure: no core:os, no core:fmt, its own RNG.
//
// Slice 1: the insomniac walks a pasture, picks up card sheep by walking into them, and sends them
// one at a time over the fence into the 7-by-6 sheepfold above it (Connect Four style: a sheep drops
// to the lowest empty spot of the column the insomniac stands under). Each jump counts one sheep
// toward the million.
//
// Slice 2: four or more sheep of one suit in a row (across, down or diagonal) make a line. When a
// sheep lands, every line clears at once: those sheep fall asleep and float off, the sheep above drop
// down, and after a short pause the fold is checked again, so drops can chain.

// Tuning. Claude's placeholders; the user's to change.
TOTAL_SHEEP :: 1_000_000
FLOCK_TARGET :: 10 // sheep wandering the pasture at once
ARMFUL_START :: 3 // sheep the insomniac can carry at first
SPAWN_EVERY :: 0.7 // seconds between new sheep wandering in
WANDER_MIN :: 1.5 // seconds a sheep stands before it wanders a step
WANDER_SPREAD :: 3.0 // plus up to this many more
JUMP_TIME :: 0.55 // seconds a jump over the fence takes
NOTICE_TIME :: 1.6
CLEAR_PAUSE :: 0.4 // seconds between a clear and the chain check after the sheep above drop
FALL_SPEED :: 240.0 // pixels a second a dropped sheep falls, for drawing
SLEEP_TIME :: 1.2 // seconds a cleared sheep takes to float off
LINE_LENGTH :: 4

// Layout, in tiles of the pasture grid. The fold's first column stands over pasture column
// FOLD_FIRST_COL, so walking along the fence chooses the column.
PASTURE_COLS :: 20
PASTURE_ROWS :: 5
FOLD_COLS :: 7
FOLD_ROWS :: 6
FOLD_FIRST_COL :: 6

ARMFUL_MAX :: 12
FLOCK_MAX :: 32
JUMPS_MAX :: 16
SOUNDS_MAX :: 16
SLEEPERS_MAX :: FOLD_COLS * FOLD_ROWS

Suit :: enum u8 {
	Spades,
	Hearts,
	Diamonds,
	Clubs,
}

// A playing card. rank 0 is no card; 1 is the Ace, 11 to 13 the Jack, Queen and King.
Card :: struct {
	rank: u8,
	suit: Suit,
}

Sheep :: struct {
	card: Card,
	x, y: i32,
	flip: bool, // facing left
	wait: f32, // seconds until it wanders
}

// A sheep in the air over the fence. The fold already holds it; this is only for drawing.
Jump :: struct {
	card:     Card,
	from_col: i32, // pasture column it jumped from
	col, row: i32, // where it lands in the fold
	t:        f32,
	flip:     bool,
}

// Order matches the page's C table (web/index.html).
Command :: enum u8 {
	North,
	South,
	West,
	East,
	Ok,
	Cancel,
}

// Order matches the page's SOUNDS table (web/index.html).
Sound :: enum u8 {
	Pick,
	Jump,
	Land,
	Deny,
	Clear,
}

Notice :: enum u8 {
	None,
	Arms_Full,
	Arms_Empty,
	Not_Under_Fold,
	Column_Full,
	Line,
}

// A cleared sheep floating off asleep, for drawing.
Sleeper :: struct {
	card:     Card,
	col, row: i32,
	t:        f32,
}

Game :: struct {
	rng:         u64,
	px, py:      i32, // the insomniac, in pasture tiles; row 0 is along the fence
	flip:        bool,
	held:        [ARMFUL_MAX]Card, // held[0] jumps first
	held_count:  i32,
	armful:      i32,
	flock:       [FLOCK_MAX]Sheep,
	flock_count: i32,
	fold:        [FOLD_COLS][FOLD_ROWS]Card, // row 0 is the bottom, against the fence
	counted:     i64,
	jumps:       [JUMPS_MAX]Jump,
	jump_count:  i32,
	fall:        [FOLD_COLS][FOLD_ROWS]f32, // pixels above its spot a dropped sheep still is (drawing)
	sleepers:    [SLEEPERS_MAX]Sleeper,
	sleeper_count: i32,
	recheck_t:   f32, // > 0 while a chain is settling
	chain:       i32, // clears in the current chain
	best_chain:  i32,
	lines:       i64, // lines cleared
	spawn_t:     f32,
	notice:      Notice,
	notice_t:    f32,
	sounds:      [SOUNDS_MAX]Sound,
	sound_count: i32,
	time:        f64,
}

init_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed
	g.px, g.py = PASTURE_COLS / 2, 2
	g.armful = ARMFUL_START
	for _ in 0 ..< FLOCK_TARGET {
		spawn_sheep(g)
	}
}

// splitmix64
next_u64 :: proc(g: ^Game) -> u64 {
	g.rng += 0x9E3779B97F4A7C15
	z := g.rng
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

rand_int :: proc(g: ^Game, n: int) -> int {
	return int(next_u64(g) % u64(n))
}

rand_f32 :: proc(g: ^Game) -> f32 {
	return f32(next_u64(g) >> 40) / f32(1 << 24)
}

random_card :: proc(g: ^Game) -> Card {
	return {rank = u8(1 + rand_int(g, 13)), suit = Suit(rand_int(g, 4))}
}

// Cribbage value: Ace 1, face cards 10.
card_value :: proc(c: Card) -> int {
	return min(int(c.rank), 10)
}

is_face :: proc(c: Card) -> bool {
	return c.rank >= 11
}

play :: proc(g: ^Game, s: Sound) {
	if g.sound_count < SOUNDS_MAX {
		g.sounds[g.sound_count] = s
		g.sound_count += 1
	}
}

show_notice :: proc(g: ^Game, n: Notice) {
	g.notice = n
	g.notice_t = NOTICE_TIME
}

in_pasture :: proc(x, y: i32) -> bool {
	return x >= 0 && y >= 0 && x < PASTURE_COLS && y < PASTURE_ROWS
}

sheep_at :: proc(g: ^Game, x, y: i32) -> int {
	for i in 0 ..< int(g.flock_count) {
		if g.flock[i].x == x && g.flock[i].y == y {
			return i
		}
	}
	return -1
}

tile_free :: proc(g: ^Game, x, y: i32) -> bool {
	return in_pasture(x, y) && sheep_at(g, x, y) < 0 && !(x == g.px && y == g.py)
}

// Sheep not yet seen: neither counted, carried nor wandering the pasture.
sheep_unseen :: proc(g: ^Game) -> i64 {
	return TOTAL_SHEEP - g.counted - i64(g.held_count) - i64(g.flock_count)
}

sheep_to_count :: proc(g: ^Game) -> i64 {
	return TOTAL_SHEEP - g.counted
}

// A new sheep wanders onto a free tile, if the pasture has room and any sheep are left.
spawn_sheep :: proc(g: ^Game) -> bool {
	if g.flock_count >= FLOCK_TARGET || g.flock_count >= FLOCK_MAX || sheep_unseen(g) <= 0 {
		return false
	}
	for _ in 0 ..< 40 {
		x := i32(rand_int(g, PASTURE_COLS))
		y := i32(rand_int(g, PASTURE_ROWS))
		if !tile_free(g, x, y) {
			continue
		}
		g.flock[g.flock_count] = {
			card = random_card(g),
			x    = x,
			y    = y,
			flip = rand_int(g, 2) == 0,
			wait = WANDER_MIN + rand_f32(g) * WANDER_SPREAD,
		}
		g.flock_count += 1
		return true
	}
	return false
}

remove_sheep :: proc(g: ^Game, i: int) {
	g.flock_count -= 1
	g.flock[i] = g.flock[g.flock_count]
}

command :: proc(g: ^Game, c: Command) {
	switch c {
	case .North:
		if g.py == 0 {
			send_sheep(g) // walking into the fence sends a sheep over
		} else {
			step(g, 0, -1)
		}
	case .South:
		step(g, 0, 1)
	case .West:
		step(g, -1, 0)
	case .East:
		step(g, 1, 0)
	case .Ok:
		if g.py == 0 {
			send_sheep(g)
		}
	case .Cancel:
	}
}

step :: proc(g: ^Game, dx, dy: i32) {
	if dx < 0 {
		g.flip = true
	} else if dx > 0 {
		g.flip = false
	}
	nx, ny := g.px + dx, g.py + dy
	if !in_pasture(nx, ny) {
		return
	}
	if i := sheep_at(g, nx, ny); i >= 0 {
		pick_sheep(g, i)
		return
	}
	g.px, g.py = nx, ny
}

pick_sheep :: proc(g: ^Game, i: int) {
	if g.held_count >= g.armful {
		show_notice(g, .Arms_Full)
		play(g, .Deny)
		return
	}
	g.held[g.held_count] = g.flock[i].card
	g.held_count += 1
	remove_sheep(g, i)
	play(g, .Pick)
}

// The fold column the insomniac stands under, or -1.
fold_column :: proc(g: ^Game) -> i32 {
	col := g.px - FOLD_FIRST_COL
	if g.py != 0 || col < 0 || col >= FOLD_COLS {
		return -1
	}
	return col
}

// The lowest empty row of a fold column, or -1 when it is full.
landing_row :: proc(g: ^Game, col: i32) -> i32 {
	for r in 0 ..< i32(FOLD_ROWS) {
		if g.fold[col][r].rank == 0 {
			return r
		}
	}
	return -1
}

// Sends the first sheep held over the fence into the column above: it is counted as it jumps.
send_sheep :: proc(g: ^Game) -> bool {
	col := fold_column(g)
	if col < 0 {
		show_notice(g, .Not_Under_Fold)
		play(g, .Deny)
		return false
	}
	if g.held_count == 0 {
		show_notice(g, .Arms_Empty)
		play(g, .Deny)
		return false
	}
	row := landing_row(g, col)
	if row < 0 {
		show_notice(g, .Column_Full)
		play(g, .Deny)
		return false
	}
	card := g.held[0]
	for i in 1 ..< int(g.held_count) {
		g.held[i - 1] = g.held[i]
	}
	g.held_count -= 1
	g.held[g.held_count] = {}
	g.fold[col][row] = card
	g.counted += 1
	if g.jump_count < JUMPS_MAX {
		g.jumps[g.jump_count] = {
			card     = card,
			from_col = g.px,
			col      = col,
			row      = row,
			flip     = false,
		}
		g.jump_count += 1
	}
	play(g, .Jump)
	return true
}

// True while a sheep is still in the air on its way to this fold cell.
landing_pending :: proc(g: ^Game, col, row: i32) -> bool {
	for i in 0 ..< int(g.jump_count) {
		if g.jumps[i].col == col && g.jumps[i].row == row {
			return true
		}
	}
	return false
}

// Advances real time: jumps land, sheep wander and wander in, notices fade.
tick :: proc(g: ^Game, dt_in: f64) {
	dt := f32(min(max(dt_in, 0), 0.25))
	g.time += f64(dt)

	i := 0
	for i < int(g.jump_count) {
		g.jumps[i].t += dt
		if g.jumps[i].t >= JUMP_TIME {
			g.jump_count -= 1
			g.jumps[i] = g.jumps[g.jump_count]
			play(g, .Land)
			resolve_lines(g)
			continue
		}
		i += 1
	}

	for c in 0 ..< FOLD_COLS {
		for r in 0 ..< FOLD_ROWS {
			g.fall[c][r] = max(0, g.fall[c][r] - FALL_SPEED * dt)
		}
	}
	if g.recheck_t > 0 {
		g.recheck_t -= dt
		if g.recheck_t <= 0 {
			g.recheck_t = 0
			if !resolve_lines(g) {
				g.chain = 0
			}
		}
	}
	si := 0
	for si < int(g.sleeper_count) {
		g.sleepers[si].t += dt
		if g.sleepers[si].t >= SLEEP_TIME {
			g.sleeper_count -= 1
			g.sleepers[si] = g.sleepers[g.sleeper_count]
			continue
		}
		si += 1
	}

	if g.notice_t > 0 {
		g.notice_t -= dt
		if g.notice_t <= 0 {
			g.notice = .None
		}
	}

	g.spawn_t += dt
	if g.spawn_t >= SPAWN_EVERY {
		g.spawn_t = 0
		spawn_sheep(g)
	}

	for k in 0 ..< int(g.flock_count) {
		s := &g.flock[k]
		s.wait -= dt
		if s.wait > 0 {
			continue
		}
		s.wait = WANDER_MIN + rand_f32(g) * WANDER_SPREAD
		DIRS := [4][2]i32{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		d := DIRS[rand_int(g, 4)]
		if tile_free(g, s.x + d[0], s.y + d[1]) {
			s.x += d[0]
			s.y += d[1]
			if d[0] != 0 {
				s.flip = d[0] < 0
			}
		}
	}
}

// A fold cell that counts toward lines: a landed sheep (one still in the air does not count yet).
line_card :: proc(g: ^Game, col, row: i32) -> (Card, bool) {
	if col < 0 || row < 0 || col >= FOLD_COLS || row >= FOLD_ROWS {
		return {}, false
	}
	c := g.fold[col][row]
	if c.rank == 0 || landing_pending(g, col, row) {
		return {}, false
	}
	return c, true
}

// Marks every sheep in a run of LINE_LENGTH or more of one suit; returns how many runs there are.
// A run longer than four is one line.
find_lines :: proc(g: ^Game, marks: ^[FOLD_COLS][FOLD_ROWS]bool) -> int {
	DIRS := [4][2]i32{{1, 0}, {0, 1}, {1, 1}, {1, -1}}
	lines := 0
	for d in DIRS {
		for col in 0 ..< i32(FOLD_COLS) {
			for row in 0 ..< i32(FOLD_ROWS) {
				c, ok := line_card(g, col, row)
				if !ok {
					continue
				}
				// Only start at the first sheep of a run.
				if p, pok := line_card(g, col - d[0], row - d[1]); pok && p.suit == c.suit {
					continue
				}
				n: i32 = 1
				for {
					q, qok := line_card(g, col + n * d[0], row + n * d[1])
					if !qok || q.suit != c.suit {
						break
					}
					n += 1
				}
				if n >= LINE_LENGTH {
					lines += 1
					for k in 0 ..< n {
						marks[col + k * d[0]][row + k * d[1]] = true
					}
				}
			}
		}
	}
	return lines
}

// Clears every line in the fold, lets the sheep above drop, and starts the chain check. False when
// there was nothing to clear.
resolve_lines :: proc(g: ^Game) -> bool {
	marks: [FOLD_COLS][FOLD_ROWS]bool
	n := find_lines(g, &marks)
	if n == 0 {
		return false
	}
	for col in 0 ..< i32(FOLD_COLS) {
		for row in 0 ..< i32(FOLD_ROWS) {
			if !marks[col][row] {
				continue
			}
			if g.sleeper_count < SLEEPERS_MAX {
				g.sleepers[g.sleeper_count] = {card = g.fold[col][row], col = col, row = row}
				g.sleeper_count += 1
			}
			g.fold[col][row] = {}
			g.fall[col][row] = 0
		}
	}
	collapse(g)
	g.lines += i64(n)
	g.chain += 1
	g.best_chain = max(g.best_chain, g.chain)
	g.recheck_t = CLEAR_PAUSE
	show_notice(g, .Line)
	play(g, .Clear)
	return true
}

// Drops every sheep to the lowest empty spot of its column. Sheep still in the air keep their place
// in the column, and their jump is re-aimed.
collapse :: proc(g: ^Game) {
	for col in 0 ..< i32(FOLD_COLS) {
		w: i32 = 0
		for r in 0 ..< i32(FOLD_ROWS) {
			if g.fold[col][r].rank == 0 {
				continue
			}
			if r != w {
				g.fold[col][w] = g.fold[col][r]
				g.fold[col][r] = {}
				g.fall[col][w] = g.fall[col][r] + f32(r - w) * TILE
				g.fall[col][r] = 0
				for j in 0 ..< int(g.jump_count) {
					if g.jumps[j].col == col && g.jumps[j].row == r {
						g.jumps[j].row = w
					}
				}
			}
			w += 1
		}
	}
}
