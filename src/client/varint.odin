package client

VarInt :: i64

encode_varint :: proc(data: VarInt) -> []byte {
	return {}
}

decode_varint :: proc(data: []byte) -> VarInt {
	return 0
}