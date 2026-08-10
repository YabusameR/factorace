extends Control

## 画面遷移だけを担当するルート。タイトル → ステージ選択 → ゲーム。

const TITLE_SCENE := preload("res://scenes/title.tscn")
const STAGE_SELECT_SCENE := preload("res://scenes/stage_select.tscn")
const GAME_SCENE := preload("res://scenes/game.tscn")
const SHOP_SCENE := preload("res://scenes/shop.tscn")

@onready var _host: Control = %ScreenHost

var _current: Control = null


func _ready() -> void:
	SaveData.load_data()
	show_title()


func show_title() -> void:
	var screen := TITLE_SCENE.instantiate()
	screen.start_requested.connect(show_stage_select)
	_swap(screen)


func show_stage_select() -> void:
	var screen := STAGE_SELECT_SCENE.instantiate()
	screen.stage_selected.connect(show_game)
	screen.shop_requested.connect(show_shop)
	screen.back_requested.connect(show_title)
	_swap(screen)


func show_shop() -> void:
	var screen := SHOP_SCENE.instantiate()
	screen.back_requested.connect(show_stage_select)
	_swap(screen)


func show_game(stage_id: String) -> void:
	var screen := GAME_SCENE.instantiate()
	screen.stage_id = stage_id
	screen.exit_requested.connect(show_stage_select)
	_swap(screen)


func _swap(screen: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = screen
	_host.add_child(screen)
