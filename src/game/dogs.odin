package game

// Sheepdogs (DESIGN.md, step 5): bought at the nightstand. A dog picks a sheep no other dog is after,
// picks it up, carries it to the fence and sends it over, like the insomniac does. Its sheep are
// counted and pegged the same way. A good dog fetches the sheep that would make the longest run of
// its suit in the fold (nearest among equals) and sends it where it does, so the fold keeps clearing;
// the emptiest column when nothing lines up. Once the fold is half full a dog fetches only sheep
// that extend a run, and waits when there are none, rather than clog the fold.
// Dogs walk over sheep and the insomniac; only the nightstand is in their way.

DOGS_MAX :: 8
DOG_SPEED :: 2.0 // tiles a second
DOG_SPEED_STEP :: 0.5 // more per speed level
DOG_SPEED_LEVELS :: 6
DOG_REST :: 1.5

Dog :: struct {
	x, y:     i32,
	flip:     bool,
	carrying: bool,
	card:     Card, // the sheep it carries
	target:   u32, // the id of the sheep it is after; 0 for none
	plan:     i32, // the pen it is taking its sheep to; -1 for none
	rest:     f32, // seconds it sits after putting a sheep back, so it does not pick it straight up
	move_t:   f32,
}

dog_speed :: proc(g: ^Game) -> f32 {
	return DOG_SPEED + DOG_SPEED_STEP * f32(g.dog_speed_level)
}

// A new dog starts beside the nightstand.
add_dog :: proc(g: ^Game) -> bool {
	if g.dog_count >= DOGS_MAX {
		return false
	}
	g.dogs[g.dog_count] = {x = NIGHTSTAND_X - 1, y = NIGHTSTAND_Y, flip = true, plan = -1}
	g.dog_count += 1
	return true
}

sheep_index :: proc(g: ^Game, id: u32) -> int {
	if id == 0 {
		return -1
	}
	for i in 0 ..< int(g.flock_count) {
		if g.flock[i].id == id {
			return i
		}
	}
	return -1
}

claimed :: proc(g: ^Game, id: u32, by: int) -> bool {
	for i in 0 ..< int(g.dog_count) {
		if i != by && !g.dogs[i].carrying && g.dogs[i].target == id {
			return true
		}
	}
	return false
}

abs_i32 :: proc(v: i32) -> i32 {
	return v if v >= 0 else -v
}

Fold :: [FOLD_COLS][FOLD_ROWS]Card

// The fold as a dog plans it: what is there or in the air, plus the sheep the other dogs are
// carrying, dropped into the pens they are taking them to.
planning_fold :: proc(g: ^Game, me: int) -> Fold {
	f := g.fold
	for i in 0 ..< int(g.dog_count) {
		o := g.dogs[i]
		if i == me || !o.carrying || o.plan < 0 {
			continue
		}
		if r := fold_landing_row(&f, o.plan); r >= 0 {
			f[o.plan][r] = o.card
		}
	}
	return f
}

// How long a run a good dog wants a sheep to make before it sends it: the fuller the fold, the
// pickier (any while it is under half full, then 2, then 3 once only a quarter is left).
run_needed :: proc(f: ^Fold) -> i32 {
	free := fold_free(f)
	if free >= FOLD_COLS * FOLD_ROWS / 2 {
		return 1
	}
	if free >= FOLD_COLS * FOLD_ROWS / 4 {
		return 2
	}
	return 3
}

fold_free :: proc(f: ^Fold) -> int {
	n := 0
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			if f[col][row].rank == 0 {
				n += 1
			}
		}
	}
	return n
}

fold_landing_row :: proc(f: ^Fold, col: i32) -> i32 {
	for r in 0 ..< i32(FOLD_ROWS) {
		if f[col][r].rank == 0 {
			return r
		}
	}
	return -1
}

fold_card :: proc(f: ^Fold, col, row: i32) -> (Card, bool) {
	if col < 0 || row < 0 || col >= FOLD_COLS || row >= FOLD_ROWS {
		return {}, false
	}
	c := f[col][row]
	return c, c.rank != 0
}

// The sheep a good dog fetches next: one no other dog is after, whose suit makes the longest run in
// the fold, the nearest among those. -1 when there is none.
pick_sheep_for :: proc(g: ^Game, f: ^Fold, d: ^Dog, me: int) -> int {
	need := run_needed(f)
	best, best_key := -1, i32(-1 << 30)
	for i in 0 ..< int(g.flock_count) {
		s := g.flock[i]
		if claimed(g, s.id, me) {
			continue
		}
		run: i32 = 0
		if col := dog_column(f, s.card, d.x); col >= 0 {
			run = run_through(f, col, fold_landing_row(f, col), s.card.suit)
		}
		if run < need {
			continue
		}
		dist := abs_i32(s.x - d.x) + abs_i32(s.y - d.y)
		key := run * 8 - dist
		if key > best_key {
			best, best_key = i, key
		}
	}
	return best
}

