#+build !js
package game

import "core:testing"

cd :: proc(rank: u8, suit: Suit = .Spades) -> Card {
	return {rank = rank, suit = suit}
}

@(test)
peg_fifteen_and_thirty_one :: proc(t: ^testing.T) {
	p: Pegging
	testing.expect_value(t, peg(&p, cd(10)).points, i32(0))
	r := peg(&p, cd(5, .Hearts))
	testing.expect(t, .Fifteen in r.calls)
	testing.expect_value(t, r.points, i32(2))
	testing.expect_value(t, p.count, i32(15))
	peg(&p, cd(13, .Clubs)) // 25
	r = peg(&p, cd(6, .Diamonds)) // 31
	testing.expect(t, .Thirty_One in r.calls)
	testing.expect_value(t, r.points, i32(2))
	testing.expect_value(t, p.count, i32(0))
	testing.expect_value(t, p.len, i32(0))
}

@(test)
peg_go_starts_again :: proc(t: ^testing.T) {
	p: Pegging
	peg(&p, cd(10))
	peg(&p, cd(12, .Hearts))
	peg(&p, cd(8, .Clubs)) // 28
	r := peg(&p, cd(9)) // would be 37
	testing.expect_value(t, r.calls, bit_set[Peg_Call]{.Go})
	testing.expect_value(t, r.points, i32(1))
	testing.expect_value(t, p.count, i32(9))
	testing.expect_value(t, p.len, i32(1))
	// The go ends the sequence: a 9 after it is a fresh pair, not three of a kind.
	r = peg(&p, cd(9, .Hearts))
	testing.expect(t, .Pair in r.calls)
}

@(test)
peg_pairs :: proc(t: ^testing.T) {
	p: Pegging
	peg(&p, cd(3))
	testing.expect_value(t, peg(&p, cd(3, .Hearts)).points, i32(2))
	r := peg(&p, cd(3, .Clubs))
	testing.expect(t, .Pair_Royal in r.calls)
	testing.expect_value(t, r.points, i32(6))
	r = peg(&p, cd(3, .Diamonds)) // 12 in all: not a fifteen
	testing.expect(t, .Double_Pair_Royal in r.calls)
	testing.expect_value(t, r.points, i32(12))
}

@(test)
peg_runs_in_any_order :: proc(t: ^testing.T) {
	p: Pegging
	peg(&p, cd(4))
	peg(&p, cd(2, .Hearts))
	r := peg(&p, cd(3, .Clubs)) // 2-3-4
	testing.expect(t, .Run in r.calls)
	testing.expect_value(t, r.run, i32(3))
	testing.expect_value(t, r.points, i32(3))
	r = peg(&p, cd(5, .Diamonds)) // 2-3-4-5, count 14
	testing.expect_value(t, r.run, i32(4))
	r = peg(&p, cd(1)) // A-2-3-4-5, count 15
	testing.expect(t, .Fifteen in r.calls)
	testing.expect_value(t, r.run, i32(5))
	testing.expect_value(t, r.points, i32(7))
	// A repeated rank breaks the run.
	q: Pegging
	peg(&q, cd(4))
	peg(&q, cd(4, .Hearts))
	r = peg(&q, cd(5))
	testing.expect(t, .Run not_in r.calls)
}

@(test)
hand_of_twenty_nine :: proc(t: ^testing.T) {
	// Three 5s and the Jack of the cut's suit, with the fourth 5 as the cut: the best hand there is.
	h := score_hand({cd(5, .Hearts), cd(5, .Clubs), cd(5, .Diamonds), cd(11, .Spades)}, cd(5, .Spades))
	testing.expect_value(t, h.fifteens, i32(16))
	testing.expect_value(t, h.pairs, i32(12))
	testing.expect_value(t, h.nobs, i32(1))
	testing.expect_value(t, h.total, i32(29))
}

