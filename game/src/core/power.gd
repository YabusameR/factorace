class_name PowerGrid
extends RefCounted

## 回転力(動力)の解決。盤面のレイアウトから「どの機械が何倍速で回るか」を決める。
##
## ## 考え方
## Create Mod の回転力を2Dグリッド向けに整理したもの。軸は2本ある。
##
## - **回転数**: 動力源が生む速さ。伝わる先の機械はこの倍率で動く。増速機で2倍、減速機で半分になる
## - **応力**: 機械が動力網から食う負荷。`応力 = 機械の基本応力 × その機械の回転数`。
##   つまり速く回すほど食う。動力源の供給量を超えたら、その系統は丸ごと止まる(過負荷)
##
## この2本があるおかげで「速くしたいが動力が持たない、動力源を足すと場所を食う」という
## 綱引きが生まれる。詰まり(factory.gd)に続く第二の律速。
##
## ## 用語
## - **網 (Network)**: 導通するマス(動力源/シャフト/機械)が隣接で繋がったかたまり。網の中では回転数が同じ
## - **系統 (System)**: 網どうしを増速機/減速機で繋いだ全体。応力の収支はこの単位で見る
##
## 増速機・減速機は網には属さず、網と網の“境界”として振る舞う。だから網ごとに回転数が変わる。

## 回転数が同じマスのかたまり。
class Network:
	extends RefCounted

	var cells: Array = []  ## Vector2i の配列
	var rpm := 0.0
	var rpm_known := false
	var system := -1


## 応力の収支を見る単位。
class PowerSystem:
	extends RefCounted

	var networks: Array = []  ## Network のインデックス
	var capacity := 0.0
	var demand := 0.0
	var overstressed := false  ## 消費が供給を超えた
	var conflict := false  ## 回転数の指定が矛盾した(増速機のループなど)

	func ok() -> bool:
		return not overstressed and not conflict


var networks: Array = []
var systems: Array = []

var _net_of := {}  ## Vector2i -> networks のインデックス


func clear() -> void:
	networks.clear()
	systems.clear()
	_net_of.clear()


## 盤面から動力網を解く。レイアウトが変わったときだけ呼べばよい(稼働中は変化しない)。
func build(cells: Dictionary) -> void:
	clear()
	_build_networks(cells)
	var edges := _build_gearbox_edges(cells)
	_build_systems(edges)
	for system in systems:
		_resolve_rpm(system, edges, cells)
	_compute_load(cells)


## そのマスの機械が実際に回る回転数。0 なら動かない(未接続・過負荷・回転数の矛盾)。
func rpm_at(pos: Vector2i) -> float:
	var network := _network_at(pos)
	if network == null or not network.rpm_known:
		return 0.0
	var system := system_at(pos)
	if system == null or not system.ok():
		return 0.0
	return network.rpm


## 表示用。過負荷でも「本来なら何倍速か」を返す。繋がっていなければ 0。
func nominal_rpm_at(pos: Vector2i) -> float:
	var network := _network_at(pos)
	if network == null or not network.rpm_known:
		return 0.0
	return network.rpm


func system_at(pos: Vector2i) -> PowerSystem:
	var network := _network_at(pos)
	if network == null or network.system < 0:
		return null
	return systems[network.system]


## 盤面全体の動力状況。HUD用。
func summary() -> Dictionary:
	var capacity := 0.0
	var demand := 0.0
	var overstressed := false
	var conflict := false
	for system in systems:
		capacity += system.capacity
		demand += system.demand
		overstressed = overstressed or system.overstressed
		conflict = conflict or system.conflict
	return {
		"capacity": capacity,
		"demand": demand,
		"overstressed": overstressed,
		"conflict": conflict,
	}


# --------------------------------------------------------------------------
# 内部
# --------------------------------------------------------------------------


## 回転を隣へ伝えるマスか。増速機/減速機は境界役なので導通しない。
static func conducts(cell) -> bool:
	var kind: int = cell.kind()
	return (
		kind == Defs.Kind.POWER_SOURCE or kind == Defs.Kind.SHAFT or kind == Defs.Kind.MACHINE
	)


func _network_at(pos: Vector2i) -> Network:
	var index: int = _net_of.get(pos, -1)
	if index < 0:
		return null
	return networks[index]


