package backends

Vtable :: struct {
	destroy_window: proc(rawdata: rawptr),
	poll_events: proc(rawdata: rawptr),
	clear_screen: proc(rawdata: rawptr),
	present_screen: proc(rawdata: rawptr),
	should_quit: proc(rawdata: rawptr) -> bool,
}

Window :: struct {
	vtable: Vtable,
	data: rawptr
}