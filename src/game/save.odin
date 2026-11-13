package game

// Saves: the whole Game as raw bytes behind a small header. A save from another build (another
// version or size) is not loaded, and the page starts a fresh night instead; a save that loads is
// checked field by field first, so a damaged one cannot put the game in a broken state.

SAVE_MAGIC :: u32(0x5353_4F43) // "COSS"
SAVE_VERSION :: u32(2) // 2: lap_points (November 13, 2026)

Save_Header :: struct {
	magic:   u32,
	version: u32,
	size:    u32,
}

SAVE_CAP :: size_of(Save_Header) + size_of(Game)

save_game :: proc(g: ^Game, out: []u8) -> int {
	if len(out) < SAVE_CAP {
		return 0
	}
	h := Save_Header{SAVE_MAGIC, SAVE_VERSION, u32(size_of(Game))}
	copy(out, (cast([^]u8)&h)[:size_of(Save_Header)])
	copy(out[size_of(Save_Header):], (cast([^]u8)g)[:size_of(Game)])
	return SAVE_CAP
}

load_game :: proc(g: ^Game, data: []u8) -> bool {
	if len(data) != SAVE_CAP {
		return false
	}
	h: Save_Header
	copy((cast([^]u8)&h)[:size_of(Save_Header)], data)
	if h.magic != SAVE_MAGIC || h.version != SAVE_VERSION || h.size != u32(size_of(Game)) {
		return false
	}
	tmp := new(Game)
	defer free(tmp)
	copy((cast([^]u8)tmp)[:size_of(Game)], data[size_of(Save_Header):])
	if !save_is_sane(tmp) {
		return false
	}
	g^ = tmp^
	g.sound_count = 0
	return true
}

card_ok :: proc(c: Card, may_be_empty: bool) -> bool {
	if c.rank == 0 {
		return may_be_empty
	}
	return c.rank <= 13 && u8(c.suit) <= u8(max(Suit))
}

save_is_sane :: proc(g: ^Game) -> bool {
	if !in_pasture(g.px, g.py) || is_nightstand(g.px, g.py) {
		return false
	}
	if g.armful < ARMFUL_START || g.armful > ARMFUL_MAX || g.held_count < 0 || g.held_count > g.armful {
		return false
	}
	if g.flock_count < 0 || g.flock_count > FLOCK_MAX || g.flock_target < FLOCK_TARGET || g.flock_target > FLOCK_MAX {
		return false
	}
	if g.jump_count < 0 || g.jump_count > JUMPS_MAX || g.sleeper_count < 0 || g.sleeper_count > SLEEPERS_MAX {
		return false
	}
	if g.pop_count < 0 || g.pop_count > POPS_MAX || g.dog_count < 0 || g.dog_count > DOGS_MAX {
		return false
	}
	if g.count_level < 0 || int(g.count_level) >= len(COUNT_BY) || g.grass_level < 0 || g.grass_level > GRASS_LEVELS {
		return false
	}
	if g.dog_speed_level < 0 || g.dog_speed_level > DOG_SPEED_LEVELS || g.lap < 0 || g.zzz < 0 || g.points < 0 || g.lap_points < 0 {
		return false
	}
	if g.counted < 0 || g.counted > TOTAL_SHEEP || g.pegging.count < 0 || g.pegging.count > 31 {
		return false
	}
	if g.pegging.len < 0 || g.pegging.len > PEG_SEQ_MAX {
		return false
	}
	if u8(g.shop.row) > u8(max(Shop_Row)) || g.shop.col < 0 || g.shop.col >= FOLD_COLS {
		return false
	}
	if u8(g.notice) > u8(max(Notice)) || u8(g.menu.row) > u8(max(Menu_Row)) {
		return false
	}
	if !card_ok(g.moon, false) {
		return false
	}
	for i in 0 ..< int(g.held_count) {
		if !card_ok(g.held[i], false) {
			return false
		}
	}
	for i in 0 ..< int(g.flock_count) {
		s := g.flock[i]
		if !card_ok(s.card, false) || !in_pasture(s.x, s.y) {
			return false
		}
	}
	for col in 0 ..< FOLD_COLS {
		for row in 0 ..< FOLD_ROWS {
			if !card_ok(g.fold[col][row], true) {
				return false
			}
		}
	}
	for i in 0 ..< int(g.jump_count) {
		j := g.jumps[i]
		if !card_ok(j.card, false) || j.col < 0 || j.col >= FOLD_COLS || j.row < 0 || j.row >= FOLD_ROWS {
			return false
		}
	}
	for i in 0 ..< int(g.sleeper_count) {
		s := g.sleepers[i]
		if s.col < 0 || s.col >= FOLD_COLS || s.row < 0 || s.row >= FOLD_ROWS || !card_ok(s.card, false) {
			return false
		}
	}
	for i in 0 ..< int(g.dog_count) {
		d := g.dogs[i]
		if !in_pasture(d.x, d.y) || d.plan < -1 || d.plan >= FOLD_COLS || !card_ok(d.card, !d.carrying) {
			return false
		}
	}
	return true
}
