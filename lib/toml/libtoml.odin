package toml

import "core:reflect"
import "core:unicode/utf8"
import "core:strings"
import "base:intrinsics"
import "core:strconv"
import "core:mem/virtual"
import "core:os"
import "base:runtime"
import "core:mem"
import "core:encoding/json"
import "core:fmt"
import "dates"
import rt "base:runtime"
import "core:math"

// ======================== TABLE OF CONTENTS ========================
// 1. main.odin.....................................................29
// 2. toml.odin....................................................296
// 3. unmarshal.odin...............................................475
// 4. tokenizer.odin..............................................1128
// 5. validator.odin..............................................1258
// 6. parser.odin.................................................1736
// 7. misc.odin...................................................2168
// ===================================================================


// ================================================
// ================   main.odin   =================
// ================================================




main :: proc() {
    if any_of("-parse-example", ..os.args) {
        unmarshal_example_toml()
        logln("========================")
        parse_example_toml()
        return
    }
    if any_of("-pack", ..os.args) {
        pack_source_files()
        return
    }

    run_integrated_test()
}

// packs .odin files into a single libtoml.odin (that still uses the dates library!)
// useful for Neovim's telescope users
// and people who don't want to litter their project...
pack_source_files :: proc() {
    alloc := make_arena(8 * 1024*1024) // 8 megabytes
    context.allocator = alloc
    defer free_all(alloc)

    files :: [?] string {
        "main.odin"         ,
        "toml.odin"         ,
        "unmarshal.odin"    ,

        "tokenizer.odin"    ,
        "validator.odin"    ,
        "parser.odin"       ,

        "misc.odin"         ,
    }

    output_file := "libtoml.odin"

    head   : strings.Builder // for package, imports and TOC
    body   : strings.Builder // for everything else (decls, ...)

    imports  :  map [string] struct{}
    contents := make([] string, len(files))
    lengths  := make([] int   , len(files))// lines per file (same order as files)

    for file, file_index in files {
        data, err := os.read_entire_file(file, alloc)
        fmt.assertf(err == nil, "Failed to pack the source files! Received error '%s' when reading '%s'", err, file)

        temp_text := string(data)
        line_count:  int
        
        for line in strings.split_lines_iterator(&temp_text) {

            if strings.starts_with(line, "package") || strings.starts_with(line, "#+") {
                continue
            }

            if strings.starts_with(strings.trim_left_space(line), "import ") {
                imports[line] = {}
                // valid odin code (as of 2026-05):
                //     import "core:os"
                //     import hmm1 "core:os"
                //     import hmm2 "core:os"
                continue
            }

            line_count += 1
        }

        contents[file_index] = string(data)
        lengths [file_index] = line_count
    }

    // ======================== HEAD ========================

    strings.write_string(&head, "package toml\n")
    strings.write_byte(&head, '\n')
    
    for import_stmt, _ in imports {
        strings.write_string(&head, import_stmt)
        strings.write_byte(&head, '\n')
    }                                             
    strings.write_byte(&head, '\n')
 
    toc_banner := "// ======================== TABLE OF CONTENTS ========================\n"
    strings.write_string(&head, toc_banner) // + 1
    toc_cursor := 8 + len(imports) + len(files)
    for file, file_index in files {
        padding := strings.repeat(".", max(len(toc_banner)-3 - 4 - len(file) - int(math.log10(f32(toc_cursor)) + 1), 4))
        fmt.sbprintfln(&head, "// %d. %s%s%d", file_index + 1, file, padding, toc_cursor)
        toc_cursor += lengths[file_index]
        toc_cursor += 6 // "\n\n === FILE NAME === \n\n"
    }
    strings.write_string(&head, "// ===================================================================\n")

    // ======================== BODY ========================

    for file, file_index in files {
        lhs_padding := strings.repeat("=", (max(42 - len(file), 1)) / 2)
        rhs_padding := strings.repeat("=", (max(43 - len(file), 0)) / 2)

        strings.write_string(&body, "\n\n// ================================================\n")
        fmt.sbprintf(&body, "// %s   %s   %s", lhs_padding, file, rhs_padding)
        strings.write_string(&body, "\n// ================================================\n\n")

        temp_text := string(contents[file_index])
        for line in strings.split_lines_iterator(&temp_text) {
            trimmed_line := strings.trim_left_space(line)

            if strings.starts_with(trimmed_line, "package ") || 
               strings.starts_with(trimmed_line, "import ")  ||
               strings.starts_with(trimmed_line, "#+") {
                continue
            }

            strings.write_string(&body, line)
            strings.write_byte(&body, '\n')
        }
    }

    // fmt.println(string(head.buf[:]))
    // fmt.println(string(body.buf[:]))
    strings.write_bytes(&head, body.buf[:])
    err := os.write_entire_file(output_file, head.buf[:])
    fmt.assertf(err == nil, "Failed to write to the output file -- %s with error %v", output_file, err)

}

unmarshal_example_toml :: proc() {
    value : struct {
        integer  : int,
        num      : f32,
        infinity : f64,
        mstr     : string `toml:"multiline_str"`,
        a : struct { b: string },
        c : struct { d: string },
        // rest of values in example.toml
        // are ignored by unmarshal_table
    }

    table, err1 := parse_file("example.toml")
    err2 := unmarshal_table(value, nil)

    print_error(err1)
    assert(err2 == .None)

    logln(value)
}

parse_example_toml :: proc() {
    table, err := parse_file("example.toml")
    print_error(err)
    print_table(table)
}

// use ./run-tests.bash to run all tests at once
run_integrated_test :: proc() {

	data := make([]u8, 16 * 1024 * 1024)
	count, err_read := os.read(os.stdin, data)
	assert(err_read == nil || err_read == .EOF)

	table, err := parse(string(data[:count]), "<stdin>")

	if err.type != .None {print_error(err); os.exit(1)}

	idk, ok := marshal(table)
	if !ok do return

	json, _ := json.marshal(idk)
	logln(string(json))

	deep_delete(table)
    delete_error(&err)


    TypedValue :: struct {
        type:  string,
        value: union {
            map[string] UntypedValue,
            [] UntypedValue,
            string,
            bool,
            i64,
            f64,
        },
    }

    UntypedValue :: union {
        TypedValue,
        map[string] UntypedValue,
        [] UntypedValue,
    }

    marshal :: proc(input: Type) -> (result: UntypedValue, ok: bool) {
        output: TypedValue

        switch value in input {
        case nil:
            assert(false)
        case ^List:
            if value == nil do return result, false
            out := make([]UntypedValue, len(value))
            for v, i in value {out[i] = marshal(v) or_continue}
            return out, true

        case ^Table:
            if value == nil do return result, false
            out := make(map[string]UntypedValue)
            for k, v in value {out[k] = marshal(v) or_continue}
            return out, true

        case string:
            output = {
                type  = "string",
                value = value,
            }
        case bool:
            output = {
                type  = "bool",
                value = fmt.aprint(value),
            }
        case i64:
            output = {
                type  = "integer",
                value = fmt.aprint(value),
            }
        case f64:
            output = {
                type  = "float",
                value = fmt.aprint(value),
            }

        case dates.Date:
            result, err := dates.partial_date_to_string(date = value, time_sep = 'T')
            if err != .NONE do os.exit(1) // I shouldn't do this like that...

            date := value
            if date.is_time_only {
                output.type = "time-local"
            } else if date.is_date_only {
                output.type = "date-local"
            } else if date.is_date_local {
                output.type = "datetime-local"
            } else {
                output.type = "datetime"
            }
            output.value = result
        }

        return output, true
    }



}




// ================================================
// ================   toml.odin   =================
// ================================================




log     :: fmt.print
logf    :: fmt.printf
logln   :: fmt.println

assertf :: fmt.assertf

Builder        :: strings.Builder
b_destroy      :: strings.builder_destroy
b_reset        :: strings.builder_reset
b_write_string :: strings.write_string
b_printf       :: fmt.sbprintf

// Parses the file. You can use print_error(err) for error messages.
parse_file :: proc(filename: string, allocator := context.allocator) -> (section: ^Table, err: Error) {
    context.allocator = allocator

    blob, osErr := os.read_entire_file_from_path(filename, allocator)
    if osErr != nil {
        err.type = .Bad_File
        b_write_string(&err.more, filename)
        return nil, err
    }

    section, err = parse(string(blob), filename, allocator)
    delete_slice(blob)
    return
}

// This is made to be used with default, err := #load(filename). original_filename is only used for errors.
parse_data :: proc(data: []u8, original_filename := "untitled data", allocator := context.allocator) -> (section: ^Table, err: Error) {
    return parse(string(data), original_filename, allocator)
}

// Frees all of the memory allocated by the parser for a particular type
// It is recursive, so you can just give it the root Table.
deep_delete :: proc(type: Type, allocator := context.allocator) -> (err: runtime.Allocator_Error) {
    context.allocator = allocator
    #partial switch value in type {
    case ^List:
        if value == nil do break
        for &item in value {
            err = deep_delete(item, allocator)
            if err != .None do return
        }
        err = delete_dynamic_array(value^)
        if err == .None do free(value)

    case ^Table:
        if value == nil do break
        for k, &v in value {
            err = delete_string(k)
            if err != .None do return
            err = deep_delete(v, allocator)
            if err != .None do return
        }
        err = delete_map(value^)
        if err == .None do free(value)

    case string:
        err = delete_string(value)
    }
    return
}

