class_name Factory
extends RefCounted

## 工場そのもの。盤面(グリッド)の状態と、搬送/加工のシミュレーションを持つ。
##
## 描画やUIには一切依存しないので、単体でテストしたりリプレイに載せ替えたりできる。
##
## ## 搬送モデル
## ベルト1マスはアイテムを最大1個だけ持ち、progress(0.0〜1.0)が進行度。
## progress が 1.0 に達したら次のマスへ受け渡す。受け取り手が塞がっていれば 1.0 のまま待つ。
## この「待つ」がそのまま詰まり(バックプレッシャー)になり、ライン設計の巧拙がタイムに出る。

## シミュレーションの固定ステップ。フレームレートに依らず同じ結果になるようにする。
const STEP := 1.0 / 60.0
## 1フレームで消化する最大シミュレーション時間(タブ復帰時の暴走を防ぐ)。
const MAX_CATCHUP := 0.25


## 盤面1マスぶんの状態。
class Cell:
	extends RefCounted

	var pos: Vector2i
	var def_id: String = ""
	var def: Dictionary = {}
	var dir: int = 0
	## ステージがあらかじめ置いたもの(搬入口・搬出口)。プレイヤーは触れない。
	var fixed: bool = false

	# --- 搬送系(BELT / SPLITTER) ---
	var item: String = ""
	var progress: float = 0.0
	var split_toggle: int = 0

	# --- 機械(MACHINE) ---
	var inputs: Dictionary = {}
	var crafting: bool = false
	var craft_left: float = 0.0
	var out_item: String = ""
	var out_count: int = 0

	# --- 搬入口(SOURCE) ---
	var spawn_item: String = ""
	var spawn_interval: float = 1.0
	var spawn_timer: float = 0.0

	func kind() -> int:
		return def.get("kind", -1)

	## 中身だけを空にする。設置物そのものは残す。
	func clear_contents() -> void:
		item = ""
		progress = 0.0
		split_toggle = 0
		inputs.clear()
		crafting = false
		craft_left = 0.0
		out_item = ""
		out_count = 0
		spawn_timer = 0.0

	## 加工の進捗(0.0〜1.0)。UIのプログレスバー用。
	func craft_ratio() -> float:
		if not crafting:
			return 0.0
		var total := float(def.recipe.time)
		if total <= 0.0:
			return 1.0
		return clampf(1.0 - craft_left / total, 0.0, 1.0)


var size := Vector2i(10, 8)
var cells := {}  ## Vector2i -> Cell
var target_item := ""
var target_count := 0

var delivered := 0
var elapsed := 0.0
var running := false
var cleared := false

var _acc := 0.0
var _order: Array = []  ## 決定的な処理順(y→xの昇順)


## ステージ定義から盤面を初期化する。
func setup(stage: Dictionary) -> void:
	size = stage.size
	target_item = stage.target_item
	target_count = int(stage.target_count)
	cells.clear()
	for fixed_def in stage.fixed:
		var c := Cell.new()
		c.pos = fixed_def.pos
		c.def_id = fixed_def.def
		c.def = Defs.building(c.def_id)
		c.dir = int(fixed_def.get("dir", 0))
		c.fixed = true
		c.spawn_item = String(fixed_def.get("item", ""))
		c.spawn_interval = float(fixed_def.get("interval", 1.0))
		cells[c.pos] = c
	_rebuild_order()
	reset_run()


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < size.x and pos.y < size.y


func cell_at(pos: Vector2i) -> Cell:
	return cells.get(pos)


## プレイヤーが置ける数(固定物は含まない)。
func part_count() -> int:
	var n := 0
	for pos in cells:
		if not cells[pos].fixed:
			n += 1
	return n


## パーツを置く。既存の設置物があれば置き換える。置けなければ false。
func place(pos: Vector2i, def_id: String, dir: int) -> bool:
	if not in_bounds(pos):
		return false
	var d := Defs.building(def_id)
	if d.is_empty():
		return false
	var existing: Cell = cells.get(pos)
	if existing != null:
		if existing.fixed:
			return false
		if existing.def_id == def_id and existing.dir == dir:
			return false
		cells.erase(pos)
	var c := Cell.new()
	c.pos = pos
	c.def_id = def_id
	c.def = d
	c.dir = dir
	cells[pos] = c
	_rebuild_order()
	return true


func remove(pos: Vector2i) -> bool:
	var c: Cell = cells.get(pos)
	if c == null or c.fixed:
		return false
	cells.erase(pos)
	_rebuild_order()
	return true


## プレイヤーの設置物をすべて撤去する。
func clear_all() -> void:
	for pos in cells.keys():
		if not cells[pos].fixed:
			cells.erase(pos)
	_rebuild_order()


## 稼働をリセットする。レイアウトは残したまま、流れているアイテムとタイムを消す。
func reset_run() -> void:
	for pos in cells:
		cells[pos].clear_contents()
	delivered = 0
	elapsed = 0.0
	running = false
	cleared = false
	_acc = 0.0


## 経過時間を進める。running でなければ何もしない。
func advance(delta: float) -> void:
	if not running or cleared:
		return
	_acc += minf(delta, MAX_CATCHUP)
	while _acc >= STEP:
		_acc -= STEP
		_step(STEP)
		elapsed += STEP
		if delivered >= target_count:
			cleared = true
			running = false
			_acc = 0.0
			return


