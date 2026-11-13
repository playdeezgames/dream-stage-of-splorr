package game

// The Esc menu, out in the pasture: carry on, sound on or off, and starting over (after a warning,
// with No chosen first). Starting over keeps the bests of finished nights.

Menu_Row :: enum u8 {
	Carry_On,
	Sound,
	Start_Over,
}

Menu :: struct {
	open:    bool,
	row:     Menu_Row,
	confirm: bool, // the "start over?" question is up
	yes:     bool, // Yes chosen in it (No is first)
}

open_menu :: proc(g: ^Game) {
	g.menu = {open = true}
	play(g, .Open)
}

menu_command :: proc(g: ^Game, c: Command) {
	m := &g.menu
	if m.confirm {
		switch c {
		case .North, .South, .West, .East:
			m.yes = !m.yes
		case .Ok:
			if m.yes {
				start_over(g)
				return
			}
			m.confirm = false
		case .Cancel:
			m.confirm = false
		}
		return
	}
	switch c {
	case .North:
		m.row = Menu_Row((int(m.row) + len(Menu_Row) - 1) % len(Menu_Row))
	case .South:
		m.row = Menu_Row((int(m.row) + 1) % len(Menu_Row))
	case .West, .East:
	case .Ok:
		switch m.row {
		case .Carry_On:
			m.open = false
			play(g, .Close)
		case .Sound:
			g.muted = !g.muted
			play(g, .Buy)
		case .Start_Over:
			m.confirm = true
			m.yes = false
		}
	case .Cancel:
		m.open = false
		play(g, .Close)
	}
}

// A fresh night now. Everything of this night is lost; the bests of finished nights and the sound
// setting stay.
start_over :: proc(g: ^Game) {
	new_night(g)
	play(g, .Close)
}
