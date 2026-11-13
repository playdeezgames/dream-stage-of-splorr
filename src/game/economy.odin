package game

// The economy (DESIGN.md): points peg a 121-hole cribbage board, and each lap is a deeper sleep
// stage, with a new moon card and a bigger Zzz multiplier. Zzz buys upgrades at the nightstand in the
// pasture's corner. Counting the millionth sheep ends the night; a new night keeps only the bests.
//
// Prices are Claude's placeholders, picked with a rough pacing model (sheepdogs included) for a run of
// about two hours; the user's to change.

BOARD_HOLES :: 121
FINISH_PAUSE :: 1.5 // seconds after the millionth sheep before Space starts a new night
SHOP_FLASH :: 0.5

NIGHTSTAND_X :: PASTURE_COLS - 1
NIGHTSTAND_Y :: PASTURE_ROWS - 1

ARMFUL_PRICE :: 30.0
ARMFUL_GROWTH :: 1.6
GRASS_PRICE :: 40.0
GRASS_GROWTH :: 1.8
GRASS_LEVELS :: 5
GRASS_SHEEP :: 2 // more sheep wandering the pasture per level
COUNT_PRICE :: 150.0
COUNT_GROWTH :: 3.0
DOG_PRICE :: 150.0
DOG_GROWTH :: 2.8
DOG_SPEED_PRICE :: 150.0
DOG_SPEED_GROWTH :: 2.8
CLEAR_PRICE :: 15 // times the stage's multiplier

// Each jump counts this many sheep, by level ("count by twos, fives, tens", as dream logic allows).
COUNT_BY := [?]i64{1, 2, 3, 5, 8, 12, 20, 30, 50, 75, 100, 150, 250, 400, 600, 1000}

Shop_Row :: enum u8 {
	Armful,
	Grass,
	Count_By,
	Sheepdog,
	Dog_Speed,
	Clear,
	Leave,
}

Shop :: struct {
	open:      bool,
	row:       Shop_Row,
	col:       i32, // the fold column a clear takes
	flash:     f32, // the row flashes red: too few Zzz
	flash_row: Shop_Row,
}

// Kept from night to night.
Bests :: struct {
	nights:  i32,
	fastest: f64, // seconds; 0 before the first night is finished
	points:  i64,
	hand:    i32,
	chain:   i32,
}

count_by :: proc(g: ^Game) -> i64 {
	return COUNT_BY[g.count_level]
}

// Zzz for each point: 1 while drowsy, then one more for each sleep cycle (four laps of the board).
multiplier :: proc(g: ^Game) -> i64 {
	return 1 + i64(stage_cycle(g.lap))
}

// Where the peg stands on this lap, 0 to 120.
peg_hole :: proc(g: ^Game) -> i32 {
	return i32(g.points % BOARD_HOLES)
}

// Drowsy, then the four stages of a sleep cycle, over and over: N1, N2, N3, REM.
stage_name :: proc(lap: i32) -> string {
	if lap == 0 {
		return "Drowsy"
	}
	NAMES := [4]string{"N1", "N2", "N3", "REM"}
	return NAMES[(lap - 1) % 4]
}

// Which sleep cycle a stage is in (0 while drowsy).
stage_cycle :: proc(lap: i32) -> i32 {
	return 0 if lap == 0 else (lap - 1) / 4 + 1
}

// Scores points: they move the peg and earn Zzz at the stage's multiplier. A full lap of the board
// goes a stage deeper, with a new moon.
add_points :: proc(g: ^Game, pts: i32) {
	if pts <= 0 {
		return
	}
	g.zzz += i64(pts) * multiplier(g)
	g.points += i64(pts)
	lap := i32(g.points / BOARD_HOLES)
	if lap > g.lap {
		g.lap = lap
		g.moon = random_card(g)
		show_notice(g, .Stage)
		play(g, .Stage)
	}
}

// A jump counts COUNT_BY sheep; the millionth ends the night.
count_sheep_in :: proc(g: ^Game) {
	g.counted = min(TOTAL_SHEEP, g.counted + count_by(g))
	if g.counted >= TOTAL_SHEEP && !g.finished {
		g.finished = true
		g.finish_t = 0
		g.finish_time = g.time
		g.shop.open = false
		b := &g.bests
		b.nights += 1
		if b.fastest == 0 || g.time < b.fastest {
			b.fastest = g.time
		}
		b.points = max(b.points, g.points)
		b.hand = max(b.hand, g.best_hand)
		b.chain = max(b.chain, g.best_chain)
		play(g, .Asleep)
	}
}

// A fresh night: upgrades and the fold start over; the bests and the sound setting stay.
new_night :: proc(g: ^Game) {
	bests, muted := g.bests, g.muted
	seed := next_u64(g)
	init_game(g, seed)
	g.bests = bests
	g.muted = muted
	g.night = bests.nights
}

grow_price :: proc(base, growth: f64, level: i32) -> i64 {
	v := base
	for _ in 0 ..< level {
		v *= growth
	}
	return i64(v + 0.5)
}

