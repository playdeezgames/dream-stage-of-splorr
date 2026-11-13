package game

import "core:math"

// Screen layout in pixels. The fold sits on the fence, its columns over pasture columns
// FOLD_FIRST_COL.., so a sheep sent from under a column jumps straight up into it.
PASTURE_Y :: 120
FENCE_Y :: PASTURE_Y - TILE
FOLD_X :: FOLD_FIRST_COL * TILE
FOLD_Y :: FENCE_Y - FOLD_ROWS * TILE
PANEL_X :: PASTURE_COLS * TILE
STRIP_Y :: PASTURE_Y + PASTURE_ROWS * TILE

MOON_X :: 30
MOON_Y :: 28
CALL_X :: FOLD_X + FOLD_COLS * TILE + 6

COLOR_SKY_BG :: COLOR_BLACK
COLOR_GRASS_BG :: COLOR_TEAL
COLOR_PANEL :: COLOR_DARK

RANKS := "A23456789TJQK"

suit_color :: proc(s: Suit) -> u8 {
	switch s {
	case .Spades:
		return COLOR_WHITE
	case .Hearts:
		return COLOR_ORANGE
	case .Diamonds:
		return COLOR_CYAN
	case .Clubs:
		return COLOR_LIME
	}
	return COLOR_WHITE
}

// Code page 437 suit glyphs.
suit_glyph :: proc(s: Suit) -> u8 {
	switch s {
	case .Spades:
		return 6
	case .Hearts:
		return 3
	case .Diamonds:
		return 4
	case .Clubs:
		return 5
	}
	return '?'
}

// A card sheep: wool in its suit's colour, the rank on its side, a black face for face cards.
draw_sheep :: proc(f: ^Frame, c: Card, x, y: int, flip: bool) {
	r := IDENTITY
	r[12] = suit_color(c.suit)
	if is_face(c) {
		r[13] = COLOR_BLACK
		r[1] = COLOR_WHITE
	} else {
		r[1] = COLOR_DARK
	}
	draw_gfx(f, .Sheep, x, y, flip, r)
	print_glyph(f, RANKS[c.rank - 1], x + (7 if flip else 3), y + 3, COLOR_BLACK)
}

// A sheep fallen asleep: drawn like the others, its eye shut (a closed eye is the face colour).
draw_sleeping_sheep :: proc(f: ^Frame, c: Card, x, y: int) {
	r := IDENTITY
	r[12] = suit_color(c.suit)
	r[13] = COLOR_BLACK if is_face(c) else COLOR_LIGHT
	r[1] = r[13]
	draw_gfx(f, .Sheep, x, y, false, r)
	print_glyph(f, RANKS[c.rank - 1], x + 3, y + 3, COLOR_BLACK)
}

