package mcbot

// Minecraft 1.8.9 (protocol 47) bot skeleton — offline mode only.
// No encryption/auth: if the server has online-mode=true you'll get an
// Encryption Request (login, 0x01) that this code doesn't handle yet.
//
// NOTE: core:net's exact proc names/signatures have shifted across Odin
// versions. Check `odin doc core:net` against your installed compiler
// and adjust dial_tcp/recv_tcp/send_tcp calls if they don't match.

import "core:net"
import "core:fmt"
import "core:os"

// ---------------------------------------------------------------------
// VarInt (de)serialization
// ---------------------------------------------------------------------

write_varint :: proc(buf: ^[dynamic]byte, value: i32) {
	v := u32(value)
	for {
		b := u8(v & 0x7F)
		v >>= 7
		if v != 0 {
			b |= 0x80
		}
		append(buf, b)
		if v == 0 {
			break
		}
	}
}

write_string :: proc(buf: ^[dynamic]byte, s: string) {
	write_varint(buf, i32(len(s)))
	append(buf, ..transmute([]u8)s)
}

write_ushort :: proc(buf: ^[dynamic]byte, v: u16) {
	append(buf, u8(v >> 8), u8(v & 0xFF))
}

// Parses a VarInt out of an in-memory byte slice, advancing `pos`.
read_varint_bytes :: proc(data: []u8, pos: ^int) -> i32 {
	result: i32 = 0
	shift: uint = 0
	for {
		b := data[pos^]
		pos^ += 1
		result |= i32(b & 0x7F) << shift
		if b & 0x80 == 0 {
			break
		}
		shift += 7
	}
	return result
}

read_string_bytes :: proc(data: []u8, pos: ^int) -> string {
	length := read_varint_bytes(data, pos)
	s := string(data[pos^:pos^ + int(length)])
	pos^ += int(length)
	return s
}

// ---------------------------------------------------------------------
// Raw socket I/O
// ---------------------------------------------------------------------

read_exact :: proc(sock: net.TCP_Socket, n: int) -> ([]u8, bool) {
	data := make([]u8, n)
	total := 0
	for total < n {
		got, err := net.recv_tcp(sock, data[total:])
		if err != nil || got == 0 {
			delete(data)
			return nil, false
		}
		total += got
	}
	return data, true
}

read_varint_socket :: proc(sock: net.TCP_Socket) -> (i32, bool) {
	result: i32 = 0
	shift: uint = 0
	for {
		b, ok := read_exact(sock, 1)
		if !ok {
			return 0, false
		}
		byte_val := b[0]
		delete(b)
		result |= i32(byte_val & 0x7F) << shift
		if byte_val & 0x80 == 0 {
			break
		}
		shift += 7
		if shift >= 35 {
			return 0, false // malformed VarInt
		}
	}
	return result, true
}

// Reads one full packet: returns packet_id, payload (id already stripped), ok
read_packet :: proc(sock: net.TCP_Socket) -> (packet_id: i32, payload: []u8, ok: bool) {
	length, ok1 := read_varint_socket(sock)
	if !ok1 {
		return 0, nil, false
	}
	raw, ok2 := read_exact(sock, int(length))
	if !ok2 {
		return 0, nil, false
	}
	pos := 0
	packet_id = read_varint_bytes(raw, &pos)
	payload = raw[pos:]
	return packet_id, payload, true
}

send_packet :: proc(sock: net.TCP_Socket, packet_id: i32, body: []u8) -> bool {
	inner: [dynamic]byte
	defer delete(inner)
	write_varint(&inner, packet_id)
	append(&inner, ..body)

	header: [dynamic]byte
	defer delete(header)
	write_varint(&header, i32(len(inner)))

	_, err1 := net.send_tcp(sock, header[:])
	_, err2 := net.send_tcp(sock, inner[:])
	return err1 == nil && err2 == nil
}

// ---------------------------------------------------------------------
// Handshake + Login
// ---------------------------------------------------------------------

PROTOCOL_VERSION :: 47

do_handshake :: proc(sock: net.TCP_Socket, host: string, port: u16) -> bool {
	body: [dynamic]byte
	defer delete(body)
	write_varint(&body, PROTOCOL_VERSION)
	write_string(&body, host)
	write_ushort(&body, port)
	write_varint(&body, 2) // next state: login
	return send_packet(sock, 0x00, body[:])
}

do_login_start :: proc(sock: net.TCP_Socket, username: string) -> bool {
	body: [dynamic]byte
	defer delete(body)
	write_string(&body, username)
	return send_packet(sock, 0x00, body[:])
}

