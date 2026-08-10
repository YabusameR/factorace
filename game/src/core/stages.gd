class_name Stages
extends RefCounted

## ステージ(お題)の定義。
##
## 1ステージ =「盤面の広さ」「鉱脈/搬出口の位置」「目標生産物と個数」「使えるパーツ」「ランク基準タイム」。
## fixed に置いたものはプレイヤーが撤去できない。鉱脈には item(原石)と interval(採掘間隔・秒)を持たせる。
## 採掘間隔はドリルではなく鉱脈が持つ。鉱脈の豊かさをステージ設計で決められるようにするため。
##
## par は [金, 銀, 銅] のクリアタイム(秒)。この時間以下ならそのランク。

static var LIST := [
	{
		"id": "s1",
		"name": "1. まっすぐ運ぶ",
		"desc": "鉱脈の鉄鉱石を掘って、搬出口まで運ぶ。",
		"hint": "鉱脈はクリックで手掘りできるが遅い。ドリルを鉱脈に重ねて置けば自動で掘る。コンベアは矢印の向きにしか運ばない(Rキーで回転)。",
		"size": Vector2i(10, 8),
		"target_item": "ore_iron",
		"target_count": 20,
		"palette": ["drill", "belt"],
		"fixed": [
			{"pos": Vector2i(0, 4), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(9, 4), "def": "sink", "dir": 2},
		],
		"par": [13.0, 15.5, 20.0],
	},
	{
		"id": "s2",
		"name": "2. 鉄を製錬する",
		"desc": "鉄鉱石を製錬炉に通して鉄板にし、搬出口へ届ける。",
		"hint": "製錬炉は1秒に1枚しか作れない。ドリルは毎秒2個掘る。分配器で炉を並べよう。",
		"size": Vector2i(12, 9),
		"target_item": "plate_iron",
		"target_count": 18,
		"palette": ["drill", "belt", "splitter", "smelter_iron"],
		"fixed": [
			{"pos": Vector2i(0, 4), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(11, 4), "def": "sink", "dir": 2},
		],
		"par": [14.0, 17.0, 23.0],
	},
	{
		"id": "s3",
		"name": "3. 歯車をつくる",
		"desc": "鉄板2枚から歯車を組み立てて搬出する。",
		"hint": "歯車1個につき鉄板が2枚いる。製錬炉の本数が足りているか数えてみよう。",
		"size": Vector2i(12, 10),
		"target_item": "gear",
		"target_count": 14,
		"palette": ["drill", "belt", "splitter", "smelter_iron", "assembler_gear"],
		"fixed": [
			{"pos": Vector2i(0, 5), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.4},
			{"pos": Vector2i(11, 5), "def": "sink", "dir": 2},
		],
		"par": [19.0, 23.0, 30.0],
	},
	{
		"id": "s4",
		"name": "4. 基板をつくる",
		"desc": "鉄と銅、2系統のラインを合流させて基板を作る。",
		"hint": "組立機は鉄板と銅板を両方受け取る。2方向から別々のベルトを差し込める。",
		"size": Vector2i(14, 10),
		"target_item": "circuit",
		"target_count": 12,
		"palette": [
			"drill",
			"belt",
			"belt_fast",
			"splitter",
			"smelter_iron",
			"smelter_copper",
			"assembler_circuit",
		],
		"fixed": [
			{"pos": Vector2i(0, 2), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(0, 7), "def": "ore_node", "dir": 0, "item": "ore_copper", "interval": 0.5},
			{"pos": Vector2i(13, 5), "def": "sink", "dir": 2},
		],
		"par": [23.0, 27.5, 35.0],
	},
	{
		"id": "s5",
		"name": "5. 動力を通す",
		"desc": "水車の回転をシャフトで運び、製錬炉を回す。",
		"hint": "機械もドリルも、動力網に繋がっていないと動かない。シャフトは隣接していれば上下左右どちらにも繋がる。",
		"size": Vector2i(12, 9),
		"target_item": "plate_iron",
		"target_count": 18,
		"power": true,
		"palette": ["drill", "belt", "splitter", "shaft", "smelter_iron"],
		"fixed": [
			{"pos": Vector2i(0, 4), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(11, 4), "def": "sink", "dir": 2},
			{"pos": Vector2i(5, 0), "def": "water_wheel", "capacity": 8.0},
		],
		"par": [14.0, 17.0, 23.0],
	},
	{
		"id": "s6",
		"name": "6. 増速する",
		"desc": "増速機で回転を上げると機械は速くなる。ただし食う応力も増える。",
		"hint": "応力 = 機械の基本応力 × 回転数。台数を増やすか、増速して台数を減らすか。どちらも応力は同じで、違うのは占める場所。",
		"size": Vector2i(13, 10),
		"target_item": "gear",
		"target_count": 20,
		"power": true,
		"palette": [
			"drill",
			"belt",
			"splitter",
			"shaft",
			"gearbox_up",
			"smelter_iron",
			"assembler_gear",
		],
		"fixed": [
			{"pos": Vector2i(0, 5), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.25},
			{"pos": Vector2i(12, 5), "def": "sink", "dir": 2},
			{"pos": Vector2i(4, 0), "def": "water_wheel", "capacity": 8.0},
			{"pos": Vector2i(8, 0), "def": "water_wheel", "capacity": 8.0},
		],
		"par": [18.0, 23.0, 30.0],
	},
	{
		"id": "s7",
		"name": "7. 動力をやりくりする",
		"desc": "供給が足りない。減速機で余った回転を落とし、必要なところへ応力を回す。",
		"hint": "同じ網の中は全部同じ回転数になる。速くしたい機械だけ増速し、そうでない機械は減速機で戻すと応力が浮く。",
		"size": Vector2i(14, 10),
		"target_item": "circuit",
		"target_count": 12,
		"power": true,
		"palette": [
			"drill",
			"belt",
			"belt_fast",
			"splitter",
			"shaft",
			"gearbox_up",
			"gearbox_down",
			"smelter_iron",
			"smelter_copper",
			"assembler_circuit",
		],
		"fixed": [
			{"pos": Vector2i(0, 2), "def": "ore_node", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(0, 7), "def": "ore_node", "dir": 0, "item": "ore_copper", "interval": 0.5},
			{"pos": Vector2i(13, 5), "def": "sink", "dir": 2},
			{"pos": Vector2i(6, 0), "def": "water_wheel", "capacity": 6.0},
			{"pos": Vector2i(7, 0), "def": "water_wheel", "capacity": 6.0},
		],
		"par": [18.0, 23.0, 30.0],
	},
]


