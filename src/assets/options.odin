package assets

import "core:os"
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
	defer free_all(context.temp_allocator)

	_ = os.write_entire_file_from_string(get_path_in_data("resources/options.toml") or_else "", fmt.tprintf("[video]\nfps = {}\nfov = {}\n\n[audio]\nvolume = {{ master = %.1f }}", options.video.fps, options.video.fov, options.audio.volume.master))
}