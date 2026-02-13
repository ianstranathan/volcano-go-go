extends Control

@export var slots_container: VBoxContainer
@export var status_label: Label
@export var ip_input: LineEdit
@export var name_input: LineEdit
@export var host_btn: Button
@export var join_btn: Button
@export var leave_btn: Button
@export var start_btn: Button

var player_slots := {}  # peer_id -> slot node

func _ready() -> void:
	NetManager.peer_disconnected.connect(_on_player_left)
	NetManager.player_info_updated.connect(_on_player_info_updated)
	NetManager.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	NetManager.host(player_name)
	
	status_label.text = "Hosting"
	_update_ui_state()

func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter an IP address"
		return
	
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	
	NetManager.join(ip, player_name)
	status_label.text = "Connecting to %s..." % ip
	_update_ui_state()

func _on_leave_pressed() -> void:
	NetManager.leave()
	_clear_all_slots()
	status_label.text = "Disconnected"
	_update_ui_state()

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		_load_game.rpc()

func _on_player_info_updated(peer_id: int, player_name: String, _spawn_index: int) -> void:
	if peer_id in player_slots:
		var slot = player_slots[peer_id]
		var label = slot.get_child(0).get_child(0) as Label
		label.text = player_name
	else:
		_add_slot(peer_id)
		_update_ui_state()
	
	# Update status when client connects (not host, they show IP already)
	if peer_id == multiplayer.get_unique_id() and not multiplayer.is_server():
		status_label.text = "Connected"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"
	_update_ui_state()

func _on_server_disconnected() -> void:
	# Server kicked us or disconnected
	NetManager.leave()
	_clear_all_slots()
	status_label.text = "Disconnected from server"
	_update_ui_state()

func _on_player_left(id: int) -> void:
	_remove_slot(id)
	_update_ui_state()

func _add_slot(peer_id: int) -> void:
	if peer_id in player_slots:
		return
	
	var slot = _create_slot(peer_id)
	slots_container.add_child(slot)
	player_slots[peer_id] = slot

func _remove_slot(peer_id: int) -> void:
	if peer_id not in player_slots:
		return
	
	var slot = player_slots[peer_id]
	slot.queue_free()
	player_slots.erase(peer_id)

func _clear_all_slots() -> void:
	for slot in player_slots.values():
		slot.queue_free()
	player_slots.clear()

func _create_slot(peer_id: int) -> PanelContainer:
	var slot = PanelContainer.new()
	var hbox = HBoxContainer.new()
	slot.add_child(hbox)
	
	var name_label = Label.new()
	var p_data = NetManager.player_data.get(peer_id)
	var player_name = "Player %d" % peer_id # -- Default fallback
	if p_data:
		player_name = p_data.get(NetManager.KEY_NAME, player_name)
	name_label.text = player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	# Show kick button only if you're server AND it's not you
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		var kick_btn = Button.new()
		kick_btn.text = "Kick"
		kick_btn.pressed.connect(func(): multiplayer.multiplayer_peer.disconnect_peer(peer_id))
		hbox.add_child(kick_btn)
	
	return slot

func _update_ui_state() -> void:
	var has_connection = multiplayer.multiplayer_peer != null
	var is_host = has_connection and multiplayer.is_server()
	
	host_btn.disabled = has_connection
	join_btn.disabled = has_connection
	ip_input.editable = not has_connection
	leave_btn.disabled = not has_connection
	start_btn.disabled = not is_host

@rpc("authority", "call_local", "reliable")
func _load_game() -> void:
	get_tree().change_scene_to_file("res://game/game.tscn")
