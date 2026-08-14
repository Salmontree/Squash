package client

VarInt :: distinct i32

encode_varint :: proc(data: VarInt, allocator := context.allocator) -> [dynamic]byte {
	result := make([dynamic]byte, allocator)

	value := u32(data)

	for _ in 0..<5 {
		b := byte(value & 0x7F)
		value >>= 7

		if value != 0 {
			b |= 0x80
		}

		append(&result, b)

		if value == 0 { break }
	}

	return result
}

decode_varint :: proc(data: []byte) -> VarInt {
	result := u32(0)

	for b, i in data {
		result |= u32(b & 0b0111_1111) << u32(i * 7)
		if (b & 0b1000_0000) == 0 { break }
		if i == 4 { break }
	}

	return VarInt(result)
}