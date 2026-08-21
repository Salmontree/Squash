package assets

import "core:log"

@(private)
store: struct {
	assets: map[string]Asset,
	loaders: map[typeid]Loader,
	destroyers: map[typeid]Destroyer,
}

@(private)
Asset :: struct {
	data: rawptr,
	type: typeid
}

@(private) Loader :: #type proc(files: ..string) -> (asset: rawptr, ok: bool)
@(private) Destroyer :: #type proc(asset: rawptr)

init :: proc() {
	log.info("Initializing asset store")

	store.assets = make(type_of(store.assets))
	store.destroyers = make(type_of(store.destroyers))
	store.loaders = make(type_of(store.loaders))
	scaffold_all_paths()
	
	log.info("Loading options"); register(Options, options_load, options_destroy); if !load(Options, "options") do log.error("Couldn't load options, using defaults")
	log.info("Loading sounds"); register(Sound, sound_load, sound_destroy); if !sound_init() do log.error("Couldn't load sounds")
	log.info("Loading textures"); register(Texture, texture_load, texture_destroy); if !texture_init() do log.error("Couldn't load textures")
	log.info("Loading shaders"); register(Shader, shader_load, shader_destroy); if !shader_init() do log.error("Couldn't load shaders")
}

quit :: proc() {
	log.info("Clearing assets")
	for _, asset in store.assets do store.destroyers[asset.type](asset.data)
	sound_quit()
	delete(store.assets)
	delete(store.destroyers)
	delete(store.loaders)
}

register :: proc($type: typeid, loader: proc(files: ..string) -> (asset: ^type, ok: bool), destroyer: proc(asset: ^type)) {
	store.loaders[type] = Loader(loader)
	store.destroyers[type] = Destroyer(destroyer)
}

get :: proc($type: typeid, id: string) -> (asset: ^type, ok: bool) {
	ret, ok2 := store.assets[id]
	if ret.type == type && ok2 do return (^type)(ret.data), true
	return nil, false
}
get_unsafe :: proc($type: typeid, id: string) -> (asset: ^type) {
	return (^type)(store.assets[id].data)
}

load :: proc($type: typeid, id: string, files: ..string) -> (ok: bool) {
	data, ok2 := store.loaders[type](..files)
	if !ok2 do return false

	store.assets[id] = Asset {
		data = data,
		type = type
	}
	return true
}

is_loaded :: proc(id: string) -> bool {
	return id in store.assets
}