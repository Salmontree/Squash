package main

import "src:world/ecs"
import "src:renderer"
import "core:strings"
import "core:os"
import "core:time"
import "src:assets"
import "core:log"
import "src:window"

main :: proc() {
	context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Info, { .Level, .Terminal_Color, .Short_File_Path, .Line } when ODIN_DEBUG else { .Level, .Terminal_Color, .Date, .Time })
	
	assets.scaffold_all_paths() // make sure the 'logs' directory exists
	file_logger: log.Logger
	if log_file, err := os.create(assets.get_path(strings.concatenate({ "logs/", time.to_string_mm_dd_yy(time.now(), make([]u8, 16, context.temp_allocator)), " -- ", time.to_string_hms(time.now(), make([]u8, 16, context.temp_allocator)), ".log" }), context.temp_allocator)); err == nil || err == os.ERROR_NONE do file_logger = log.create_file_logger(log_file, .Debug when ODIN_DEBUG else .Info, { .Level, .Date, .Time })
	else do log.error("Couldn't create log file")
	
	context.logger = log.create_multi_logger(context.logger, file_logger) if file_logger != {} else log.create_multi_logger(context.logger)
	defer log.destroy_multi_logger(context.logger)

	log.info("Starting up...")

	win, ok := window.create_window(1280, 720, "Strawberry")
	defer win->destroy()
	if !ok { log.fatal("Couldn't create window"); os.exit(-1); }

	assets.init()
	defer assets.quit()

	renderer.init()
	defer renderer.free()

	ecs.init()
	defer ecs.deinit()

	if !assets.load(assets.Shader, "a", assets.get_path("resources/shaders/asdf.prog", context.temp_allocator)) do log.error("nope")

	for !win->should_quit() {
		renderer.frame()
		win->present_screen()
		win->poll_events()
		free_all(context.temp_allocator)
	}

	log.info("Shutting down...")
}