// Retrieves and type checks the value at path. The last element of path is the actual key.
// section may be any Table.
get :: proc($T: typeid, section: ^Table, path: ..string) -> (val: T, ok: bool)
    where intrinsics.type_is_variant_of(Type, T)
{
    assert(len(path) > 0, "You must specify at least one path str in toml.fetch()!")
	if section == nil {
		return val, false
	}

    section := section
    for dir in path[:len(path) - 1] {
        if dir in section {
            section, ok = section[dir].(^Table)
            if !ok do return val, false
        } else do return val, false
    }
    last := path[len(path) - 1]
    if last in section do return section[last].(T)
    else do return val, false
}

// Also retrieves and typechecks the value at path, but if something goes wrong, it crashes the program.
get_panic :: proc($T: typeid, section: ^Table, path: ..string) -> T
    where intrinsics.type_is_variant_of(Type, T)
{
    assert(len(path) > 0, "You must specify at least one path str in toml.fetch_panic()!")
    section := section
    for dir in path[:len(path) - 1] {
        assertf(dir in section, "Missing key: '%s' in table '%v'!", path, section^)
        section = section[dir].(^Table)
    }
    last := path[len(path) - 1]
    assertf(last in section, "Missing key: '%s' in table '%v'!", last, section^)
    return section[last].(T)
}

// Currently(2024-06-__), Odin hangs if you simply fmt.print Table
print_table :: proc(section: ^Table, level := 0) {
    log("{ ")
    i := 0
    if section == nil { 
        log("<nil>") 
        return 
    }
    for k, v in section {
        log(k, "= ")
        print_value(v, level)
        if i != len(section) - 1 do log(", ")
        else do log(" ")
        i += 1
    }
    log("}")
    if level == 0 do logln()

    print_value :: proc(v: Type, level := 0) {
        #partial switch t in v {
        case ^Table:
            print_table(t, level + 1)
        case ^[dynamic] Type:
            log("[ ")
            for e, i in t {
                print_value(e, level)
                if i != len(t) - 1 do log(", ")
                else do log(" ")
            }
            log("]")
        case string:
            logf("%q", v)
        case:
            log(v)
        }
    }
}


// Here lies the code for LSP:
get_i64    :: proc(section: ^Table, path: ..string) ->
            (val: i64, ok: bool) { return get(i64, section, ..path) }
get_f64    :: proc(section: ^Table, path: ..string) ->
            (val: f64, ok: bool) { return get(f64, section, ..path) }
get_bool   :: proc(section: ^Table, path: ..string) ->
            (val: bool, ok: bool) { return get(bool, section, ..path) }
get_string :: proc(section: ^Table, path: ..string) ->
            (val: string, ok: bool) { return get(string, section, ..path) }
get_date   :: proc(section: ^Table, path: ..string) ->
            (val: dates.Date, ok: bool) { return get(dates.Date, section, ..path) }
get_list   :: proc(section: ^Table, path: ..string) ->
            (val: ^List, ok: bool) { return get(^List, section, ..path) }
get_table  :: proc(section: ^Table, path: ..string) ->
            (val: ^Table, ok: bool) { return get(^Table, section, ..path) }

get_i64_panic    :: proc(section: ^Table, path: ..string) ->
            i64 { return get_panic(i64, section, ..path) }
get_f64_panic    :: proc(section: ^Table, path: ..string) ->
            f64 { return get_panic(f64, section, ..path) }
get_bool_panic   :: proc(section: ^Table, path: ..string) ->
            bool { return get_panic(bool, section, ..path) }
get_string_panic :: proc(section: ^Table, path: ..string) ->
            string { return get_panic(string, section, ..path) }
get_date_panic   :: proc(section: ^Table, path: ..string) ->
            dates.Date { return get_panic(dates.Date, section, ..path) }
get_list_panic   :: proc(section: ^Table, path: ..string) ->
            ^List { return get_panic(^List, section, ..path) }
get_table_panic  :: proc(section: ^Table, path: ..string) ->
            ^Table { return get_panic(^Table, section, ..path) }


// ================================================
// ==============   unmarshal.odin   ==============
// ================================================



// An enum, may be used like: if unmarshal_error == .None { it worked! }
Unmarshal_Error :: enum {
	None,
	Invalid_Data,
	Invalid_Parameter,
	Non_Pointer_Parameter,
	Multiple_Use_Field,
	Out_Of_Memory,
	Unsupported_Type,
}

// Unmarshal TOML text into the passed value. Usage: unmarshal_any(toml_text, &output_value) 
// v must be a pointer value! However, it can be a pointer to anything (struct is most common).
unmarshal_any :: proc(data: []byte, v: any, allocator := context.allocator) -> Unmarshal_Error {
	v := v
	if v == nil || v.id == nil {
		return .Invalid_Parameter
	}

	if v.data == nil {
		return .Invalid_Parameter
	}

	v = reflect.any_base(v)
	ti := type_info_of(v.id)
	if !reflect.is_pointer(ti) || ti.id == rawptr {
		return .Non_Pointer_Parameter
	}

	ti_named, ti_named_ok := ti.variant.(reflect.Type_Info_Named)
	filename: string
	if ti_named_ok do filename = ti_named.name

	table, parse_err := parse_data(data, filename, allocator)
	if parse_err.type != .None {
		return .Invalid_Data
	}

	v = any {
		data = (^rawptr)(v.data)^,
		id   = ti.variant.(reflect.Type_Info_Pointer).elem.id,
	}
	if err := unmarshal_table(v, table); err != nil {
		return err
	}
	return nil
}

// Unmarshal TOML text into the passed value. 
// Usage: unmarshal_any(toml_text, &output_value) 
unmarshal :: proc(data: []byte, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error {
	return unmarshal_any(data, ptr, allocator)
}

// Unmarshal TOML text into the passed value. 
// Usage: unmarshal_any(toml_text, &output_value) 
unmarshal_string :: proc(
	data: string,
	ptr: ^$T,
	allocator := context.allocator,
) -> Unmarshal_Error {
	return unmarshal_any(transmute([]byte)data, ptr, allocator)
}

@(private)
assign_int :: proc(val: any, i: $T) -> bool {
	switch &v in val {
	case Type:
		v = i64(i)
		return true
	}

	v := reflect.any_core(val)
	switch &dst in v {
	case i8:
		dst = i8(i)
	case i16:
		dst = i16(i)
	case i16le:
		dst = i16le(i)
	case i16be:
		dst = i16be(i)
	case i32:
		dst = i32(i)
	case i32le:
		dst = i32le(i)
	case i32be:
		dst = i32be(i)
	case i64:
		dst = i64(i)
	case i64le:
		dst = i64le(i)
	case i64be:
		dst = i64be(i)
	case i128:
		dst = i128(i)
	case i128le:
		dst = i128le(i)
	case i128be:
		dst = i128be(i)
	case u8:
		dst = u8(i)
	case u16:
		dst = u16(i)
	case u16le:
		dst = u16le(i)
	case u16be:
		dst = u16be(i)
	case u32:
		dst = u32(i)
	case u32le:
		dst = u32le(i)
	case u32be:
		dst = u32be(i)
	case u64:
		dst = u64(i)
	case u64le:
		dst = u64le(i)
	case u64be:
		dst = u64be(i)
	case u128:
		dst = u128(i)
	case u128le:
		dst = u128le(i)
	case u128be:
		dst = u128be(i)
	case int:
		dst = int(i)
	case uint:
		dst = uint(i)
	case uintptr:
		dst = uintptr(i)
	case Type:
		dst = i64(i)
	case:
		is_bit_set_different_endian_to_platform :: proc(ti: ^runtime.Type_Info) -> bool {
			if ti == nil {
				return false
			}
			t := runtime.type_info_base(ti)
			#partial switch info in t.variant {
			case runtime.Type_Info_Integer:
				switch info.endianness {
				case .Platform:
					return false
				case .Little:
					return ODIN_ENDIAN != .Little
				case .Big:
					return ODIN_ENDIAN != .Big
				}
			}
			return false
		}

		ti := type_info_of(v.id)
		if info, ok := ti.variant.(runtime.Type_Info_Bit_Set); ok {
			do_byte_swap := is_bit_set_different_endian_to_platform(info.underlying)
			switch ti.size * 8 {
			case 0: // no-op.
			case 8:
				x := (^u8)(v.data)
				x^ = u8(i)
			case 16:
				x := (^u16)(v.data)
				x^ = do_byte_swap ? intrinsics.byte_swap(u16(i)) : u16(i)
			case 32:
				x := (^u32)(v.data)
				x^ = do_byte_swap ? intrinsics.byte_swap(u32(i)) : u32(i)
			case 64:
				x := (^u64)(v.data)
				x^ = do_byte_swap ? intrinsics.byte_swap(u64(i)) : u64(i)
			case:
				panic("unknown bit_size size")
			}
			return true
		}
		return false
	}
	return true
}

