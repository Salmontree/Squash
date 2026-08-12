package assets

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