@(test)
hand_runs_and_flush :: proc(t: ^testing.T) {
	// 4-5-6-7 of hearts with a 6 cut: a double run of four (8), a pair (2), 4+5+6 twice (4) and a
	// flush of 4 (the cut is another suit).
	h := score_hand({cd(4, .Hearts), cd(5, .Hearts), cd(6, .Hearts), cd(7, .Hearts)}, cd(6, .Clubs))
	testing.expect_value(t, h.runs, i32(8))
	testing.expect_value(t, h.pairs, i32(2))
	testing.expect_value(t, h.fifteens, i32(4))
	testing.expect_value(t, h.flush, i32(4))
	testing.expect_value(t, h.nobs, i32(0))
	testing.expect_value(t, h.total, i32(18))
	// The same four with a heart cut: a five-card flush.
	h = score_hand({cd(4, .Hearts), cd(5, .Hearts), cd(6, .Hearts), cd(7, .Hearts)}, cd(13, .Hearts))
	testing.expect_value(t, h.flush, i32(5))
}

@(test)
hand_of_nothing_but_the_flush :: proc(t: ^testing.T) {
	// 2, 4, 6, 8 of clubs with a King: no fifteens, pairs or runs; only the flush.
	h := score_hand({cd(2, .Clubs), cd(4, .Clubs), cd(6, .Clubs), cd(8, .Clubs)}, cd(13, .Spades))
	testing.expect_value(t, h.fifteens, i32(0))
	testing.expect_value(t, h.runs, i32(0))
	testing.expect_value(t, h.total, i32(4))
}

@(test)
line_of_five_scores_its_best_four_plus_one :: proc(t: ^testing.T) {
	// 5 5 5 J 9 of spades, cut 5 of hearts: the best four is 5 5 5 J, and the fifth sheep is a
	// point as an extra.
	cards := []Card{cd(5), cd(5, .Spades), cd(5, .Spades), cd(11, .Spades), cd(9, .Spades)}
	ls := score_line(cards, cd(5, .Hearts))
	testing.expect_value(t, ls.extras, i32(1))
	best := score_hand({cd(5), cd(5), cd(5), cd(11)}, cd(5, .Hearts))
	testing.expect_value(t, ls.hand.total, best.total)
	testing.expect_value(t, ls.total, best.total + 1)
	// A line of four has no extras.
	four := score_line(cards[:4], cd(5, .Hearts))
	testing.expect_value(t, four.extras, i32(0))
	testing.expect_value(t, four.total, best.total)
}

@(test)
a_jump_pegs_and_a_line_scores :: proc(t: ^testing.T) {
	g: Game
	bare_game(&g)
	g.moon = cd(13, .Diamonds)
	// Three spades already in the fold; the fourth lands and makes 2 3 4 5 of spades.
	g.fold[0][0] = cd(2)
	g.fold[1][0] = cd(3)
	g.fold[2][0] = cd(4)
	g.px, g.py = FOLD_FIRST_COL + 3, 0
	g.held[0] = cd(5)
	g.held[1] = cd(10, .Hearts)
	g.held_count = 2
	send_sheep(&g) // 5 of spades into column 3: count 5, nothing
	testing.expect_value(t, g.points, i64(0))
	g.px = FOLD_FIRST_COL + 5
	send_sheep(&g) // 10 of hearts into column 5: count 15, fifteen for 2
	testing.expect_value(t, g.points, i64(2))
	testing.expect(t, .Fifteen in g.last_peg.calls)
	for _ in 0 ..< 7 {
		tick(&g, 0.1)
	}
	// 2 3 4 5 of spades with the King of diamonds: run of 4, fifteens 2+3+K and 5+K = 4, flush 4.
	h := score_hand({cd(2), cd(3), cd(4), cd(5)}, g.moon)
	testing.expect_value(t, g.lines, i64(1))
	testing.expect_value(t, g.last_line.total, h.total)
	testing.expect_value(t, g.points, i64(2 + h.total))
	testing.expect_value(t, g.pop_count, i32(1))
}
