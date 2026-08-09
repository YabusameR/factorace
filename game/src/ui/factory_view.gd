class_name FactoryView
extends Control

## 盤面の描画と、マウスでの設置/撤去入力。
##
## 画像を使わず _draw() の矩形と多角形だけで描く。Web書き出しの重さを避けるための方針
## (CLAUDE.md「重いシェーダー/アセットは避ける」)。

signal cell_painted(pos: Vector2i)  ## 左ドラッグ:設置
signal cell_erased(pos: Vector2i)  ## 右ドラッグ:撤去

const BOARD_BG := Color("14171d")
const GRID_LINE := Color(1, 1, 1, 0.06)
const FIXED_OUTLINE := Color(1, 1, 1, 0.45)

var factory: Factory = null:
	set(value):
		factory = value
		_recalc_layout()
		queue_redraw()

## 設置プレビュー(ゴースト)に使う。
var ghost_def := "":
	set(value):
		ghost_def = value
		queue_redraw()
var ghost_dir := 0:
	set(value):
		ghost_dir = value
		queue_redraw()
var erase_mode := false:
	set(value):
		erase_mode = value
		queue_redraw()

var _cell_size := 32.0
var _origin := Vector2.ZERO
var _hover := Vector2i(-1, -1)
var _drag := 0  ## 0=なし, 1=設置, 2=撤去


func _ready() -> void:
	resized.connect(_on_resized)
	_recalc_layout()


func _on_resized() -> void:
	_recalc_layout()
	queue_redraw()


func _recalc_layout() -> void:
	if factory == null:
		return
	var grid := factory.size
	if grid.x <= 0 or grid.y <= 0:
		return
	var available := size - Vector2(8.0, 8.0)
	_cell_size = maxf(floorf(minf(available.x / grid.x, available.y / grid.y)), 8.0)
	var used := Vector2(_cell_size * grid.x, _cell_size * grid.y)
	_origin = ((size - used) * 0.5).floor()


func _cell_rect(pos: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(pos) * _cell_size, Vector2(_cell_size, _cell_size))


func _cell_center(pos: Vector2i) -> Vector2:
	return _origin + (Vector2(pos) + Vector2(0.5, 0.5)) * _cell_size


func _to_grid(local: Vector2) -> Vector2i:
	var v := (local - _origin) / _cell_size
	return Vector2i(floori(v.x), floori(v.y))


# --------------------------------------------------------------------------
# 描画
# --------------------------------------------------------------------------


func _draw() -> void:
	if factory == null:
		return
	var grid := factory.size
	draw_rect(Rect2(_origin, Vector2(grid) * _cell_size), BOARD_BG, true)
	for x in range(grid.x + 1):
		var px := _origin.x + x * _cell_size
		draw_line(Vector2(px, _origin.y), Vector2(px, _origin.y + grid.y * _cell_size), GRID_LINE)
	for y in range(grid.y + 1):
		var py := _origin.y + y * _cell_size
		draw_line(Vector2(_origin.x, py), Vector2(_origin.x + grid.x * _cell_size, py), GRID_LINE)

	for pos in factory.cells:
		_draw_building(factory.cells[pos])
	for pos in factory.cells:
		_draw_contents(factory.cells[pos])
	_draw_ghost()


