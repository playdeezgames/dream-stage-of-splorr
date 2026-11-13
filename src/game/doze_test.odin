#+build !js
package game

import "core:testing"

@(test)
an_old_sheep_dozes_off_and_the_column_drops :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.flock_target = 0
	g.fold[2][0] = {rank = 4, suit = .Clubs}
	g.fold[2][1] = {rank = 9, suit = .Hearts}
	g.age[2][0] = DOZE_TIME - 0.05
	g.age[2][1] = 3
	testing.expect(t, sleepy(&g, 2, 0))
	testing.expect(t, !sleepy(&g, 2, 1))
	tick(&g, 0.1)
	testing.expect_value(t, g.dozed, i64(1))
	testing.expect_value(t, g.fold[2][0], Card{rank = 9, suit = .Hearts}) // dropped into its place
	testing.expect_value(t, g.fold[2][1].rank, u8(0))
	testing.expect(t, g.age[2][0] > 3 && g.age[2][0] < 4) // its own age came with it
	testing.expect_value(t, g.points, i64(0)) // dozing is not scored
	testing.expect_value(t, g.sleeper_count, i32(1))
}

@(test)
a_doze_can_drop_sheep_into_a_line :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.flock_target = 0
	// Spades on row 0 of columns 0..2; column 3 has an old heart under a spade.
	g.fold[0][0] = {rank = 2, suit = .Spades}
	g.fold[1][0] = {rank = 3, suit = .Spades}
	g.fold[2][0] = {rank = 4, suit = .Spades}
	g.fold[3][0] = {rank = 9, suit = .Hearts}
	g.fold[3][1] = {rank = 5, suit = .Spades}
	g.age[3][0] = DOZE_TIME
	for _ in 0 ..< 10 {
		tick(&g, 0.1)
	}
	testing.expect_value(t, g.dozed, i64(1))
	testing.expect_value(t, g.lines, i64(1))
	testing.expect(t, g.points > 0)
}

@(test)
a_sheep_in_the_air_does_not_age :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.px, g.py = FOLD_FIRST_COL, 0
	g.held[0] = {rank = 6, suit = .Diamonds}
	g.held_count = 1
	send_sheep(&g)
	tick(&g, 0.2)
	testing.expect_value(t, g.age[0][0], f32(0))
	tick(&g, 0.25)
	tick(&g, 0.25) // it has landed
	testing.expect(t, g.age[0][0] > 0)
}
