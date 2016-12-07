extends Node

enum {TCP, UDP}

onready var b_ip_type = get_node("Panel/config/Mode")
onready var b_proto_type = get_node("Panel/config/Proto")
onready var l_log = get_node("Panel/msg/Label")
onready var e_port = get_node("Panel/config/port/LineEdit")
onready var e_send = get_node("Panel/msg/send/LineEdit")

var _connected = false
var ip_type = IP.TYPE_ANY
var proto = TCP

var _udp = PacketPeerUDP.new()
var _tcp = TCP_Server.new()
var _clients = []

func _ready():
	var popup = b_ip_type.get_popup()
	popup.add_item("IPV4")
	popup.add_item("IPV6")
	popup.add_item("ANY")
	popup.connect("item_pressed", self, "_change_ip_type")
	
	popup = b_proto_type.get_popup()
	popup.add_item("TCP")
	popup.add_item("UDP")
	popup.connect("item_pressed", self, "_change_proto_type")
	pass

func _process(delta):
	var msgs = []
	if proto == TCP:
		if _tcp.is_connection_available():
			print("new client")
			var stream = _tcp.take_connection()
			var peer = PacketPeerStream.new()
			peer.set_stream_peer(stream)
			_clients.append([peer, stream])
		var i = 0
		while i < _clients.size() and i >= 0:
			var c = _clients[i]
			# Disconnect dead clients
			if c[1].get_status() != StreamPeerTCP.STATUS_CONNECTED and c[1].get_status() != StreamPeerTCP.STATUS_CONNECTING:
				_clients.remove(i)
				i-=1
				continue
			# Fetch incoming messages
			while c[0].get_available_packet_count() > 0:
				var packet = c[0].get_var()
				if (typeof(packet) == TYPE_STRING):
					print(packet)
					msgs.append(str(c[1].get_connected_host()) + ":" + str(c[1].get_connected_port()) + " > " + packet)
			i+=1
		
		# Send messages
		for c in _clients:
			for msg in msgs:
				c[0].put_var(msg)
	else:
		while _udp.get_available_packet_count() > 0:
			var pkt = _udp.get_var()
			if typeof(pkt) == TYPE_STRING:
				# Check if new client
				var found = false
				for c in _clients:
					if c[0] == _udp.get_packet_ip() and c[1] == _udp.get_packet_port():
						found = true
						break
				if not found:
					print("Adding client")
					_clients.append([_udp.get_packet_ip(), _udp.get_packet_port()])
				# Append message
				msgs.append(_udp.get_packet_ip() + ":" + str(_udp.get_packet_port()) + " > " + pkt + "\n")
		for c in _clients:
			for msg in msgs:
				_udp.set_send_address(c[0], c[1])
				_udp.put_var(msg)
		pass

func _change_ip_type(id):
	if _connected:
		l_log.add_text("* Can't change when connected\n")
		return
	if id == 0:
		ip_type = IP.TYPE_IPV4
		b_ip_type.set_text("IPV4")
	elif id == 1:
		ip_type = IP.TYPE_IPV6
		b_ip_type.set_text("IPV6")
	else:
		ip_type = IP.TYPE_ANY
		b_ip_type.set_text("ANY")
	_tcp.set_ip_type(ip_type)
	_udp.set_ip_type(ip_type)

func _change_proto_type(id):
	if _connected:
		l_log.add_text("* Can't change when connected\n")
		return
	if id == 0:
		proto = TCP
		b_proto_type.set_text("TCP")
	else:
		proto = UDP
		b_proto_type.set_text("UDP")

func _on_listen_toggled( pressed ):
	if pressed:
		do_listen()
	else:
		do_stop()

func do_stop():
	set_process(false)
	if proto == TCP:
		_tcp.stop()
		for c in _clients:
			c[1].disconnect()
	else:
		_udp.close()
	l_log.add_text("Disconnected\n")
	_connected = false
	get_node("Panel/config/listen").set_pressed(false)

func do_listen():
	var port = e_port.get_text()
	if proto == TCP:
		var err = _tcp.listen(int(port))
		if err == OK:
			_connected = true
			l_log.add_text("Listening on TCP port: " + port)
		else:
			l_log.add_text("Failed listen on TCP port: " + port + " -> " + str(err))
	elif proto == UDP:
		var err = _udp.listen(int(port))
		if err == OK:
			_connected = true
			l_log.add_text("Listening on UDP port:" + port)
		else:
			l_log.add_text("Failed to listen on UDP port: " + port + " -> " + str(err))
	l_log.add_text("\n")
	if not _connected:
		do_stop()
		return
	set_process(true)
	pass

func _on_send_pressed():
	if not _connected:
		return
	var data = e_send.get_text()
	if data == null or data.length() < 1:
		return
	var err = OK
	if proto == TCP:
		for c in _clients:
			c[0].put_var("Server said: " + data)
	else:
		for c in _clients:
			_udp.set_send_address(c[0], c[1])
			_udp.put_var("Server said: " + data)
	e_send.set_text("")