func _build_networks(cells: Dictionary) -> void:
	var visited := {}
	for start in cells:
		if visited.has(start) or not conducts(cells[start]):
			continue
		var network := Network.new()
		var index := networks.size()
		var queue := [start]
		visited[start] = true
		while not queue.is_empty():
			var pos: Vector2i = queue.pop_back()
			network.cells.append(pos)
			_net_of[pos] = index
			for i in Defs.DIR_VECTORS.size():
				var step: Vector2i = Defs.DIR_VECTORS[i]
				var next_pos: Vector2i = pos + step
				if visited.has(next_pos):
					continue
				var neighbour = cells.get(next_pos)
				if neighbour == null or not conducts(neighbour):
					continue
				visited[next_pos] = true
				queue.append(next_pos)
		networks.append(network)


## 増速機/減速機は「入力側の網」と「出力側の網」を倍率つきで繋ぐ辺になる。
func _build_gearbox_edges(cells: Dictionary) -> Array:
	var edges := []
	for pos in cells:
		var cell = cells[pos]
		if cell.kind() != Defs.Kind.GEARBOX:
			continue
		var step: Vector2i = Defs.DIR_VECTORS[cell.dir]
		var from_index: int = _net_of.get(pos - step, -1)
		var to_index: int = _net_of.get(pos + step, -1)
		if from_index < 0 or to_index < 0:
			continue
		edges.append({"from": from_index, "to": to_index, "ratio": float(cell.def.ratio)})
	return edges


func _build_systems(edges: Array) -> void:
	var system_of := {}
	for start in networks.size():
		if system_of.has(start):
			continue
		var system := PowerSystem.new()
		var index := systems.size()
		var queue := [start]
		system_of[start] = index
		while not queue.is_empty():
			var current: int = queue.pop_back()
			system.networks.append(current)
			networks[current].system = index
			for edge in edges:
				var other := -1
				if int(edge.from) == current:
					other = int(edge.to)
				elif int(edge.to) == current:
					other = int(edge.from)
				if other >= 0 and not system_of.has(other):
					system_of[other] = index
					queue.append(other)
		systems.append(system)


## 動力源のある網を起点に、増速機/減速機の辺をたどって回転数を配る。
func _resolve_rpm(system: PowerSystem, edges: Array, cells: Dictionary) -> void:
	var queue := []
	for index in system.networks:
		var network: Network = networks[index]
		for pos in network.cells:
			var cell = cells[pos]
			if cell.kind() != Defs.Kind.POWER_SOURCE:
				continue
			var source_rpm := float(cell.power_rpm)
			if network.rpm_known and not is_equal_approx(network.rpm, source_rpm):
				# 同じ網に回転数の違う動力源が繋がっている。
				system.conflict = true
			network.rpm = source_rpm
			network.rpm_known = true
			if not queue.has(index):
				queue.append(index)

	while not queue.is_empty():
		var current: int = queue.pop_back()
		var rpm: float = networks[current].rpm
		for edge in edges:
			var other := -1
			var value := 0.0
			if int(edge.from) == current:
				other = int(edge.to)
				value = rpm * float(edge.ratio)
			elif int(edge.to) == current:
				other = int(edge.from)
				value = rpm / float(edge.ratio)
			if other < 0:
				continue
			var target: Network = networks[other]
			if target.rpm_known:
				# 別経路から違う回転数が来た(増速機でループを作った等)。
				if not is_equal_approx(target.rpm, value):
					system.conflict = true
			else:
				target.rpm = value
				target.rpm_known = true
				queue.append(other)


func _compute_load(cells: Dictionary) -> void:
	for pos in cells:
		var cell = cells[pos]
		var network := _network_at(pos)
		if network == null or network.system < 0:
			continue
		var system: PowerSystem = systems[network.system]
		var kind: int = cell.kind()
		if kind == Defs.Kind.POWER_SOURCE:
			system.capacity += cell.power_capacity * network.rpm
		elif kind == Defs.Kind.MACHINE:
			# 速く回すほど食う。ここが「増速すればタイムは縮むが動力が要る」の正体。
			system.demand += float(cell.def.get("stress", 0.0)) * network.rpm
	for system in systems:
		system.overstressed = system.demand > system.capacity + 0.0001
