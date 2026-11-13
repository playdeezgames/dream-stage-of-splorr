#+build !js
package game

import "core:testing"

@(test)
a_night_saves_and_loads :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g, 31)
	g.zzz = 777
	g.counted = 4242
	g.lap = 5
	g.fold[3][0] = {rank = 12, suit = .Diamonds}
	add_dog(g)
	g.dogs[0].carrying = true
	g.dogs[0].card = {rank = 2, suit = .Clubs}
	g.muted = true
	g.bests.nights = 2
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	testing.expect_value(t, save_game(g, buf), SAVE_CAP)

	h := new(Game)
	defer free(h)
	init_game(h, 1)
	testing.expect(t, load_game(h, buf))
	testing.expect_value(t, h.zzz, i64(777))
	testing.expect_value(t, h.counted, i64(4242))
	testing.expect_value(t, h.lap, i32(5))
	testing.expect_value(t, h.fold[3][0], Card{rank = 12, suit = .Diamonds})
	testing.expect_value(t, h.dog_count, i32(1))
	testing.expect(t, h.muted)
	testing.expect_value(t, h.bests.nights, i32(2))
	testing.expect_value(t, h.rng, g.rng)
}

@(test)
a_bad_save_is_not_loaded :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	init_game(g, 32)
	buf := make([]u8, SAVE_CAP)
	defer delete(buf)
	save_game(g, buf)

	h := new(Game)
	defer free(h)
	init_game(h, 2)
	before := h.rng
	testing.expect(t, !load_game(h, buf[:SAVE_CAP - 1])) // wrong size
	bad := make([]u8, SAVE_CAP)
	defer delete(bad)
	copy(bad, buf)
	bad[4] = 99 // another version
	testing.expect(t, !load_game(h, bad))
	// A damaged game inside a good header.
	g.fold[0][0] = {rank = 40, suit = .Hearts}
	save_game(g, bad)
	testing.expect(t, !load_game(h, bad))
	g.fold[0][0] = {}
	g.held_count = 99
	save_game(g, bad)
	testing.expect(t, !load_game(h, bad))
	testing.expect_value(t, h.rng, before) // left alone
}

@(test)
esc_opens_the_menu_and_mute_silences :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	command(&g, .Cancel)
	testing.expect(t, g.menu.open)
	g.sound_count = 0
	command(&g, .South) // Sound
	command(&g, .Ok)
	testing.expect(t, g.muted)
	command(&g, .Cancel)
	testing.expect(t, !g.menu.open)
	g.sound_count = 0
	g.px, g.py = FOLD_FIRST_COL, 0
	command(&g, .Ok) // empty arms: would play Deny
	testing.expect_value(t, g.sound_count, i32(0))
	// While the menu is open, the insomniac stays put.
	g.px, g.py = 5, 2
	command(&g, .Cancel)
	command(&g, .West)
	testing.expect_value(t, g.px, i32(5))
}

@(test)
starting_over_asks_first_and_keeps_the_bests :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.zzz = 500
	g.counted = 9999
	g.bests = {nights = 3, points = 1234}
	g.muted = true
	command(&g, .Cancel)
	command(&g, .North) // wraps to Start over
	testing.expect_value(t, g.menu.row, Menu_Row.Start_Over)
	command(&g, .Ok)
	testing.expect(t, g.menu.confirm)
	command(&g, .Ok) // No is chosen first
	testing.expect(t, !g.menu.confirm)
	testing.expect_value(t, g.zzz, i64(500))
	command(&g, .Ok)
	command(&g, .South) // to Yes
	command(&g, .Ok)
	testing.expect(t, !g.menu.open)
	testing.expect_value(t, g.zzz, i64(0))
	testing.expect_value(t, g.counted, i64(0))
	testing.expect_value(t, g.bests.nights, i32(3))
	testing.expect_value(t, g.bests.points, i64(1234))
	testing.expect(t, g.muted)
}