fold_cell_xy :: proc(col, row: i32) -> (int, int) {
	return FOLD_X + int(col) * TILE, FOLD_Y + (FOLD_ROWS - 1 - int(row)) * TILE
}

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_SKY_BG)

	// Stars.
	for i in 0 ..< 48 {
		sx := (i * 97 + 13) % PANEL_X
		sy := (i * 57 + 5) % FENCE_Y
		set_px(f, sx, sy, COLOR_MID if i % 3 == 0 else COLOR_LIGHT)
	}

	print(f, "COUNTING SHEEP", 6, 6, COLOR_WHITE)
	print(f, "of SPLORR!!", 6, 16, COLOR_LIGHT)

	// The moon is the cut card for every hand.
	draw_gfx(f, .Moon, MOON_X, MOON_Y, scale = 2)
	print_glyph(f, RANKS[g.moon.rank - 1], MOON_X + 10, MOON_Y + 12, COLOR_BLACK)
	print_glyph(f, suit_glyph(g.moon.suit), MOON_X + 16, MOON_Y + 12, COLOR_BLACK)
	print(f, "the cut", MOON_X - 4, MOON_Y + 34, COLOR_MID)
	draw_board(f, g)

	// The fold.
	for col in 0 ..< i32(FOLD_COLS) {
		for row in 0 ..< i32(FOLD_ROWS) {
			x, y := fold_cell_xy(col, row)
			draw_gfx(f, .Fold, x, y)
			c := g.fold[col][row]
			if c.rank != 0 && !landing_pending(g, col, row) {
				if sleepy(g, col, row) {
					// Nodding off: eyes shut, and a z now and then.
					draw_sleeping_sheep(f, c, x, y - int(g.fall[col][row]))
					if int(g.age[col][row] * 2) % 3 == 0 {
						print_glyph(f, 'z', x + 10, y - 2, COLOR_LIGHT)
					}
				} else {
					draw_sheep(f, c, x, y - int(g.fall[col][row]), false)
				}
			}
		}
	}

	// Cleared sheep, asleep, floating up off the fold with their Zs.
	for i in 0 ..< int(g.sleeper_count) {
		s := g.sleepers[i]
		x, y := fold_cell_xy(s.col, s.row)
		p := s.t / SLEEP_TIME
		rise := int(p * 28)
		if p > 0.7 && int(s.t * 20) % 2 == 0 {
			continue // flickers out
		}
		draw_sleeping_sheep(f, s.card, x, y - rise)
		if p > 0.2 {
			print_glyph(f, 'z', x + 9, y - 4 - rise - int(p * 8), COLOR_WHITE)
		}
	}

	// Which column a sheep would go into.
	if col := fold_column(g); col >= 0 {
		x, _ := fold_cell_xy(col, 0)
		print_glyph(f, 31, x + 5, FOLD_Y - 8, COLOR_YELLOW)
		if row := landing_row(g, col); row >= 0 && g.held_count > 0 {
			cx, cy := fold_cell_xy(col, row)
			fill_rect(f, cx + 2, cy + 2, 12, 1, COLOR_YELLOW)
			fill_rect(f, cx + 2, cy + 13, 12, 1, COLOR_YELLOW)
			fill_rect(f, cx + 2, cy + 2, 1, 12, COLOR_YELLOW)
			fill_rect(f, cx + 13, cy + 2, 1, 12, COLOR_YELLOW)
		}
	}

	// The fence and the pasture.
	for x := 0; x < PANEL_X; x += TILE {
		draw_gfx(f, .Fence, x, FENCE_Y)
	}
	fill_rect(f, 0, PASTURE_Y, PANEL_X, PASTURE_ROWS * TILE, COLOR_GRASS_BG)
	grass := IDENTITY
	grass[COLOR_TEAL] = COLOR_GREEN
	for ty in 0 ..< PASTURE_ROWS {
		for tx in 0 ..< PASTURE_COLS {
			if (tx * 7 + ty * 13) % 3 == 0 {
				draw_gfx(f, .Grass, tx * TILE, PASTURE_Y + ty * TILE, (tx + ty) % 2 == 0, grass)
			}
		}
	}

	draw_gfx(f, .Nightstand, NIGHTSTAND_X * TILE, PASTURE_Y + NIGHTSTAND_Y * TILE)
	for i in 0 ..< int(g.flock_count) {
		s := g.flock[i]
		draw_sheep(f, s.card, int(s.x) * TILE, PASTURE_Y + int(s.y) * TILE, s.flip)
	}
	draw_gfx(f, .Insomniac, int(g.px) * TILE, PASTURE_Y + int(g.py) * TILE, g.flip)
	for i in 0 ..< int(g.dog_count) {
		d := g.dogs[i]
		x, y := int(d.x) * TILE, PASTURE_Y + int(d.y) * TILE
		if d.carrying {
			draw_sheep(f, d.card, x, y - 7, d.flip)
		}
		draw_gfx(f, .Sheepdog, x, y, d.flip)
	}

	// Points from hands, floating up off the fold.
	for i in 0 ..< int(g.pop_count) {
		pp := g.pops[i]
		p := pp.t / POP_TIME
		if p > 0.75 && int(pp.t * 20) % 2 == 0 {
			continue
		}
		buf: [16]u8
		text := commas(buf[1:], i64(pp.value))
		buf[0] = '+'
		text = string(buf[:len(text) + 1])
		x := FOLD_X + int(pp.col * TILE) + TILE / 2 - text_width(text) / 2
		y := FOLD_Y + int((FOLD_ROWS - 1 - pp.row) * TILE) + 4 - int(p * 24)
		fill_rect(f, x - 1, y - 1, text_width(text) + 2, GLYPH_H + 2, COLOR_BLACK)
		print(f, text, x, y, COLOR_YELLOW)
	}

	// Sheep in the air, over everything.
	for i in 0 ..< int(g.jump_count) {
		j := g.jumps[i]
		p := f64(j.t / JUMP_TIME)
		x0, y0 := f64(j.from_col * TILE), f64(PASTURE_Y)
		ex, ey := fold_cell_xy(j.col, j.row)
		x := x0 + (f64(ex) - x0) * p
		y := y0 + (f64(ey) - y0) * p - math.sin(p * math.PI) * 28
		draw_sheep(f, j.card, int(x), int(y), false)
	}

	draw_panel(f, g)
	draw_strip(f, g)
	draw_notice(f, g)
	if g.shop.open {
		draw_shop(f, g)
	}
	if g.menu.open {
		draw_menu(f, g)
	}
	if g.finished {
		draw_finish(f, g)
	}
}

