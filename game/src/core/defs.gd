class_name Defs
extends RefCounted

## アイテムとパーツ(建物)の静的定義。
##
## 新しいアイテム / パーツ / レシピを増やすときは、このファイルの辞書に足すだけでよい。
## ステージ側は id を文字列で参照するので、ここに追記 → ステージの palette に id を並べる、が基本の流れ。

## パーツの種類。挙動の分岐はすべてこれで行う。
enum Kind {
	BELT,      ## 矢印の向きへ1マスずつ運ぶ
	SPLITTER,  ## 正面と、その右隣へ交互に振り分ける
	MACHINE,   ## レシピに従って加工する
	SOURCE,    ## 原料の搬入口(ステージ固定・撤去不可)
	SINK,      ## 目標物の搬出口(ステージ固定・撤去不可)
}

## 方向は 0=右, 1=下, 2=左, 3=上。時計回りに +1 で回転する。
const DIR_VECTORS := [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]
const DIR_NAMES := ["右", "下", "左", "上"]

## アイテム定義。short は盤面に描く短い表示名。
static var ITEMS := {
	"ore_iron": {"name": "鉄鉱石", "short": "鉄鉱", "color": Color("7d8590")},
	"ore_copper": {"name": "銅鉱石", "short": "銅鉱", "color": Color("b5713c")},
	"plate_iron": {"name": "鉄板", "short": "鉄板", "color": Color("c9d1d9")},
	"plate_copper": {"name": "銅板", "short": "銅板", "color": Color("e08a4a")},
	"gear": {"name": "歯車", "short": "歯車", "color": Color("8fb8de")},
	"circuit": {"name": "基板", "short": "基板", "color": Color("6fbf73")},
}

## パーツ定義。
##   kind    … 挙動の種類(Kind)
##   speed   … BELT / SPLITTER のみ。マス/秒
##   recipe  … MACHINE のみ。{inputs: {item_id: 個数}, output: item_id, count: 個数, time: 秒}
##   short   … 盤面に描く1〜2文字のラベル(空なら描かない)
static var BUILDINGS := {
	"belt": {
		"name": "コンベア",
		"short": "",
		"kind": Kind.BELT,
		"color": Color("464f5e"),
		"speed": 3.0,
		"desc": "矢印の向きへアイテムを運ぶ。3マス/秒。",
	},
	"belt_fast": {
		"name": "高速コンベア",
		"short": "",
		"kind": Kind.BELT,
		"color": Color("3d6f96"),
		"speed": 6.0,
		"desc": "6マス/秒で運ぶ。詰まりやすい区間に。",
	},
	"splitter": {
		"name": "分配器",
		"short": "分",
		"kind": Kind.SPLITTER,
		"color": Color("6a5a91"),
		"speed": 3.0,
		"desc": "正面と、その右隣のマスへ交互に振り分ける。",
	},
	"smelter_iron": {
		"name": "製錬炉(鉄)",
		"short": "製",
		"kind": Kind.MACHINE,
		"color": Color("7a4a34"),
		"recipe": {"inputs": {"ore_iron": 1}, "output": "plate_iron", "count": 1, "time": 1.0},
		"desc": "鉄鉱石を鉄板にする。",
	},
	"smelter_copper": {
		"name": "製錬炉(銅)",
		"short": "製",
		"kind": Kind.MACHINE,
		"color": Color("8a5a2a"),
		"recipe": {"inputs": {"ore_copper": 1}, "output": "plate_copper", "count": 1, "time": 1.0},
		"desc": "銅鉱石を銅板にする。",
	},
	"assembler_gear": {
		"name": "組立機(歯車)",
		"short": "組",
		"kind": Kind.MACHINE,
		"color": Color("35607a"),
		"recipe": {"inputs": {"plate_iron": 2}, "output": "gear", "count": 1, "time": 1.0},
		"desc": "鉄板2枚から歯車を作る。",
	},
	"assembler_circuit": {
		"name": "組立機(基板)",
		"short": "組",
		"kind": Kind.MACHINE,
		"color": Color("2f6b52"),
		"recipe": {
			"inputs": {"plate_iron": 1, "plate_copper": 1},
			"output": "circuit",
			"count": 1,
			"time": 1.5,
		},
		"desc": "鉄板と銅板から基板を作る。",
	},
	"source": {
		"name": "搬入口",
		"short": "",
		"kind": Kind.SOURCE,
		"color": Color("2f6b3f"),
		"desc": "原料が一定間隔で出てくる。撤去できない。",
	},
	"sink": {
		"name": "搬出口",
		"short": "",
		"kind": Kind.SINK,
		"color": Color("7a6b25"),
		"desc": "目標のアイテムだけを受け取る。撤去できない。",
	},
}

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "short": "?", "color": Color.MAGENTA})


static func item_name(id: String) -> String:
	return item(id).name


static func item_short(id: String) -> String:
	return item(id).short


static func item_color(id: String) -> Color:
	return item(id).color


static func building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


static func building_name(id: String) -> String:
	var d := building(id)
	return d.name if d.has("name") else id


## パーツの説明文。機械ならレシピも添える。
static func building_detail(id: String) -> String:
	var d := building(id)
	if d.is_empty():
		return ""
	var lines := PackedStringArray([String(d.name), String(d.desc)])
	if d.has("recipe"):
		lines.append(recipe_text(d.recipe))
	elif d.has("speed"):
		lines.append("搬送速度: %.1f マス/秒" % float(d.speed))
	return "\n".join(lines)


static func recipe_text(recipe: Dictionary) -> String:
	var parts := PackedStringArray()
	for input_id in recipe.inputs:
		parts.append("%s x%d" % [item_name(input_id), int(recipe.inputs[input_id])])
	return "%s → %s x%d(%.1f秒)" % [
		" + ".join(parts),
		item_name(recipe.output),
		int(recipe.count),
		float(recipe.time),
	]
