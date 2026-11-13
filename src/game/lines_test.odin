#+build !js
package game

import "core:testing"

H :: Suit.Hearts
S :: Suit.Spades
D :: Suit.Diamonds
C :: Suit.Clubs

place :: proc(g: ^Game, col, row: i32, suit: Suit, rank: u8 = 5) {
	g.fold[col][row] = {rank = rank, suit = suit}
}

count_sheep :: proc(g: ^Game) -> int {
	n := 0
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			if g.fold[col][row].rank != 0 {
				n += 1
			}
		}
	}
	return n
}

@(test)
four_across_clears :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for c in 1 ..< i32(5) {
		place(&g, c, 0, H)
	}
	place(&g, 1, 1, S) // sits on the line and drops when it clears
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, g.lines, i64(1))
	testing.expect_value(t, count_sheep(&g), 1)
	testing.expect_value(t, g.fold[1][0].suit, S)
	testing.expect_value(t, g.fall[1][0], f32(TILE))
	testing.expect_value(t, g.sleeper_count, i32(4))
	testing.expect_value(t, g.chain, i32(1))
}

@(test)
four_down_clears :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for r in 0 ..< i32(4) {
		place(&g, 3, r, C)
	}
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, count_sheep(&g), 0)
}

@(test)
diagonals_clear :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for i in 0 ..< i32(4) {
		place(&g, i, i, D) // rising
	}
	marks: [FOLD_COLS][FOLD_ROWS]bool
	testing.expect_value(t, find_lines(&g, &marks), 1)

	g2: Game
	bare_game(&g2)
	for i in 0 ..< i32(4) {
		place(&g2, 2 + i, 3 - i, S) // falling
	}
	marks = {}
	testing.expect_value(t, find_lines(&g2, &marks), 1)
	testing.expect(t, marks[2][3] && marks[5][0])
}

@(test)
mixed_suits_and_three_do_not_clear :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	place(&g, 0, 0, H)
	place(&g, 1, 0, H)
	place(&g, 2, 0, D)
	place(&g, 3, 0, H)
	place(&g, 4, 0, H)
	place(&g, 5, 0, H)
	testing.expect(t, !resolve_lines(&g))
	testing.expect_value(t, count_sheep(&g), 6)
	testing.expect_value(t, g.lines, i64(0))
}

@(test)
five_in_a_row_is_one_line :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for c in 0 ..< i32(5) {
		place(&g, c, 0, S)
	}
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, g.lines, i64(1))
	testing.expect_value(t, count_sheep(&g), 0)
}

@(test)
crossing_lines_clear_together :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for c in 0 ..< i32(4) {
		place(&g, c, 0, H)
	}
	for r in 1 ..< i32(4) {
		place(&g, 0, r, H) // column 0 is hearts four high, sharing the corner
	}
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, g.lines, i64(2))
	testing.expect_value(t, count_sheep(&g), 0)
}

@(test)
a_clear_with_nothing_after_ends_the_chain :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	// Hearts on row 0 under clubs C C C S: when the hearts go, row 0 becomes C C C S, no line.
	for c in 0 ..< i32(4) {
		place(&g, c, 0, H)
	}
	place(&g, 0, 1, C)
	place(&g, 1, 1, C)
	place(&g, 2, 1, C)
	place(&g, 3, 1, S)
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, g.chain, i32(1))
	for _ in 0 ..< 10 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.chain, i32(0))
	testing.expect_value(t, g.best_chain, i32(1))
	testing.expect_value(t, count_sheep(&g), 4)
}

@(test)
drops_chain :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	// Hearts on row 0 of columns 0..3, clubs over columns 1..3 and a club on the floor of column 4:
	// the hearts go, the clubs drop beside the floor club, and the four clubs clear in turn.
	for c in 0 ..< i32(4) {
		place(&g, c, 0, H)
	}
	place(&g, 1, 1, C)
	place(&g, 2, 1, C)
	place(&g, 3, 1, C)
	place(&g, 4, 0, C)
	testing.expect(t, resolve_lines(&g))
	testing.expect_value(t, g.chain, i32(1))
	testing.expect_value(t, g.lines, i64(1)) // the second line waits for the pause
	for _ in 0 ..< 5 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.chain, i32(2))
	testing.expect_value(t, g.lines, i64(2))
	testing.expect_value(t, g.best_chain, i32(2))
	testing.expect_value(t, count_sheep(&g), 0)
}

@(test)
a_landing_sheep_makes_the_line :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	for c in 0 ..< i32(3) {
		place(&g, c, 0, S)
	}
	g.px, g.py = FOLD_FIRST_COL + 3, 0
	g.held[0] = {rank = 2, suit = S}
	g.held_count = 1
	send_sheep(&g)
	// In the air it does not count yet.
	marks: [FOLD_COLS][FOLD_ROWS]bool
	testing.expect_value(t, find_lines(&g, &marks), 0)
	for _ in 0 ..< 7 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.lines, i64(1))
	testing.expect_value(t, count_sheep(&g), 0)
	testing.expect_value(t, g.counted, i64(1))
}

@(test)
a_sheep_in_the_air_is_reaimed_when_its_column_drops :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	// Column 0 holds a heart on row 0; hearts in 1..3 on row 0 complete a line once landed.
	for c in 0 ..< i32(4) {
		place(&g, c, 0, H)
	}
	g.px, g.py = FOLD_FIRST_COL, 0
	g.held[0] = {rank = 8, suit = D}
	g.held_count = 1
	send_sheep(&g) // lands on row 1 of column 0
	testing.expect_value(t, g.jumps[0].row, i32(1))
	testing.expect(t, resolve_lines(&g)) // the hearts clear while it is in the air
	testing.expect_value(t, g.jumps[0].row, i32(0))
	testing.expect_value(t, g.fold[0][0].suit, D)
	for _ in 0 ..< 7 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.jump_count, i32(0))
	testing.expect_value(t, g.fold[0][0].suit, D)
	testing.expect_value(t, count_sheep(&g), 1)
}
