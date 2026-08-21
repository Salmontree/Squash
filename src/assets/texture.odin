package assets

import "core:strings"
import "core:path/filepath"
import "core:log"
import "core:os"
import stbi "vendor:stb/image"

Texture :: struct {
	pixels: [^]byte,
	width, height, channels: i32
}

@(private)
texture_init :: proc() -> (ok: bool) {
	// Read block textures
	files, err := os.read_directory_by_path(get_path("resources/textures/blocks", context.temp_allocator), 0, context.temp_allocator)
	if err != nil && err != os.ERROR_NONE { log.error(err); return false }

	ok = true

	for file in files {
		if strings.ends_with(file.name, ".mcmeta") do continue
		if !load(Texture, strings.concatenate({ "minecraft:texture/block/", filepath.stem(file.name) }, context.temp_allocator), file.fullpath) { ok = false; continue }
	}

	return ok
}

@(private)
texture_load :: proc(files: ..string) -> (asset: ^Texture, ok: bool) {
	if len(files) != 1 do return nil, false
	filepath := files[0]

	asset = new(Texture)
	if asset == nil do return nil, false

	asset.pixels = stbi.load(strings.clone_to_cstring(filepath, context.temp_allocator), &asset.width, &asset.height, &asset.channels, 4)
	if asset.pixels == nil {
		log.debug("Couldn't load texture", filepath, "because:", stbi.failure_reason())
		free(asset)
		return nil, false
	}

	return asset, true
}

@(private)
texture_destroy :: proc(asset: ^Texture) {
	stbi.image_free(asset.pixels)
	free(asset)
}