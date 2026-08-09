extends SceneTree

## エディタを開けない環境用の動作確認スクリプト。
##
##   godot --headless --script res://tools/headless_check.gd
##
## 各ステージに「想定解」のレイアウトを組んでシミュレーションを回し、
## クリアできること・そのときのタイムを表示する。par(ランク基準タイム)の調整にも使う。
## 続けて全画面を実際に生成し、_ready / _process が例外なく回ることを確認する。

## [位置, パーツID, 向き] の並び。向きは 0=右 1=下 2=左 3=上。
const LAYOUTS := {
	"s1":
	[
		[Vector2i(1, 4), "belt", 0],
		[Vector2i(2, 4), "belt", 0],
		[Vector2i(3, 4), "belt", 0],
		[Vector2i(4, 4), "belt", 0],
		[Vector2i(5, 4), "belt", 0],
		[Vector2i(6, 4), "belt", 0],
		[Vector2i(7, 4), "belt", 0],
		[Vector2i(8, 4), "belt", 0],
	],
	"s2":
	[
		[Vector2i(1, 4), "belt", 0],
		[Vector2i(2, 4), "belt", 0],
		[Vector2i(3, 4), "splitter", 0],
		[Vector2i(4, 4), "belt", 0],
		[Vector2i(5, 4), "smelter_iron", 0],
		[Vector2i(3, 5), "belt", 0],
		[Vector2i(4, 5), "belt", 0],
		[Vector2i(5, 5), "smelter_iron", 0],
		[Vector2i(6, 5), "belt", 3],
		[Vector2i(6, 4), "belt", 0],
		[Vector2i(7, 4), "belt", 0],
		[Vector2i(8, 4), "belt", 0],
		[Vector2i(9, 4), "belt", 0],
		[Vector2i(10, 4), "belt", 0],
	],
	"s3":
	[
		[Vector2i(1, 5), "belt", 0],
		[Vector2i(2, 5), "belt", 0],
		[Vector2i(3, 5), "splitter", 0],
		[Vector2i(4, 5), "belt", 0],
		[Vector2i(5, 5), "smelter_iron", 0],
		[Vector2i(3, 6), "belt", 0],
		[Vector2i(4, 6), "belt", 0],
		[Vector2i(5, 6), "smelter_iron", 0],
		[Vector2i(6, 6), "belt", 3],
		[Vector2i(6, 5), "belt", 0],
		[Vector2i(7, 5), "assembler_gear", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
	],
	"s4":
	[
		[Vector2i(1, 2), "belt", 0],
		[Vector2i(2, 2), "belt", 0],
		[Vector2i(3, 2), "belt", 0],
		[Vector2i(4, 2), "belt", 0],
		[Vector2i(5, 2), "smelter_iron", 0],
		[Vector2i(6, 2), "belt", 0],
		[Vector2i(7, 2), "belt", 1],
		[Vector2i(7, 3), "belt", 1],
		[Vector2i(7, 4), "belt", 1],
		[Vector2i(1, 7), "belt", 0],
		[Vector2i(2, 7), "belt", 0],
		[Vector2i(3, 7), "belt", 0],
		[Vector2i(4, 7), "belt", 0],
		[Vector2i(5, 7), "smelter_copper", 0],
		[Vector2i(6, 7), "belt", 0],
		[Vector2i(7, 7), "belt", 3],
		[Vector2i(7, 6), "belt", 3],
		[Vector2i(7, 5), "assembler_circuit", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
		[Vector2i(11, 5), "belt", 0],
		[Vector2i(12, 5), "belt", 0],
	],
}

## 動力ステージの想定解。水車からシャフトで回転を運び、機械を回す。
const LAYOUTS_POWER := {
	"s5":
	[
		# 搬送:分配して製錬炉2台へ、合流して搬出口へ
		[Vector2i(1, 4), "belt", 0],
		[Vector2i(2, 4), "splitter", 0],
		[Vector2i(3, 4), "smelter_iron", 0],
		[Vector2i(2, 5), "belt", 0],
		[Vector2i(3, 5), "smelter_iron", 0],
		[Vector2i(4, 5), "belt", 3],
		[Vector2i(4, 4), "belt", 0],
		[Vector2i(5, 4), "belt", 0],
		[Vector2i(6, 4), "belt", 0],
		[Vector2i(7, 4), "belt", 0],
		[Vector2i(8, 4), "belt", 0],
		[Vector2i(9, 4), "belt", 0],
		[Vector2i(10, 4), "belt", 0],
		# 動力:水車(5,0)から製錬炉まで
		[Vector2i(5, 1), "shaft", 0],
		[Vector2i(4, 1), "shaft", 0],
		[Vector2i(3, 1), "shaft", 0],
		[Vector2i(3, 2), "shaft", 0],
		[Vector2i(3, 3), "shaft", 0],
	],
	"s6":
	[
		# 搬送:製錬炉2台(増速)→ 組立機1台(増速)
		[Vector2i(1, 5), "belt", 0],
		[Vector2i(2, 5), "splitter", 0],
		[Vector2i(3, 5), "smelter_iron", 0],
		[Vector2i(2, 6), "belt", 0],
		[Vector2i(3, 6), "smelter_iron", 0],
		[Vector2i(4, 6), "belt", 3],
		[Vector2i(4, 5), "belt", 0],
		[Vector2i(5, 5), "assembler_gear", 0],
		[Vector2i(6, 5), "belt", 0],
		[Vector2i(7, 5), "belt", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
		[Vector2i(11, 5), "belt", 0],
		# 動力:水車2台を繋いでから増速し、機械へ配る
		[Vector2i(5, 0), "shaft", 0],
		[Vector2i(6, 0), "shaft", 0],
		[Vector2i(7, 0), "shaft", 0],
		[Vector2i(6, 1), "gearbox_up", 1],
		[Vector2i(6, 2), "shaft", 0],
		[Vector2i(5, 2), "shaft", 0],
		[Vector2i(4, 2), "shaft", 0],
		[Vector2i(3, 2), "shaft", 0],
		[Vector2i(3, 3), "shaft", 0],
		[Vector2i(3, 4), "shaft", 0],
		[Vector2i(5, 3), "shaft", 0],
		[Vector2i(5, 4), "shaft", 0],
	],
	"s7":
	[
		# 鉄ライン
		[Vector2i(1, 2), "belt", 0],
		[Vector2i(2, 2), "smelter_iron", 0],
		[Vector2i(3, 2), "belt", 0],
		[Vector2i(4, 2), "belt", 1],
		[Vector2i(4, 3), "belt", 1],
		[Vector2i(4, 4), "belt", 1],
		# 銅ライン
		[Vector2i(1, 7), "belt", 0],
		[Vector2i(2, 7), "smelter_copper", 0],
		[Vector2i(3, 7), "belt", 0],
		[Vector2i(4, 7), "belt", 3],
		[Vector2i(4, 6), "belt", 3],
		# 組立と搬出
		[Vector2i(4, 5), "assembler_circuit", 0],
		[Vector2i(5, 5), "belt", 0],
		[Vector2i(6, 5), "belt", 0],
		[Vector2i(7, 5), "belt", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
		[Vector2i(11, 5), "belt", 0],
		[Vector2i(12, 5), "belt", 0],
		# 動力:水車から等速のまま製錬炉2台へ。組立機だけ増速機で2倍にする
		[Vector2i(6, 1), "shaft", 0],
		[Vector2i(5, 1), "shaft", 0],
		[Vector2i(4, 1), "shaft", 0],
		[Vector2i(3, 1), "shaft", 0],
		[Vector2i(2, 1), "shaft", 0],
		[Vector2i(2, 3), "shaft", 0],
		[Vector2i(2, 4), "shaft", 0],
		[Vector2i(2, 5), "shaft", 0],
		[Vector2i(2, 6), "shaft", 0],
		[Vector2i(3, 5), "gearbox_up", 0],
	],
}

## 詰めたレイアウト。par(特にGOLD)が到達可能かを確かめるために測る。
const LAYOUTS_TUNED := {
	"s2":
	[
		[Vector2i(1, 4), "splitter", 0],
		[Vector2i(2, 4), "smelter_iron", 0],
		[Vector2i(1, 5), "belt", 0],
		[Vector2i(2, 5), "smelter_iron", 0],
		[Vector2i(3, 5), "belt", 3],
		[Vector2i(3, 4), "belt", 0],
		[Vector2i(4, 4), "belt", 0],
		[Vector2i(5, 4), "belt", 0],
		[Vector2i(6, 4), "belt", 0],
		[Vector2i(7, 4), "belt", 0],
		[Vector2i(8, 4), "belt", 0],
		[Vector2i(9, 4), "belt", 0],
		[Vector2i(10, 4), "belt", 0],
	],
	"s4":
	[
		[Vector2i(1, 2), "belt", 0],
		[Vector2i(2, 2), "smelter_iron", 0],
		[Vector2i(3, 2), "belt", 0],
		[Vector2i(4, 2), "belt", 0],
		[Vector2i(5, 2), "belt", 1],
		[Vector2i(5, 3), "belt", 1],
		[Vector2i(5, 4), "belt", 1],
		[Vector2i(1, 7), "belt", 0],
		[Vector2i(2, 7), "smelter_copper", 0],
		[Vector2i(3, 7), "belt", 0],
		[Vector2i(4, 7), "belt", 0],
		[Vector2i(5, 7), "belt", 3],
		[Vector2i(5, 6), "belt", 3],
		[Vector2i(5, 5), "assembler_circuit", 0],
		[Vector2i(6, 5), "belt", 0],
		[Vector2i(7, 5), "belt", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
		[Vector2i(11, 5), "belt", 0],
		[Vector2i(12, 5), "belt", 0],
	],
	"s3":
	[
		[Vector2i(1, 5), "belt", 0],
		[Vector2i(2, 5), "splitter", 0],
		[Vector2i(3, 5), "splitter", 3],
		[Vector2i(3, 4), "belt", 3],
		[Vector2i(3, 3), "smelter_iron", 0],
		[Vector2i(4, 5), "belt", 0],
		[Vector2i(5, 5), "smelter_iron", 0],
		[Vector2i(2, 6), "belt", 0],
		[Vector2i(3, 6), "belt", 0],
		[Vector2i(4, 6), "belt", 0],
		[Vector2i(5, 6), "smelter_iron", 0],
		[Vector2i(4, 3), "belt", 0],
		[Vector2i(5, 3), "belt", 0],
		[Vector2i(6, 3), "belt", 1],
		[Vector2i(6, 4), "belt", 1],
		[Vector2i(6, 5), "belt", 1],
		[Vector2i(6, 6), "belt", 1],
		[Vector2i(6, 7), "splitter", 0],
		[Vector2i(7, 7), "assembler_gear", 0],
		[Vector2i(6, 8), "belt", 0],
		[Vector2i(7, 8), "assembler_gear", 0],
		[Vector2i(8, 7), "belt", 1],
		[Vector2i(8, 8), "belt", 0],
		[Vector2i(9, 8), "belt", 3],
		[Vector2i(9, 7), "belt", 3],
		[Vector2i(9, 6), "belt", 3],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
	],
}

## さらに短経路化したレイアウト。GOLD が到達可能かの確認用。
static var LAYOUTS_FAST := {
	"s3":
	[
		[Vector2i(1, 5), "splitter", 0],
		[Vector2i(2, 5), "splitter", 3],
		[Vector2i(2, 4), "belt", 0],
		[Vector2i(3, 4), "smelter_iron", 0],
		[Vector2i(3, 5), "smelter_iron", 0],
		[Vector2i(1, 6), "belt", 0],
		[Vector2i(2, 6), "belt", 0],
		[Vector2i(3, 6), "smelter_iron", 0],
		[Vector2i(4, 4), "belt", 1],
		[Vector2i(4, 5), "belt", 1],
		[Vector2i(4, 6), "belt", 0],
		[Vector2i(5, 6), "splitter", 3],
		[Vector2i(5, 5), "assembler_gear", 0],
		[Vector2i(6, 6), "assembler_gear", 3],
		[Vector2i(6, 5), "belt", 0],
		[Vector2i(7, 5), "belt", 0],
		[Vector2i(8, 5), "belt", 0],
		[Vector2i(9, 5), "belt", 0],
		[Vector2i(10, 5), "belt", 0],
	],
	"s4": _swap_to_fast_belts(LAYOUTS_TUNED["s4"]),
}


static func _swap_to_fast_belts(layout: Array) -> Array:
	var result := []
	for entry in layout:
		result.append([entry[0], "belt_fast" if entry[1] == "belt" else entry[1], entry[2]])
	return result

## 何秒ぶんまで回して諦めるか。
const TIMEOUT_SEC := 180.0

var _failures := 0
var _frames := 0
var _screens_ready := false


func _initialize() -> void:
	print("=== シミュレーション(基本の想定解) ===")
	for stage in Stages.LIST:
		if LAYOUTS.has(stage.id):
			_run_stage(String(stage.id), LAYOUTS, "基本")
	print("=== シミュレーション(動力ステージ) ===")
	for stage_id in LAYOUTS_POWER:
		_run_stage(String(stage_id), LAYOUTS_POWER, "基本")
	print("=== シミュレーション(詰めたレイアウト) ===")
	for stage_id in LAYOUTS_TUNED:
		_run_stage(String(stage_id), LAYOUTS_TUNED, "最適化")
	print("=== シミュレーション(高速コンベア版) ===")
	for stage_id in LAYOUTS_FAST:
		_run_stage(String(stage_id), LAYOUTS_FAST, "高速")


func _process(_delta: float) -> bool:
	# root がツリーとして動き出すまで待つ。_initialize の時点ではまだ _ready が走らない。
	if not _screens_ready:
		print("=== 画面生成 ===")
		_spawn_screens()
		return false
	_frames += 1
	if _frames < 30:
		return false
	print("画面の _ready / _process が %d フレーム通過" % _frames)
	print("=== 失敗 %d 件 ===" % _failures)
	quit(1 if _failures > 0 else 0)
	return true


func _fail(message: String) -> void:
	_failures += 1
	printerr("NG: %s" % message)


func _run_stage(stage_id: String, layouts: Dictionary, label: String) -> void:
	var stage := Stages.get_stage(stage_id)
	if stage.is_empty():
		_fail("ステージ定義が無い: %s" % stage_id)
		return
	if not layouts.has(stage_id):
		_fail("想定解レイアウトが無い: %s" % stage_id)
		return

	var factory := Factory.new()
	factory.setup(stage)
	for entry in layouts[stage_id]:
		if not factory.place(entry[0], String(entry[1]), int(entry[2])):
			_fail("%s: %s を %s に置けない" % [stage_id, entry[1], entry[0]])
			return

	factory.running = true
	while not factory.cleared and factory.elapsed < TIMEOUT_SEC:
		factory.advance(Factory.STEP)

	if not factory.cleared:
		_fail(
			(
				"%s: %.0f秒でクリアできない(%d/%d)"
				% [stage_id, TIMEOUT_SEC, factory.delivered, factory.target_count]
			)
		)
		return

	print(
		(
			"%s %s [%s]  タイム %s  ランク %s  パーツ %d個  par %s"
			% [
				stage_id,
				stage.name,
				label,
				SaveData.format_time(factory.elapsed),
				Stages.rank_label(stage, factory.elapsed),
				factory.part_count(),
				Stages.par_text(stage),
			]
		)
	)


func _spawn_screens() -> void:
	var app: Control = load("res://main.tscn").instantiate()
	root.add_child(app)
	# タイトル → ステージ選択 → 各ゲーム画面、を実際に通してみる。
	app.show_stage_select()
	for stage in Stages.LIST:
		app.show_game(String(stage.id))
	_screens_ready = true
