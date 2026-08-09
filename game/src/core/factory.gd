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
##
## ## 採掘
## 原石は鉱脈から出る。鉱脈はクリックで手掘りできるが遅い(採掘間隔の MANUAL_PENALTY 倍)。
## 鉱脈の上にドリルを重ねて置くと自動で掘り、動力ステージでは回転数に比例して速くなる。
## ドリルが乗っている鉱脈は手掘りできない。手とドリルを併用した連打で稼ぐ遊びを避けるため。
##
## ## 動力(回転力)
## `power` を有効にしたステージでは、機械は動力網に繋がっていないと動かない。
## 回転数が高いほど加工が速く終わるが、食う応力も比例して増え、系統の供給を超えると丸ごと止まる。
## 解決は power.gd が持つ。ここでは「機械の加工速度に回転数を掛ける」だけ。

## シミュレーションの固定ステップ。フレームレートに依らず同じ結果になるようにする。
const STEP := 1.0 / 60.0
## 1フレームで消化する最大シミュレーション時間(タブ復帰時の暴走を防ぐ)。
const MAX_CATCHUP := 0.25
## 手掘りのクールタイムは採掘間隔の何倍か。ドリルを置く動機を残すため遅くしてある。
const MANUAL_PENALTY := 3.0


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

	# --- 鉱脈(ORE_NODE) ---
	var spawn_item: String = ""
	var spawn_interval: float = 1.0
	var spawn_timer: float = 0.0
	var manual_timer: float = 0.0  ## 手掘りのクールタイム残り

	# --- 重ね置き(いまのところ鉱脈の上のドリルだけ) ---
	var overlay_def_id: String = ""
	var overlay_def: Dictionary = {}
	var overlay_dir: int = 0

	# --- 動力源(POWER_SOURCE) ---
	# def の値が既定だが、ステージ側で強弱を変えられるようにセルに持たせている。
	var power_rpm: float = 1.0
	var power_capacity: float = 0.0

	func kind() -> int:
		return def.get("kind", -1)

	func has_drill() -> bool:
		return overlay_def.get("kind", -1) == Defs.Kind.DRILL

	## 原石を吐き出す向き。ドリルが乗っていればドリルの向きに従う。
	func output_dir() -> int:
		return overlay_dir if has_drill() else dir

	## 手掘りできる状態か。ドリルが塞いでいたら不可。
	func can_mine_by_hand() -> bool:
		return kind() == Defs.Kind.ORE_NODE and not has_drill() and manual_timer <= 0.0

	## 手掘りクールタイムの進み具合(0.0〜1.0)。1.0 で掘れる。
	func manual_ready_ratio() -> float:
		var total := spawn_interval * MANUAL_PENALTY
		if total <= 0.0:
			return 1.0
		return clampf(1.0 - manual_timer / total, 0.0, 1.0)

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
		manual_timer = 0.0

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

## 動力(回転力)を使うステージか。false なら機械は常に回転数1で回る。
## 既存ステージのバランスを壊さないよう、ステージ側で明示的に有効化する。
var power_enabled := false
var power := PowerGrid.new()

var delivered := 0
var elapsed := 0.0
var running := false
var cleared := false

var _acc := 0.0
var _order: Array = []  ## 決定的な処理順(y→xの昇順)


## ステージ定義から盤面を初期化する。
func setup(stage: Dictionary) -> void:
	power_enabled = bool(stage.get("power", false))
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
		c.power_rpm = float(fixed_def.get("rpm", c.def.get("rpm", 1.0)))
		c.power_capacity = float(fixed_def.get("capacity", c.def.get("capacity", 0.0)))
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
		var c: Cell = cells[pos]
		if not c.fixed:
			n += 1
		if c.has_drill():
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
	var is_drill: bool = int(d.get("kind", -1)) == Defs.Kind.DRILL
	if is_drill:
		# ドリルは単体では置けない。鉱脈の上に重ねる。
		if existing == null or existing.kind() != Defs.Kind.ORE_NODE:
			return false
		if existing.overlay_def_id == def_id and existing.overlay_dir == dir:
			return false
		existing.overlay_def_id = def_id
		existing.overlay_def = d
		existing.overlay_dir = dir
		existing.spawn_timer = 0.0
		_rebuild_order()
		return true
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
	if c == null:
		return false
	if c.has_drill():
		# 固定物(鉱脈)そのものは残し、重ねたドリルだけ外す。
		_strip_overlay(c)
		_rebuild_order()
		return true
	if c.fixed:
		return false
	cells.erase(pos)
	_rebuild_order()
	return true


