class_name Stages
extends RefCounted

## ステージ(お題)の定義。
##
## 1ステージ =「盤面の広さ」「搬入口/搬出口の位置」「目標生産物と個数」「使えるパーツ」「ランク基準タイム」。
## fixed に置いたものはプレイヤーが撤去できない。搬入口には item(原料)と interval(秒)を持たせる。
##
## par は [金, 銀, 銅] のクリアタイム(秒)。この時間以下ならそのランク。

static var LIST := [
	{
		"id": "s1",
		"name": "1. まっすぐ運ぶ",
		"desc": "搬入口から出てくる鉄鉱石を、そのまま搬出口まで運ぶ。",
		"hint": "コンベアは矢印の向きにしか運ばない。Rキーで向きを変えられる。",
		"size": Vector2i(10, 8),
		"target_item": "ore_iron",
		"target_count": 20,
		"palette": ["belt"],
		"fixed": [
			{"pos": Vector2i(0, 4), "def": "source", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(9, 4), "def": "sink", "dir": 2},
		],
		"par": [13.0, 15.5, 20.0],
	},
	{
		"id": "s2",
		"name": "2. 鉄を製錬する",
		"desc": "鉄鉱石を製錬炉に通して鉄板にし、搬出口へ届ける。",
		"hint": "製錬炉は1秒に1枚しか作れない。搬入口は毎秒2個出てくる。分配器で炉を並べよう。",
		"size": Vector2i(12, 9),
		"target_item": "plate_iron",
		"target_count": 18,
		"palette": ["belt", "splitter", "smelter_iron"],
		"fixed": [
			{"pos": Vector2i(0, 4), "def": "source", "dir": 0, "item": "ore_iron", "interval": 0.5},
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
		"palette": ["belt", "splitter", "smelter_iron", "assembler_gear"],
		"fixed": [
			{"pos": Vector2i(0, 5), "def": "source", "dir": 0, "item": "ore_iron", "interval": 0.4},
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
			"belt",
			"belt_fast",
			"splitter",
			"smelter_iron",
			"smelter_copper",
			"assembler_circuit",
		],
		"fixed": [
			{"pos": Vector2i(0, 2), "def": "source", "dir": 0, "item": "ore_iron", "interval": 0.5},
			{"pos": Vector2i(0, 7), "def": "source", "dir": 0, "item": "ore_copper", "interval": 0.5},
			{"pos": Vector2i(13, 5), "def": "sink", "dir": 2},
		],
		"par": [23.0, 27.5, 35.0],
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