@(private)
assign_float :: proc(val: any, f: $T) -> bool {
	switch &v in val {
	case Type:
		v = f64(f)
		return true
	}

	v := reflect.any_core(val)
	switch &dst in v {
	case f16:
		dst = f16(f)
	case f16le:
		dst = f16le(f)
	case f16be:
		dst = f16be(f)
	case f32:
		dst = f32(f)
	case f32le:
		dst = f32le(f)
	case f32be:
		dst = f32be(f)
	case f64:
		dst = f64(f)
	case f64le:
		dst = f64le(f)
	case f64be:
		dst = f64be(f)

	case complex32:
		dst = complex(f16(f), 0)
	case complex64:
		dst = complex(f32(f), 0)
	case complex128:
		dst = complex(f64(f), 0)

	case quaternion64:
		dst = quaternion(w = f16(f), x = 0, y = 0, z = 0)
	case quaternion128:
		dst = quaternion(w = f32(f), x = 0, y = 0, z = 0)
	case quaternion256:
		dst = quaternion(w = f64(f), x = 0, y = 0, z = 0)

	case Type:
		dst = f64(f)

	case:
		return false
	}
	return true
}

@(private)
assign_bool :: proc(val: any, b: bool) -> bool {
	switch &v in val {
	case Type:
		v = bool(b)
		return true
	}

	v := reflect.any_core(val)
	switch &dst in v {
	case bool:
		dst = bool(b)
	case b8:
		dst = b8(b)
	case b16:
		dst = b16(b)
	case b32:
		dst = b32(b)
	case b64:
		dst = b64(b)
	case Type:
		dst = b
	case:
		return false
	}
	return true
}

@(private)
assign_date :: proc(val: any, date: dates.Date) -> bool {
	switch &v in val {
	case dates.Date:
		v = date
		return true
	case Type:
		v = date
		return true
	}
	return false
}

@(private)
unmarshal_string_token :: proc(val: any, str: string, ti: ^reflect.Type_Info) -> bool {
	val := val
	switch &v in val {
	case string:
		v = str
		return true
	case cstring:
		if str == "" {
			cstr, cstr_err := strings.clone_to_cstring(str)
			if cstr_err != .None do return false
			v = cstr
		} else {
			// NOTE: This is valid because 'clone_string' appends a NUL terminator
			v = cstring(raw_data(str))
		}
		return true
	case Type:
		v = str
		return true
	}

	#partial switch variant in ti.variant {
	case reflect.Type_Info_Enum:
		for name, i in variant.names {
			if name == str {
				assign_int(val, variant.values[i])
				return true
			}
		}
		return true

	case reflect.Type_Info_Integer:
		i := strconv.parse_i128(str) or_return
		if assign_int(val, i) {
			return true
		}
		if assign_float(val, i) {
			return true
		}

	case reflect.Type_Info_Float:
		f := strconv.parse_f64(str) or_return
		if assign_int(val, f) {
			return true
		}
		if assign_float(val, f) {
			return true
		}
	}

	return false
}

@(private)
unmarshal_value :: proc(dest: any, value: Type) -> (err: Unmarshal_Error) {
	dest := dest
	ti := reflect.type_info_base(type_info_of(dest.id))

	if u, ok := ti.variant.(reflect.Type_Info_Union); ok {
		// NOTE: If it's a union with only one variant, then treat it as that variant
		if len(u.variants) == 1 {
			variant := u.variants[0]
			dest.id = variant.id
			ti = reflect.type_info_base(variant)
			if !reflect.is_pointer_internally(variant) {
				tag := any {
					data = rawptr(uintptr(dest.data) + u.tag_offset),
					id   = u.tag_type.id,
				}
				assign_int(tag, 1)
			}
		} else if dest.id != Type {
			for variant, i in u.variants {
				variant_any := any {
					data = dest.data,
					id   = variant.id,
				}
				if err = unmarshal_value(variant_any, value); err == nil {
					raw_tag := i
					if !u.no_nil do raw_tag += 1
					tag := any {
						data = rawptr(uintptr(dest.data) + u.tag_offset),
						id   = u.tag_type.id,
					}
					assign_int(tag, raw_tag)
					return
				}
			}
			return .Unsupported_Type
		}
	}

	switch v in value {
	case ^List:
		unmarshal_list(dest, v) or_return

	case ^Table:
		unmarshal_table(dest, v) or_return

	case bool:
		if !assign_bool(dest, v) {
			return .Unsupported_Type
		}

	case dates.Date:
		if !assign_date(dest, v) {
			return .Unsupported_Type
		}

	case f64:
		if !assign_float(dest, v) {
			return .Unsupported_Type
		}

	case i64:
		if !assign_int(dest, v) {
			return .Unsupported_Type
		}

	case string:
		if !unmarshal_string_token(dest, v, ti) {
			return .Unsupported_Type
		}
	}

	return nil
}

@(private)
toml_name_from_tag_value :: proc(value: string) -> (toml_name, extra: string) {
	toml_name = value
	if comma_idx := strings.index_byte(toml_name, ','); comma_idx >= 0 {
		toml_name = toml_name[:comma_idx]
		extra = value[1 + comma_idx:]
	}
	return
}

@(private)
unmarshal_list :: proc(dest: any, list: ^List) -> Unmarshal_Error {
	assign_list :: proc(
		base: rawptr,
		elem_ti: ^reflect.Type_Info,
		list: ^List,
	) -> Unmarshal_Error {
		for i in 0 ..< len(list) {
			elem_ptr := rawptr(uintptr(base) + uintptr(i) * uintptr(elem_ti.size))
			elem := any {
				data = elem_ptr,
				id   = elem_ti.id,
			}

			unmarshal_value(elem, list[i]) or_return
		}

		return .None
	}

	ti := reflect.type_info_base(type_info_of(dest.id))

	#partial switch t in ti.variant {
	case reflect.Type_Info_Slice:
		raw := cast(^mem.Raw_Slice)dest.data
		data, data_ok := mem.alloc_bytes(t.elem.size * len(list), t.elem.align, list.allocator)
		if data_ok != .None {
			return .Out_Of_Memory
		}
		raw.data = raw_data(data)
		raw.len = len(list)

		return assign_list(raw.data, t.elem, list)

	case reflect.Type_Info_Dynamic_Array:
		raw := cast(^mem.Raw_Dynamic_Array)dest.data
		data, data_ok := mem.alloc_bytes(t.elem.size * len(list), t.elem.align, list.allocator)
		if data_ok != .None {
			return .Out_Of_Memory
		}
		raw.data = raw_data(data)
		raw.len = len(list)
		raw.allocator = context.allocator
		return assign_list(raw.data, t.elem, list)

	case reflect.Type_Info_Array:
		// NOTE(bill): Allow lengths which are less than the dst array
		if len(list) > t.count {
			return .Unsupported_Type
		}
		return assign_list(dest.data, t.elem, list)

	case reflect.Type_Info_Enumerated_Array:
		// NOTE(bill): Allow lengths which are less than the dst array
		if len(list) > t.count {
			return .Unsupported_Type
		}
		return assign_list(dest.data, t.elem, list)

	case reflect.Type_Info_Complex:
		// NOTE(bill): Allow lengths which are less than the dst array
		if len(list) > 2 {
			return .Unsupported_Type
		}

		switch ti.id {
		case complex32:
			return assign_list(dest.data, type_info_of(f16), list)
		case complex64:
			return assign_list(dest.data, type_info_of(f32), list)
		case complex128:
			return assign_list(dest.data, type_info_of(f64), list)
		}


	}

	return .Unsupported_Type
}

// Unmarshal parsed TOML into the passed value. 
// Usage: unmarshal_any(&output_value, parse_file("file") or_else nil) 
unmarshal_table :: proc(v: any, table: ^Table) -> Unmarshal_Error {
	v := v
	ti := reflect.type_info_base(type_info_of(v.id))

    if table == nil { return .Invalid_Parameter }

	#partial switch t in ti.variant {
	case reflect.Type_Info_Struct:
		if .raw_union in t.flags {
			return .Unsupported_Type
		}

		fields := reflect.struct_fields_zipped(ti.id)
		for key in table {
			use_field_idx := -1

			for field, field_idx in fields {
				tag_value := reflect.struct_tag_get(field.tag, "toml")
				toml_name, _ := toml_name_from_tag_value(tag_value)
				if key == toml_name {
					use_field_idx = field_idx
					break
				}
			}

			if use_field_idx < 0 {
				for field, field_idx in fields {
					tag_value := reflect.struct_tag_get(field.tag, "toml")
					toml_name, _ := toml_name_from_tag_value(tag_value)
					if toml_name == "" && key == field.name {
						use_field_idx = field_idx
						break
					}
				}
			}


			check_children_using_fields :: proc(
				key: string,
				parent: typeid,
			) -> (
				offset: uintptr,
				type: ^reflect.Type_Info,
				found: bool,
			) {
				for field in reflect.struct_fields_zipped(parent) {
					if field.is_using && field.name == "_" {
						offset, type, found = check_children_using_fields(key, field.type.id)
						if found {
							offset += field.offset
							return
						}
					}

					tag_value := reflect.struct_tag_get(field.tag, "toml")
					toml_name, _ := toml_name_from_tag_value(tag_value)
					if (toml_name == "" && field.name == key) || toml_name == key {
						offset = field.offset
						type = field.type
						found = true
						return
					}
				}
				return
			}


			offset: uintptr
			type: ^reflect.Type_Info
			field_found := use_field_idx >= 0

			if field_found {
				offset = fields[use_field_idx].offset
				type = fields[use_field_idx].type
			} else {
				offset, type, field_found = check_children_using_fields(key, ti.id)
			}

			if field_found {
				field_ptr := rawptr(uintptr(v.data) + offset)
				field := any {
					data = field_ptr,
					id   = type.id,
				}
				unmarshal_value(field, table[key])
			}
		}

	case reflect.Type_Info_Map:
		if !reflect.is_string(t.key) && !reflect.is_integer(t.key) {
			return .Unsupported_Type
		}
		raw_map := cast(^mem.Raw_Map)v.data
		if raw_map.allocator.procedure == nil {
			raw_map.allocator = table.allocator
		}

		elem_backing, elem_backing_err := mem.alloc_bytes(
			t.value.size,
			t.value.align,
			table.allocator,
		)
		if elem_backing_err != .None {
			return .Out_Of_Memory
		}
		defer delete(elem_backing, table.allocator)

		map_backing_value := any {
			data = raw_data(elem_backing),
			id   = t.value.id,
		}

		for key, value in table {
			mem.zero_slice(elem_backing)
			if err := unmarshal_value(map_backing_value, value); err != nil {
				delete(key, table.allocator)
				return err
			}


			key_ptr := any(key).data

			set_ptr := runtime.__dynamic_map_set_without_hash(
				raw_map,
				t.map_info,
				key_ptr,
				map_backing_value.data,
			)
			if set_ptr == nil {
				delete(key, table.allocator)
			}

			// there's no need to keep string value on the heap, since it was copied into map
			if reflect.is_integer(t.key) {
				delete(key, table.allocator)
			}
		}

	case:
		switch &val in v {
		case Type:
			val = table
			return nil
		}
		return .Unsupported_Type
	}

	return nil
}



