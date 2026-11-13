#+build !js
package game

import "core:testing"

@(test)
points_earn_zzz_and_laps_go_deeper :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	add_points(&g, 100)
	testing.expect_value(t, g.zzz, i64(100))
	testing.expect_value(t, g.lap, i32(0))
	testing.expect_value(t, stage_name(g.lap), "Drowsy")
	add_points(&g, 30) // 130 points: past the 121st hole
	testing.expect_value(t, g.lap, i32(1))
	testing.expect_value(t, g.zzz, i64(130)) // earned at x1, the lap it was scored on
	testing.expect_value(t, peg_hole(&g), i32(4)) // 9 of N1's 242 points (a hole is worth 2 now)
	testing.expect_value(t, stage_name(g.lap), "N1")
	testing.expect_value(t, g.notice, Notice.Stage)
	add_points(&g, 10)
	testing.expect_value(t, g.zzz, i64(150)) // x2 now
}

@(test)
laps_grow_with_the_multiplier :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	testing.expect_value(t, lap_needed(&g), i64(121))
	add_points(&g, 121)
	testing.expect_value(t, g.lap, i32(1))
	testing.expect_value(t, lap_needed(&g), i64(242)) // N1 is cycle 1: x2
	add_points(&g, 241)
	testing.expect_value(t, g.lap, i32(1))
	add_points(&g, 1)
	testing.expect_value(t, g.lap, i32(2))
	testing.expect_value(t, g.lap_points, i64(0))
	// One big score can go more than one stage deeper.
	add_points(&g, 242 * 2 + 10)
	testing.expect_value(t, g.lap, i32(4))
	testing.expect_value(t, g.lap_points, i64(10))
}

@(test)
stages_cycle :: proc(t: ^testing.T) {
	testing.expect_value(t, stage_name(0), "Drowsy")
	testing.expect_value(t, stage_name(1), "N1")
	testing.expect_value(t, stage_name(4), "REM")
	testing.expect_value(t, stage_name(5), "N1")
	testing.expect_value(t, stage_cycle(0), i32(0))
	testing.expect_value(t, stage_cycle(4), i32(1))
	testing.expect_value(t, stage_cycle(5), i32(2))
}

@(test)
a_new_stage_brings_a_new_moon :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	changed := 0
	for _ in 0 ..< 20 {
		before := g.moon
		add_points(&g, i32(lap_needed(&g)))
		if g.moon != before {
			changed += 1
		}
	}
	testing.expect_value(t, g.lap, i32(20))
	testing.expect(t, changed >= 15) // a random card may repeat now and then
}

@(test)
the_shop_opens_at_the_nightstand :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = NIGHTSTAND_X - 1, NIGHTSTAND_Y
	command(&g, .East)
	testing.expect(t, g.shop.open)
	testing.expect_value(t, g.px, i32(NIGHTSTAND_X - 1)) // the insomniac does not stand on it
	command(&g, .South)
	testing.expect_value(t, g.shop.row, Shop_Row.Grass)
	command(&g, .North)
	command(&g, .North) // wraps to Leave
	testing.expect_value(t, g.shop.row, Shop_Row.Leave)
	command(&g, .West) // only the clear row uses left and right
	command(&g, .Cancel)
	testing.expect(t, !g.shop.open)
	// While the shop is open, walking keys move the cursor, not the insomniac.
	command(&g, .East)
	testing.expect(t, g.shop.open)
	command(&g, .West)
	testing.expect_value(t, g.px, i32(NIGHTSTAND_X - 1))
}

@(test)
buying_upgrades :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	cost, _ := price(&g, .Armful)
	testing.expect_value(t, cost, i64(30))
	testing.expect(t, !buy(&g, .Armful)) // no Zzz yet
	testing.expect_value(t, g.shop.flash_row, Shop_Row.Armful)
	g.zzz = 1000
	testing.expect(t, buy(&g, .Armful))
	testing.expect_value(t, g.armful, i32(ARMFUL_START + 1))
	testing.expect_value(t, g.zzz, i64(970))
	next, _ := price(&g, .Armful)
	testing.expect_value(t, next, i64(48))
	testing.expect(t, buy(&g, .Grass))
	testing.expect_value(t, g.flock_target, i32(FLOCK_TARGET + GRASS_SHEEP))
	testing.expect(t, buy(&g, .Count_By))
	testing.expect_value(t, count_by(&g), i64(2))
}

@(test)
upgrades_stop_at_their_most :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.zzz = 1 << 50
	for _ in 0 ..< 40 {
		buy(&g, .Armful)
		buy(&g, .Grass)
		buy(&g, .Count_By)
	}
	testing.expect_value(t, g.armful, i32(ARMFUL_MAX))
	testing.expect_value(t, g.grass_level, i32(GRASS_LEVELS))
	testing.expect_value(t, count_by(&g), COUNT_BY[len(COUNT_BY) - 1])
	_, more := price(&g, .Armful)
	testing.expect(t, !more)
	testing.expect(t, g.flock_target <= FLOCK_MAX)
}

