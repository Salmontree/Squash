package assets

import "core:fmt"
import "core:strings"
import "core:os"

@(private="file")
_load_resourcepack :: proc(path: string) {

}

@(private="file")
_scan_dir :: proc(path: string) {
	if data, err := os.read_entire_file(strings.concatenate({ path, "/pack.mcmeta" }, context.temp_allocator), context.temp_allocator); err == os.ERROR_NONE || err == nil {
		
	}
}

load_resourcepacks :: proc() {
	_scan_dir(get_path(strings.concatenate({"resources/default_resourcepack"}, context.temp_allocator), context.temp_allocator))
	for pack in get_unsafe(Options, "options").video.resourcepacks do _scan_dir(get_path(strings.concatenate({"resourcepacks/", pack}, context.temp_allocator), context.temp_allocator))
}