// Drives login until we're in Play state (Login Success) or get disconnected.
// Handles Set Compression; does NOT handle Encryption Request (online mode).
login_flow :: proc(sock: net.TCP_Socket) -> bool {
	for {
		packet_id, payload, ok := read_packet(sock)
		if !ok {
			fmt.eprintln("connection closed during login")
			return false
		}
		switch packet_id {
		case 0x00: // Disconnect
			pos := 0
			reason := read_string_bytes(payload, &pos)
			fmt.eprintln("disconnected during login:", reason)
			return false
		case 0x01: // Encryption Request — online mode, not handled yet
			fmt.eprintln("server requires online-mode auth (Encryption Request) — not implemented")
			return false
		case 0x02: // Login Success
			pos := 0
			uuid := read_string_bytes(payload, &pos)
			name := read_string_bytes(payload, &pos)
			fmt.println("logged in as", name, uuid)
			return true
		case 0x03:
			// Set Compression — payload is a VarInt threshold.
			// If threshold >= 0, all subsequent packets are compressed
			// (extra VarInt data-length prefix per packet). Not handled
			// in this skeleton — disable compression server-side while
			// testing, or add compression support before relying on this.
			fmt.eprintln("server enabled compression — extend read_packet/send_packet to handle it")
		}
	}
}

// ---------------------------------------------------------------------
// Play state — enough to stay connected and look like a real client
// ---------------------------------------------------------------------

send_client_settings :: proc(sock: net.TCP_Socket) -> bool {
	body: [dynamic]byte
	defer delete(body)
	write_string(&body, "en_US")     // locale
	append(&body, u8(8))             // view distance
	write_varint(&body, 0)           // chat mode: enabled
	append(&body, u8(1))             // chat colors: true
	append(&body, u8(0x7F))          // displayed skin parts: all
	write_varint(&body, 1)           // main hand: right (1.9+ field, harmless to include/omit per your target)
	return send_packet(sock, 0x15, body[:])
}

send_brand :: proc(sock: net.TCP_Socket, brand: string) -> bool {
	body: [dynamic]byte
	defer delete(body)
	write_string(&body, "MC|Brand")
	write_string(&body, brand)
	return send_packet(sock, 0x17, body[:])
}

send_keep_alive :: proc(sock: net.TCP_Socket, id: i32) -> bool {
	body: [dynamic]byte
	defer delete(body)
	write_varint(&body, id)
	return send_packet(sock, 0x00, body[:])
}

play_loop :: proc(sock: net.TCP_Socket) {
	sent_settings := false

	for {
		packet_id, payload, ok := read_packet(sock)
		if !ok {
			fmt.println("disconnected")
			return
		}

		switch packet_id {
		case 0x00: // Keep Alive (clientbound)
			pos := 0
			id := read_varint_bytes(payload, &pos)
			send_keep_alive(sock, id)

		case 0x01: // Join Game
			// Parse EID/gamemode/dimension/difficulty/max players/level type
			// here if you need them. Real clients send Client Settings and
			// the brand plugin message right after joining — do the same.
			if !sent_settings {
				send_client_settings(sock)
				send_brand(sock, "vanilla") // swap for your own bot's brand string
				sent_settings = true
			}

		case 0x02: // Chat Message
			pos := 0
			json_chat := read_string_bytes(payload, &pos)
			fmt.println("chat:", json_chat)

		case 0x40: // Disconnect (play)
			pos := 0
			reason := read_string_bytes(payload, &pos)
			fmt.println("kicked:", reason)
			return

		case:
			// Everything else (chunk data, entity updates, time update,
			// health, etc.) — ignore for now, or parse as your bot needs.
		}
	}
}

// ---------------------------------------------------------------------

main :: proc() {
	host := "127.0.0.1"
	port: u16 = 25565
	username := "OdinBot"

	endpoint, resolve_err := net.resolve_ip4(host)
	if resolve_err != nil {
		fmt.eprintln("resolve failed:", resolve_err)
		os.exit(1)
	}

	sock, dial_err := net.dial_tcp(net.Endpoint{address = endpoint.address, port = int(port)})
	if dial_err != nil {
		fmt.eprintln("connect failed:", dial_err)
		os.exit(1)
	}
	defer net.close(sock)

	if !do_handshake(sock, host, port) {
		fmt.eprintln("handshake failed")
		os.exit(1)
	}
	if !do_login_start(sock, username) {
		fmt.eprintln("login start failed")
		os.exit(1)
	}
	if !login_flow(sock) {
		os.exit(1)
	}

	play_loop(sock)
}