static func count() -> int:
	return LIST.size()


static func get_stage(id: String) -> Dictionary:
	for stage in LIST:
		if stage.id == id:
			return stage
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1


## 前のステージをクリアしていれば解放。最初のステージは常に遊べる。
static func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index >= LIST.size():
		return false
	return SaveData.best_time(LIST[index - 1].id) >= 0.0


static func next_id(id: String) -> String:
	var i := index_of(id)
	if i < 0 or i + 1 >= LIST.size():
		return ""
	return LIST[i + 1].id


## タイムからランク文字列を返す。par を満たさなければ "クリア"。
static func rank_label(stage: Dictionary, time: float) -> String:
	var par: Array = stage.par
	if time <= float(par[0]):
		return "GOLD"
	if time <= float(par[1]):
		return "SILVER"
	if time <= float(par[2]):
		return "BRONZE"
	return "クリア"


static func rank_color(rank: String) -> Color:
	match rank:
		"GOLD":
			return Color("ffd24a")
		"SILVER":
			return Color("d5dbe3")
		"BRONZE":
			return Color("cf8b52")
		_:
			return Color("9aa4b2")


static func par_text(stage: Dictionary) -> String:
	var par: Array = stage.par
	return "GOLD %s / SILVER %s / BRONZE %s" % [
		SaveData.format_time(float(par[0])),
		SaveData.format_time(float(par[1])),
		SaveData.format_time(float(par[2])),
	]