BOARD_X :: 6
BOARD_Y :: 86
STAGE_Y :: 74

// The sleep stage and a 121-hole cribbage board: three rows of 40 holes, back and forth in fives,
// and the last hole at the end. The peg is the lap's points.
draw_board :: proc(f: ^Frame, g: ^Game) {
	buf: [16]u8
	w := print(f, stage_name(g.lap), BOARD_X, STAGE_Y, COLOR_WHITE)
	w += print(f, " x", BOARD_X + w, STAGE_Y, COLOR_MID)
	print(f, commas(buf[:], multiplier(g)), BOARD_X + w, STAGE_Y, COLOR_YELLOW)
	hole := peg_hole(g)
	for i in 0 ..< i32(BOARD_HOLES) {
		x, y := hole_xy(i)
		c: u8 = COLOR_MID // holes still to go
		if i < hole {
			c = COLOR_SKY // holes the peg has passed this lap
		}
		if i == hole {
			fill_rect(f, x, y - 1, 2, 2, COLOR_YELLOW)
			continue
		}
		set_px(f, x, y, c)
	}
}

hole_xy :: proc(i: i32) -> (int, int) {
	if i >= 120 {
		return BOARD_X + 89, BOARD_Y + 4
	}
	row := int(i / 40)
	k := int(i % 40)
	if row == 1 {
		k = 39 - k
	}
	return BOARD_X + k * 2 + k / 5, BOARD_Y + row * 4
}

draw_panel :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, PANEL_X, 0, SCREEN_W - PANEL_X, SCREEN_H, COLOR_PANEL)
	buf: [32]u8
	x := PANEL_X + 4
	print(f, "TO COUNT", x, 6, COLOR_LIGHT)
	print(f, commas(buf[:], sheep_to_count(g)), x, 16, COLOR_WHITE)
	print(f, "COUNTED", x, 32, COLOR_LIGHT)
	print(f, commas(buf[:], g.counted), x, 42, COLOR_WHITE)
	print(f, "ARMFUL", x, 58, COLOR_LIGHT)
	w := print(f, commas(buf[:], i64(g.held_count)), x, 68, COLOR_WHITE)
	w += print(f, "/", x + w, 68, COLOR_MID)
	print(f, commas(buf[:], i64(g.armful)), x + w, 68, COLOR_WHITE)
	print(f, "LINES", x, 84, COLOR_LIGHT)
	print(f, commas(buf[:], g.lines), x, 94, COLOR_WHITE)
	print(f, "TOP CHAIN", x, 110, COLOR_LIGHT)
	print(f, commas(buf[:], i64(g.best_chain)), x, 120, COLOR_WHITE)
	print(f, "POINTS", x, 136, COLOR_LIGHT)
	print(f, commas(buf[:], g.points), x, 146, COLOR_WHITE)
	print(f, "ZZZ", x, 162, COLOR_LIGHT)
	print(f, commas(buf[:], g.zzz), x, 172, COLOR_YELLOW)
	print(f, "COUNT BY", x, 188, COLOR_LIGHT)
	print(f, commas(buf[:], count_by(g)), x, 198, COLOR_WHITE)
}