// ================================================
// ==============   tokenizer.odin   ==============
// ================================================


tokenize :: proc(raw: string, file := "<unknown file>") -> (tokens: [dynamic] string, err: Error) {
    err = { file = file, line = 1 }

    skip: int
    outer: for r, i in raw {
        this := raw[i:]

        switch { // by the way, do NOT use the 'fallthrough' keyword
        // makes more invalid tests pass
        case !is_bare_rune_valid(r):
            set_err(&err, .Bad_Unicode_Char, "'%v'", r)
            return

        // throws error if only a carriage return is found, I guess, fuck macOS ..9?
        case r == '\r' && len(raw) > i + 1 && raw[i + 1] != '\n':
            set_err(&err, .Bad_Unicode_Char, "carriage returns must be followed by new lines in TOML!")
            return

        // skips until the end of e.g.: string and comment (this replaces having state.)
        case skip > 0: 
            skip -= 1

        // unix new lines
        case r == '\n':
            append(&tokens, "\n")
            err.line += 1

        // windows new lines
        case starts_with(raw[i:], "\r\n"):
            append(&tokens, "\n")
            err.line += 1

        case is_space(this[0]):
            // do nothing

        case is_special(this[0]):
            append(&tokens, this[:1])

        // removes a comment (in one go)
        case r == '#':
            j, runes := find_newline(this)
            if j == -1 do return tokens, { }
            skip += runes - 1

        // ============ START OF STRINGS ============ 
        case starts_with(this, "\"\"\""):
            j, runes := find(this, "\"\"\"", 3)
            if j == -1 do return tokens, set_err(&err, .Missing_Quote, shorten_string(this, 16))
            j2, runes2 := go_further(this[j + 3:], '"')
            j += j2; runes += runes2
            append(&tokens, this[:j + 3])
            skip += runes + 2

        case starts_with(this, "'''"):
            j, runes := find(this, "'''", 3, false)
            if j == -1 do return tokens, set_err(&err, .Missing_Quote, shorten_string(this, 16))
            j2, runes2 := go_further(this[j + 3:], '\'')
            j += j2; runes += runes2
            append(&tokens, this[:j + 3])
            skip += runes + 2
        
        case r == '"':
            j, runes := find(this, "\"", 1)
            if j == -1 do return tokens, set_err(&err, .Missing_Quote, shorten_string(this, 16))
            append(&tokens, this[:j + 1])
            skip += runes

        case r == '\'':
            j, runes := find(this, "'", 1, false)
            if j == -1 do return tokens, set_err(&err, .Missing_Quote, shorten_string(this, 16))
            append(&tokens, this[:j + 1])
            skip += runes
        // ============  END OF STRINGS  ============ 

        // tokenizes all leftover things (in one go)
        // this is "text", numbers & so on
        case:
            key := leftover(this)
            if len(key) == 0 do return tokens, set_err(&err, .None, shorten_string(this, 1))
            append(&tokens, key)
            skip += len(key) - 1
        }
    }

    return tokens, err


    leftover :: proc(raw: string) -> string {
        for _, i in raw {
            if is_space(raw[i]) || is_special(raw[i]) || raw[i] == '#' {
                return raw[:i]
            }
        }
        return raw
    }

    find :: proc(a: string, b: string, skip := 0, escape := true) -> (bytes: int, runes: int) {
        escaped: bool
        for r, i in a[skip:] {
            defer runes += 1
            if escaped do escaped = false
            else if escape && r == '\\' do escaped = true
            else if starts_with(a[i + skip:], b) do return i + skip, runes + skip 
        }    // "+ skip" here is bad, it would be best to count runes up until "skip"
        return -1, -1
    }

    go_further :: proc(a: string, r1: rune) -> (bytes: int, runes: int) {
        for r2, i in a {
            if r1 != r2 do return i, runes
            bytes  = i
            runes += 1
        }
        return 
    }

    set_err :: proc(err: ^Error, type: ErrorType, more_fmt: string, more_args: ..any) -> Error {
        err.type = type
        b_printf(&err.more, more_fmt, ..more_args)
        return err^
    }
}



// ================================================
// ==============   validator.odin   ==============
// ================================================


ErrorType :: enum {
    None,

    Bad_Date,
    Bad_File,
    Bad_Float,
    Bad_Integer,
    Bad_Name,
    Bad_New_Line,
    Bad_Unicode_Char,
    Bad_Value,

    Missing_Bracket,
    Missing_Comma,
    Missing_Key,
    Missing_Newline,
    Missing_Quote,
    Missing_Value,

    Double_Comma,
    Expected_Equals,
    Key_Already_Exists,
    Parser_Is_Stuck,
    Unexpected_Token,
}

Error :: struct {
    type: ErrorType,
    line: int,
    file: string,
    more: Builder,
    formatted: Builder,
}

// The filename is not freed, since it is only sliced
delete_error :: proc(err: ^Error) {
    if err.type != .None {
        b_destroy(&err.more)
    }
    if len(err.formatted.buf) > 0 {
        b_destroy(&err.formatted)
    }
}

// This may also be a warning!
print_error :: proc(err: Error, allocator := context.allocator) -> (fatal: bool) {
    err := err
    message: string
    message, fatal = format_error(&err, allocator)
    if message != "" {
        logf("[TOML ERROR] %s", message)
        delete(message, allocator)
    }
    return fatal
}

// The message is allocated and should be freed after use.
format_error :: proc(err: ^Error, allocator := context.allocator) -> (message: string, fatal: bool) {
    if err.type == .None do return "", false

    descriptions : [ErrorType] string = {
        .None               = "",
        .Bad_Date           = "Failed to parse a date",
        .Bad_File           = "Toml parser could not read the given file",
        .Bad_Float          = "Failed to parse a floating-point number (may be invalid value)",
        .Bad_Integer        = "Failed to parse an interger",
        .Bad_Name           = "Bad key/table name found before, use quotes, or only 'A-Za-z0-9_-'",
        .Bad_New_Line       = "New line is out of place",
        .Bad_Unicode_Char   = "Found an invalid unicode character in string",
        .Bad_Value          = "Bad value found after '='",
        .Double_Comma       = "Lists must have exactly 1 comma after each element (except trailing commas are optional)",
        .Expected_Equals    = "Expected '=' after assignment of a key",
        .Key_Already_Exists = "That key/section already exists",
        .Missing_Bracket    = "A bracket is missing (one of: '[', '{', '}', ']')",
        .Missing_Comma      = "A comma is missing",
        .Missing_Key        = "Expected key before '='",
        .Missing_Newline    = "A new line is missing between two key-value pairs",
        .Missing_Quote      = "Missing a quote",
        .Missing_Value      = "Expected a value after '='",
        .Parser_Is_Stuck    = "Parser has halted due to being in an infinite loop",
        .Unexpected_Token   = "Found a token that should not be there",
    }

    err.formatted.buf = make(type_of(err.formatted.buf), allocator)
    b_printf(&err.formatted, "%s:%d %s! %s\n", err.file, err.line + 1, descriptions[err.type], err.more.buf[:])

    return string(err.formatted.buf[:]), true
}

// Skips all consecutive new lines
// new lines should not be skipped everywhere
// that's why this is not inside of the peek() procedure.
skip_newline :: proc(io: ^IO) -> (ok: bool) { ok = peek(io) == "\n"; for peek(io) == "\n" { io.err.line += 1; skip(io) }; return }

validate :: proc(raw_tokens: [] string, file: string, allocator := context.allocator) -> Error {
    io: IO = {
        toks = raw_tokens,
        err  = { line = 1, file = file },
        aloc = allocator,
    }

    for peek(&io) != "" {
        if !validate_stmt(&io) {
            make_err(&io, .Unexpected_Token, "Unexpected token at the start of a statement: %s!", peek(&io))
        }
        if io.err.type != .None do break
    }

    err := io.err
    return err
}

