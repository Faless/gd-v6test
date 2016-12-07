extends Node

const JOIN_MSG = "Someone joined"

enum {TCP, UDP}

onready var b_ip_type = get_node("Panel/config/Mode")
onready var b_proto_type = get_node("Panel/config/Proto")
onready var l_log = get_node("Panel/msg/Label")
onready var e_host = get_node("Panel/config/host/LineEdit")
onready var e_port = get_node("Panel/config/port/LineEdit")
onready var e_send = get_node("Panel/msg/send/LineEdit")

var _waiting = false
var _connected = false

var _udp = PacketPeerUDP.new()
var _tcp = StreamPeerTCP.new()
var _tcp_p = PacketPeerStream.new()

var ip_type = IP.TYPE_ANY
var proto = TCP

func _ready():
	_tcp_p.set_stream_peer(_tcp)
	var popup = b_ip_type.get_popup()
	popup.add_item("IPV4")
	popup.add_item("IPV6")
	popup.add_item("ANY")
	popup.connect("item_pressed", self, "_change_ip_type")
	
	popup = b_proto_type.get_popup()
	popup.add_item("TCP")
	popup.add_item("UDP")
	popup.connect("item_pressed", self, "_change_proto_type")

func _process(delta):
	if proto == TCP:
		if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
			_waiting = true
		elif _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if _waiting:
				l_log.add_text("Connected!\n")
				_waiting = false
			while _tcp_p.get_available_packet_count() > 0:
				var pkt = _tcp_p.get_var()
				if typeof(pkt) == TYPE_STRING:
					l_log.add_text(pkt + "\n")
		else:
			print("disconnect")
			do_disconnect()
			return
	else:
		while _udp.get_available_packet_count() > 0:
			var pkt = _udp.get_var()
			if typeof(pkt) == TYPE_STRING:
				l_log.add_text(pkt + "\n")
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

func _on_connect_pressed(pressed):
	if pressed:
		do_connect()
	else:
		do_disconnect()

func do_connect():
	var host = e_host.get_text()
	var port = e_port.get_text()
	var ip_str = host if host.is_valid_ip_address() else host + " (" + IP.resolve_hostname(host, ip_type) + ") "
	if proto == TCP:
		var err = _tcp.connect(e_host.get_text(), int(e_port.get_text()))
		if err == OK:
			_connected = true
			l_log.add_text("Connecting via TCP to: " + ip_str + " : " + port)
		else:
			l_log.add_text("Failed to connect via TCP to: " + ip_str + " : " + port + " -> " + str(err))
	elif proto == UDP:
		_udp.set_send_address(e_host.get_text(), int(e_port.get_text()))
		var err = _udp.put_var(JOIN_MSG)
		if err == OK:
			_connected = true
			l_log.add_text("Connecting via UDP to: " + ip_str + " : " + port)
		else:
			l_log.add_text("Failed to connect via UDP to: " + ip_str + " : " + port + " -> " + str(err))
	l_log.add_text("\n")
	if not _connected:
		do_disconnect()
		return
	set_process(true)

func do_disconnect():
	set_process(false)
	if proto == TCP:
		_tcp.disconnect()
	else:
		_udp.close()
	l_log.add_text("Disconnected\n")
	_connected = false
	get_node("Panel/config/connect").set_pressed(false)

func _on_send_pressed():
	if not _connected:
		return
	var data = e_send.get_text()
	if data == null or data.length() < 1:
		return
	var err = OK
	if proto == TCP:
		if not _tcp.is_connected():
			err = ERR_UNAVAILABLE
		else:
			err =_tcp_p.put_var(data)
	else:
		err = _udp.put_var(data)
	if err != OK:
		l_log.add_text("Unable to send: " + data + " -> " + str(err) + "\n")
	e_send.set_text("")
