#+build !js
package game

// A playtest bot: plays a whole night through `command`, the same input a player gives, at about a
// human's pace, and logs the timeline (purchases, income, idling, dozing, jams). Off unless asked:
//   odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:PLAYTEST=true \
//     -define:ODIN_TEST_NAMES=game.playtest_nights

import "core:fmt"
import "core:testing"

PLAYTEST :: #config(PLAYTEST, false)
PLAYTEST_QUICK :: #config(PLAYTEST_QUICK, false)
BOT_PRESS :: 0.2 // seconds between key presses
BOT_HOURS :: 4.0

Bot_Style :: enum {
	Careful, // picks sheep and pens to make lines
	Lazy, // nearest sheep, emptiest pen
	Relaxed, // careful until it owns a dog, then only goes shopping
}

Bot_Stats :: struct {
	presses:       int,
	walk_presses:  int,
	shop_presses:  int,
	idle_presses:  int, // nothing useful to do
	full_seconds:  f64, // the fold was full
	took_all:      int,
	clears:        int,
	purchases:     int,
	last_purchase: f64,
	longest_gap:   f64, // the longest stretch between purchases
	gap_at:        f64,
}

DIR4 := [4][2]i32{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
DIR_CMD := [4]Command{.North, .South, .West, .East}

// One step on a shortest path to (tx, ty) through the pasture, treating sheep as walls (except the
// goal). -1 when there is no path or the insomniac is there.
bot_path :: proc(g: ^Game, tx, ty: i32) -> int {
	if g.px == tx && g.py == ty {
		return -1
	}
	prev: [PASTURE_COLS][PASTURE_ROWS]i8
	seen: [PASTURE_COLS][PASTURE_ROWS]bool
	queue: [PASTURE_COLS * PASTURE_ROWS][2]i32
	head, tail := 0, 0
	queue[tail] = {tx, ty}
	tail += 1
	seen[tx][ty] = true
	for head < tail {
		c := queue[head]
		head += 1
		for d, k in DIR4 {
			nx, ny := c[0] - d[0], c[1] - d[1] // walk backwards from the goal
			if !in_pasture(nx, ny) || seen[nx][ny] {
				continue
			}
			if nx == g.px && ny == g.py {
				return k
			}
			if sheep_at(g, nx, ny) >= 0 || is_nightstand(nx, ny) {
				continue
			}
			seen[nx][ny] = true
			prev[nx][ny] = i8(k)
			queue[tail] = {nx, ny}
			tail += 1
		}
	}
	return -1
}

bot_plan_col :: proc(g: ^Game, c: Card, style: Bot_Style) -> i32 {
	f := g.fold
	if style != .Lazy {
		return dog_column(&f, c, g.px)
	}
	best, best_row := i32(-1), i32(99)
	for col in 0 ..< i32(FOLD_COLS) {
		if r := landing_row(g, col); r >= 0 && r < best_row {
			best, best_row = col, r
		}
	}
	return best
}

// What the bot wants to buy now, if anything: the cheapest thing it can afford.
bot_want :: proc(g: ^Game) -> (Shop_Row, bool) {
	best: Shop_Row
	best_cost := i64(-1)
	for row in ([]Shop_Row{.Armful, .Grass, .Count_By, .Sheepdog, .Dog_Speed}) {
		cost, ok := price(g, row)
		if ok && cost <= g.zzz && (best_cost < 0 || cost < best_cost) {
			best, best_cost = row, cost
		}
	}
	return best, best_cost >= 0
}

// One key press of the bot.
bot_press :: proc(g: ^Game, style: Bot_Style, st: ^Bot_Stats) {
	st.presses += 1
	if g.finished {
		return
	}
	// In the shop: buy what it came for (or clear a pen when the fold is full), then leave.
	if g.shop.open {
		st.shop_presses += 1
		want, ok := bot_want(g)
		if fold_full(g) {
			want, ok = .Clear, true
			g.shop.col = 3
		}
		if !ok {
			command(g, .Cancel)
			return
		}
		if g.shop.row != want {
			command(g, .South)
			return
		}
		zzz_before := g.zzz
		if buy(g, want) {
			if want == .Clear {
				st.clears += 1
				if g.notice == .Took_All {
					st.took_all += 1
				}
			} else {
				st.purchases += 1
				gap := g.time - st.last_purchase
				if gap > st.longest_gap {
					st.longest_gap, st.gap_at = gap, st.last_purchase
				}
				st.last_purchase = g.time
				_ = zzz_before
			}
		}
		return
	}
	// Go shopping when something is affordable, or the fold is full.
	_, can_buy := bot_want(g)
	if can_buy || (fold_full(g) && g.held_count > 0) {
		st.walk_presses += 1
		for t in ([][2]i32{{NIGHTSTAND_X - 1, NIGHTSTAND_Y}, {NIGHTSTAND_X, NIGHTSTAND_Y - 1}}) {
			if g.px == t[0] && g.py == t[1] {
				command(g, .East if t[0] == NIGHTSTAND_X - 1 else .South)
				return
			}
		}
		k := bot_path(g, NIGHTSTAND_X - 1, NIGHTSTAND_Y)
		if k < 0 {
			k = bot_path(g, NIGHTSTAND_X, NIGHTSTAND_Y - 1)
		}
		if k >= 0 {
			command(g, DIR_CMD[k])
		}
		return
	}
	relaxing := style == .Relaxed && g.dog_count > 0
	if relaxing && g.held_count == 0 {
		st.idle_presses += 1
		return
	}
	// Arms not full and sheep about: fetch one.
	if !relaxing && g.held_count < g.armful && g.flock_count > 0 {
		f := g.fold
		best, best_key := -1, i32(-1 << 30)
		for i in 0 ..< int(g.flock_count) {
			s := g.flock[i]
			dist := abs_i32(s.x - g.px) + abs_i32(s.y - g.py)
			key := -dist
			if style != .Lazy {
				run: i32 = 0
				if col := dog_column(&f, s.card, g.px); col >= 0 {
					run = run_through(&f, col, fold_landing_row(&f, col), s.card.suit)
				}
				key = run * 6 - dist
			}
			if key > best_key {
				best, best_key = i, key
			}
		}
		s := g.flock[best]
		// Adjacent: step into it.
		for d, k in DIR4 {
			if g.px + d[0] == s.x && g.py + d[1] == s.y {
				st.walk_presses += 1
				command(g, DIR_CMD[k])
				return
			}
		}
		if k := bot_path(g, s.x, s.y); k >= 0 {
			st.walk_presses += 1
			command(g, DIR_CMD[k])
			return
		}
	}
	// Holding sheep: take the first to its pen.
	if g.held_count > 0 {
		col := bot_plan_col(g, g.held[0], style)
		if col < 0 {
			st.idle_presses += 1
			return
		}
		tx := FOLD_FIRST_COL + col
		if g.px == tx && g.py == 0 {
			command(g, .Ok)
			return
		}
		st.walk_presses += 1
		if k := bot_path(g, tx, 0); k >= 0 {
			command(g, DIR_CMD[k])
		} else {
			// Boxed in by sheep: push through (picks one up if there is room).
			command(g, .North)
		}
		return
	}
	st.idle_presses += 1
}

fmt_clock :: proc(seconds: f64) -> string {
	s := int(seconds)
	return fmt.tprintf("%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
}

STAGE_SHOP_NAMES := [Shop_Row]string {
	.Armful    = "armful",
	.Grass     = "grass",
	.Count_By  = "count by",
	.Sheepdog  = "sheepdog",
	.Dog_Speed = "dog speed",
	.Clear     = "clear",
	.Leave     = "leave",
}

playtest_night :: proc(style: Bot_Style, seed: u64, verbose: bool) {
	g := new(Game)
	defer free(g)
	init_game(g, seed)
	st: Bot_Stats
	press_t: f64 = 0
	last := g^
	next_report: f64 = 0
	snap_counted, snap_points, snap_zzz, snap_dozed, snap_lines: i64
	for g.time < BOT_HOURS * 3600 && !g.finished {
		tick(g, 0.05)
		g.sound_count = 0
		if fold_full(g) {
			st.full_seconds += 0.05
		}
		press_t += 0.05
		for press_t >= BOT_PRESS {
			press_t -= BOT_PRESS
			before := g^
			bot_press(g, style, &st)
			if verbose {
				// Log each purchase.
				for row in ([]Shop_Row{.Armful, .Grass, .Count_By, .Sheepdog, .Dog_Speed}) {
					was, now: i32
					switch row {
					case .Armful:
						was, now = before.armful, g.armful
					case .Grass:
						was, now = before.grass_level, g.grass_level
					case .Count_By:
						was, now = before.count_level, g.count_level
					case .Sheepdog:
						was, now = before.dog_count, g.dog_count
					case .Dog_Speed:
						was, now = before.dog_speed_level, g.dog_speed_level
					case .Clear, .Leave:
					}
					if now > was {
						fmt.printfln("  %s  bought %-9s -> %d   (Zzz left %d, stage %s x%d, counted %d)", fmt_clock(g.time), STAGE_SHOP_NAMES[row], now, g.zzz, stage_name(g.lap), multiplier(g), g.counted)
					}
				}
			}
		}
		if verbose && g.time >= next_report {
			if next_report > 0 {
				fmt.printfln("  %s  [10 min] +%d counted, +%d points, +%d Zzz earned-ish, +%d lines, +%d dozed; count by %d, dogs %d, armful %d, fold free %d",
					fmt_clock(g.time), g.counted - snap_counted, g.points - snap_points, g.zzz - snap_zzz, g.lines - snap_lines, g.dozed - snap_dozed,
					count_by(g), g.dog_count, g.armful, fold_free(&g.fold))
			}
			snap_counted, snap_points, snap_zzz, snap_dozed, snap_lines = g.counted, g.points, g.zzz, g.dozed, g.lines
			next_report += 600
		}
	}
	_ = last
	fmt.printfln("%v seed %d: %s %s, counted %d, points %d, lines %d, dozed %d, top chain %d, best hand %d, stage %s cycle %d",
		style, seed, "FINISHED" if g.finished else "not finished at", fmt_clock(g.finish_time if g.finished else g.time), g.counted, g.points, g.lines, g.dozed,
		g.best_chain, g.best_hand, stage_name(g.lap), stage_cycle(g.lap))
	fmt.printfln("   presses %d: walking %d%%, shop %d%%, idle %d%%; fold full %.0f s, clears %d (took all %d); purchases %d, longest gap %s from %s",
		st.presses, 100 * st.walk_presses / max(st.presses, 1), 100 * st.shop_presses / max(st.presses, 1), 100 * st.idle_presses / max(st.presses, 1),
		st.full_seconds, st.clears, st.took_all, st.purchases, fmt_clock(st.longest_gap), fmt_clock(st.gap_at))
}

@(test)
playtest_nights :: proc(t: ^testing.T) {
	when PLAYTEST {
		when PLAYTEST_QUICK {
			playtest_night(.Careful, 1, false)
			playtest_night(.Lazy, 1, false)
			playtest_night(.Relaxed, 1, false)
		} else {
			playtest_night(.Careful, 1, true)
			playtest_night(.Lazy, 1, true)
			playtest_night(.Relaxed, 1, true)
		}
	}
}