// '||' operator has short-circuiting in Odin, so I use this to chain functions.
validate_stmt :: proc(io: ^IO) -> bool {
    return skip_newline(io) || (validate_array(io) || validate_table(io) || validate_assign(io)) &&
           !err_if_not(io, peek(io) == "" || peek(io) == "\n", .Missing_Newline, "Found a missing new line between statements!")
}

// array of tables: `[[item]]` at the start of lines
validate_array :: proc(io: ^IO) -> bool {
    if peek(io, 0) != "[" || peek(io, 1) != "[" do return false
    #no_bounds_check {
        if err_if_not(io, peek(io, 0)[1] == '[', .Missing_Bracket, "In section array both brackets must follow one another! '[[' not '[ ['") do return false
    }

    skip(io, 2) // '[' '['
    validate_path(io)

    #no_bounds_check {
        if peek(io, 0) == "]" && peek(io, 1) == "]" && err_if_not(io, peek(io, 0)[1] == ']', .Missing_Bracket, "In section array both brackets must follow one another! ']]' not '] ]'!") do return false
    }
    if err_if_not(io, next(io) == "]", .Missing_Bracket, "']' missing in section array declaration!") do return false
    if err_if_not(io, next(io) == "]", .Missing_Bracket, "']' missing in section array declaration!") do return false

    return true
}

// tables: `[object]` at the start of lines
validate_table :: proc(io: ^IO) -> bool {
    if peek(io, 0) != "[" do return false

    skip(io) // '['
    validate_path(io)
    return !err_if_not(io, next(io) == "]", .Missing_Bracket, "']' missing in section declaration!")
}

// key = value
validate_assign :: proc(io: ^IO) -> bool {
    if peek(io, 1) != "=" && peek(io, 1) != "." do return false

    if !validate_path(io) do return false
    if err_if_not(io, peek(io) == "=", .Expected_Equals, "Keys must be followed by '='! Instead got: %s!", peek(io)) do return false
    skip(io) // '='
    return validate_expr(io)
}

// there.are.dotted.paths.in.toml   each "directory" is supposed to be an object, last depends on the context.
// for example: in statement [[a.b]] a is a Table, b is a List of Table(s)
validate_path :: proc(io: ^IO) -> bool {//{{{
    validate_name :: proc(io: ^IO) -> bool {
        skip(io)
        return true
    }

    for peek(io, 1) == "." {
        if peek(io, 0) == "\n" || peek(io, 2) == "\n" {
            make_err(io, .Bad_New_Line, "paths.of.keys must be on the same line!")
            return false
        }

        if !validate_name(io) {
            make_err(io, .Bad_Name, "key in path cannot have this name: '%s'!", peek(io))
            return false
        }
        skip(io)
    }

    if !validate_name(io) {
        make_err(io, .Bad_Name, "key in path cannot have this name: '%s'!", peek(io))
        return false
    }

    return true
}//}}}

// Order matters. There can be expressions without statements (See: last line of validate_assign()).
validate_expr :: proc(io: ^IO) -> bool {
    return validate_string(io)       ||
           validate_bool(io)         ||
           validate_date(io)         ||
           validate_inline_list(io)  ||
           validate_inline_table(io) ||
           validate_number(io)
}

validate_string :: proc(io: ^IO) -> bool {//{{{
    validate_quotes :: proc(io: ^IO) -> bool {
        PATTERNS := [] string { "\"\"\"", "'''", "\"", "\'", }
        for p in PATTERNS {
            if starts_with(peek(io), p) {
                if err_if_not(io, ends_with(peek(io), p), .Missing_Quote, "string '%s' is missing one or more quotes!", peek(io)) do return false
            }
        }
        skip(io)
        return true
    }

    if len(peek(io)) == 0 do return false
    if r := peek(io)[0]; !any_of(r, '"', '\'') do return false

    return validate_quotes(io)
}//}}}

validate_bool :: proc(io: ^IO) -> bool {  //{{{
    if eq(peek(io), "yes") do make_err(io, .Bad_Value, "'Yes' is not a valid expression in TOML, please use 'true'!")
    if eq(peek(io), "no")  do make_err(io, .Bad_Value, "'No' is not a valid expression in TOML, please use 'false'!")

    // eq is case-insensitive compare, while '==' operator is case-sensitive
    if !eq(peek(io), "false") && !eq(peek(io), "true") do return false

    defer skip(io)
    return !err_if_not(io, peek(io) == "false" || peek(io) == "true", .Bad_Value, "Booleans must be lowercase!")
}//}}}

validate_date :: proc(io: ^IO) -> (ok: bool) {  //{{{
    is_proper_date :: proc(str: string) -> bool {
        // I hope, LLVM can do something with this...
        return len(str) > 9 &&
            str[0] >= '0' && str[0] <= '9' &&
            str[1] >= '0' && str[1] <= '9' &&
            str[2] >= '0' && str[2] <= '9' &&
            str[3] >= '0' && str[3] <= '9' &&
            str[4] == '-' &&
            str[5] >= '0' && str[5] <= '9' &&
            str[6] >= '0' && str[6] <= '9' &&
            str[7] == '-' &&
            str[8] >= '0' && str[8] <= '9' &&
            str[9] >= '0' && str[9] <= '9'
    }

    is_proper_time :: proc(str: string) -> bool {
        if len(str) == 5 {
            return str[0] >= '0' && str[0] <= '9' &&
                str[1] >= '0' && str[1] <= '9' &&
                str[2] == ':' &&
                str[3] >= '0' && str[3] <= '9' &&
                str[4] >= '0' && str[4] <= '9'
        }
        return len(str) > 7 &&
            str[0] >= '0' && str[0] <= '9' &&
            str[1] >= '0' && str[1] <= '9' &&
            str[2] == ':' &&
            str[3] >= '0' && str[3] <= '9' &&
            str[4] >= '0' && str[4] <= '9' &&
            str[5] == ':' &&
            str[6] >= '0' && str[6] <= '9' &&
            str[7] >= '0' && str[7] <= '9'
    }

    validate_time :: proc(io: ^IO, str: string) -> bool {
        if err_if_not(io, is_proper_time(str), .Bad_Date, "The date: '%s' is not valid, please use rfc 3339 (e.io.: 1234-12-12, or 60:45:30+02:00)!", peek(io)) do return false

        offset := str[8:] if len(str) > 8 else ""

        // because of dotted.keys, 'start' '.' 'end' are different tokens.
        if peek(io, 1) == "." {
            for r, i in peek(io, 2) {
                if r == '-' || r == '+' {
                    offset = peek(io, 2)[i:]
                    break
                }
                if err_if_not(io, is_digit(r, 10) || r == 'Z' || r == 'z', .Bad_Date, "Bad millisecond count in the date!") do return false
            }
            skip(io, 2)
        }

        if offset == "" do return true

        if offset[0] == '+' || offset[0] == '-' {
            s := offset[1:]
            return len(str) > 4 &&
                s[0] >= '0' && s[0] <= '9' &&
                s[1] >= '0' && s[1] <= '9' &&
                s[2] == ':' &&
                s[3] >= '0' && s[3] <= '9' &&
                s[4] >= '0' && s[4] <= '9'
        }
        return true // 'Z' and 'z' are unnecessary in TOML
    }

    // Dates will necessarily have - as their 5th symbol: "0123-00-00"
    if len(peek(io)) > 4 && peek(io)[4] == '-' {
        err_if_not(io, is_proper_date(peek(io)), .Bad_Date, "The date: '%s' is not valid, please use rfc 3339 (e.io.: 1234-12-12, or 60:45:30+02:00)!", peek(io))

        // time can be seperated either by { 't', 'T' or ' ' }, ' ' is split by tokenizer
        if len(peek(io)) > 11 && (peek(io)[10] == 'T' || peek(io)[10] == 't') {
            if !validate_time(io, peek(io)[11:]) do return false
        }
        next(io)
        ok = true
    }

    // Time can be either without date or split from it by whitespace.
    // This handles both scenarios
    if len(peek(io)) > 2 && peek(io)[2] == ':' {
        validate_time(io, peek(io))
        next(io)
        ok = true
    }

    return ok
}//}}}