draw_strip :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, 0, STRIP_Y, PANEL_X, SCREEN_H - STRIP_Y, COLOR_BLACK)
	x := 4
	y := STRIP_Y + 4
	x += print(f, "IN ARMS:", x, y, COLOR_LIGHT) + GLYPH_W
	if g.held_count == 0 {
		print(f, "nothing", x, y, COLOR_MID)
		return
	}
	for i in 0 ..< int(g.held_count) {
		c := g.held[i]
		col := suit_color(c.suit)
		print_glyph(f, RANKS[c.rank - 1], x, y, col)
		print_glyph(f, suit_glyph(c.suit), x + GLYPH_W, y, col)
		x += 3 * GLYPH_W
	}
}

draw_notice :: proc(f: ^Frame, g: ^Game) {
	draw_calls(f, g)
	x := CALL_X
	lines: [3]string
	color: u8 = COLOR_LIGHT
	switch g.notice {
	case .None:
		if int(g.time / 5) % 2 == 0 {
			lines = {"Walk into sheep,", "then under a pen", "press Space."}
		} else {
			lines = {"Walk into the", "nightstand to", "spend yer Zzz."}
		}
		color = COLOR_MID
	case .Stage:
		print(f, "Deeper: ", x, NOTICE_Y, COLOR_YELLOW)
		print(f, stage_name(g.lap), x + 8 * GLYPH_W, NOTICE_Y, COLOR_WHITE)
		buf: [16]u8
		w := print(f, "Zzz x", x, NOTICE_Y + 10, COLOR_YELLOW)
		print(f, commas(buf[:], multiplier(g)), x + w, NOTICE_Y + 10, COLOR_WHITE)
		print(f, "and a new moon.", x, NOTICE_Y + 20, COLOR_YELLOW)
		return
	case .Clear_Wait:
		lines = {"A sheep is still", "in the air.", ""}
	case .Clear_Empty:
		lines = {"That pen's empty.", "", ""}
	case .Took_All:
		lines = {"The clear took", "all yer Zzz.", ""}
	case .Arms_Full:
		lines = {"Yer arms are full", "", ""}
	case .Arms_Empty:
		lines = {"No sheep in arms.", "", ""}
	case .Not_Under_Fold:
		lines = {"Stand under a pen", "to send a sheep.", ""}
	case .Column_Full:
		lines = {"That pen is full.", "", ""}
	case .Line:
		buf: [16]u8
		print(f, "Four in a row!", x, NOTICE_Y, COLOR_YELLOW)
		w := print(f, "Hand for ", x, NOTICE_Y + 10, COLOR_YELLOW)
		print(f, commas(buf[:], i64(g.last_line.total)), x + w, NOTICE_Y + 10, COLOR_WHITE)
		if g.chain >= 2 {
			w = print(f, "Chain x", x, NOTICE_Y + 20, COLOR_YELLOW)
			print(f, commas(buf[:], i64(g.chain)), x + w, NOTICE_Y + 20, COLOR_WHITE)
		}
		return
	}
	if g.notice != .None {
		color = COLOR_YELLOW
	}
	for l, i in lines {
		print(f, l, x, NOTICE_Y + i * 10, color)
	}
}

NOTICE_Y :: 26
COUNT_Y :: 62

