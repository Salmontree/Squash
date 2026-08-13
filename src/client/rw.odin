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

write_bool :: proc(socket: net.TCP_Socket, data: bool) {}

write_u8 :: proc(socket: net.TCP_Socket, data: u8) {}

write_u16 :: proc(socket: net.TCP_Socket, data: u16) {}

write_u32 :: proc(socket: net.TCP_Socket, data: u32) {}

write_i8 :: proc(socket: net.TCP_Socket, data: i8) {}

write_i16 :: proc(socket: net.TCP_Socket, data: i16) {}

write_i32 :: proc(socket: net.TCP_Socket, data: i32) {}

write_f32 :: proc(socket: net.TCP_Socket, data: f32) {}

write_f64 :: proc(socket: net.TCP_Socket, data: f64) {}

write_bytes :: proc(socket: net.TCP_Socket, data: []byte) {}

write_varint :: proc(socket: net.TCP_Socket, data: i64) {}

write_string :: proc(socket: net.TCP_Socket, data: string) {}