// Good luck!
validate_number :: proc(io: ^IO) -> bool {//{{{
    at :: proc(s: string, i: int) -> rune { for r, j in s do if i == j do return r; return 0 }

    number := peek(io)
    if at(number, 0) == '+' || at(number, 0) == '-' do number = number[1:]

    if eq(number, "nan") || eq(number, "inf") {
        err_if_not(io, number == "nan" || number == "inf", .Bad_Float, 
            "NaN and Inf must be fully lowercase in TOML: `nan` and `inf`! (I don't know why). Your's is: '%s'!", peek(io))
        skip(io)
        return true
    }

    split_by :: proc(a: string, b: string) -> (string, string) {
        for r1, i in a {
            for r2 in b {
               if r1 == r2 do return a[:i], a[i + 1:]
            }
        }
        return a, ""
    }

    // underscores must be between 2 digits
    validate_underscores :: proc(io: ^IO, r: rune, p: rune, is_last: bool) -> bool {
        if r != '_' do return true
        switch {
        case p == '_' : make_err(io, .Bad_Integer, "Double underscore mid number!")
        case p == 0   : make_err(io, .Bad_Integer, "Underscore cannot be the first character in a number!")
        case is_last  : make_err(io, .Bad_Integer, "Underscore cannot be the last character in a number!")
        case: return true
        }
        return false
    }

    // I split the number into three parts:  main.fractionEexponent or mainEexponent
    main, fraction, exponent: string

    {
        exp1, exp2: string
        main, exp1 = split_by(number, "eE")
        if peek(io, 1) == "." {
            fraction, exp2 = split_by(peek(io, 2), "eE")

            if exp1 != "" && exp2 != "" {
                make_err(io, .Bad_Float, "A number cannot have 2 exponent parts! '1e5.7e6' is invalid!")
                return false
            }
        }
        exponent = exp1 if exp1 != "" else exp2
        if at(exponent, 0) == '-' || at(exponent, 0) == '+' do exponent = exponent[1:]
    }

    // If a number starts with zero it must be followed by 'x', 'o', 'b' ir nothing
    base := 10
    if at(main, 0) == '0' {
        switch at(main, 1) {
        case 'x': base = 16; main = main[2:]
        case 'o': base =  8; main = main[2:]
        case 'b': base =  2; main = main[2:]
        case  0 : // nothing
        case: make_err(io, .Bad_Integer, "A number cannot start with '0'. Please use '0o1234' for octal!")
        }
    }

    prev: rune

    prev = 0
    for r, i in main {
        if prev == 0 && !is_digit(r, base) do return false
        if err_if_not(io, is_digit(r, base) || r == '_', .Bad_Integer, "Unexpected character: '%v' in number!", r) do return false
        if !validate_underscores(io, r, prev, i == len(main) - 1) do return false
        prev = r
    }

    prev = 0
    for r, i in fraction {
        if prev == 0 && !is_digit(r, base) do return false
        if err_if_not(io, is_digit(r, base) || r == '_', .Bad_Integer, "Unexpected character: '%v' in decimal part of number!", r) do return false
        if !validate_underscores(io, r, prev, i == len(fraction) - 1) do return false
        prev = r
    }

    prev = 0
    for r, i in exponent {
        if prev == 0 && !is_digit(r, base) do return false
        if err_if_not(io, is_digit(r, base) || r == '_', .Bad_Integer, "Unexpected character: '%v' in exponent part of number!", r) do return false
        if !validate_underscores(io, r, prev, i == len(exponent) - 1) do return false
        prev = r
    }

    skip(io)
    if fraction != "" do skip(io, 2)
    return true
}//}}}

validate_inline_list :: proc(io: ^IO) -> bool { //{{{
    if peek(io) != "[" do return false
    skip(io) // '['

    for {
        skip_newline(io)
        if peek(io) == "]" do break

        if err_if_not(io, validate_expr(io), .Unexpected_Token, "Unexpected token in inline list!") do return false

        skip_newline(io)
        if peek(io) == "]" do break

        if err_if_not(io, peek(io) == ",", .Missing_Comma, "Missing comma or ']' in list!") do return false
        skip(io) // ','
        skip_newline(io)
        if peek(io) == "," {
            make_err(io, .Double_Comma, "double comma found in an inline list!")
            return false
        }
    }

    return !err_if_not(io, next(io) == "]", .Missing_Bracket, "']' missing in inline array declaration!")
}//}}}

validate_inline_table :: proc(io: ^IO) -> bool { //{{{
    if peek(io) != "{" do return false
    skip(io) // '{'

    for {
        skip_newline(io)
        if peek(io) == "}" do break

        if err_if_not(io, validate_assign(io), .Unexpected_Token, "Unexpected token in inline table!") do return false

        skip_newline(io)
        if peek(io) == "}" do break

        if err_if_not(io, peek(io) == ",", .Missing_Comma, "Missing comma or '}' in table!") do return false
        skip(io) // ','
        skip_newline(io)
        if peek(io) == "," {
            make_err(io, .Double_Comma, "double comma found in an inline list!")
            return false
        }
    }

    return !err_if_not(io, next(io) == "}", .Missing_Bracket, "'}' missing in inline table declaration!")
}//}}}

make_err :: proc(io: ^IO, type: ErrorType, more_fmt: string, more_args: ..any) {
    io.err.type = type
    context.allocator = io.aloc
    if len(io.err.more.buf) > 0 do return // b_reset(&io.err.more) 
    b_printf(&io.err.more, more_fmt, ..more_args)
}

err_if_not :: proc(io: ^IO, cond: bool, type: ErrorType, more_fmt: string, more_args: ..any) -> bool {
    if !cond do make_err(io, type, more_fmt, ..more_args)
    return !cond
}



// ================================================
// ===============   parser.odin   ================
// ================================================




Table :: map [string] Type
List  :: [dynamic] Type

Type :: union {
    ^Table,
    ^List,
    string,
    bool,
    i64,
    f64,
    dates.Date,
}

@private
IO :: struct {
    toks    : [] string,    // all token list
    curr    : int,          // the current token index
    err     : Error,        // current error
    root    : ^Table,       // the root/global table
    section : ^Table,       // TOML's `[section]` table
    this    : ^Table,       // TOML's local p.a.t.h or { table = {} } table
    reps    : int,          // for halting upon infinite loops
    aloc    : rt.Allocator, // probably useless, honestly...
}

@private // gets a token or an empty string.
peek :: proc(io: ^IO, o := 0) -> string {
    if io.curr + o >= len(io.toks) do return ""
    if io.reps >= 1000 { // <-- solution to the halting problem!
        if io.toks[io.curr + o] == "\n" {
            make_err(io, .Bad_New_Line,  "The parser is stuck on an out-of-place new line.")
        } else {
            io.err.type = .Parser_Is_Stuck
            b_printf(&io.err.more, "Token: '%s' at index: %d", io.toks[io.curr + o], io.curr + o)
        }
        return ""
    }
    io.reps += 1

    return io.toks[io.curr + o]
}


// skips by one or more tokens, the parser & validator CANNOT go back,
@private // since my solution to the halting problem may not work then.
skip :: proc(io: ^IO, o := 1) {
    assert(o >= 0)
    io.curr += o
    if o != 0 do io.reps = 0
}

@private // returns the current token and skips to the next token.
next :: proc(io: ^IO) -> string {
    defer skip(io)
    return peek(io)
}

parse :: proc(data: string, original_file: string, allocator := context.allocator) -> (tokens: ^Table, err: Error) {
    context.allocator = allocator

    // === TOKENIZER ===
    raw_tokens, t_err := tokenize(data, file = original_file)
    defer delete_dynamic_array(raw_tokens)
    if t_err.type != .None do return nil, t_err

    // === VALIDATOR ===
    v_err := validate(raw_tokens[:], original_file, allocator)
    if v_err.type != .None do return tokens, v_err

    // === TEMP DATA ===
    tokens = new(Table)

    io: IO = {
        toks = raw_tokens[:],
        err  = { line = 1, file = original_file },

        root    = tokens,
        this    = tokens,
        section = tokens,

        aloc = allocator,
    }

    // === MAIN WORK ===
    for peek(&io) != "" {
        if io.err.type != .None {
            return nil, io.err
        }

        if peek(&io) == "\n" {
            io.err.line += 1
            skip(&io)
            continue
        }

        parse_statement(&io)
        io.this = io.section
    }

    if io.err.type != .None {
        return nil, io.err
    }

    return
}

// ======================== STATEMENTS ========================

parse_statement :: proc(io: ^IO) {
    ok: bool

    ok = parse_section_list(io);  if ok do return
    ok = parse_section(io);       if ok do return
    ok = parse_assign(io);        if ok do return

    parse_expr(io) // skips orphaned expressions
}

// This function is for dotted.paths (stops at.the.NAME)
walk_down :: proc(io: ^IO, parent: ^Table) {

    // ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
    // ! This is intricate as fuck and I still don't         !
    // ! really get how it works.                            !
    // ! PLEASE RUN ALL TESTS IF YOU CHANGE THIS AT ALL.     !
    // ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

    if peek(io, 1) != "." do return

    name, err := unquote(next(io))
    io.err.type = err.type
    io.err.more = err.more
    if err.type != .None do return
    skip(io) // '.'

    do_not_free: bool
    defer if !do_not_free do delete_string(name)

    #partial switch value in parent[name] {
    case nil:
        io.this = new(Table)
        parent[name] = io.this
        do_not_free = true

    case ^Table:
        io.this = value

    case ^List:
        if len(value^) == 0 {
            io.this = new(Table)
            append(value, io.this)

        } else {
            table, is_table := value[len(value^) - 1].(^Table)
            if !is_table {
                make_err(io, .Key_Already_Exists, name)
                return
            }
            io.this = table
        }

    case:
        make_err(io, .Key_Already_Exists, name)
        return
    }

    walk_down(io, io.this)
}


parse_section_list :: proc(io: ^IO) -> bool {
    if peek(io, 0) != "[" || peek(io, 1) != "[" do return false
    skip(io, 2) // '[' '['

    io.this = io.root
    io.section = io.root
    walk_down(io, io.root)

    name, err := unquote(next(io)) // take care with ordering of this btw
    io.err.type = err.type
    io.err.more = err.more
    if err.type != .None do return true

    list   : ^List
    result := new(Table)

    if name not_in io.this {
        list = new(List)
        io.this[name] = list

    } else if !is_list(io.this[name]) {
        make_err(io, .Key_Already_Exists, name)
    } else {
        list = io.this[name].(^List)
        delete_string(name)
    }

    append(list, result)

    skip(io, 2) // ']' ']'
    io.section = result
    return true
}

