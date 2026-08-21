package assets

import "core:os"
import "core:log"
import "core:strings"
import "core:path/filepath"

Shader :: struct {
	src: []byte
}

shader_init :: proc() -> (ok: bool) {
	files, err := os.read_directory_by_path(get_path("resources/shaders", context.temp_allocator), 0, context.temp_allocator)
	if err != nil && err != os.ERROR_NONE { log.error(err); return false }

	ok = true

	for file in files {
		if !load(Texture, strings.concatenate({ "minecraft:shader/", filepath.stem(file.name) }, context.temp_allocator), file.fullpath) { ok = false; continue }
	}

	return ok
}

shader_load :: proc(files: ..string) -> (asset: ^Shader, ok: bool) {
	if len(files) != 1 do return nil, false
	filepath := files[0]

	src, err := os.read_entire_file(filepath, context.allocator)
	if err != nil && err != os.ERROR_NONE do return nil, false
	
	asset = new(Shader)
	asset.src = src
	return asset, true
}

shader_destroy :: proc(asset: ^Shader) {
	delete(asset.src)
	free(asset)
}