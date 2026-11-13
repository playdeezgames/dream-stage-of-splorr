package game

// Cribbage scoring (DESIGN.md): pegging on every jump over the fence, and a hand for every line
// cleared from the fold, with the moon as the cut card.

PEG_SEQ_MAX :: 13 // a sequence ends by 31 long before this

Peg_Call :: enum u8 {
	Fifteen,
	Thirty_One,
	Go,
	Pair, // two of a kind, 2
	Pair_Royal, // three of a kind, 6
	Double_Pair_Royal, // four of a kind, 12
	Run,
}

Peg_Result :: struct {
	calls:  bit_set[Peg_Call],
	run:    i32, // length of the run, when Run is called
	points: i32,
}

// The running count and the sheep jumped since it last started.
Pegging :: struct {
	count: i32,
	seq:   [PEG_SEQ_MAX]Card,
	len:   i32,
}

// Pegs one sheep jumping the fence, as in cribbage's play: 15 and 31 score 2 (31 starts the count
// again), a sheep that would pass 31 is a go for 1 and starts the count with itself, pairs and runs
// among the last sheep score.
peg :: proc(p: ^Pegging, c: Card) -> Peg_Result {
	r: Peg_Result
	v := i32(card_value(c))
	if p.count + v > 31 {
		r.calls += {.Go}
		r.points += 1
		p.count = v
		p.seq[0] = c
		p.len = 1
		return r
	}
	p.count += v
	if p.len < PEG_SEQ_MAX {
		p.seq[p.len] = c
		p.len += 1
	}

	if p.count == 15 {
		r.calls += {.Fifteen}
		r.points += 2
	}

	// Pairs: how many of the last sheep share this one's rank, back to back.
	same: i32 = 1
	for i := p.len - 2; i >= 0 && p.seq[i].rank == c.rank; i -= 1 {
		same += 1
	}
	switch same {
	case 2:
		r.calls += {.Pair}
		r.points += 2
	case 3:
		r.calls += {.Pair_Royal}
		r.points += 6
	case 4:
		r.calls += {.Double_Pair_Royal}
		r.points += 12
	}

	// Runs: the longest tail of 3 or more whose ranks are all different and consecutive.
	for k := p.len; k >= 3; k -= 1 {
		if is_run(p.seq[p.len - k:p.len]) {
			r.calls += {.Run}
			r.run = k
			r.points += k
			break
		}
	}

	if p.count == 31 {
		r.calls += {.Thirty_One}
		r.points += 2
		p.count = 0
		p.len = 0
	}
	return r
}

// True when the cards' ranks are all different and consecutive, in any order.
is_run :: proc(cards: []Card) -> bool {
	seen: [14]bool
	lo, hi := 14, 0
	for c in cards {
		r := int(c.rank)
		if seen[r] {
			return false
		}
		seen[r] = true
		lo = min(lo, r)
		hi = max(hi, r)
	}
	return hi - lo == len(cards) - 1
}

Hand_Score :: struct {
	fifteens: i32, // points from fifteens (2 each)
	pairs:    i32, // points from pairs (2 each)
	runs:     i32,
	flush:    i32,
	nobs:     i32,
	total:    i32,
}

// Scores four cards plus the cut card as a cribbage hand: fifteens, pairs, runs, a flush (4, or 5
// with the cut) and his nobs (the Jack of the cut's suit).
score_hand :: proc(hand: [4]Card, cut: Card) -> Hand_Score {
	s: Hand_Score
	all := [5]Card{hand[0], hand[1], hand[2], hand[3], cut}

	for mask in 1 ..< 32 {
		sum := 0
		for i in 0 ..< 5 {
			if mask & (1 << uint(i)) != 0 {
				sum += card_value(all[i])
			}
		}
		if sum == 15 {
			s.fifteens += 2
		}
	}

	for i in 0 ..< 5 {
		for j in i + 1 ..< 5 {
			if all[i].rank == all[j].rank {
				s.pairs += 2
			}
		}
	}

	// Runs: the longest span of consecutive ranks present, times the ways to pick one card of each.
	counts: [15]i32
	for c in all {
		counts[c.rank] += 1
	}
	best_len, best_ways: i32 = 0, 0
	r := 1
	for r <= 13 {
		if counts[r] == 0 {
			r += 1
			continue
		}
		start := r
		ways: i32 = 1
		for r <= 13 && counts[r] > 0 {
			ways *= counts[r]
			r += 1
		}
		span := i32(r - start)
		if span >= 3 && span > best_len {
			best_len, best_ways = span, ways
		}
	}
	s.runs = best_len * best_ways

	if hand[0].suit == hand[1].suit && hand[1].suit == hand[2].suit && hand[2].suit == hand[3].suit {
		s.flush = 4
		if cut.suit == hand[0].suit {
			s.flush = 5
		}
	}

	for c in hand {
		if c.rank == 11 && c.suit == cut.suit {
			s.nobs = 1
		}
	}

	s.total = s.fifteens + s.pairs + s.runs + s.flush + s.nobs
	return s
}

Line_Score :: struct {
	hand:   Hand_Score, // the best four
	best:   [4]Card,
	extras: i32, // sheep past four, a point each
	total:  i32,
}

// A line of four scores as a hand with the moon; a longer line scores its best four, plus a point
// for every sheep past four (the user's rule, November 13, 2026).
score_line :: proc(cards: []Card, cut: Card) -> Line_Score {
	ls: Line_Score
	n := len(cards)
	if n < 4 {
		return ls
	}
	first := true
	for a in 0 ..< n {
		for b in a + 1 ..< n {
			for c in b + 1 ..< n {
				for d in c + 1 ..< n {
					four := [4]Card{cards[a], cards[b], cards[c], cards[d]}
					h := score_hand(four, cut)
					if first || h.total > ls.hand.total {
						ls.hand, ls.best = h, four
						first = false
					}
				}
			}
		}
	}
	ls.extras = i32(n - 4)
	ls.total = ls.hand.total + ls.extras
	return ls
}
