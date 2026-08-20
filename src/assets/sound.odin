package assets

import ma "vendor:miniaudio"
import "core:strings"

Sound :: struct {
	sound: ma.sound,
	initialized: bool,
	play: proc(asset: ^Sound),
	set_volume: proc(asset: ^Sound, volume: f32),
	set_pitch: proc(asset: ^Sound, pitch: f32),
}

@(private="file")
state: struct {
	engine: ma.engine,
	initialized: bool,
}

@(private="file")
_sound_load_all :: proc() -> bool {
	return true
}

@(private)
sound_init :: proc() -> bool {
	if state.initialized do return true

	result := ma.engine_init(nil, &state.engine)
	if result != .SUCCESS do return false

	if !_sound_load_all() do return false

	state.initialized = true
	return true
}

@(private)
sound_quit :: proc() {
	if state.initialized {
		ma.engine_uninit(&state.engine)
		state.initialized = false
	}
}

@(private="file")
_sound_play :: proc(asset: ^Sound) {
	if asset == nil || !asset.initialized do return
	ma.sound_seek_to_pcm_frame(&asset.sound, 0)
	ma.sound_start(&asset.sound)
}
@(private="file")
_sound_set_volume :: proc(asset: ^Sound, volume: f32) {
	if asset == nil || !asset.initialized do return
	ma.sound_set_volume(&asset.sound, clamp(volume, 0.0, 1.0))
}
@(private="file")
_sound_set_pitch :: proc(asset: ^Sound, pitch: f32) {
	if asset == nil || !asset.initialized do return
	ma.sound_set_pitch(&asset.sound, max(pitch, 0.0001)) // can't be <= 0 in miniaudio
}

@(private)
sound_load :: proc(filepath: string) -> (asset: ^Sound, ok: bool) {
	if !state.initialized do return nil, false

	cpath, err := strings.clone_to_cstring(filepath, context.temp_allocator)
	if err != nil do return nil, false

	asset = new(Sound)
	if asset == nil do return nil, false

	result := ma.sound_init_from_file(
		&state.engine,
		cpath,
		{ .DECODE },
		nil,
		nil,
		&asset.sound,
	)
	if result != .SUCCESS {
		free(asset)
		return nil, false
	}

	asset.initialized = true
	asset.play = _sound_play
	asset.set_volume = _sound_set_volume
	asset.set_pitch = _sound_set_pitch

	return asset, true
}

@(private)
sound_destroy :: proc(asset: ^Sound) {
	ma.sound_uninit(&asset.sound)
	free(asset)
}