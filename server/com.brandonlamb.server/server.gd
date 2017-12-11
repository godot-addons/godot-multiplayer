extends Node

const Settings = preload("res://com.brandonlamb.server/settings.gd")
const Result = preload("res://com.brandonlamb.server/result.gd")

signal network_peer_connected(id)
signal network_peer_disconnected(id)

var tree
var settings
var is_running
var host
var peers

func _init(tree_, settings_ = Settings.new()):
	tree = tree_
	settings = settings_
	is_running = false
	peers = {}

"""
Start the server. Returns a Result object.
"""
func start():
	# If host is not null then it must already be running, return error
	if host != null:
		return Result.new(false, "Host is already defined")

	# Create new ENet host and bind to IP defined in settings
	host = NetworkedMultiplayerENet.new()
	host.set_bind_ip(settings.ip)
	#net.set_compression_mode(host.COMPRESS_ZLIB)

	# If host is null, we were not able to create the host, return error
	if host == null:
		return Result.new(false, "Could not create ENet host")

	# Create server on host, return error if result is not OK
	var server = host.create_server(
		settings.port,
		settings.max_peers,
		settings.outbound_bandwidth,
		settings.incoming_bandwidth
	)

	if server != OK:
		return Result.new(false, str("Cannot create a server: ip=", settings.ip, ", port=", settings.port, "!"))

	# Listen for network signals
	tree.connect("network_peer_connected", self, "_network_peer_connected")
	tree.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	# Set the host as the root network peer, which will be what enables the RPC call magic to happen
	tree.set_network_peer(host)

	is_running = true

	return Result.new(true, "ENet host started")

"""
Stop the server
"""
func stop():
	# If host is null, return error
	if host == null:
		return Result.new(false, "Host not running")

	# Disconnect signals
	tree.disconnect("network_peer_connected", self, "_network_peer_connected")
	tree.disconnect("network_peer_disconnected", self, "_network_peer_disconnected")

	# Cleanup
	host.close_connection()
	host = null
	tree.call_deferred("set_network_peer", null)

	return Result.new(true, "Host successfully destroyed")

"""
Signal handler for when a peer connects.
Adds the peer to peers dictionary by its ID.
@param id integer peer's id
"""
func _network_peer_connected(id):
	emit_signal("network_peer_connected", id)

	if tree.is_network_server():
		peers[id] = null

"""
Signal handler for when a peer disconnects.
Disconnect the peer and cleanup any scene tree nodes
@param id integer peer's id
"""
func _network_peer_disconnected(id):
	emit_signal("network_peer_disconnected", id)

	if tree.is_network_server() && peers.has(id):
		peers.erase(id)
