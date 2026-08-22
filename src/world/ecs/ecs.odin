package ecs

import "core:mem"

@(private="file")
Entity :: struct {
	id:  int,
	gen: int,
}

@(private="file")
Filter_Kind :: enum u8 {
	With,
	Without,
}

@(private="file")
Query_Filter :: struct {
	id:   typeid,
	kind: Filter_Kind,
}

With :: proc($T: typeid) -> Query_Filter {
	return Query_Filter{id = T, kind = .With}
}

Without :: proc($T: typeid) -> Query_Filter {
	return Query_Filter{id = T, kind = .Without}
}

@(private="file")
Component_Store :: struct {
	id:        typeid,
	size:      int,
	align:     int,
	by_entity: map[Entity]rawptr,
}

@(private="file")
state: struct {
	initialized: bool,
	next_id:     int,
	free_ids:    [dynamic]int,
	generations: [dynamic]int,
	alive:       map[Entity]bool,
	stores:      map[typeid]Component_Store,
}

init :: proc() {
	state.stores = make(map[typeid]Component_Store)
	state.alive = make(map[Entity]bool)
	state.free_ids = make([dynamic]int)
	state.generations = make([dynamic]int)
	state.next_id = 0
	state.initialized = true
}

deinit :: proc() {
	for _, store in state.stores {
		for _, ptr in store.by_entity {
			free(ptr)
		}
		delete(store.by_entity)
	}
	delete(state.stores)
	delete(state.alive)
	delete(state.free_ids)
	delete(state.generations)
	state = {}
}

@(private="file")
new_entity_id :: proc() -> Entity {
	if len(state.free_ids) > 0 {
		id := pop(&state.free_ids)
		return Entity{id = id, gen = state.generations[id]}
	}
	id := state.next_id
	state.next_id += 1
	append(&state.generations, 0)
	return Entity{id = id, gen = 0}
}

@(private="file")
get_or_create_store :: proc(id: typeid) -> ^Component_Store {
	if id not_in state.stores {
		ti := type_info_of(id)
		state.stores[id] = Component_Store {
			id        = id,
			size      = ti.size,
			align     = ti.align,
			by_entity = make(map[Entity]rawptr),
		}
	}
	return &state.stores[id]
}

@(private="file")
store_set :: proc(store: ^Component_Store, e: Entity, data: rawptr, size: int) {
	if ptr, ok := store.by_entity[e]; ok {
		mem.copy(ptr, data, size)
		return
	}
	ptr, _ := mem.alloc(size, store.align)
	mem.copy(ptr, data, size)
	store.by_entity[e] = ptr
}

@(private="file")
store_remove :: proc(store: ^Component_Store, e: Entity) {
	if ptr, ok := store.by_entity[e]; ok {
		free(ptr)
		delete_key(&store.by_entity, e)
	}
}

@(private="file")
store_contains :: proc(id: typeid, e: Entity) -> bool {
	store, ok := state.stores[id]
	if !ok do return false
	return e in store.by_entity
}

@(private="file")
passes_filters :: proc(e: Entity, filters: []Query_Filter) -> bool {
	for f in filters {
		has := store_contains(f.id, e)
		switch f.kind {
		case .With:
			if !has do return false
		case .Without:
			if has do return false
		}
	}
	return true
}

spawn :: proc(components: ..any) -> Entity {
	e := new_entity_id()
	state.alive[e] = true
	for comp in components {
		store := get_or_create_store(comp.id)
		store_set(store, e, comp.data, store.size)
	}
	return e
}

despawn :: proc(e: Entity) {
	if !alive(e) do return
	delete_key(&state.alive, e)
	for id in state.stores do store_remove(&state.stores[id], e)
	state.generations[e.id] += 1
	append(&state.free_ids, e.id)
}

alive :: proc(e: Entity) -> bool {
	return e in state.alive
}

add :: proc(e: Entity, component: any) {
	if !alive(e) do return
	store := get_or_create_store(component.id)
	store_set(store, e, component.data, store.size)
}

remove :: proc(e: Entity, $T: typeid) {
	if T in state.stores {
		store := &state.stores[T]
		store_remove(store, e)
	}
}

has :: proc(e: Entity, $T: typeid) -> bool {
	store, ok := state.stores[T]
	if !ok do return false
	return e in store.by_entity
}

get :: proc(e: Entity, $T: typeid) -> ^T {
	store, ok := state.stores[T]
	if !ok do return nil
	ptr, ok2 := store.by_entity[e]
	if !ok2 do return nil
	return cast(^T)ptr
}

@(private="file")
query1 :: proc($T: typeid, filters: ..Query_Filter) -> []^T {
	store := get_or_create_store(T)
	result := make([dynamic]^T, 0, len(store.by_entity), context.temp_allocator)
	for e, ptr in store.by_entity {
		if !passes_filters(e, filters) do continue
		append(&result, cast(^T)ptr)
	}
	return result[:]
}

@(private="file")
query2 :: proc($T1: typeid, $T2: typeid, filters: ..Query_Filter) -> ([]^T1, []^T2) {
	store1 := get_or_create_store(T1)
	store2 := get_or_create_store(T2)
	as := make([dynamic]^T1, 0, len(store1.by_entity), context.temp_allocator)
	bs := make([dynamic]^T2, 0, len(store1.by_entity), context.temp_allocator)
	for e, ptr1 in store1.by_entity {
		ptr2, ok := store2.by_entity[e]
		if !ok do continue
		if !passes_filters(e, filters) do continue
		append(&as, cast(^T1)ptr1)
		append(&bs, cast(^T2)ptr2)
	}
	return as[:], bs[:]
}

@(private="file")
query3 :: proc($T1: typeid, $T2: typeid, $T3: typeid, filters: ..Query_Filter) -> ([]^T1, []^T2, []^T3) {
	store1 := get_or_create_store(T1)
	store2 := get_or_create_store(T2)
	store3 := get_or_create_store(T3)
	as := make([dynamic]^T1, 0, len(store1.by_entity), context.temp_allocator)
	bs := make([dynamic]^T2, 0, len(store1.by_entity), context.temp_allocator)
	cs := make([dynamic]^T3, 0, len(store1.by_entity), context.temp_allocator)
	for e, ptr1 in store1.by_entity {
		ptr2, ok2 := store2.by_entity[e]
		if !ok2 do continue
		ptr3, ok3 := store3.by_entity[e]
		if !ok3 do continue
		if !passes_filters(e, filters) do continue
		append(&as, cast(^T1)ptr1)
		append(&bs, cast(^T2)ptr2)
		append(&cs, cast(^T3)ptr3)
	}
	return as[:], bs[:], cs[:]
}

query :: proc {
	query1,
	query2,
	query3,
}