// put() is only used in parse_section, so it's specialized
// general version: commit 8910187045028ce13df3214e04ace6071ea89158
put :: proc(io: ^IO, parent: ^Table, key: string, value: ^Table) {

    // I simply admit that I do not understand how tables work...
    // fuck this shit! [[a.b]]\n [a] is somehow valid..?
    // I do not know what the hell is even that...
    // The valid tests pass. That is what matters...

    #partial switch existing in parent[key] {
    case ^Table:
        for k, v in value { existing[k] = v }
        delete_map(value^)
        value^ = existing^
    case ^List:
        append(existing, value)

    case nil:
        parent[key] = value

    case:
        make_err(io, .Key_Already_Exists, key)
    }
}

parse_section :: proc(io: ^IO) -> bool {
    if peek(io) != "[" do return false
    skip(io) // '['

    io.this = io.root
    io.section = io.root
    walk_down(io, io.root)

    name, err := unquote(next(io)) // take care with ordering of this btw
    io.err.type = err.type
    io.err.more = err.more
    if err.type != .None do return true

    result := new(Table)

    put(io, io.this, name, result)

    skip(io) // ']'
    io.this = result
    io.section = io.this
    return true
}

parse_assign :: proc(io: ^IO)  -> bool {
    if peek(io, 1) != "=" && peek(io, 1) != "." do return false

    walk_down(io, io.this)

    key, err := unquote(peek(io))
    io.err.type = err.type
    io.err.more = err.more
    if err.type != .None do return true

    if any_of(u8('\n'), ..transmute([] u8)peek(io)) {
        make_err(io, .Bad_Name, "Keys cannot have raw new lines in them")
        return true
    }

    skip(io, 2)
    value := parse_expr(io)

    if key in io.this {
        make_err(io, .Key_Already_Exists, key)
    }

    io.this[key] = value
    return true
}

// ======================== EXPRESSIONS ========================


parse_expr :: proc(io: ^IO) -> (result: Type) {
    ok: bool
    result, ok = parse_string(io); if ok do return
    result, ok = parse_bool(io);   if ok do return
    result, ok = parse_date(io);   if ok do return
    result, ok = parse_float(io);  if ok do return
    result, ok = parse_int(io);    if ok do return
    result, ok = parse_list(io);   if ok do return
    result, ok = parse_table(io);  if ok do return
    return
}

parse_string :: proc(io: ^IO) -> (result: string, ok: bool) {
    if len(peek(io)) == 0 do return
    if r := peek(io)[0]; !any_of(r, '"', '\'') do return
    str, err := unquote(next(io))
    io.err.type = err.type
    io.err.more = err.more
    return str, true
}

parse_bool :: proc(io: ^IO) -> (result: bool, ok: bool) {
    if peek(io) == "true"  { skip(io); return true, true }
    if peek(io) == "false" { skip(io); return false, true }
    return false, false
}

parse_float :: proc(io: ^IO) -> (result: f64, ok: bool) {

    has_e_but_not_x :: proc(s: string) -> bool {
        if len(s) > 2       { if any_of(s[1], 'x', 'X') do return false }
        #reverse for r in s { if any_of(r,    'e', 'E') do return true }
        return false
    }

    Infinity : f64 = 0h7FF0_0000_0000_0000 // or: 1.0e5000 (but not 1e5000)
    NaN      : f64 = 0h7FF0_0000_0000_0001 // or: transmute(f64) ( transmute(i64) Infinity | 1 )

    if len(peek(io)) == 4 {
        if peek(io)[0] == '-' { if peek(io)[1:] == "inf" { skip(io); return -Infinity, true } }
        if peek(io)[0] == '+' { if peek(io)[1:] == "inf" { skip(io); return +Infinity, true } }
        if peek(io)[1:] == "nan" { skip(io); return NaN, true }
    }

    if peek(io) == "nan" { skip(io); return NaN, true }
    if peek(io) == "inf" { skip(io); return Infinity, true }

    if peek(io, 1) == "." {
        number := fmt.aprint(peek(io), ".", peek(io, 2), sep = "")
        cleaned, has_alloc := strings.remove_all(number, "_")
        defer if has_alloc do delete(cleaned)
        defer delete(number)
        skip(io, 3)
        return strconv.parse_f64(cleaned)

    } else if has_e_but_not_x(peek(io)) {
        cleaned, has_alloc := strings.remove_all(next(io), "_")
        defer if has_alloc do delete(cleaned)
        return strconv.parse_f64(cleaned)
    }

    // it's an int then
    return
}

parse_int :: proc(io: ^IO) -> (result: i64, ok: bool) {
    result, ok = strconv.parse_i64(peek(io))
    if ok do skip(io)
    return
}

parse_date :: proc(io: ^IO) -> (result: dates.Date, ok: bool) {
    if !dates.is_date_lax(peek(io, 0)) do return
    ok = true

    full: strings.Builder
    strings.write_string(&full, next(io))

    // is date, time or both?
    if dates.is_date_lax(peek(io)) {
        strings.write_rune(&full, ' ')
        strings.write_string(&full, next(io))
    }

    if peek(io) == "." {
        strings.write_byte(&full, '.'); skip(io)
        strings.write_string(&full, next(io))
    }

    err: dates.DateError
    result, err = dates.from_string(strings.to_string(full))
    if err != .NONE {
        make_err(io, .Bad_Date, "Received error: %v by parsing: '%s' as date\n", err, strings.to_string(full))
        return
    }

    strings.builder_destroy(&full)
    return

}

parse_list :: proc(io: ^IO) -> (result: ^List, ok: bool) {
    if peek(io) != "[" do return
    skip(io) // '['
    ok = true

    result = new(List)

    for !any_of(peek(io), "]", "") {

        if peek(io) == "," { skip(io); continue }
        if peek(io) == "\n" { io.err.line += 1; skip(io); continue }

        element := parse_expr(io)
        append(result, element)
    }

    skip(io) // ']'
    return
}

parse_table :: proc(io: ^IO) -> (result: ^Table, ok: bool) {
    if peek(io) != "{" do return
    skip(io) // '{'
    ok = true

    result = new(Table)

    temp_this, temp_section := io.this, io.section
    for !any_of(peek(io), "}", "") {

        if peek(io) == "," { skip(io); continue }
        if peek(io) == "\n" { io.err.line += 1; skip(io); continue }

        io.this, io.section = result, result
        parse_assign(io)
    }
    io.this, io.section = temp_this, temp_section

    skip(io) // '}'
    return
}


// ================================================
// ================   misc.odin   =================
// ================================================




Allocator :: mem.Allocator

@private 
make_arena :: proc(initial_size := mem.Megabyte, caller := #caller_location) -> Allocator {
    arena := new(virtual.Arena) // <-- least impactful memory leak here
    _ = virtual.arena_init_growing(arena, uint(initial_size))
    return virtual.arena_allocator(arena) 
}

@private
find_newline :: proc(raw: string) -> (bytes: int, runes: int) {
    for r, i in raw {
        defer runes += 1
        if r == '\r' || r == '\n' do return i, runes
    }
    return -1, -1
}

@private
shorten_string :: proc(s: string, limit: int, or_newline := true) -> string {
    min :: proc(a, b: int) -> int {
        return a if a < b else b
    }

    newline, _ := find_newline(s) // add another line if you are using (..MAC OS 9) here... fuck it.
    if newline == -1 do newline = len(s)

    if limit < len(s) || newline < len(s) {
        return fmt.aprint(s[:min(limit, newline)], "...")
    }

    return s
}

// when literal is true, function JUST returns str
@private
cleanup_backslashes :: proc(str: string, literal := false) -> (result: string, err: Error) {
    raw := strings.clone(str)
    if literal do return raw, err

    set_err :: proc(err: ^Error, type: ErrorType, more_fmt: string, more_args: ..any) {
        err.type = type
        b_printf(&err.more, more_fmt, ..more_args)
    }

    b: strings.Builder
    // defer builder_derawoy(&b) // don't need to, shouldn't even free the original text here

    to_skip := 0

    last: rune
    escaped: bool
    for r, i in raw {

        if to_skip > 0 {
            to_skip -= 1
            continue
        }
        // basically, if last == '\\' {
        if escaped {
            escaped = false

            switch r {
            case 'x', 'u', 'U':
                to_skip = 2
                if r == 'u' {
                    to_skip = 4
                } else if r == 'U' {
                    to_skip = 8
                }
                if len(raw) < i + to_skip + 1 {
                    set_err(&err, .Bad_Unicode_Char, "'\\%v' must have %v hex digits after it in string:", r, to_skip, raw)
                    return raw, err
                }

                code, ok := strconv.parse_u64(raw[i + 1: i + to_skip + 1], 16)
                if !ok {
                    set_err(&err, .Bad_Unicode_Char, "'%s'", raw[i + 1:i + to_skip + 1])
                }
                buf, bytes := toml_ucs_to_utf8(code)
                if bytes == -1 {
                    set_err(&err, .Bad_Unicode_Char, "'%s'", raw[i + 1:i + to_skip + 1])
                    return raw, err
                }

                parsed_rune, _ := utf8.decode_rune_in_bytes(buf[:bytes])
                strings.write_rune(&b, parsed_rune)

            case 'n' : strings.write_byte(&b, '\n')
            case 'r' : strings.write_byte(&b, '\r')
            case 't' : strings.write_byte(&b, '\t')
            case 'b' : strings.write_byte(&b, '\b')
            case 'f' : strings.write_byte(&b, '\f')
            case 'e' : strings.write_byte(&b, '\e')
            case '\\': strings.write_byte(&b, '\\')
            case '"' : strings.write_byte(&b, '"')
            case '\'': strings.write_byte(&b, '\'')
            case ' ', '\t', '\r', '\n':
                // Fun thing for multiline line string line escaping.
                for r2 in raw[i + 1:] {
                    if r2 == ' ' || r2 == '\t' || r2 == '\r' || r2 == '\n' do to_skip += 1
                    else do break
                }
            case:
                set_err(&err, .Bad_Unicode_Char, "Unexpected escape sequence found.")
                return raw, err
            }
        } else if r != '\\' {
            strings.write_rune(&b, r)
        } else {
            escaped = true
        }

        last = r
    }
    delete_string(raw)
    defer b_destroy(&b) // you can't free a builder that has been cast to string
    return strings.clone(strings.to_string(b)), err
}

