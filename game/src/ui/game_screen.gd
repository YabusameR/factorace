extends Control

## ゲーム画面。工場の組み立て → 稼働 → クリア判定までを回す。
##
## 操作:
##   左ドラッグ … 選択中のパーツを設置
##   右ドラッグ … 撤去
##   1〜9      … パーツ選択
##   R         … 向きを回転
##   Space     … 稼働開始 / 一時停止
##   Esc       … ステージ選択へ戻る

signal exit_requested

## App から instantiate 直後に代入される。_ready でこれを見てステージを組む。
var stage_id := ""

var _stage: Dictionary = {}
var _factory: Factory = null
var _selected_def := ""
var _dir := 0
var _erase_mode := false
var _result_shown := false
var _palette_buttons: Array = []

@onready var _view: FactoryView = %FactoryView
@onready var _stage_label: Label = %StageLabel
@onready var _goal_label: Label = %GoalLabel
@onready var _parts_label: Label = %PartsLabel
@onready var _time_label: Label = %TimeLabel
@onready var _best_label: Label = %BestLabel
@onready var _palette_list: VBoxContainer = %PaletteList
@onready var _info_label: Label = %InfoLabel
@onready var _power_label: Label = %PowerLabel
@onready var _start_button: Button = %StartButton
@onready var _erase_button: Button = %EraseButton
@onready var _result_layer: Control = %ResultLayer


func _ready() -> void:
	_stage = Stages.get_stage(stage_id)
	if _stage.is_empty():
		push_error("不明なステージID: %s" % stage_id)
		_stage_label.text = "ステージが見つかりません"
		return

	_factory = Factory.new()
	_factory.setup(_stage)
	_view.factory = _factory
	_view.cell_painted.connect(_on_cell_painted)
	_view.cell_erased.connect(_on_cell_erased)

	_stage_label.text = String(_stage.name)
	%HintLabel.text = String(_stage.hint)
	%ParLabel.text = Stages.par_text(_stage)

	_start_button.pressed.connect(_toggle_run)
	%ResetButton.pressed.connect(_reset_run)
	%ClearButton.pressed.connect(_clear_layout)
	%BackButton.pressed.connect(func() -> void: exit_requested.emit())
	_erase_button.toggled.connect(_set_erase_mode)
	%RotateButton.pressed.connect(_rotate)
	%RetryButton.pressed.connect(_reset_run)
	%ToSelectButton.pressed.connect(func() -> void: exit_requested.emit())

	_build_palette()
	_power_label.visible = _factory.power_enabled
	_result_layer.visible = false
	_refresh_best_label()
	_update_hud()


func _process(delta: float) -> void:
	if _factory == null:
		return
	_factory.advance(delta)
	_view.queue_redraw()
	_update_hud()
	if _factory.cleared and not _result_shown:
		_show_result()


# --------------------------------------------------------------------------
# パレット
# --------------------------------------------------------------------------


func _build_palette() -> void:
	for child in _palette_list.get_children():
		_palette_list.remove_child(child)
		child.queue_free()
	_palette_buttons.clear()

	var palette: Array = _stage.palette
	for i in palette.size():
		var def_id := String(palette[i])
		var def := Defs.building(def_id)
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text = "%d. %s" % [i + 1, def.name]
		button.tooltip_text = Defs.building_detail(def_id)
		button.pressed.connect(_select_def.bind(def_id))
		_palette_list.add_child(button)
		_palette_buttons.append(button)

	if not palette.is_empty():
		_select_def(String(palette[0]))


func _select_def(def_id: String) -> void:
	_selected_def = def_id
	if _erase_mode:
		_erase_button.button_pressed = false
	var palette: Array = _stage.palette
	for i in _palette_buttons.size():
		_palette_buttons[i].set_pressed_no_signal(String(palette[i]) == def_id)
	_view.ghost_def = def_id
	_view.ghost_dir = _dir
	_update_info()


func _set_erase_mode(enabled: bool) -> void:
	_erase_mode = enabled
	_view.erase_mode = enabled
	if enabled:
		for button in _palette_buttons:
			button.set_pressed_no_signal(false)
	elif _selected_def != "":
		_select_def(_selected_def)
	_update_info()


