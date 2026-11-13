#+build !js
package game

import "core:testing"

put_sheep_id :: proc(g: ^Game, x, y: i32, c: Card) -> u32 {
	g.next_id += 1
	g.flock[g.flock_count] = {id = g.next_id, card = c, x = x, y = y, wait = 99}
	g.flock_count += 1
	return g.next_id
}

@(test)
a_dog_fetches_and_sends_a_sheep :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.flock_target = 0 // no new sheep wander in
	add_dog(&g)
	put_sheep_id(&g, 3, 3, {rank = 7, suit = .Hearts})
	for _ in 0 ..< 200 {
		tick(&g, 0.1)
		if g.counted > 0 {
			break
		}
	}
	testing.expect_value(t, g.counted, i64(1))
	testing.expect_value(t, g.flock_count, i32(0))
	testing.expect(t, !g.dogs[0].carrying)
	testing.expect_value(t, g.dogs[0].y, i32(0)) // it sent the sheep from the fence
	testing.expect_value(t, g.pegging.count, i32(7)) // dogs' sheep are pegged too
}

@(test)
two_dogs_go_after_different_sheep :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.flock_target = 0
	add_dog(&g)
	add_dog(&g)
	a := put_sheep_id(&g, 15, 4, {rank = 2, suit = .Clubs})
	b := put_sheep_id(&g, 14, 4, {rank = 3, suit = .Clubs})
	dog_step(&g, 0)
	dog_step(&g, 1)
	testing.expect(t, g.dogs[0].target != 0 && g.dogs[1].target != 0)
	testing.expect(t, g.dogs[0].target != g.dogs[1].target)
	testing.expect(t, (g.dogs[0].target == a || g.dogs[0].target == b))
}

@(test)
a_good_dog_makes_runs :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	// Three spades along the bottom in columns 0..2: a spade belongs in column 3.
	g.fold[0][0] = {rank = 2, suit = .Spades}
	g.fold[1][0] = {rank = 3, suit = .Spades}
	g.fold[2][0] = {rank = 4, suit = .Spades}
	testing.expect_value(t, dog_column(&g.fold, {rank = 9, suit = .Spades}, 15), i32(3))
	// With nothing to line up, the emptiest column (nearest among equals).
	h: Game
	bare_game(&h)
	h.fold[0][0] = {rank = 2, suit = .Hearts}
	testing.expect(t, dog_column(&h.fold, {rank = 9, suit = .Clubs}, FOLD_FIRST_COL) != 0)
	testing.expect_value(t, dog_column(&h.fold, {rank = 9, suit = .Clubs}, FOLD_FIRST_COL + 6), i32(6))
}

@(test)
a_dog_puts_back_a_sheep_that_would_clog_the_fold :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			g.fold[col][row] = {rank = u8(1 + (col + row) % 13), suit = Suit((col * 2 + row) % 4)}
		}
	}
	add_dog(&g)
	g.dogs[0].carrying = true
	g.dogs[0].card = {rank = 5, suit = .Hearts}
	dog_step(&g, 0)
	testing.expect(t, !g.dogs[0].carrying)
	testing.expect_value(t, g.flock_count, i32(1))
	testing.expect_value(t, g.flock[0].card, Card{rank = 5, suit = .Hearts})
	testing.expect_value(t, g.counted, i64(0))
	testing.expect_value(t, dog_column(&g.fold, {rank = 5, suit = .Hearts}, 10), i32(-1))
	// It rests a moment instead of picking the same sheep straight back up.
	dog_step(&g, 0)
	testing.expect_value(t, g.flock_count, i32(1))
}

@(test)
pickier_as_the_fold_fills :: proc(t: ^testing.T) {
	f: Fold
	testing.expect_value(t, run_needed(&f), i32(1))
	n := 0
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			if n < 25 {
				f[col][row] = {rank = 2, suit = .Clubs}
			}
			n += 1
		}
	}
	testing.expect_value(t, run_needed(&f), i32(2)) // 17 free
	f = {}
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< 5 {
			f[col][row] = {rank = 2, suit = .Clubs}
		}
	}
	testing.expect_value(t, run_needed(&f), i32(3)) // 7 free
}

@(test)
eight_dogs_keep_the_fold_flowing :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 77)
	for _ in 0 ..< DOGS_MAX {
		add_dog(&g)
	}
	g.dog_speed_level = 3
	full := 0
	for _ in 0 ..< 20 * 180 { // three minutes, dogs alone
		tick(&g, 0.05)
		if fold_full(&g) {
			full += 1
		}
	}
	testing.expect(t, g.counted > 250, "eight dogs should send a good few sheep in three minutes")
	testing.expect(t, g.lines > 40)
	testing.expect(t, full < 20 * 10, "the fold should hardly ever be full")
}

@(test)
dogs_keep_off_the_nightstand_and_in_the_pasture :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 21)
	for _ in 0 ..< DOGS_MAX {
		add_dog(&g)
	}
	testing.expect(t, !add_dog(&g))
	g.flock_target = FLOCK_MAX
	g.dog_speed_level = DOG_SPEED_LEVELS
	for _ in 0 ..< 4000 {
		tick(&g, 0.05)
		for i in 0 ..< int(g.dog_count) {
			d := g.dogs[i]
			testing.expect(t, in_pasture(d.x, d.y))
			testing.expect(t, !is_nightstand(d.x, d.y))
		}
		// Keep the fold from filling so the dogs keep working.
		if fold_full(&g) {
			g.fold = {}
		}
	}
	testing.expect(t, g.counted > 100)
}

@(test)
buying_dogs :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	_, ok := price(&g, .Dog_Speed)
	testing.expect(t, !ok) // no dog to speed up yet
	g.zzz = 1 << 40
	testing.expect(t, buy(&g, .Sheepdog))
	testing.expect_value(t, g.dog_count, i32(1))
	testing.expect(t, buy(&g, .Dog_Speed))
	testing.expect_value(t, dog_speed(&g), f32(DOG_SPEED + DOG_SPEED_STEP))
	for _ in 0 ..< 20 {
		buy(&g, .Sheepdog)
		buy(&g, .Dog_Speed)
	}
	testing.expect_value(t, g.dog_count, i32(DOGS_MAX))
	testing.expect_value(t, g.dog_speed_level, i32(DOG_SPEED_LEVELS))
}

@(test)
a_new_night_sends_the_dogs_home :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	add_dog(&g)
	g.counted = TOTAL_SHEEP
	g.finished = true
	g.finish_t = FINISH_PAUSE
	command(&g, .Ok)
	testing.expect_value(t, g.dog_count, i32(0))
}
