extends Node

const NETWORK_MODE_MASTER = 1
const NETWORK_MODE_SLAVE = 2
const PLAYERS_PATH = "players/"

onready var ui = get_node("ui")
onready var world = get_parent().get_node("world")

slave var name = "Player"

var players = {}

func _ready():
	ui.connect("server_started", self, "_on_server_started")
	ui.connect("server_stopped", self, "_on_server_stopped")

	var t = get_tree()
	t.connect("network_peer_connected", self, "_network_peer_connected")
	t.connect("network_peer_disconnected", self, "_network_peer_disconnected")

#	t.connect("connected_to_server", self, "_connected_to_server")
#	t.connect("connection_failed", self, "_connection_failed")
#	t.connect("server_disconnected", self, "_server_disconnected")

func _on_server_started(ctx):
	print("Starting server")
	ui.add_message("Starting server")

	if !host_game(ctx["ip_address"], ctx["port"], ctx["max_clients"]):
		ui.add_message(str("Unable to start server on ip:port ", ctx["ip_address"], ":", ctx["port"]))

func _on_server_stopped():
	print("Stopping server")
	ui.add_message("Stopping server")
	get_tree().call_deferred("set_network_peer", null)

func _network_peer_connected(id):
	ui.add_message(str("_network_peer_connected ", id))
	if get_tree().is_network_server():
		players[id] = null

func _network_peer_disconnected(id):
	ui.add_message(str("_network_peer_disconnected ", id))
	if get_tree().is_network_server() && players.has(id):
		player_disconnected(id)
		players.erase(id)

#func _connected_to_server():
#	ui.add_message("_connected_to_server")
#	rpc("player_joined", get_tree().get_network_unique_id(), name)

#func _connection_failed():
#	print("Failed connecting to the server")
#	ui.add_message("_connection_failed")

#func _server_disconnected():
#	print("Disconnected from server")
#	ui.add_message("_server_disconnected")

func host_game(ip, port, max_clients):
	var net = NetworkedMultiplayerENet.new()
	net.set_bind_ip(ip)
	#net.set_compression_mode(net.COMPRESS_ZLIB)

	if net.create_server(port, max_clients) != OK:
		print("Cannot create a server on ip:port ", ip, ":", port, "!")
		ui.add_message(str("Cannot create a server on ip:port ", ip, ":", port, "!"))
		return false

	print("Server hosted on ip:port ", ip, ":", port, ".")
	ui.add_message(str("Server hosted on ip:port ", ip, ":", port, "."))
	print("Max clients: ", max_clients)
	ui.add_message(str("Max clients: ", max_clients))

	get_tree().set_network_peer(net)
	#create_world()
	return true

func player_connected(id):
	if id != 1:
		rpc_id(id, "create_world")

func player_disconnected(id):
	rpc("despawn_player", id)

func get_player_by_id(id):
	var path = PLAYERS_PATH + str(id)
	if !world.has_node(path):
		return null

	return world.get_node(path)

func get_players():
	var ret = []
	for i in world.get_node(PLAYERS_PATH).get_children():
		if !players.has(i.get_name().to_int()):
			continue
		ret.append(i)
	return ret

func world_ready():
	if !get_tree().is_network_server():
		rpc("player_ready", get_tree().get_network_unique_id())





master func player_joined(id, name):
	ui.add_message(str("player_joined id:name ", id, ":", name))
	if !players.has(id) || players[id] != null || !get_tree().is_network_server():
		return

	players[id] = name
	player_connected(id)

master func player_ready(id):
	ui.add_message(str("player_ready id ", id))
	if !players.has(id) || players[id] == null || !get_tree().is_network_server():
		return

	if id != 1:
		rpc_id(id, "clean_players")

		for i in world.get_node(PLAYERS_PATH).get_children():
			var pid = i.get_name().to_int()
			if pid == id:
				continue

			var pos = i.get_global_transform().origin
			rpc_id(id, "spawn_player", pid, players[pid], pos)

	var spawn_pos = Vector2(0, 0)
	rpc("spawn_player", id, players[id], spawn_pos)
	ui.add_message(str(players[id], " connected."))

sync func spawn_player(id, name, pos = null):
	ui.add_message(str("spawn_player id:name ", id, ":", name))
	if get_player_by_id(id) != null:
		return

	var inst = Node2D.new()
	inst.set_name(str(id))
	#inst.player_name = str(name)

	world.get_node(PLAYERS_PATH).add_child(inst)

sync func despawn_player(id):
	var node = get_player_by_id(id)
	if node != null:
		node.queue_free()