@(test)
count_by_counts_more_per_jump :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.count_level = 3 // fives
	g.px, g.py = FOLD_FIRST_COL, 0
	g.held[0] = {rank = 2, suit = .Hearts}
	g.held_count = 1
	send_sheep(&g)
	testing.expect_value(t, g.counted, i64(5))
}

@(test)
clearing_a_pen :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.fold[2][0] = {rank = 4, suit = .Clubs}
	g.fold[2][1] = {rank = 9, suit = .Hearts}
	g.shop.col = 2
	cost, _ := price(&g, .Clear)
	testing.expect_value(t, cost, i64(CLEAR_PRICE))
	testing.expect(t, !buy(&g, .Clear)) // too few Zzz, and the fold is not full
	testing.expect_value(t, g.fold[2][0].rank, u8(4))
	g.zzz = 100
	testing.expect(t, buy(&g, .Clear))
	testing.expect_value(t, g.zzz, i64(100 - CLEAR_PRICE))
	testing.expect_value(t, g.fold[2][0].rank, u8(0))
	testing.expect_value(t, g.fold[2][1].rank, u8(0))
	testing.expect_value(t, g.sleeper_count, i32(2))
	testing.expect_value(t, g.points, i64(0)) // not scored
	// An empty pen is not worth paying for.
	testing.expect(t, !buy(&g, .Clear))
	testing.expect_value(t, g.notice, Notice.Clear_Empty)
}

@(test)
a_full_fold_clear_takes_all_the_zzz :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			g.fold[col][row] = {rank = u8(1 + (col + row) % 13), suit = Suit((col * 2 + row) % 4)}
		}
	}
	testing.expect(t, fold_full(&g))
	g.zzz = 3
	g.shop.col = 5
	testing.expect(t, buy(&g, .Clear))
	testing.expect_value(t, g.zzz, i64(0))
	testing.expect_value(t, g.notice, Notice.Took_All)
	testing.expect_value(t, landing_row(&g, 5), i32(0))
	testing.expect(t, !fold_full(&g))
}

@(test)
a_pen_with_a_sheep_in_the_air_waits :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = FOLD_FIRST_COL + 1, 0
	g.held[0] = {rank = 6, suit = .Spades}
	g.held_count = 1
	send_sheep(&g)
	g.zzz = 100
	g.shop.col = 1
	testing.expect(t, !buy(&g, .Clear))
	testing.expect_value(t, g.notice, Notice.Clear_Wait)
	testing.expect_value(t, g.zzz, i64(100))
}

@(test)
the_millionth_sheep_ends_the_night :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.counted = TOTAL_SHEEP - 1
	g.points = 4321
	g.best_hand = 17
	g.time = 3600
	g.zzz = 99
	g.count_level = 4
	g.px, g.py = FOLD_FIRST_COL, 0
	g.held[0] = {rank = 6, suit = .Spades}
	g.held_count = 1
	send_sheep(&g)
	testing.expect(t, g.finished)
	testing.expect_value(t, g.counted, i64(TOTAL_SHEEP)) // never past a million
	testing.expect_value(t, sheep_to_count(&g), i64(0))
	testing.expect_value(t, g.bests.nights, i32(1))
	testing.expect_value(t, g.bests.points, i64(4321))
	testing.expect_value(t, g.bests.fastest, f64(3600))
	// Nothing happens until the pause is over; then Space starts a new night.
	command(&g, .West)
	command(&g, .Ok)
	testing.expect(t, g.finished)
	for _ in 0 ..< 10 {
		tick(&g, 0.2)
	}
	command(&g, .Ok)
	testing.expect(t, !g.finished)
	testing.expect_value(t, g.counted, i64(0))
	testing.expect_value(t, g.zzz, i64(0))
	testing.expect_value(t, g.count_level, i32(0))
	testing.expect_value(t, g.bests.nights, i32(1))
	testing.expect_value(t, g.bests.hand, i32(17))
	testing.expect_value(t, g.night, i32(1))
	testing.expect_value(t, g.flock_count, i32(FLOCK_TARGET))
}

@(test)
sheep_never_wander_onto_the_nightstand :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 99)
	g.flock_target = FLOCK_MAX
	for _ in 0 ..< 3000 {
		tick(&g, 0.05)
		testing.expect(t, sheep_at(&g, NIGHTSTAND_X, NIGHTSTAND_Y) < 0)
	}
}

@(test)
draws_the_shop_and_the_end :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 5)
	f := new(Frame)
	defer free(f)
	for row in Shop_Row {
		g.shop.open = true
		g.shop.row = row
		draw_game(f, &g)
	}
	g.shop.open = false
	g.finished = true
	g.finish_t = 5
	g.lap = 13
	draw_game(f, &g)
	buf: [16]u8
	testing.expect_value(t, clock(buf[:], 3725), "1:02:05")
	testing.expect_value(t, clock(buf[:], 59), "0:00:59")
}
