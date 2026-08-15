package main

import "core:fmt"
import "core:log"
import "window"
import "client"
import "assets"

main :: proc() {
	context.logger = log.create_console_logger()

	win, _ := window.create_default_window(1280, 720, "hi")
	defer window.destroy_window(win)

	assets.scaffold_default_paths()
	assets.load_options()

	fmt.println(assets.options)

	// conn, err := client.connect("localhost:25565")
	// if err != nil { fmt.printfln("{}", err) }
	// defer client.close(conn)

	for !window.should_quit(win) {
		window.poll_events(win)
		window.clear_screen(win)
		window.present_screen(win)
	}
}
