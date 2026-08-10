extends Control

signal stage_selected(stage_id: String)
signal shop_requested
signal back_requested

const DIM := Color(0.68, 0.72, 0.78)


func _ready() -> void:
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	%ShopButton.pressed.connect(func() -> void: shop_requested.emit())
	%MoneyLabel.text = "資金 %s" % SaveData.format_money(SaveData.money())
	_build_list()


func _build_list() -> void:
	var list: VBoxContainer = %StageList
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for i in Stages.count():
		var stage: Dictionary = Stages.LIST[i]
		var unlocked := Stages.is_unlocked(i)
		var best := SaveData.best_time(stage.id)

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var button := Button.new()
		button.disabled = not unlocked
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 40)
		button.clip_text = true
		if unlocked:
			var best_text := "未クリア"
			if best >= 0.0:
				best_text = "ベスト %s(%s)" % [
					SaveData.format_time(best), Stages.rank_label(stage, best)
				]
			button.text = "%s      %s" % [stage.name, best_text]
			button.tooltip_text = Stages.par_text(stage)
			var stage_id := String(stage.id)
			button.pressed.connect(func() -> void: stage_selected.emit(stage_id))
		else:
			button.text = "%s      (前のステージをクリアすると解放)" % stage.name
		row.add_child(button)

		var desc := Label.new()
		desc.text = "    %s" % stage.desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", DIM)
		desc.add_theme_font_size_override("font_size", 13)
		row.add_child(desc)

		list.add_child(row)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		back_requested.emit()
		get_viewport().set_input_as_handled()
