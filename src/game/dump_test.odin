#+build !js
package game

import "core:os"
import "core:testing"

_ :: os

DUMP_PLAY :: #config(DUMP_PLAY, "")
DUMP_CLEAR :: #config(DUMP_CLEAR, "")

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