func _strip_overlay(cell: Cell) -> void:
	cell.overlay_def_id = ""
	cell.overlay_def = {}
	cell.overlay_dir = 0
	cell.spawn_timer = 0.0


## プレイヤーの設置物をすべて撤去する。
func clear_all() -> void:
	for pos in cells.keys():
		var c: Cell = cells[pos]
		if c.has_drill():
			_strip_overlay(c)
		if not c.fixed:
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
	# 動力網は稼働中に変化しないので、レイアウトが変わったときだけ解き直せばよい。
	if power_enabled:
		power.build(cells)
	else:
		power.clear()


## 機械が回る回転数。動力を使わないステージでは常に1。0 なら止まっている。
func machine_rpm(cell: Cell) -> float:
	if not power_enabled:
		return 1.0
	return power.rpm_at(cell.pos)


func _step(dt: float) -> void:
	for pos in _order:
		var c: Cell = cells.get(pos)
		if c == null:
			continue
		var kind: int = c.kind()
		if kind == Defs.Kind.ORE_NODE:
			_step_ore_node(c, dt)
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


func _step_ore_node(c: Cell, dt: float) -> void:
	# 手掘りのクールタイムはドリルの有無に関係なく進む。
	if c.manual_timer > 0.0:
		c.manual_timer = maxf(c.manual_timer - dt, 0.0)
	if not c.has_drill():
		return
	# ドリルは回転が速いほど速く掘る。動力が届いていなければ止まる。
	var rpm := drill_rpm(c)
	if rpm <= 0.0:
		return
	c.spawn_timer += dt * rpm
	if c.spawn_timer < c.spawn_interval:
		return
	if _push(c, c.overlay_dir, c.spawn_item, 0.0):
		c.spawn_timer -= c.spawn_interval
	else:
		# 出口が詰まっている間は溜め込まない。空いた瞬間に出せるよう満タンで待つ。
		c.spawn_timer = c.spawn_interval


## ドリルが回る回転数。動力を使わないステージでは常に1。0 なら止まっている。
func drill_rpm(cell: Cell) -> float:
	if not cell.has_drill():
		return 0.0
	if not power_enabled:
		return 1.0
	return power.rpm_at(cell.pos)


## 鉱脈を手で掘る。掘れたら true。稼働中しか掘れない。
func mine_by_hand(pos: Vector2i) -> bool:
	if not running or cleared:
		return false
	var c: Cell = cells.get(pos)
	if c == null or not c.can_mine_by_hand():
		return false
	if not _push(c, c.dir, c.spawn_item, 0.0):
		return false
	c.manual_timer = c.spawn_interval * MANUAL_PENALTY
	return true


func _step_machine(c: Cell, dt: float) -> void:
	# 動力が届いていない/系統が過負荷なら、機械は完全に止まる(Create の Overstressed と同じ扱い)。
	var rpm := machine_rpm(c)
	if rpm <= 0.0:
		return
	var recipe: Dictionary = c.def.recipe
	# 完成品の払い出し。受け取り手が空くたびに1個ずつ出る。
	if c.out_count > 0 and _push(c, c.dir, c.out_item, 0.0):
		c.out_count -= 1
		if c.out_count == 0:
			c.out_item = ""
	if c.crafting:
		# 回転が速いほど加工が速く終わる。実質の加工時間は 基本時間 ÷ 回転数。
		c.craft_left -= dt * rpm
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
