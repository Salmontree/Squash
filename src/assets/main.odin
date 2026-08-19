package assets

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

@(private) Loader :: #type proc(filepath: string) -> (asset: rawptr, ok: bool)
@(private) Destroyer :: #type proc(asset: rawptr)

init :: proc() {
	store.assets = make(type_of(store.assets))
	store.destroyers = make(type_of(store.destroyers))
	store.loaders = make(type_of(store.loaders))
	sound_init()
	scaffold_all_paths()
	
	register(Sound, sound_load, sound_destroy)
	register(Options, options_load, options_destroy); load(Options, "options")
}

quit :: proc() {
	for _, asset in store.assets do store.destroyers[asset.type](asset.data)
	sound_quit()
	delete(store.assets)
	delete(store.destroyers)
	delete(store.loaders)
}

register :: proc($type: typeid, loader: proc(filepath: string) -> (asset: ^type, ok: bool), destroyer: proc(asset: ^type)) {
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

load :: proc($type: typeid, id: string, filepath: string = "") -> (ok: bool) {
	data, ok2 := store.loaders[type](filepath)
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