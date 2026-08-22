#+private
package window

import "core:strings"
import "core:log"
import "vendor:sdl3"
import gl "vendor:OpenGL"

SDL3State :: struct {
	window: ^sdl3.Window,
	ctx: sdl3.GLContext,
	should_quit: bool
}

sdl3_create_window :: proc(width: int, height: int, title: string) -> (window: Window, ok: bool) {
	if !sdl3.Init({.VIDEO}) do return {}, false
	state := new(SDL3State); if state == nil do return {}, false

	sdl3.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl3.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	sdl3.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl3.GLProfile.CORE))

	if state.window = sdl3.CreateWindow(strings.clone_to_cstring(title, context.temp_allocator), i32(width), i32(height), { .RESIZABLE, .OPENGL }); state.window == nil do return {}, false
	sdl3.SetWindowMinimumSize(state.window, 720, 480)
	state.ctx = sdl3.GL_CreateContext(state.window); sdl3.GL_MakeCurrent(state.window, state.ctx)
	state.should_quit = false

	gl.load_up_to(3, 3, sdl3.gl_set_proc_address)

	w, h: i32; sdl3.GetWindowSizeInPixels(state.window, &w, &h)
	gl.Viewport(0, 0, w, h)

	return {
		state=state,

		destroy = proc(window: Window) {
			log.info("Destroying window")
			state := (^SDL3State)(window.state)
			sdl3.GL_DestroyContext(state.ctx)
			sdl3.DestroyWindow(state.window)
			sdl3.Quit()
			free(state)
		},

		poll_events = proc(window: Window) {
			state := (^SDL3State)(window.state)
			event: sdl3.Event
			for sdl3.PollEvent(&event) {
				#partial switch event.type {
					case .QUIT: state.should_quit = true
					case .WINDOW_RESIZED:
						w, h: i32; sdl3.GetWindowSizeInPixels(state.window, &w, &h)
						gl.Viewport(0, 0, w, h)
				}
			}
		},

		present_screen = proc(window: Window) {
			state := (^SDL3State)(window.state)
			sdl3.GL_SwapWindow(state.window)
		},

		should_quit = proc(window: Window) -> bool {
			state := (^SDL3State)(window.state)
			return state.should_quit
		},
	}, true
}