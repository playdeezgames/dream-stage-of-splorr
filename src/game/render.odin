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

	// The fold.
	for col in 0 ..< i32(FOLD_COLS) {
		for row in 0 ..< i32(FOLD_ROWS) {
			x, y := fold_cell_xy(col, row)
			draw_gfx(f, .Fold, x, y)
			c := g.fold[col][row]
			if c.rank != 0 && !landing_pending(g, col, row) {
				draw_sheep(f, c, x, y - int(g.fall[col][row]), false)
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

	for i in 0 ..< int(g.flock_count) {
		s := g.flock[i]
		draw_sheep(f, s.card, int(s.x) * TILE, PASTURE_Y + int(s.y) * TILE, s.flip)
	}
	draw_gfx(f, .Insomniac, int(g.px) * TILE, PASTURE_Y + int(g.py) * TILE, g.flip)

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
	x := FOLD_X + FOLD_COLS * TILE + 6
	lines: [3]string
	color: u8 = COLOR_LIGHT
	switch g.notice {
	case .None:
		lines = {"Walk into sheep,", "then under a pen", "press Space."}
		color = COLOR_MID
	case .Arms_Full:
		lines = {"Yer arms are full", "", ""}
	case .Arms_Empty:
		lines = {"No sheep in arms.", "", ""}
	case .Not_Under_Fold:
		lines = {"Stand under a pen", "to send a sheep.", ""}
	case .Column_Full:
		lines = {"That pen is full.", "", ""}
	case .Line:
		lines = {"Four in a row!", "Sweet dreams.", ""}
		if g.chain >= 2 {
			buf: [16]u8
			lines[1] = "Chain x"
			lines[2] = commas(buf[:], i64(g.chain))
			print(f, lines[0], x, 40, COLOR_YELLOW)
			w := print(f, lines[1], x, 50, COLOR_YELLOW)
			print(f, lines[2], x + w, 50, COLOR_YELLOW)
			return
		}
	}
	if g.notice != .None {
		color = COLOR_YELLOW
	}
	for l, i in lines {
		print(f, l, x, 40 + i * 10, color)
	}
}
