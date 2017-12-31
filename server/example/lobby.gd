extends Node

const Server = preload("res://com.brandonlamb.server/server.gd")
const Settings = preload("res://com.brandonlamb.server/settings.gd")

#const NETWORK_MODE_MASTER = 1
#const NETWORK_MODE_SLAVE = 2
const PLAYERS_PATH = "players/"

onready var ui = get_node("ui")
onready var world = get_parent().get_node("world")

slave var name = "Player"

var server

func _ready():
	# Listen for server start/stop signals
	ui.connect("server_started", self, "_on_server_started")
	ui.connect("server_stopped", self, "_on_server_stopped")

"""
Host a new game. Create a network server and bind to ip:port.
@param ip string
@param port integer
@param max_clients integer
@return bool
"""
func host_game(ip, port, max_clients):
	if server != null:
		print("Server already running")
		return false

	# Create new server, need to pass in scene tree and settings object
	server = Server.new(get_tree(), Settings.new(ip, port, max_clients, 0, 0))

	# Listen for network signals
	server.connect("network_peer_connected", self, "_network_peer_connected")
	server.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	var r = server.start()

	if !r.status:
		print(r.message)
		ui.add_message(r.message)
		return false

	print(r.message)
	ui.add_message(r.message)

	print("Max clients: ", server.settings.max_peers)
	ui.add_message(str("Max clients: ", server.settings.max_peers))

	#create_world()
	return true

"""
Signal handler for when the "Start Server" button is clicked
@param ctx { ip_address, port, max_clients }
"""
func _on_server_started(ctx):
	print("Starting server")
	ui.add_message("Starting server")

	if !host_game(ctx["ip_address"], ctx["port"], ctx["max_clients"]):
		print("Unable to start server on ip:port ", ctx["ip_address"], ":", ctx["port"])
		ui.add_message(str("Unable to start server on ip:port ", ctx["ip_address"], ":", ctx["port"]))

"""
Signal handler for when the "Stop Server" button is clicked
"""
func _on_server_stopped():
	print("Stopping server")
	ui.add_message("Stopping server")

	# Stop server, log result
	var r = server.stop()
	print(r.message)
	ui.add_message(r.message)

	server = null

"""
Signal handler for when a client connects.
@param id integer player's id
"""
func _network_peer_connected(id):
	print("_network_peer_connected: id=", id)
	ui.add_message(str("_network_peer_connected: id=", id))

"""
Signal handler for when a client disconnects.
Disconnect the player and cleanup any scene tree nodes
@param id integer player's id
"""
func _network_peer_disconnected(id):
	print("_network_peer_disconnected: id=", id)
	ui.add_message(str("_network_peer_disconnected: id=", id))

	rpc("despawn_player", id)

func get_player_by_id(id):
	var path = PLAYERS_PATH + str(id)
	if !world.has_node(path):
		return null

	return world.get_node(path)

func get_players():
	var ret = []
	for i in world.get_node(PLAYERS_PATH).get_children():
		if !server.peers.has(i.get_name().to_int()):
			continue
		ret.append(i)
	return ret

"""
Called by world on ready
"""
func world_ready():
	if !get_tree().is_network_server():
		rpc("player_ready", get_tree().get_network_unique_id())

#
# RPC functions
#

master func player_joined(id, name):
	print("player_joined: id=", id, ", name=", name)
	ui.add_message(str("player_joined: id=", id, ", name=", name))

	if !server.peers.has(id) || server.peers[id] != null || !get_tree().is_network_server():
		return

	server.peers[id] = name

	# Tell the client to run create_world
	if id != 1:
		rpc_id(id, "create_world")

master func player_ready(id):
	print("player_ready: id=", id)
	ui.add_message(str("player_ready: id=", id))

	if !server.peers.has(id) || server.peers[id] == null || !get_tree().is_network_server():
		return

	# Tell the client to run clean_players
	if id != 1:
		rpc_id(id, "clean_players")

		for i in world.get_node(PLAYERS_PATH).get_children():
			var pid = i.get_name().to_int()
			if pid == id:
				continue

			var pos = i.get_global_transform().origin
			if server.peers.has(pid):
				rpc_id(id, "spawn_player", pid, server.peers[pid], pos)

	var spawn_pos = Vector2(0, 0)
	rpc("spawn_player", id, server.peers[id], spawn_pos)
	ui.add_message(str(server.peers[id], " connected."))

sync func spawn_player(id, name, pos = null):
	print("spawn_player: id=", id, ", name=", name)
	ui.add_message(str("spawn_player: id=", id, ", name=", name))

	if get_player_by_id(id) != null:
		return

	var inst = Node2D.new()
	inst.set_name(str(id))
	#inst.player_name = str(name)

	world.get_node(PLAYERS_PATH).add_child(inst)

sync func despawn_player(id):
	print("despawn_player: id=", id)
	ui.add_message(str("despawn_player: id=", id))

	var node = get_player_by_id(id)
	if node != null:
		node.queue_free()