func _draw_building(cell) -> void:
	var rect := _cell_rect(cell.pos).grow(-2.0)
	draw_rect(rect, cell.def.color, true)
	var kind: int = cell.kind()

	if cell.fixed:
		draw_rect(rect, FIXED_OUTLINE, false, 2.0)

	if kind == Defs.Kind.SOURCE:
		draw_circle(rect.get_center(), _cell_size * 0.2, Defs.item_color(cell.spawn_item))
	elif kind == Defs.Kind.SINK:
		draw_circle(rect.get_center(), _cell_size * 0.2, Defs.item_color(factory.target_item))
		draw_arc(rect.get_center(), _cell_size * 0.32, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
	elif kind == Defs.Kind.MACHINE:
		# 何を作る機械かひと目で分かるよう、産出物の色を右上に置く。
		var badge := rect.position + Vector2(rect.size.x - _cell_size * 0.22, _cell_size * 0.22)
		draw_circle(badge, _cell_size * 0.12, Defs.item_color(cell.def.recipe.output))
		var ratio: float = cell.craft_ratio()
		if ratio > 0.0:
			var bar := Rect2(
				rect.position + Vector2(3.0, rect.size.y - 5.0),
				Vector2((rect.size.x - 6.0) * ratio, 3.0)
			)
			draw_rect(bar, Color("ffd24a"), true)

	# 矢印は出口側に寄せて描く。中央を空けておかないとラベルや流れるアイテムと重なる。
	if kind != Defs.Kind.SINK:
		_draw_edge_arrow(cell.pos, cell.dir, Color(1, 1, 1, 0.6))
	if kind == Defs.Kind.SPLITTER:
		_draw_edge_arrow(cell.pos, (cell.dir + 1) % 4, Color(1, 1, 1, 0.4))

	var label: String = cell.def.get("short", "")
	if label != "":
		_draw_centered_text(rect.get_center() + Vector2(0.0, -_cell_size * 0.02), label)


## ベルト上を流れるアイテムと、機械が抱えている素材を描く。
func _draw_contents(cell) -> void:
	var kind: int = cell.kind()
	if kind == Defs.Kind.BELT or kind == Defs.Kind.SPLITTER:
		if cell.item == "":
			return
		var dir_vec := Vector2(Defs.DIR_VECTORS[cell.dir])
		var t: float = clampf(cell.progress, 0.0, 1.0)
		var at := _cell_center(cell.pos) + dir_vec * _cell_size * (t - 0.5)
		draw_circle(at, _cell_size * 0.17, Defs.item_color(cell.item))
	elif kind == Defs.Kind.MACHINE:
		var rect := _cell_rect(cell.pos).grow(-2.0)
		var i := 0
		for input_id in cell.def.recipe.inputs:
			var have: int = int(cell.inputs.get(input_id, 0))
			for n in have:
				var at := rect.position + Vector2(
					_cell_size * (0.16 + 0.15 * n), _cell_size * (0.18 + 0.17 * i)
				)
				draw_circle(at, _cell_size * 0.055, Defs.item_color(input_id))
			i += 1
		if cell.out_count > 0:
			var at_out := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.74)
			draw_circle(at_out, _cell_size * 0.1, Defs.item_color(cell.out_item))


func _draw_ghost() -> void:
	if factory == null or not factory.in_bounds(_hover):
		return
	var rect := _cell_rect(_hover).grow(-2.0)
	if erase_mode:
		draw_rect(rect, Color(1.0, 0.35, 0.35, 0.25), true)
		draw_rect(rect, Color(1.0, 0.45, 0.45, 0.8), false, 2.0)
		return
	if ghost_def == "":
		draw_rect(rect, Color(1, 1, 1, 0.12), false, 2.0)
		return
	var def := Defs.building(ghost_def)
	if def.is_empty():
		return
	var occupied = factory.cell_at(_hover)
	var blocked: bool = occupied != null and occupied.fixed
	var tint: Color = def.color
	tint.a = 0.45
	draw_rect(rect, tint, true)
	draw_rect(rect, Color(1, 0.4, 0.4, 0.9) if blocked else Color(1, 1, 1, 0.7), false, 2.0)
	if not blocked:
		_draw_edge_arrow(_hover, ghost_dir, Color(1, 1, 1, 0.85))


## マスの出口側の縁に小さな矢印を描く。
func _draw_edge_arrow(pos: Vector2i, dir: int, color: Color) -> void:
	var forward := Vector2(Defs.DIR_VECTORS[dir])
	var at := _cell_center(pos) + forward * _cell_size * 0.3
	_draw_arrow(at, dir, _cell_size * 0.16, color)


func _draw_arrow(center: Vector2, dir: int, length: float, color: Color) -> void:
	var forward := Vector2(Defs.DIR_VECTORS[dir])
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array(
		[
			center + forward * length,
			center - forward * length * 0.55 + side * length * 0.7,
			center - forward * length * 0.55 - side * length * 0.7,
		]
	)
	draw_colored_polygon(points, color)


func _draw_centered_text(center: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := int(maxf(_cell_size * 0.32, 8.0))
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := center - Vector2(extent.x * 0.5, -font_size * 0.36)
	draw_string(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.85)
	)


# --------------------------------------------------------------------------
# 入力
# --------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if factory == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var pos := _to_grid(button.position)
		if button.button_index == MOUSE_BUTTON_LEFT:
			_drag = 1 if button.pressed else 0
			if button.pressed:
				_emit_for(pos)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_drag = 2 if button.pressed else 0
			if button.pressed:
				cell_erased.emit(pos)
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var pos := _to_grid(motion.position)
		if pos != _hover:
			_hover = pos
			queue_redraw()
		if _drag == 1:
			_emit_for(pos)
		elif _drag == 2:
			cell_erased.emit(pos)


func _emit_for(pos: Vector2i) -> void:
	if erase_mode:
		cell_erased.emit(pos)
	else:
		cell_painted.emit(pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2i(-1, -1)
		_drag = 0
		queue_redraw()
