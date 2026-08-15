package assets

import "core:fmt"
import "core:strings"
import "core:os"

scaffold_default_paths :: proc() {
	path, _ := get_path_in_data("resources"); os.make_directory_all(path);
	path, _  = get_path_in_data("resourcepacks"); os.make_directory_all(path)
	path, _  = get_path_in_data("mods"); os.make_directory_all(path)

	free_all(context.temp_allocator)
}

get_path_in_data :: proc(path: string, allocator := context.temp_allocator) -> (string, bool) {
	dpath, err := os.user_data_dir(allocator)
	defer delete(dpath, allocator)

	if err == nil { return strings.concatenate({dpath, "/squash/", path}, allocator), true }
	else { return "", false }
}