func _rebuild_order() -> void:
	_order = cells.keys()
	_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.y == b.y else a.y < b.y)


func _step(dt: float) -> void:
	for pos in _order:
		var c: Cell = cells.get(pos)
		if c == null:
			continue
		var kind: int = c.kind()
		if kind == Defs.Kind.SOURCE:
			_step_source(c, dt)
		elif kind == Defs.Kind.MACHINE:
			_step_machine(c, dt)
		elif kind == Defs.Kind.BELT or kind == Defs.Kind.SPLITTER:
			_step_belt(c, dt)


func _step_belt(c: Cell, dt: float) -> void:
	if c.item == "":
		return
	c.progress += float(c.def.speed) * dt
	if c.progress < 1.0:
		return
	var carry := c.progress - 1.0
	if c.kind() == Defs.Kind.SPLITTER:
		# 正面と右隣を交互に試す。片方が詰まっていればもう片方へ逃がす。
		var first := c.dir if c.split_toggle == 0 else (c.dir + 1) % 4
		var second := (c.dir + 1) % 4 if c.split_toggle == 0 else c.dir
		if _push(c, first, c.item, carry) or _push(c, second, c.item, carry):
			c.split_toggle = 1 - c.split_toggle
			c.item = ""
			c.progress = 0.0
			return
	elif _push(c, c.dir, c.item, carry):
		c.item = ""
		c.progress = 0.0
		return
	c.progress = 1.0


func _step_source(c: Cell, dt: float) -> void:
	c.spawn_timer += dt
	if c.spawn_timer < c.spawn_interval:
		return
	if _push(c, c.dir, c.spawn_item, 0.0):
		c.spawn_timer -= c.spawn_interval
	else:
		# 出口が詰まっている間は溜め込まない。空いた瞬間に出せるよう満タンで待つ。
		c.spawn_timer = c.spawn_interval


func _step_machine(c: Cell, dt: float) -> void:
	var recipe: Dictionary = c.def.recipe
	# 完成品の払い出し。受け取り手が空くたびに1個ずつ出る。
	if c.out_count > 0 and _push(c, c.dir, c.out_item, 0.0):
		c.out_count -= 1
		if c.out_count == 0:
			c.out_item = ""
	if c.crafting:
		c.craft_left -= dt
		if c.craft_left <= 0.0:
			c.crafting = false
			c.out_item = recipe.output
			c.out_count += int(recipe.count)
	elif c.out_count == 0 and _has_inputs(c, recipe):
		for input_id in recipe.inputs:
			c.inputs[input_id] = int(c.inputs[input_id]) - int(recipe.inputs[input_id])
		c.crafting = true
		c.craft_left = float(recipe.time)


func _has_inputs(c: Cell, recipe: Dictionary) -> bool:
	for input_id in recipe.inputs:
		if int(c.inputs.get(input_id, 0)) < int(recipe.inputs[input_id]):
			return false
	return true


## 機械が1素材あたり溜め込める上限。少なすぎると常に律速し、多すぎると詰まりが見えない。
func _input_cap(recipe: Dictionary, item_id: String) -> int:
	return maxi(int(recipe.inputs[item_id]) * 2, 2)


## from_cell の dir 方向へ item を1個渡す。渡せたら true。
func _push(from_cell: Cell, dir: int, item_id: String, carry: float) -> bool:
	var dir_vec: Vector2i = Defs.DIR_VECTORS[dir]
	var target_pos: Vector2i = from_cell.pos + dir_vec
	if not in_bounds(target_pos):
		return false
	var target: Cell = cells.get(target_pos)
	if target == null:
		return false
	if not _can_accept(target, from_cell.pos, item_id):
		return false
	_receive(target, item_id, carry)
	return true


func _can_accept(target: Cell, from_pos: Vector2i, item_id: String) -> bool:
	var kind: int = target.kind()
	if kind == Defs.Kind.BELT or kind == Defs.Kind.SPLITTER:
		if target.item != "":
			return false
		# 自分が吐き出す先からは受け取らない(向かい合ったベルトのピンポンを防ぐ)。
		var out_dir_vec: Vector2i = Defs.DIR_VECTORS[target.dir]
		return target.pos + out_dir_vec != from_pos
	if kind == Defs.Kind.MACHINE:
		var recipe: Dictionary = target.def.recipe
		if not recipe.inputs.has(item_id):
			return false
		return int(target.inputs.get(item_id, 0)) < _input_cap(recipe, item_id)
	if kind == Defs.Kind.SINK:
		return item_id == target_item
	return false


func _receive(target: Cell, item_id: String, carry: float) -> void:
	var kind: int = target.kind()
	if kind == Defs.Kind.BELT or kind == Defs.Kind.SPLITTER:
		target.item = item_id
		target.progress = clampf(carry, 0.0, 0.999)
	elif kind == Defs.Kind.MACHINE:
		target.inputs[item_id] = int(target.inputs.get(item_id, 0)) + 1
	elif kind == Defs.Kind.SINK:
		delivered += 1
