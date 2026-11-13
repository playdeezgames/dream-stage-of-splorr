#+build !js
package game

import "core:os"
import "core:testing"

_ :: os

DUMP_PLAY :: #config(DUMP_PLAY, "")
DUMP_CLEAR :: #config(DUMP_CLEAR, "")
DUMP_SHOP :: #config(DUMP_SHOP, "")
DUMP_END :: #config(DUMP_END, "")

write_ppm :: proc(path: string, f: ^Frame) -> bool {
	out := make([dynamic]u8)
	defer delete(out)
	header := "P6\n384 216\n255\n"
	append(&out, ..transmute([]u8)header)
	for p in f.px {
		c := PALETTE[p & 15]
		append(&out, u8(c >> 16), u8(c >> 8), u8(c))
	}
	return os.write_entire_file(path, out[:]) == nil
}

// A frame mid-play, for screenshots: -define:DUMP_PLAY=<path.ppm>
@(test)
dump_play :: proc(t: ^testing.T) {
	when DUMP_PLAY != "" {
		g: Game
		init_game(&g, 11)
		g.px, g.py = FOLD_FIRST_COL + 2, 0
		g.fold[0][0] = {rank = 5, suit = .Hearts}
		g.fold[0][1] = {rank = 12, suit = .Clubs}
		g.fold[1][0] = {rank = 1, suit = .Spades}
		g.fold[3][0] = {rank = 13, suit = .Diamonds}
		g.fold[3][1] = {rank = 7, suit = .Diamonds}
		g.held[0] = {rank = 9, suit = .Clubs}
		g.held[1] = {rank = 11, suit = .Hearts}
		g.held_count = 2
		g.counted = 1234
		g.pegging.count = 15
		g.last_peg = {calls = {.Fifteen, .Pair}, points = 4}
		g.peg_t = 2
		g.points = 87 + 3 * BOARD_HOLES
		g.lap = 3
		g.zzz = 412
		g.count_level = 2
		f := new(Frame)
		defer free(f)
		draw_game(f, &g)
		testing.expect(t, write_ppm(DUMP_PLAY, f))
	}
}

// A frame just after a chain clear, sheep asleep and dropping: -define:DUMP_CLEAR=<path.ppm>
@(test)
dump_clear :: proc(t: ^testing.T) {
	when DUMP_CLEAR != "" {
		g: Game
		init_game(&g, 12)
		g.px, g.py = FOLD_FIRST_COL + 4, 0
		for c in 0 ..< i32(4) {
			g.fold[c][0] = {rank = u8(2 + c), suit = .Hearts}
		}
		g.fold[1][1] = {rank = 10, suit = .Clubs}
		g.fold[2][1] = {rank = 6, suit = .Clubs}
		g.fold[3][1] = {rank = 13, suit = .Clubs}
		g.fold[4][0] = {rank = 1, suit = .Clubs}
		g.fold[5][0] = {rank = 8, suit = .Spades}
		resolve_lines(&g)
		tick(&g, 0.45) // the clubs line up, the second clear of the chain
		tick(&g, 0.3)
		f := new(Frame)
		defer free(f)
		draw_game(f, &g)
		testing.expect(t, write_ppm(DUMP_CLEAR, f))
	}
}

// The nightstand's menu, on the clear row with a full fold: -define:DUMP_SHOP=<path.ppm>
@(test)
dump_shop :: proc(t: ^testing.T) {
	when DUMP_SHOP != "" {
		g: Game
		init_game(&g, 13)
		g.px, g.py = NIGHTSTAND_X - 1, NIGHTSTAND_Y
		g.zzz = 140
		g.armful_level, g.armful = 2, ARMFUL_START + 2
		g.lap = 2
		g.points = 2 * BOARD_HOLES + 40
		for col in 0 ..< FOLD_COLS {
			for row in 0 ..< FOLD_ROWS {
				g.fold[col][row] = {rank = u8(1 + (col * 3 + row * 5) % 13), suit = Suit((col + row * 3) % 4)}
			}
		}
		g.zzz = 20
		open_shop(&g)
		g.shop.row = .Clear
		g.shop.col = 3
		f := new(Frame)
		defer free(f)
		draw_game(f, &g)
		testing.expect(t, write_ppm(DUMP_SHOP, f))
	}
}

// The end of a night: -define:DUMP_END=<path.ppm>
@(test)
dump_end :: proc(t: ^testing.T) {
	when DUMP_END != "" {
		g: Game
		init_game(&g, 14)
		g.points = 9876
		g.best_hand = 24
		g.best_chain = 3
		g.lap = 61
		g.time = 2 * 3600 + 7 * 60 + 33
		g.counted = TOTAL_SHEEP - 1
		count_sheep_in(&g)
		g.finish_t = 2
		f := new(Frame)
		defer free(f)
		draw_game(f, &g)
		testing.expect(t, write_ppm(DUMP_END, f))
	}
}
