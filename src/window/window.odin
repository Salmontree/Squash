package window

import "backends"

Window :: backends.Window

create_default_window :: proc(width: uint, height: uint, title: string) -> (Window, bool) {
	window, success := backends.sdl3_create_window(width, height, title)
	if success { return window, true }

	return Window{}, false
}

destroy_window :: proc(window: Window) {
	window.vtable.destroy_window(window.data)
}

poll_events :: proc(window: Window) {
	window.vtable.poll_events(window.data)
}

clear_screen :: proc(window: Window) {
	window.vtable.clear_screen(window.data)
}

present_screen :: proc(window: Window) {
	window.vtable.present_screen(window.data)
}

should_quit :: proc(window: Window) -> bool {
	return window.vtable.should_quit(window.data)
}