var ip
var port
var max_peers
var outbound_bandwidth
var incoming_bandwidth

func _init(
	ip_ = "0.0.0.0",
	port_ = 9000,
	max_peers_ = 32,
	outbound_bandwidth_ = 0,
	incoming_bandwidth_ = 0
):
	ip = ip_
	port = port_
	max_peers = max_peers_
	outbound_bandwidth = outbound_bandwidth_
	incoming_bandwidth = incoming_bandwidth_
