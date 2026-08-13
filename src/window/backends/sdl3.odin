package backends

import "core:strings"
import "base:runtime"
import "vendor:sdl3"

Data :: struct {
	window: ^sdl3.Window,
	renderer: ^sdl3.Renderer,
	allocator: runtime.Allocator,

	should_quit: bool
}

sdl3_create_window :: proc(width: uint, height: uint, title: string, allocator := context.allocator) -> (Window, bool) {
	data := new(Data, allocator)
	
	if !sdl3.Init({.VIDEO, .EVENTS}) { return Window{}, false }

	sdl3.CreateWindowAndRenderer(strings.clone_to_cstring(title, context.temp_allocator), i32(width), i32(height), {.RESIZABLE}, &data.window, &data.renderer)
	data.allocator = allocator
	data.should_quit = false

	return Window {
		vtable = {
			destroy_window = sdl3_destroy_window,
			poll_events = sdl3_poll_events,
			clear_screen = sdl3_clear_screen,
			present_screen = sdl3_present_screen,
			should_quit = sdl3_should_quit,
		},
		data = data,
	}, true
}

sdl3_destroy_window :: proc(rawdata: rawptr) {
	data := (^Data)(rawdata)

	sdl3.DestroyWindow(data.window)
	sdl3.DestroyRenderer(data.renderer)
	sdl3.Quit()

	free(rawdata, data.allocator)
}

sdl3_poll_events :: proc(rawdata: rawptr) {
	data := (^Data)(rawdata)

	event: sdl3.Event
	for sdl3.PollEvent(&event) {
		if event.type == .QUIT {
			data.should_quit = true
		}
	}
}

sdl3_clear_screen :: proc(rawdata: rawptr) {
	data := (^Data)(rawdata)
	sdl3.SetRenderDrawColorFloat(data.renderer, 0.05, 0.05, 0.1, 1.0)
	sdl3.RenderClear(data.renderer)
}
sdl3_present_screen :: proc(rawdata: rawptr) {
	data := (^Data)(rawdata)
	sdl3.RenderPresent(data.renderer)
}
sdl3_should_quit :: proc(rawdata: rawptr) -> bool {
	data := (^Data)(rawdata)
	return data.should_quit
}