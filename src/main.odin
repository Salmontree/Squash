package main

import "core:log"
import "window"

main :: proc() {
	context.logger = log.create_console_logger()

	win, _ := window.create_default_window(1280, 720, "hi")

	for !window.should_quit(win) {
		window.poll_events(win)
		window.clear_screen(win)
		window.present_screen(win)
	}

	window.destroy_window(win)
}
