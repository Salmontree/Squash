package main

import "core:log"
import "window"

main :: proc() {
	context.logger = log.create_console_logger()

	win, ok := window.create_window(1280, 720, "aeidfhr")
	if !ok do log.fatal("Couldn't create window")

	for !win->should_quit() {
		win->present_screen()
		win->poll_events()
	}
	
	win->destroy()
}