// The price of a shop row's next purchase; false when there is nothing more to buy.
price :: proc(g: ^Game, row: Shop_Row) -> (i64, bool) {
	switch row {
	case .Armful:
		if g.armful >= ARMFUL_MAX {
			return 0, false
		}
		return grow_price(ARMFUL_PRICE, ARMFUL_GROWTH, g.armful_level), true
	case .Grass:
		if g.grass_level >= GRASS_LEVELS {
			return 0, false
		}
		return grow_price(GRASS_PRICE, GRASS_GROWTH, g.grass_level), true
	case .Count_By:
		if int(g.count_level) + 1 >= len(COUNT_BY) {
			return 0, false
		}
		return grow_price(COUNT_PRICE, COUNT_GROWTH, g.count_level), true
	case .Sheepdog:
		if g.dog_count >= DOGS_MAX {
			return 0, false
		}
		return grow_price(DOG_PRICE, DOG_GROWTH, g.dog_count), true
	case .Dog_Speed:
		if g.dog_count == 0 || g.dog_speed_level >= DOG_SPEED_LEVELS {
			return 0, false
		}
		return grow_price(DOG_SPEED_PRICE, DOG_SPEED_GROWTH, g.dog_speed_level), true
	case .Clear:
		return CLEAR_PRICE * multiplier(g), true
	case .Leave:
		return 0, false
	}
	return 0, false
}

fold_full :: proc(g: ^Game) -> bool {
	for col in 0 ..< i32(FOLD_COLS) {
		if landing_row(g, col) >= 0 {
			return false
		}
	}
	return true
}

open_shop :: proc(g: ^Game) {
	g.shop.open = true
	g.shop.row = .Armful
	play(g, .Open)
}

close_shop :: proc(g: ^Game) {
	g.shop.open = false
	play(g, .Close)
}

shop_command :: proc(g: ^Game, c: Command) {
	switch c {
	case .North:
		g.shop.row = Shop_Row((int(g.shop.row) + len(Shop_Row) - 1) % len(Shop_Row))
	case .South:
		g.shop.row = Shop_Row((int(g.shop.row) + 1) % len(Shop_Row))
	case .West:
		if g.shop.row == .Clear {
			g.shop.col = (g.shop.col + FOLD_COLS - 1) % FOLD_COLS
		}
	case .East:
		if g.shop.row == .Clear {
			g.shop.col = (g.shop.col + 1) % FOLD_COLS
		}
	case .Ok:
		buy(g, g.shop.row)
	case .Cancel:
		close_shop(g)
	}
}

deny :: proc(g: ^Game, row: Shop_Row) {
	g.shop.flash = SHOP_FLASH
	g.shop.flash_row = row
	play(g, .Deny)
}

// Buys a shop row's next purchase. True when something was bought (or the clear went through).
buy :: proc(g: ^Game, row: Shop_Row) -> bool {
	if row == .Leave {
		close_shop(g)
		return false
	}
	cost, ok := price(g, row)
	if !ok {
		deny(g, row)
		return false
	}
	if row == .Clear {
		return buy_clear(g, cost)
	}
	if g.zzz < cost {
		deny(g, row)
		return false
	}
	g.zzz -= cost
	#partial switch row {
	case .Armful:
		g.armful_level += 1
		g.armful += 1
	case .Grass:
		g.grass_level += 1
		g.flock_target += GRASS_SHEEP
	case .Count_By:
		g.count_level += 1
	case .Sheepdog:
		add_dog(g)
	case .Dog_Speed:
		g.dog_speed_level += 1
	}
	play(g, .Buy)
	return true
}

// Clears the chosen fold column. Its sheep were counted when they jumped and are not scored again.
// With the fold full and too few Zzz, the clear takes all the Zzz there are (the user's rule), so the
// fold can never leave the player stuck.
buy_clear :: proc(g: ^Game, cost: i64) -> bool {
	col := g.shop.col
	if g.fold[col][0].rank == 0 {
		show_notice(g, .Clear_Empty)
		deny(g, .Clear)
		return false
	}
	for j in 0 ..< int(g.jump_count) {
		if g.jumps[j].col == col {
			show_notice(g, .Clear_Wait)
			deny(g, .Clear)
			return false
		}
	}
	if g.zzz >= cost {
		g.zzz -= cost
	} else if fold_full(g) {
		g.zzz = 0
		show_notice(g, .Took_All)
	} else {
		deny(g, .Clear)
		return false
	}
	for row in 0 ..< i32(FOLD_ROWS) {
		if g.fold[col][row].rank == 0 {
			continue
		}
		if g.sleeper_count < SLEEPERS_MAX {
			g.sleepers[g.sleeper_count] = {card = g.fold[col][row], col = col, row = row}
			g.sleeper_count += 1
		}
		g.fold[col][row] = {}
		g.fall[col][row] = 0
		g.age[col][row] = 0
	}
	g.clears += 1
	play(g, .Clear)
	return true
}