@private
any_of :: proc(a: $T, B: ..T) -> bool {
    for b in B do if a == b do return true
    return false
}

@private
is_space :: proc(r: u8) -> bool {
    SPACE : [4] u8 = { ' ', '\r', '\n', '\t' }
    return r == SPACE[0] || r == SPACE[1] || r == SPACE[2] || r == SPACE[3]
    // Nudge nudge
}

@private
is_special :: proc(r: u8) -> bool {
    SPECIAL : [8] u8 = { '=', ',',  '.',  '[', ']', '{', '}', 0 }
    return  r == SPECIAL[0] || r == SPECIAL[1] || r == SPECIAL[2] || r == SPECIAL[3] ||
            r == SPECIAL[4] || r == SPECIAL[5] || r == SPECIAL[6] || r == SPECIAL[7]
    // Shove shove
}

@private
is_digit :: proc(r: rune, base: int) -> bool {
    switch base {
    case 16: return (r >= '0' && r <= '9') || (r >= 'A' && r <= 'F') || (r >= 'a' && r <= 'f')
    case 10: return r >= '0' && r <= '9'
    case 8:  return r >= '0' && r <= '7'
    case 2:  return r >= '0' && r <= '1'
    }
    assert(false, "Only bases: 16, 10, 8 and 2 are supported in TOML")
    return false
}

@private
between_any :: proc(a: rune, b: ..rune) -> bool {
    assert(len(b) % 2 == 0)
    for i := 0; i < len(b); i += 2 {
        if a >= b[i] && a <= b[i + 1] do return true
    }
    return false
}

@(private)
get_quote_count :: proc(a: string) -> int {
    s := len(a)
    if  s > 2 &&
        ((a[:3] == "\"\"\"" && a[s-3:] == "\"\"\"" ) ||
        (a[:3] == "'''" && a[s-3:] == "'''")) { return 3 }

    if  s > 0 &&
        ((a[:1] == "\"" && a[s-1:] == "\"") ||
        (a[:1] == "'" && a[s-1:] == "'")) { return 1 }

    return 0
}

@(private)
unquote :: proc(a: string, fluff: ..any) -> (result: string, err: Error) {
    qcount := get_quote_count(a)

    if qcount == 3 {
        first: rune
        count: int
        #reverse for r, i in a {
            if i < 3 do break
            if first == 0 do first = r
            if r == first do count = count + 1
            else if r == '\\' do count -= 1
            else do break
        }
        if count != 3 && count % 3 == 0 {
            err.type = .Bad_Value
            b_write_string(&err.more, "The quote count in multiline string is divisible by 3. Lol, get fucked!")
            return a, err
        }
    }

    unquoted := a[qcount:len(a) - qcount]
    if len(unquoted) > 0 && unquoted[0] == '\n' do unquoted = unquoted[1:]
    return cleanup_backslashes(unquoted, a[0] == '\'')
}

@(private)
starts_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[:len(b)] == b
}

@(private)
ends_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[len(a) - len(b):] == b
}

// case-insensitive compare
@private
eq :: proc(a, b: string) -> bool {
    if len(a) != len(b) do return false
    #no_bounds_check for i in 0..<len(a) {
        r1 := a[i]
        r2 := b[i]

        A := r1 - 32*u8(r1 >= 'a' && r1 <= 'z')
        B := r2 - 32*u8(r2 >= 'a' && r2 <= 'z')
        if A != B do return false
    }
    return true
}

@private
is_list :: proc(t: Type) -> bool {
    _, is_list := t.(^List)
    return is_list

}

// // from: https://www.cl.cam.ac.uk/~mgk25/ucs/utf8_check.c
// is_rune_valid :: proc(r: rune) -> bool {
//     // if !utf8.valid_rune(r) do return false
//
//     s, n := utf8.encode_rune(r)
//
//     if n == 1 {
//         /* 0xxxxxxx */
//         return true
//     } else if n == 2 {
//         /* 110XXXXx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[0] & 0xfe) == 0xc0) {                      /* overlong? */
//             return true
//         }
//     } else if n == 3 {
//         /* 1110XXXX 10Xxxxxx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[2] & 0xc0) != 0x80 ||
//             (s[0] == 0xe0 && (s[1] & 0xe0) == 0x80) ||    /* overlong? */
//             (s[0] == 0xed && (s[1] & 0xe0) == 0xa0) ||    /* surrogate? */
//             (s[0] == 0xef && s[1] == 0xbf &&
//                 (s[2] & 0xfe) == 0xbe)) {                    /* U+FFFE or U+FFFF? */
//             return true
//         }
//     } else if n == 4 {
//         /* 11110XXX 10XXxxxx 10xxxxxx 10xxxxxx */
//         if ((s[1] & 0xc0) != 0x80 ||
//             (s[2] & 0xc0) != 0x80 ||
//             (s[3] & 0xc0) != 0x80 ||
//             (s[0] == 0xf0 && (s[1] & 0xf0) == 0x80) ||      /* overlong? */
//             (s[0] == 0xf4 && s[1] > 0x8f) || s[0] > 0xf4) { /* > U+10FFFF? */
//             return true
//         }
//     } else do return false
//
//     return true
// }

is_bare_rune_valid :: proc(r: rune) -> bool {
    if r == '\n' || r == '\r' || r == '\t' do return true
    return r >= 32
}


// Completely ripped from tomlc99:
// https://github.com/cktan/tomlc99

/**
 *	Convert a UCS char to utf8 code, and return it in buf.
 *	Return #bytes used in buf to encode the char, or
 *	-1 on error.
 */
toml_ucs_to_utf8 :: proc(code: u64) -> (buf: [6] u8, byte_count: int) {
    /* http://stackoverflow.com/questions/6240055/manually-converting-unicode-codepoints-into-utf-8-and-utf-16
     */
    /* The UCS code values 0xd800–0xdfff (UTF-16 surrogates) as well
     * as 0xfffe and 0xffff (UCS noncharacters) should not appear in
     * conforming UTF-8 streams.
     */
    if (0xd800 <= code && code <= 0xdfff) do return buf, -1
    // if (0xfffe <= code && code <= 0xffff) do return buf, -1

    /* 0x00000000 - 0x0000007F:
        0xxxxxxx
    */
    if (code < 0) do return buf, -1
    if (code <= 0x7F) {
        buf[0] = u8(code)
        return buf, 1
    }

    /* 0x00000080 - 0x000007FF:
       110xxxxx 10xxxxxx
    */
    if (code <= 0x000007FF) {
        buf[0] = u8(0xc0 | (code >> 6))
        buf[1] = u8(0x80 | (code & 0x3f))
        return buf, 2
    }

    /* 0x00000800 - 0x0000FFFF:
       1110xxxx 10xxxxxx 10xxxxxx
    */
    if (code <= 0x0000FFFF) {
        buf[0] = u8(0xe0 | (code >> 12))
        buf[1] = u8(0x80 | ((code >> 6) & 0x3f))
        buf[2] = u8(0x80 | (code & 0x3f))
        return buf, 3
    }

    /* 0x00010000 - 0x001FFFFF:
       11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    */
    if (code <= 0x001FFFFF) {
        buf[0] = u8(0xf0 | (code >> 18))
        buf[1] = u8(0x80 | ((code >> 12) & 0x3f))
        buf[2] = u8(0x80 | ((code >> 6) & 0x3f))
        buf[3] = u8(0x80 | (code & 0x3f))
        return buf, 4
    }

    /* 0x00200000 - 0x03FFFFFF:
       111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    if (code <= 0x03FFFFFF) {
        buf[0] = u8(0xf8 | (code >> 24))
        buf[1] = u8(0x80 | ((code >> 18) & 0x3f))
        buf[2] = u8(0x80 | ((code >> 12) & 0x3f))
        buf[3] = u8(0x80 | ((code >> 6) & 0x3f))
        buf[4] = u8(0x80 | (code & 0x3f))
        return buf, 5
    }

    /* 0x04000000 - 0x7FFFFFFF:
       1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
     */
    if (code <= 0x7FFFFFFF) {
        buf[0] = u8(0xfc | (code >> 30))
        buf[1] = u8(0x80 | ((code >> 24) & 0x3f))
        buf[2] = u8(0x80 | ((code >> 18) & 0x3f))
        buf[3] = u8(0x80 | ((code >> 12) & 0x3f))
        buf[4] = u8(0x80 | ((code >> 6) & 0x3f))
        buf[5] = u8(0x80 | (code & 0x3f))
        return buf, 6
    }

    return buf, -1
}
