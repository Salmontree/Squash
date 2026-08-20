package assets

import "core:strings"
import "core:os"

scaffold_all_paths := proc() {
	os.make_directory_all(get_path("mods", context.temp_allocator))
	os.make_directory_all(get_path("resources", context.temp_allocator))
	os.make_directory_all(get_path("config", context.temp_allocator))
}

get_data_path :: proc(allocator := context.allocator) -> string {
	dir, _ := os.user_data_dir(allocator)
	return strings.concatenate({dir, "/squash"}, allocator)
}

get_path :: proc(path: string, allocator := context.allocator) -> string {
	return strings.concatenate({ get_data_path(), "/", path }, allocator)
}