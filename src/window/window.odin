package window

import "core:log"

Window :: struct {
	state: rawptr,

	destroy: proc(window: Window),
	poll_events: proc(window: Window),
	present_screen: proc(window: Window),
	should_quit: proc(window: Window) -> bool
}

create_window :: proc(width: int, height: int, title: string) -> (window: Window, ok: bool) {
	log.info("Creating SDL3 window"); window, ok = sdl3_create_window(width, height, title); if ok do return window, true
	return {}, false
}