func _rotate() -> void:
	_dir = (_dir + 1) % Defs.DIR_VECTORS.size()
	_view.ghost_dir = _dir
	_update_info()


func _update_info() -> void:
	if _erase_mode:
		_info_label.text = "撤去モード\n盤面をドラッグすると設置物を取り除く。"
		return
	if _selected_def == "":
		_info_label.text = ""
		return
	_info_label.text = "%s\n向き: %s(Rキーで回転)" % [
		Defs.building_detail(_selected_def), Defs.DIR_NAMES[_dir]
	]


# --------------------------------------------------------------------------
# 盤面操作
# --------------------------------------------------------------------------


func _on_cell_painted(pos: Vector2i) -> void:
	if _selected_def == "":
		return
	_factory.place(pos, _selected_def, _dir)


func _on_cell_erased(pos: Vector2i) -> void:
	_factory.remove(pos)


# --------------------------------------------------------------------------
# 稼働制御
# --------------------------------------------------------------------------


func _toggle_run() -> void:
	if _factory == null or _factory.cleared:
		return
	_factory.running = not _factory.running
	_start_button.text = "一時停止" if _factory.running else "稼働開始"


func _reset_run() -> void:
	if _factory == null:
		return
	_factory.reset_run()
	_result_shown = false
	_result_layer.visible = false
	_start_button.text = "稼働開始"


func _clear_layout() -> void:
	if _factory == null:
		return
	_factory.clear_all()
	_reset_run()


func _show_result() -> void:
	_result_shown = true
	var time := _factory.elapsed
	var improved := SaveData.submit_time(stage_id, time)
	var rank := Stages.rank_label(_stage, time)

	%ResultTitle.text = "クリア!"
	%ResultTime.text = "タイム  %s" % SaveData.format_time(time)
	%ResultRank.text = rank
	%ResultRank.add_theme_color_override("font_color", Stages.rank_color(rank))
	%ResultBest.text = (
		"自己ベスト更新!" if improved else "ベスト %s" % SaveData.format_time(
			SaveData.best_time(stage_id)
		)
	)
	%ResultParts.text = "使用パーツ %d 個" % _factory.part_count()
	_start_button.text = "稼働開始"
	_refresh_best_label()
	_result_layer.visible = true


func _refresh_best_label() -> void:
	_best_label.text = "ベスト %s" % SaveData.format_time(SaveData.best_time(stage_id))


func _update_hud() -> void:
	if _factory == null:
		return
	_goal_label.text = "目標 %s  %d / %d" % [
		Defs.item_name(_factory.target_item), _factory.delivered, _factory.target_count
	]
	_parts_label.text = "パーツ %d" % _factory.part_count()
	_time_label.text = "TIME %s" % SaveData.format_time(_factory.elapsed)
	if _factory.power_enabled:
		_update_power_label()


## 動力の収支。過負荷や回転数の矛盾は、稼働前に気づけるようここで出す。
func _update_power_label() -> void:
	var power: Dictionary = _factory.power.summary()
	var lines := PackedStringArray(
		["動力  消費 %.1f / 供給 %.1f" % [float(power.demand), float(power.capacity)]]
	)
	var color := Color(0.72, 0.86, 1.0)
	if bool(power.conflict):
		lines.append("回転数が矛盾している。増速機・減速機の向きを見直そう。")
		color = Color(1.0, 0.55, 0.45)
	elif bool(power.overstressed):
		lines.append("過負荷。この系統の機械はすべて止まる。")
		color = Color(1.0, 0.55, 0.45)
	_power_label.text = "\n".join(lines)
	_power_label.add_theme_color_override("font_color", color)


# --------------------------------------------------------------------------
# キー操作
# --------------------------------------------------------------------------


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _factory == null:
		return
	var code := key.keycode
	if code == KEY_R:
		_rotate()
	elif code == KEY_SPACE:
		_toggle_run()
	elif code == KEY_ESCAPE:
		exit_requested.emit()
	elif code == KEY_X:
		_erase_button.button_pressed = not _erase_button.button_pressed
	elif code >= KEY_1 and code <= KEY_9:
		var index: int = code - KEY_1
		var palette: Array = _stage.palette
		if index >= palette.size():
			return
		_select_def(String(palette[index]))
	else:
		return
	get_viewport().set_input_as_handled()
