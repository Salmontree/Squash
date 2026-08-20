package main

import "core:fmt"
import "src:assets"
import "core:log"
import "src:window"

main :: proc() {
	context.logger = log.create_console_logger(lowest = .Debug when ODIN_DEBUG else .Info, opt = { .Level, .Terminal_Color, .Date, .Time, .Short_File_Path, .Line, .Thread_Id } when ODIN_DEBUG else { .Level, .Terminal_Color, .Date, .Time })
	defer log.destroy_console_logger(context.logger)

	log.error("hi")

	win, ok := window.create_window(1280, 720, "aeidfhr")
	defer win->destroy()
	if !ok do log.fatal("Couldn't create window")

	assets.init()
	defer assets.quit()

	for !win->should_quit() {
		win->present_screen()
		win->poll_events()
		free_all(context.temp_allocator)
	}
}
