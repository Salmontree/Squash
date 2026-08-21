package renderer

import "src:assets"
import "core:log"
import gl "vendor:OpenGL"

@(private)
state: struct {
	vao, vbo, ebo: u32
}

init :: proc() {
	log.info("Initializing renderer")

	vertices := [?]f32 {
		0.5,  0.5, 0.0, 
		0.5, -0.5, 0.0,
		-0.5, -0.5, 0.0,
		-0.5,  0.5, 0.0,
	}

	indices := [?]u32 {
		0, 1, 3,
		1, 2, 3,
	}

	gl.GenVertexArrays(1, &state.vao)
	gl.GenBuffers(1, &state.vbo)
	gl.GenBuffers(1, &state.ebo)

	gl.BindVertexArray(state.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(&vertices), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, state.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), raw_data(&indices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
}

frame :: proc() {
	gl.ClearColor(0.05, 0.05, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	assets.get_unsafe(assets.Shader, "a")->use()
	gl.BindVertexArray(state.vao)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}

free :: proc() {
	log.info("Destroying renderer")
	gl.DeleteVertexArrays(1, &state.vao)
	gl.DeleteBuffers(1, &state.vbo)
	gl.DeleteBuffers(1, &state.ebo)
}