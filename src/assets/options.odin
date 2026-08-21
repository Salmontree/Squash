package assets

import "core:strings"
import "core:fmt"
import "lib:toml"
import "core:os"

Options :: struct {
	video: struct {
		fov: f32,
		fps: f32,
		vsync: bool,
		view_bobbing: bool,
		render_distance: u8,
		fullscreen: bool,
	},
	audio: struct {
		volume: struct {
			master: f32,
			music: f32,
			midi: f32,
			weather: f32,
			blocks: f32,
			hostiles: f32,
			creatures: f32,
			players: f32,
			ambient: f32
		},
	},
	input: struct {
		mouse: struct {
			sensitivity: u8,
		},
		binds: struct {

		}
	},

	save: proc(options: ^Options)
}

@(private="file")
default_options :: Options {
	video = {
		fov = 90.0,
		fps = 0.0,
		vsync = false,
		view_bobbing = true,
		render_distance = 12,
		fullscreen = false,
	},
	audio = {
		volume = {
			master = 1.0,
			music = 1.0,
			midi = 1.0,
			weather = 1.0,
			blocks = 1.0,
			hostiles = 1.0,
			creatures = 1.0,
			players = 1.0,
			ambient = 1.0,
		},
	},
	input = {
		mouse = {
			sensitivity = 100,
		},
		binds = {

		},
	},

	save = _options_write
}

@(private="file")
_options_write :: proc(options: ^Options) {
	_ = os.write_entire_file(get_path("config/options.toml", context.temp_allocator), fmt.aprintf(
`[video]
fov = %.1f
fps = %.1f
vsync = {}
view_bobbing = {}
render_distance = {}
fullscreen = {}

[audio]
volume.master = %.1f
volume.music = %.1f
volume.midi = %.1f
volume.weather = %.1f
volume.blocks = %.1f
volume.hostiles = %.1f
volume.creatures = %.1f
volume.players = %.1f
volume.ambient = %.1f

[input]
mouse.sensitivity = {}`,
	options.video.fov, options.video.fps, options.video.vsync, options.video.view_bobbing, options.video.render_distance, options.video.fullscreen, options.audio.volume.master, options.audio.volume.music, options.audio.volume.midi, options.audio.volume.weather, options.audio.volume.blocks, options.audio.volume.hostiles, options.audio.volume.creatures, options.audio.volume.players, options.audio.volume.ambient, options.input.mouse.sensitivity,
	allocator = context.temp_allocator))
}

@(private)
options_load :: proc(filepath: string) -> (asset: ^Options, ok: bool) {
	filepath := get_path("config/options.toml", context.temp_allocator)
	asset = new(Options)

	if !os.exists(filepath) {
		asset^ = default_options
		asset->save()
		return asset, false
	}

	// TODO: error handling
	table, _ := toml.parse_file(filepath, context.temp_allocator)
	asset.video.fov = f32(table["video"].(^toml.Table)["fov"].(f64))
	asset.video.fps = f32(table["video"].(^toml.Table)["fps"].(f64))
	asset.video.vsync = table["video"].(^toml.Table)["vsync"].(bool)
	asset.video.view_bobbing = table["video"].(^toml.Table)["view_bobbing"].(bool)
	asset.video.render_distance = u8(table["video"].(^toml.Table)["render_distance"].(i64))
	asset.video.fullscreen = table["video"].(^toml.Table)["fullscreen"].(bool)
	asset.audio.volume.master = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["master"].(f64))
	asset.audio.volume.music = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["music"].(f64))
	asset.audio.volume.midi = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["midi"].(f64))
	asset.audio.volume.weather = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["weather"].(f64))
	asset.audio.volume.blocks = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["blocks"].(f64))
	asset.audio.volume.hostiles = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["hostiles"].(f64))
	asset.audio.volume.creatures = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["creatures"].(f64))
	asset.audio.volume.players = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["players"].(f64))
	asset.audio.volume.ambient = f32(table["audio"].(^toml.Table)["volume"].(^toml.Table)["ambient"].(f64))
	asset.input.mouse.sensitivity = u8(table["input"].(^toml.Table)["mouse"].(^toml.Table)["sensitivity"].(i64))
	asset.save = default_options.save
	return asset, true
}

@(private)
options_destroy :: proc(asset: ^Options) {
	asset->save()
	free(asset)
}