package assets

import "core:fmt"
import "lib:toml"

Options :: struct {
	video: struct {
		fps: int,
		fov: int,
	},

	audio: struct {
		volume: struct {
			master: f32,
		}
	},
}

default_options :: Options {
	video = {
		fps = 0,
		fov = 90
	},

	audio = {
		volume = {
			master = 1.0
		}
	}
}

options: Options

load_options :: proc() {
	defer free_all(context.temp_allocator)
	
	table, err := toml.parse_file(get_path_in_data("resources/options.toml") or_else "", context.temp_allocator)
	if toml.unmarshal_table(options, table) == toml.Unmarshal_Error.None do return
	
	options = default_options
}

save_options :: proc() {

}