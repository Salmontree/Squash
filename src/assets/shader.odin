package assets

import "vendor:sdl3"
import "core:log"
import "core:os"
import "core:strings"
import gl "vendor:OpenGL"

Shader :: struct {
	id: u32,

	use: proc(shader: ^Shader)
}

@(private)
shader_init :: proc() -> (ok: bool) {
	return true
}

@(private)
shader_load :: proc(files: ..string) -> (asset: ^Shader, ok: bool) {
	if len(files) != 1 do return nil, false

	prgsrc, err10293 := os.read_entire_file(files[0], context.temp_allocator)
	if err10293 != nil do return nil, false
	shaders, err0 := strings.split(string(prgsrc), ",", context.temp_allocator)
	if err0 != nil || len(shaders) != 2 do return nil, false

	sh1type: u32 = gl.VERTEX_SHADER if strings.ends_with(shaders[0], ".vert") else gl.FRAGMENT_SHADER
	sh2type: u32 = gl.FRAGMENT_SHADER if strings.ends_with(shaders[1], ".frag") else gl.VERTEX_SHADER
	if sh1type == sh2type do return nil, false

	success: i32

	sh1 := gl.CreateShader(sh1type); defer gl.DeleteShader(sh1)
	_sh1s, err := os.read_entire_file(get_path(strings.concatenate({ "resources/shaders/", shaders[0] }, context.temp_allocator), context.temp_allocator), context.temp_allocator); if err != nil && err != os.ERROR_NONE do return nil, false;
	sh1s, err2 := strings.clone_to_cstring(string(_sh1s), context.temp_allocator); if err2 != nil && err2 != os.ERROR_NONE do return nil, false
	gl.ShaderSource(sh1, 1, &sh1s, nil)
	gl.CompileShader(sh1)
	gl.GetShaderiv(sh1, gl.COMPILE_STATUS, &success); if success != 1 do return nil, false

	sh2 := gl.CreateShader(sh2type); defer gl.DeleteShader(sh2)
	_sh2s, err3 := os.read_entire_file(get_path(strings.concatenate({ "resources/shaders/", shaders[1] }, context.temp_allocator), context.temp_allocator), context.temp_allocator); if err3 != nil && err3 != os.ERROR_NONE do return nil, false
	sh2s, err4 := strings.clone_to_cstring(string(_sh2s), context.temp_allocator); if err4 != nil && err4 != os.ERROR_NONE do return nil, false
	gl.ShaderSource(sh2, 1, &sh2s, nil)
	gl.CompileShader(sh2)
	gl.GetShaderiv(sh2, gl.COMPILE_STATUS, &success); if success != 1 do return nil, false

	program := gl.CreateProgram()
	gl.AttachShader(program, sh1); gl.AttachShader(program, sh2)
	gl.LinkProgram(program)
	gl.GetProgramiv(program, gl.LINK_STATUS, &success); if success != 1 { gl.DeleteProgram(program); return nil, false }

	asset = new(Shader)
	asset.id = program
	asset.use = proc(shader: ^Shader) { gl.UseProgram(shader.id) }
	return asset, true
}

@(private)
shader_destroy :: proc(asset: ^Shader) {
	gl.DeleteProgram(asset.id)
	free(asset)
}