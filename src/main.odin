package main

import "core:fmt"
import "src:assets"
import "core:log"
import "src:window"

main :: proc() {
	context.logger = log.create_console_logger()

	win, ok := window.create_window(1280, 720, "aeidfhr")
	defer win->destroy()
	if !ok do log.fatal("Couldn't create window")

	assets.init()
	defer assets.quit()

	assets.load_resourcepacks()

	for !win->should_quit() {
		win->present_screen()
		win->poll_events()
		free_all(context.temp_allocator)
	}
}