// The running count, and what the last jump scored.
draw_calls :: proc(f: ^Frame, g: ^Game) {
	buf: [16]u8
	x := CALL_X
	w := print(f, "COUNT ", x, COUNT_Y, COLOR_LIGHT)
	print(f, commas(buf[:], i64(g.pegging.count)), x + w, COUNT_Y, COLOR_WHITE)
	if g.peg_t <= 0 || g.last_peg.points == 0 {
		return
	}
	y := COUNT_Y + 10
	r := g.last_peg
	call :: proc(f: ^Frame, x: int, y: ^int, name: string, points: i32) {
		buf: [16]u8
		w := print(f, name, x, y^, COLOR_YELLOW)
		print(f, commas(buf[:], i64(points)), x + w, y^, COLOR_WHITE)
		y^ += 10
	}
	if .Go in r.calls {
		call(f, x, &y, "Go for ", 1)
	}
	if .Fifteen in r.calls {
		call(f, x, &y, "Fifteen ", 2)
	}
	if .Pair in r.calls {
		call(f, x, &y, "Pair ", 2)
	}
	if .Pair_Royal in r.calls {
		call(f, x, &y, "Pair royal ", 6)
	}
	if .Double_Pair_Royal in r.calls {
		call(f, x, &y, "Double royal ", 12)
	}
	if .Run in r.calls {
		call(f, x, &y, "Run for ", r.run)
	}
	if .Thirty_One in r.calls {
		call(f, x, &y, "Thirty-one ", 2)
	}
}

SHOP_X :: 20
SHOP_Y :: 52
SHOP_W :: PANEL_X - 2 * SHOP_X
SHOP_H :: 146
SHOP_ROW_H :: 13

// The nightstand's menu.
draw_shop :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, SHOP_X, SHOP_Y, SHOP_W, SHOP_H, COLOR_BLACK)
	fill_rect(f, SHOP_X, SHOP_Y, SHOP_W, 1, COLOR_YELLOW)
	fill_rect(f, SHOP_X, SHOP_Y + SHOP_H - 1, SHOP_W, 1, COLOR_YELLOW)
	fill_rect(f, SHOP_X, SHOP_Y, 1, SHOP_H, COLOR_YELLOW)
	fill_rect(f, SHOP_X + SHOP_W - 1, SHOP_Y, 1, SHOP_H, COLOR_YELLOW)
	x := SHOP_X + 8
	print(f, "THE NIGHTSTAND", x, SHOP_Y + 6, COLOR_YELLOW)
	buf: [32]u8
	w := print(f, "Yer Zzz: ", x + 132, SHOP_Y + 6, COLOR_LIGHT)
	print(f, commas(buf[:], g.zzz), x + 132 + w, SHOP_Y + 6, COLOR_YELLOW)

	for row in Shop_Row {
		y := SHOP_Y + 22 + int(row) * SHOP_ROW_H
		chosen := row == g.shop.row
		flashing := g.shop.flash > 0 && g.shop.flash_row == row
		if chosen {
			fill_rect(f, SHOP_X + 2, y - 3, SHOP_W - 4, SHOP_ROW_H, COLOR_RED if flashing else COLOR_NAVY)
			print_glyph(f, 16, x, y, COLOR_YELLOW)
		}
		name_x := x + 10
		detail_x := x + 106
		a, b: [16]u8
		switch row {
		case .Armful:
			print(f, "Bigger armful", name_x, y, COLOR_WHITE)
			print_upgrade(f, detail_x, y, i64(g.armful), i64(g.armful + 1), g.armful < ARMFUL_MAX)
		case .Grass:
			print(f, "Greener grass", name_x, y, COLOR_WHITE)
			print_upgrade(f, detail_x, y, i64(g.flock_target), i64(g.flock_target + GRASS_SHEEP), g.grass_level < GRASS_LEVELS)
			print(f, "sheep", detail_x + 60, y, COLOR_MID)
		case .Count_By:
			print(f, "Count by", name_x, y, COLOR_WHITE)
			more := int(g.count_level) + 1 < len(COUNT_BY)
			print_upgrade(f, detail_x, y, count_by(g), COUNT_BY[min(int(g.count_level) + 1, len(COUNT_BY) - 1)], more)
		case .Sheepdog:
			print(f, "Sheepdog", name_x, y, COLOR_WHITE)
			print_upgrade(f, detail_x, y, i64(g.dog_count), i64(g.dog_count + 1), g.dog_count < DOGS_MAX)
			print(f, "dogs", detail_x + 60, y, COLOR_MID)
		case .Dog_Speed:
			print(f, "Dog speed", name_x, y, COLOR_WHITE)
			if g.dog_count == 0 {
				print(f, "no dog yet", detail_x, y, COLOR_MID)
			} else {
				print_upgrade(f, detail_x, y, i64(g.dog_speed_level) + 1, i64(g.dog_speed_level) + 2, g.dog_speed_level < DOG_SPEED_LEVELS)
			}
		case .Clear:
			print(f, "Clear a pen", name_x, y, COLOR_WHITE)
			cw := print(f, "< pen ", detail_x, y, COLOR_LIGHT)
			cw += print(f, commas(a[:], i64(g.shop.col) + 1), detail_x + cw, y, COLOR_WHITE)
			print(f, " >", detail_x + cw, y, COLOR_LIGHT)
		case .Leave:
			print(f, "Leave", name_x, y, COLOR_WHITE)
		}
		if cost, ok := price(g, row); ok {
			text := commas(b[:], cost)
			c: u8 = COLOR_YELLOW if g.zzz >= cost else COLOR_MID
			print(f, text, SHOP_X + SHOP_W - 8 - text_width(text), y, c)
		} else if row != .Leave && !(row == .Dog_Speed && g.dog_count == 0) {
			print(f, "MAX", SHOP_X + SHOP_W - 8 - text_width("MAX"), y, COLOR_MID)
		}
	}
	if g.shop.row == .Clear {
		// Show which pen a clear takes.
		cx, _ := fold_cell_xy(g.shop.col, 0)
		print_glyph(f, 31, cx + 5, FOLD_Y - 8, COLOR_RED)
		cost, _ := price(g, .Clear)
		if g.zzz < cost && fold_full(g) {
			print(f, "The fold is full: a clear takes all yer Zzz.", x, SHOP_Y + 22 + len(Shop_Row) * SHOP_ROW_H + 2, COLOR_RED)
		}
	}
	print(f, "Up/Down choose, Space buy, Esc leave", x, SHOP_Y + SHOP_H - 14, COLOR_MID)
}

