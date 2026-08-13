package client

import "core:net"

ServerConnection :: struct {
	sock: net.TCP_Socket
}

connect :: proc(ip: string) -> (ServerConnection, net.Network_Error) {
	endpoint, err := net.resolve_ip4(ip)
	if err != nil { return ServerConnection{}, err }
	sock: net.TCP_Socket; sock, err = net.dial_tcp(endpoint)
	if err != nil { return ServerConnection{}, err }	

	return ServerConnection {
		sock = sock
	}, nil
}

close :: proc(conn: ServerConnection) {
	net.close(conn.sock)
}