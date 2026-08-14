package client

import "core:net"

write :: proc {
	write_bool,
	write_u8,
	write_u16,
	write_u32,
	write_i8,
	write_i16,
	write_i32,
	write_f32,
	write_f64,
	write_bytes,
	write_varint,
	write_string
}

write_bool :: proc(socket: net.TCP_Socket, data: bool) { net.send(socket, {byte(data)}) }

write_u8 :: proc(socket: net.TCP_Socket, data: u8) { net.send(socket, {byte(data)}) }

write_u16 :: proc(socket: net.TCP_Socket, data: u16) { net.send(socket, {byte(data & 0xF), byte(data >> 8)}) }

write_u32 :: proc(socket: net.TCP_Socket, data: u32) { net.send(socket, {byte(data & 0xF), byte(data >> 8 & 0xF), byte(data >> 16 & 0xF), byte(data >> 24)}) }

write_i8 :: proc(socket: net.TCP_Socket, data: i8) { net.send(socket, {byte(data)}) }

write_i16 :: proc(socket: net.TCP_Socket, data: i16) { net.send(socket, {byte(data & 0xF), byte(data >> 8)}) }

write_i32 :: proc(socket: net.TCP_Socket, data: i32) { net.send(socket, {byte(data & 0xF), byte(data >> 8 & 0xF), byte(data >> 16 & 0xF), byte(data >> 24)}) }

write_f32 :: proc(socket: net.TCP_Socket, data: f32) { net.send(socket, {byte(transmute(u32)data & 0xF), byte(transmute(u32)data >> 8 & 0xF), byte(transmute(u32)data >> 16 & 0xF), byte(transmute(u32)data >> 24 & 0xF), byte(transmute(u32)data >> 32 & 0xF), byte(transmute(u32)data >> 40 & 0xF), byte(transmute(u32)data >> 48 & 0xF), byte(transmute(u32)data >> 56)}) }

write_f64 :: proc(socket: net.TCP_Socket, data: f64) { net.send(socket, {byte(transmute(u64)data & 0xF), byte(transmute(u64)data >> 8 & 0xF), byte(transmute(u64)data >> 16 & 0xF), byte(transmute(u64)data >> 24 & 0xF), byte(transmute(u64)data >> 32 & 0xF), byte(transmute(u64)data >> 40 & 0xF), byte(transmute(u64)data >> 48 & 0xF), byte(transmute(u64)data >> 56)}) }

write_bytes :: proc(socket: net.TCP_Socket, data: []byte) { net.send(socket, data) }

write_varint :: proc(socket: net.TCP_Socket, data: VarInt) { varint := encode_varint(data, context.temp_allocator); net.send(socket, varint[:]); free_all(context.temp_allocator) }

write_string :: proc(socket: net.TCP_Socket, data: string) {}