print_upgrade :: proc(f: ^Frame, x, y: int, now, next: i64, more: bool) {
	a, b: [16]u8
	w := print(f, commas(a[:], now), x, y, COLOR_LIGHT)
	if more {
		w += print(f, " > ", x + w, y, COLOR_MID)
		print(f, commas(b[:], next), x + w, y, COLOR_WHITE)
	}
}

// h:mm:ss
clock :: proc(buf: []u8, seconds: f64) -> string {
	s := i64(seconds)
	h, m, sec := s / 3600, s / 60 % 60, s % 60
	n := 0
	a: [16]u8
	for ch in transmute([]u8)commas(a[:], h) {
		buf[n] = ch
		n += 1
	}
	buf[n] = ':'
	buf[n + 1] = u8('0' + m / 10)
	buf[n + 2] = u8('0' + m % 10)
	buf[n + 3] = ':'
	buf[n + 4] = u8('0' + sec / 10)
	buf[n + 5] = u8('0' + sec % 10)
	return string(buf[:n + 6])
}

// The millionth sheep: the insomniac is asleep. The night's totals, the bests, and a new night.
draw_finish :: proc(f: ^Frame, g: ^Game) {
	fill_rect(f, 0, 0, PANEL_X, SCREEN_H, COLOR_BLACK)
	for i in 0 ..< 64 {
		set_px(f, (i * 97 + 13) % PANEL_X, (i * 57 + 5) % SCREEN_H, COLOR_DARK if i % 2 == 0 else COLOR_MID)
	}
	centre :: proc(f: ^Frame, text: string, y: int, c: u8) {
		print(f, text, PANEL_X / 2 - text_width(text) / 2, y, c)
	}
	centre(f, "THE MILLIONTH SHEEP.", 18, COLOR_YELLOW)
	draw_gfx(f, .Insomniac, PANEL_X / 2 - TILE, 32, scale = 2)
	centre(f, "Out like a light. Zzz...", 70, COLOR_WHITE)

	row :: proc(f: ^Frame, y: int, label, value: string) {
		print(f, label, 70, y, COLOR_LIGHT)
		print(f, value, 250 - text_width(value), y, COLOR_WHITE)
	}
	buf: [32]u8
	stage: [32]u8
	n := copy(stage[:], stage_name(g.lap))
	if c := stage_cycle(g.lap); c > 0 {
		n += copy(stage[n:], ", cycle ")
		a: [16]u8
		n += copy(stage[n:], commas(a[:], i64(c)))
	}
	row(f, 88, "Time asleep", clock(buf[:], g.finish_time))
	row(f, 98, "Points", commas(buf[:], g.points))
	row(f, 108, "Best hand", commas(buf[:], i64(g.best_hand)))
	row(f, 118, "Top chain", commas(buf[:], i64(g.best_chain)))
	row(f, 128, "Deepest stage", string(stage[:n]))

	b := g.bests
	centre(f, "BESTS, ALL NIGHTS", 146, COLOR_YELLOW)
	row(f, 158, "Fastest night", clock(buf[:], b.fastest))
	row(f, 168, "Most points", commas(buf[:], b.points))
	row(f, 178, "Best hand", commas(buf[:], i64(b.hand)))
	if g.finish_t >= FINISH_PAUSE && int(g.finish_t * 2) % 2 == 0 {
		centre(f, "Space: a new night", 198, COLOR_YELLOW)
	}
}

