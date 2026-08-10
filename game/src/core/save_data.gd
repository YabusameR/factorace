class_name SaveData
extends RefCounted

## ベストタイム・資金・アンロックの保存。
## Web書き出しでは user:// がブラウザ側(IndexedDB)に永続化される。

const PATH := "user://factorace_save.json"

static var _best := {}
static var _money := 0
static var _unlocked := {}  ## def_id -> true
static var _paid := {}  ## stage_id -> 支給済みのクリア報酬(差額支給に使う)
static var _loaded := false


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_best = _dict_of(parsed, "best_times")
	_unlocked = _dict_of(parsed, "unlocked")
	_paid = _dict_of(parsed, "paid_rewards")
	_money = int(parsed.get("money", 0))


static func _dict_of(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


## 未クリアなら -1.0。
static func best_time(stage_id: String) -> float:
	load_data()
	return float(_best.get(stage_id, -1.0))


## タイムを記録する。自己ベストを更新したら true。
static func submit_time(stage_id: String, time: float) -> bool:
	load_data()
	var previous := best_time(stage_id)
	if previous >= 0.0 and previous <= time:
		return false
	_best[stage_id] = time
	_save()
	return true


# --------------------------------------------------------------------------
# 資金とアンロック
# --------------------------------------------------------------------------


static func money() -> int:
	load_data()
	return _money


static func add_money(amount: int) -> void:
	load_data()
	_money = maxi(_money + amount, 0)
	_save()


## 足りていれば支払って true。
static func spend(amount: int) -> bool:
	load_data()
	if _money < amount:
		return false
	_money -= amount
	_save()
	return true


static func is_unlocked(def_id: String) -> bool:
	load_data()
	return bool(_unlocked.get(def_id, false))


static func unlock(def_id: String) -> void:
	load_data()
	_unlocked[def_id] = true
	_save()


## そのステージに支給済みのクリア報酬。差額支給の基準になる。
static func paid_reward(stage_id: String) -> int:
	load_data()
	return int(_paid.get(stage_id, 0))


static func set_paid_reward(stage_id: String, amount: int) -> void:
	load_data()
	_paid[stage_id] = amount
	_save()


static func clear_all() -> void:
	load_data()
	_best.clear()
	_unlocked.clear()
	_paid.clear()
	_money = 0
	_save()


static func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("セーブに失敗しました: %s" % PATH)
		return
	file.store_string(
		JSON.stringify(
			{
				"best_times": _best,
				"money": _money,
				"unlocked": _unlocked,
				"paid_rewards": _paid,
			}
		)
	)
	file.close()


## 3桁区切りで資金を整形する。GDScript に区切り指定が無いので自前で入れる。
static func format_money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if amount < 0 else "") + out


## 秒を "M:SS.ss" に整形する。負の値は未記録扱い。
static func format_time(time: float) -> String:
	if time < 0.0:
		return "--:--.--"
	var minutes := int(time) / 60
	var seconds := time - float(minutes * 60)
	return "%d:%05.2f" % [minutes, seconds]
