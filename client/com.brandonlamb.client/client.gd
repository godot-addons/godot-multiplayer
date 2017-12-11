extends Node

const Settings = preload("res://com.brandonlamb.client/settings.gd")
const Result = preload("res://com.brandonlamb.client/result.gd")

signal network_peer_connected(id)
signal network_peer_disconnected(id)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()

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
Start the client
"""
func start():
	if host != null:
		return Result.new(false, "Host already connected")

	host = NetworkedMultiplayerENet.new()
	#host.set_compression_mode(host.COMPRESS_ZLIB)

	var client = host.create_client(
		settings.ip,
		settings.port,
		settings.outbound_bandwidth,
		settings.incoming_bandwidth
	)

	if client != OK:
		return Result.new(false, str("Cannot create a client: ip=", settings.ip, ", port=", settings.port, "!"))

	# Listen for network signals
	tree.connect("network_peer_connected", self, "_network_peer_connected")
	tree.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	tree.connect("connected_to_server", self, "_connected_to_server")
	tree.connect("connection_failed", self, "_connection_failed")
	tree.connect("server_disconnected", self, "_server_disconnected")

	# Set the host as the root network peer, which will be what enables the RPC call magic to happen
	tree.set_network_peer(host)

	return Result.new(true, "ENet host started")


"""
Stop the client
"""
func stop():
	if host == null:
		return Result.new(false, "Host not running")

	# Disconnect signals
	tree.disconnect("network_peer_connected", self, "_network_peer_connected")
	tree.disconnect("network_peer_disconnected", self, "_network_peer_disconnected")

	tree.disconnect("connected_to_server", self, "_connected_to_server")
	tree.disconnect("connection_failed", self, "_connection_failed")
	tree.disconnect("server_disconnected", self, "_server_disconnected")

	# Cleanup
	host.close_connection()
	tree.call_deferred("set_network_peer", null)
	host = null

	return Result.new(true, "Host successfully destroyed")

"""
Signal handler for when a game server connects to us, we should receive ID=1
@param id integer
"""
func _network_peer_connected(id):
	emit_signal("network_peer_connected", id)

	if tree.is_network_server():
		peers[id] = null

"""
Signal handler for when a game server disconnects from us, we should receive ID=1
Does not fire when we disconnect from server. Example: server boots client from game.
@param id integer
"""
func _network_peer_disconnected(id):
	emit_signal("network_peer_disconnected", id)

"""
Signal handler for when client connects to game server. This is where we might
call some initial setup functions.
"""
func _connected_to_server():
	emit_signal("connected_to_server")

"""
Signal handler for when client is unable to connect to the server. We could
call some error handling functions to provide the user feedback.
"""
func _connection_failed():
	emit_signal("connection_failed")

"""
Signal handler for when the server connects. Example: server shuts down
"""
func _server_disconnected():
	emit_signal("server_disconnected")
