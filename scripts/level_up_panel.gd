extends CanvasLayer


signal closed


@onready var _card0: PanelContainer = $CenterContainer/HBoxContainer/Card0
@onready var _card1: PanelContainer = $CenterContainer/HBoxContainer/Card1
@onready var _card2: PanelContainer = $CenterContainer/HBoxContainer/Card2


var _connected: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false


func show_offer(offers: Array, player: Node, manager: Node) -> void:
	if offers.is_empty():
		return
	var cards: Array = [_card0, _card1, _card2]
	_disconnect_all()
	for i in cards.size():
		var card: PanelContainer = cards[i]
		if i >= offers.size():
			card.visible = false
			continue
		card.visible = true
		var offer: Dictionary = offers[i]
		_apply_offer_to_card(card, offer)
		var button: Button = card.get_node("VBoxContainer/SelectButton") as Button
		var skill_id: String = String(offer["id"])
		var cb: Callable = func() -> void:
			_on_pick(skill_id, player, manager)
		button.pressed.connect(cb)
		_connected.append({"btn": button, "cb": cb})
	visible = true
	get_tree().paused = true


func _on_pick(skill_id: String, player: Node, manager: Node) -> void:
	if is_instance_valid(manager) and manager.has_method("acquire"):
		manager.acquire(skill_id, player)
	_disconnect_all()
	visible = false
	get_tree().paused = false
	closed.emit()


func _disconnect_all() -> void:
	for entry in _connected:
		var btn: Button = entry["btn"]
		var cb: Callable = entry["cb"]
		if is_instance_valid(btn) and btn.pressed.is_connected(cb):
			btn.pressed.disconnect(cb)
	_connected.clear()


func _apply_offer_to_card(card: PanelContainer, offer: Dictionary) -> void:
	var band: ColorRect = card.get_node("VBoxContainer/ColorBand") as ColorRect
	var name_label: Label = card.get_node("VBoxContainer/NameLabel") as Label
	var desc_label: Label = card.get_node("VBoxContainer/DescLabel") as Label
	band.color = Color(String(offer["color"]))
	var title: String = String(offer["name"])
	if bool(offer.get("owned", false)):
		var cur_lv: int = int(offer.get("current_level", 1))
		title += " (Lv %d → Lv %d)" % [cur_lv, cur_lv + 1]
	name_label.text = title
	desc_label.text = String(offer["desc"])
