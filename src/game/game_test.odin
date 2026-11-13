#+build !js
package game

import "core:testing"

// A game with an empty pasture, for tests that place sheep by hand.
bare_game :: proc(g: ^Game) {
	init_game(g, 1)
	g.flock_count = 0
}

put_sheep :: proc(g: ^Game, x, y: i32, c: Card) {
	g.flock[g.flock_count] = {card = c, x = x, y = y, wait = 99}
	g.flock_count += 1
}

@(test)
starts_with_a_flock :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 42)
	testing.expect_value(t, g.flock_count, i32(FLOCK_TARGET))
	testing.expect_value(t, sheep_to_count(&g), i64(TOTAL_SHEEP))
	for i in 0 ..< int(g.flock_count) {
		s := g.flock[i]
		testing.expect(t, in_pasture(s.x, s.y))
		testing.expect(t, s.card.rank >= 1 && s.card.rank <= 13)
		testing.expect(t, !(s.x == g.px && s.y == g.py))
		for j in i + 1 ..< int(g.flock_count) {
			testing.expect(t, !(g.flock[j].x == s.x && g.flock[j].y == s.y), "two sheep on one tile")
		}
	}
}

@(test)
walking_into_a_sheep_picks_it_up :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = 5, 2
	put_sheep(&g, 6, 2, {rank = 7, suit = .Hearts})
	command(&g, .East)
	testing.expect_value(t, g.px, i32(5)) // stays put
	testing.expect_value(t, g.held_count, i32(1))
	testing.expect_value(t, g.held[0], Card{rank = 7, suit = .Hearts})
	testing.expect_value(t, g.flock_count, i32(0))
	testing.expect_value(t, g.sounds[0], Sound.Pick)
}

@(test)
arms_hold_only_an_armful :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = 5, 2
	g.held_count = g.armful
	put_sheep(&g, 5, 1, {rank = 1, suit = .Spades})
	command(&g, .North)
	testing.expect_value(t, g.held_count, g.armful)
	testing.expect_value(t, g.flock_count, i32(1))
	testing.expect_value(t, g.notice, Notice.Arms_Full)
}

@(test)
walls_stop_the_insomniac :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = 0, PASTURE_ROWS - 1
	command(&g, .West)
	command(&g, .South)
	testing.expect_value(t, g.px, i32(0))
	testing.expect_value(t, g.py, i32(PASTURE_ROWS - 1))
}

@(test)
sheep_drop_to_the_bottom_and_stack :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = FOLD_FIRST_COL + 2, 0
	g.held[0] = {rank = 5, suit = .Clubs}
	g.held[1] = {rank = 12, suit = .Diamonds}
	g.held_count = 2
	command(&g, .North) // into the fence
	testing.expect_value(t, g.fold[2][0], Card{rank = 5, suit = .Clubs})
	testing.expect_value(t, g.held_count, i32(1))
	testing.expect_value(t, g.held[0], Card{rank = 12, suit = .Diamonds})
	command(&g, .Ok)
	testing.expect_value(t, g.fold[2][1], Card{rank = 12, suit = .Diamonds})
	testing.expect_value(t, g.counted, i64(2))
	testing.expect_value(t, sheep_to_count(&g), i64(TOTAL_SHEEP - 2))
	testing.expect_value(t, g.held_count, i32(0))
	testing.expect_value(t, g.jump_count, i32(2))
	testing.expect_value(t, g.py, i32(0)) // walking into the fence does not move
}

@(test)
a_full_column_refuses :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = FOLD_FIRST_COL, 0
	for r in 0 ..< FOLD_ROWS {
		g.fold[0][r] = {rank = 2, suit = .Spades}
	}
	g.held[0] = {rank = 3, suit = .Hearts}
	g.held_count = 1
	testing.expect(t, !send_sheep(&g))
	testing.expect_value(t, g.held_count, i32(1))
	testing.expect_value(t, g.counted, i64(0))
	testing.expect_value(t, g.notice, Notice.Column_Full)
}

@(test)
sending_needs_a_pen_and_a_sheep :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = 0, 0 // left of the fold
	g.held[0] = {rank = 3, suit = .Hearts}
	g.held_count = 1
	testing.expect(t, !send_sheep(&g))
	testing.expect_value(t, g.notice, Notice.Not_Under_Fold)
	g.px = FOLD_FIRST_COL + FOLD_COLS // just right of it
	testing.expect(t, !send_sheep(&g))
	g.px = FOLD_FIRST_COL + FOLD_COLS - 1
	g.held_count = 0
	testing.expect(t, !send_sheep(&g))
	testing.expect_value(t, g.notice, Notice.Arms_Empty)
	testing.expect_value(t, g.counted, i64(0))
}

@(test)
jumps_land :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = FOLD_FIRST_COL, 0
	g.held[0] = {rank = 9, suit = .Spades}
	g.held_count = 1
	send_sheep(&g)
	testing.expect(t, landing_pending(&g, 0, 0))
	for _ in 0 ..< 10 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.jump_count, i32(0))
	testing.expect(t, !landing_pending(&g, 0, 0))
	testing.expect_value(t, g.fold[0][0].rank, u8(9))
}

@(test)
wandering_keeps_sheep_apart_and_the_flock_full :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 7)
	g.flock_count = 3 // some were picked up
	for _ in 0 ..< 2000 {
		tick(&g, 0.05)
		for i in 0 ..< int(g.flock_count) {
			s := g.flock[i]
			testing.expect(t, in_pasture(s.x, s.y))
			testing.expect(t, !(s.x == g.px && s.y == g.py))
			for j in i + 1 ..< int(g.flock_count) {
				testing.expect(t, !(g.flock[j].x == s.x && g.flock[j].y == s.y))
			}
		}
	}
	testing.expect_value(t, g.flock_count, i32(FLOCK_TARGET))
}

@(test)
no_more_sheep_than_a_million :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.counted = TOTAL_SHEEP - 2
	for _ in 0 ..< 100 {
		tick(&g, 0.25)
	}
	testing.expect_value(t, g.flock_count, i32(2))
	testing.expect_value(t, sheep_unseen(&g), i64(0))
}

@(test)
commas_format :: proc(t: ^testing.T) {
	buf: [32]u8
	testing.expect_value(t, commas(buf[:], 0), "0")
	testing.expect_value(t, commas(buf[:], 999), "999")
	testing.expect_value(t, commas(buf[:], 1000), "1,000")
	testing.expect_value(t, commas(buf[:], 1_000_000), "1,000,000")
	testing.expect_value(t, commas(buf[:], -12345), "-12,345")
}

@(test)
draws_without_trouble :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 3)
	g.px, g.py = FOLD_FIRST_COL + 3, 0
	g.held[0] = {rank = 13, suit = .Hearts}
	g.held[1] = {rank = 1, suit = .Clubs}
	g.held_count = 2
	send_sheep(&g)
	tick(&g, 0.2)
	f := new(Frame)
	defer free(f)
	draw_game(f, &g)
	resolve(f)
	testing.expect(t, f.rgba[0] != 0)
}