// The Esc menu, and the "start over?" question.
draw_menu :: proc(f: ^Frame, g: ^Game) {
	X :: 90
	Y :: 70
	W :: 140
	H :: 62
	m := g.menu
	box :: proc(f: ^Frame, x, y, w, h: int, edge: u8) {
		fill_rect(f, x, y, w, h, COLOR_BLACK)
		fill_rect(f, x, y, w, 1, edge)
		fill_rect(f, x, y + h - 1, w, 1, edge)
		fill_rect(f, x, y, 1, h, edge)
		fill_rect(f, x + w - 1, y, 1, h, edge)
	}
	if m.confirm {
		box(f, X - 40, Y - 6, W + 80, H + 20, COLOR_RED)
		print(f, "START OVER?", X - 32, Y, COLOR_RED)
		print(f, "This night's sheep, points,", X - 32, Y + 14, COLOR_WHITE)
		print(f, "Zzz and dogs are all lost.", X - 32, Y + 24, COLOR_WHITE)
		print(f, "The bests of past nights stay.", X - 32, Y + 34, COLOR_LIGHT)
		opts := [2]string{"No", "Yes, start over"}
		for o, i in opts {
			y := Y + 50 + i * 10
			chosen := (i == 1) == m.yes
			if chosen {
				print_glyph(f, 16, X - 32, y, COLOR_YELLOW)
			}
			print(f, o, X - 22, y, COLOR_YELLOW if chosen else COLOR_MID)
		}
		return
	}
	box(f, X, Y, W, H, COLOR_YELLOW)
	print(f, "ZZZ... MENU", X + 8, Y + 6, COLOR_YELLOW)
	for row in Menu_Row {
		y := Y + 20 + int(row) * 12
		chosen := row == m.row
		if chosen {
			print_glyph(f, 16, X + 8, y, COLOR_YELLOW)
		}
		c: u8 = COLOR_WHITE if chosen else COLOR_LIGHT
		switch row {
		case .Carry_On:
			print(f, "Carry on", X + 18, y, c)
		case .Sound:
			print(f, "Sound: off" if g.muted else "Sound: on", X + 18, y, c)
		case .Start_Over:
			print(f, "Start over", X + 18, y, c)
		}
	}
}
