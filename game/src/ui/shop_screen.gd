extends Control

## ショップ。便利パーツを資金でアンロックする。
##
## 並ぶのは shop.gd の PRICES にあるものだけ。必須パーツはここに出てこない
## (ステージが最初から使わせるので、買わなくてもクリアはできる)。

signal back_requested

const DIM := Color(0.68, 0.72, 0.78)
const SOLD := Color(0.45, 0.82, 0.55)


func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	_refresh()


func _refresh() -> void:
	%MoneyLabel.text = "資金 %s" % SaveData.format_money(SaveData.money())

	var list: VBoxContainer = %ItemList
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for def_id_raw in Shop.ORDER:
		var def_id := String(def_id_raw)
		var def := Defs.building(def_id)
		var owned := Shop.is_owned(def_id)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		button.clip_text = true
		if owned:
			button.text = "%s      購入済み" % def.name
			button.disabled = true
		else:
			button.text = "%s      %s" % [def.name, SaveData.format_money(Shop.price(def_id))]
			button.disabled = not Shop.can_afford(def_id)
			button.pressed.connect(_buy.bind(def_id))
		row.add_child(button)

		var desc := Label.new()
		desc.text = "    %s" % def.desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", SOLD if owned else DIM)
		desc.add_theme_font_size_override("font_size", 13)
		row.add_child(desc)

		list.add_child(row)


func _buy(def_id: String) -> void:
	if Shop.buy(def_id):
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()