// How long a run of this suit a sheep landing at (col, row) would make, in its best direction.
run_through :: proc(f: ^Fold, col, row: i32, suit: Suit) -> i32 {
	DIRS := [4][2]i32{{1, 0}, {0, 1}, {1, 1}, {1, -1}}
	best: i32 = 1
	for d in DIRS {
		n: i32 = 1
		for k: i32 = 1; ; k += 1 {
			c, ok := fold_card(f, col + k * d[0], row + k * d[1])
			if !ok || c.suit != suit {
				break
			}
			n += 1
		}
		for k: i32 = 1; ; k += 1 {
			c, ok := fold_card(f, col - k * d[0], row - k * d[1])
			if !ok || c.suit != suit {
				break
			}
			n += 1
		}
		best = max(best, n)
	}
	return best
}

// The pen a good dog sends this sheep to: the longest run it makes, then the emptiest pen, then the
// nearest. -1 when the fold is full.
dog_column :: proc(f: ^Fold, card: Card, from_x: i32) -> i32 {
	best, best_key := i32(-1), i32(-1)
	for col in 0 ..< i32(FOLD_COLS) {
		row := fold_landing_row(f, col)
		if row < 0 {
			continue
		}
		dist := abs_i32(FOLD_FIRST_COL + col - from_x)
		key := run_through(f, col, row, card.suit) * 1000 + (FOLD_ROWS - row) * 100 + (99 - dist)
		if key > best_key {
			best, best_key = col, key
		}
	}
	return best
}

// One step toward (tx, ty), the longer way first; around the nightstand if it is in the way.
dog_walk :: proc(d: ^Dog, tx, ty: i32) {
	dx, dy := tx - d.x, ty - d.y
	sx: i32 = 0 if dx == 0 else (1 if dx > 0 else -1)
	sy: i32 = 0 if dy == 0 else (1 if dy > 0 else -1)
	try_x := abs_i32(dx) >= abs_i32(dy)
	for attempt in 0 ..< 2 {
		if (try_x) != (attempt == 1) {
			if sx != 0 && in_pasture(d.x + sx, d.y) && !is_nightstand(d.x + sx, d.y) {
				d.x += sx
				d.flip = sx < 0
				return
			}
		} else {
			if sy != 0 && in_pasture(d.x, d.y + sy) && !is_nightstand(d.x, d.y + sy) {
				d.y += sy
				return
			}
		}
	}
}

dog_step :: proc(g: ^Game, me: int) {
	d := &g.dogs[me]
	if d.carrying {
		// Keep to the pen it chose; choose again only when that pen has filled up. A sheep that would
		// only clog the fold now is put back down in the pasture.
		if d.plan < 0 || landing_row(g, d.plan) < 0 {
			f := planning_fold(g, me)
			d.plan = dog_column(&f, d.card, d.x)
			if d.plan < 0 || run_through(&f, d.plan, fold_landing_row(&f, d.plan), d.card.suit) < run_needed(&f) {
				d.plan = -1
				dog_put_down(g, d)
				return
			}
		}
		tx := FOLD_FIRST_COL + d.plan
		if d.x == tx && d.y == 0 {
			if send_card(g, d.card, d.x, d.plan) {
				d.carrying = false
				d.card = {}
				d.target = 0
				d.plan = -1
			}
			return
		}
		dog_walk(d, tx, 0)
		return
	}
	if d.rest > 0 {
		return
	}
	i := sheep_index(g, d.target)
	if i < 0 {
		f := planning_fold(g, me)
		i = pick_sheep_for(g, &f, d, me)
		if i < 0 {
			d.target = 0
			return // no sheep to fetch
		}
		d.target = g.flock[i].id
	}
	s := g.flock[i]
	if abs_i32(s.x - d.x) + abs_i32(s.y - d.y) <= 1 {
		d.card = s.card
		d.carrying = true
		d.target = 0
		d.plan = -1
		if s.x != d.x {
			d.flip = s.x < d.x
		}
		remove_sheep(g, i)
		return
	}
	dog_walk(d, s.x, s.y)
}

// The dog lets its sheep go on a free tile beside it (or waits holding it when there is none).
dog_put_down :: proc(g: ^Game, d: ^Dog) {
	if g.flock_count >= FLOCK_MAX {
		return
	}
	SPOTS := [5][2]i32{{0, 0}, {0, 1}, {1, 0}, {-1, 0}, {0, -1}}
	for o in SPOTS {
		x, y := d.x + o[0], d.y + o[1]
		if !tile_free(g, x, y) {
			continue
		}
		g.next_id += 1
		g.flock[g.flock_count] = {id = g.next_id, card = d.card, x = x, y = y, flip = d.flip, wait = WANDER_MIN + WANDER_SPREAD}
		g.flock_count += 1
		d.carrying = false
		d.card = {}
		d.rest = DOG_REST
		return
	}
}

dogs_tick :: proc(g: ^Game, dt: f32) {
	if g.finished {
		return
	}
	step_time := 1 / dog_speed(g)
	for i in 0 ..< int(g.dog_count) {
		g.dogs[i].rest = max(0, g.dogs[i].rest - dt)
		g.dogs[i].move_t += dt
		for g.dogs[i].move_t >= step_time {
			g.dogs[i].move_t -= step_time
			dog_step(g, i)
			if g.finished {
				return
			}
		}
	}
}
