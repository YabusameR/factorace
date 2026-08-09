class_name SaveData
extends RefCounted

## ベストタイムの保存。Web書き出しでは user:// がブラウザ側(IndexedDB)に永続化される。

const PATH := "user://factorace_save.json"

static var _best := {}
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
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("best_times"):
		var best: Variant = parsed.best_times
		if typeof(best) == TYPE_DICTIONARY:
			_best = best


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


static func clear_all() -> void:
	load_data()
	_best.clear()
	_save()


static func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("セーブに失敗しました: %s" % PATH)
		return
	file.store_string(JSON.stringify({"best_times": _best}))
	file.close()


## 秒を "M:SS.ss" に整形する。負の値は未記録扱い。
static func format_time(time: float) -> String:
	if time < 0.0:
		return "--:--.--"
	var minutes := int(time) / 60
	var seconds := time - float(minutes * 60)
	return "%d:%05.2f" % [minutes, seconds]
