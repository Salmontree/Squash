#+private
package window

import "core:c"
import "core:strings"
import "vendor:sdl3"

SDL3State :: struct {
	window: ^sdl3.Window,
	renderer: ^sdl3.Renderer,
	should_quit: bool
}

sdl3_create_window :: proc(width: int, height: int, title: string) -> (window: Window, ok: bool) {
	if !sdl3.Init({.VIDEO}) do return {}, false
	state := new(SDL3State); if state == nil do return {}, false

	if !sdl3.CreateWindowAndRenderer(strings.clone_to_cstring(title, context.temp_allocator) or_else "", c.int(width), c.int(height), {.RESIZABLE}, &state.window, &state.renderer) do return {}, false
	state.should_quit = false

	return {
		state=state,

		destroy = proc(window: Window) {
			state := (^SDL3State)(window.state)
			sdl3.DestroyRenderer(state.renderer)
			sdl3.DestroyWindow(state.window)
			sdl3.Quit()
			free(state)
		},

		poll_events = proc(window: Window) {
			state := (^SDL3State)(window.state)
			event: sdl3.Event
			for sdl3.PollEvent(&event) {
				if event.type == .QUIT do state.should_quit = true
			}
		},

		present_screen = proc(window: Window) {
			state := (^SDL3State)(window.state)
			sdl3.SetRenderDrawColorFloat(state.renderer, 0.05, 0.05, 0.1, 1.0)
			sdl3.RenderClear(state.renderer)
			sdl3.RenderPresent(state.renderer)
		},

		should_quit = proc(window: Window) -> bool {
			state := (^SDL3State)(window.state)
			return state.should_quit
		},
	}, true
}