# .tscn ファイル書式リファレンス

Godot 4系のシーンファイル(`.tscn`)は独自のテキスト書式。エディタを使わずに手で編集するとき、
ここを間違えるとエディタが読み込めなくなる。読み方と守るべきルールをまとめる。

## 目次

- [全体構造](#全体構造)
- [ヘッダ行 gd_scene](#ヘッダ行-gd_scene)
- [ext_resource: 外部リソース参照](#ext_resource-外部リソース参照)
- [sub_resource: 埋め込みリソース](#sub_resource-埋め込みリソース)
- [node: ノード定義](#node-ノード定義)
- [id とパスの整合性ルール](#id-とパスの整合性ルール)
- [このリポジトリの main.tscn を読む](#このリポジトリの-maintscn-を読む)

## 全体構造

`.tscn` は上から順に次の並び:

1. `[gd_scene ...]` ヘッダ(必ず1行、先頭)
2. `[ext_resource ...]` 群(外部ファイルへの参照)
3. `[sub_resource ...]` 群(このファイルに埋め込むリソース)
4. `[node ...]` 群(ノードツリー。最初のノードがシーンルート)

各ブロックの下に `key = value` 形式でプロパティが続く。値の型は Godot の Variant 表記
(`Vector2(x, y)`, `Color(r,g,b,a)`, `PackedStringArray(...)`, `SubResource("id")` など)。

## ヘッダ行 gd_scene

```
[gd_scene load_steps=2 format=3 uid="uid://main_scene"]
```

- `format=3` … Godot 4系のシーンフォーマット。変えない。
- `load_steps` … 読み込むリソースの段数の目安。おおむね「ext_resource の数 + sub_resource の数 + 1」。
  厳密に一致していなくてもエディタが読み直すと修正されるが、大きくずれると警告が出る。ノード/リソースを
  足し引きしたら合わせておくと無難。
- `uid="uid://..."` … シーンの一意ID。他のファイルから `uid://` で参照される。既存の値は変えない。
  新規シーンを作るときは `uid://` に続けてユニークな文字列を付ける(エディタで開けば正式なUIDに再割り当てされる)。

## ext_resource: 外部リソース参照

別ファイル(スクリプト、画像、他シーン)を参照するときに宣言する。

```
[ext_resource type="Script" path="res://player.gd" id="1_abc"]
[ext_resource type="Texture2D" path="res://icon.svg" id="2_def"]
```

- `path="res://..."` … プロジェクトルート(= `game/`)からのパス。**実在するファイルを指すこと**。
- `id="..."` … このファイル内で一意な識別子。ノードやプロパティから `ExtResource("1_abc")` で参照する。
- 宣言していない id を `ExtResource(...)` で使うと読み込み失敗。逆に宣言だけして未使用でも害はない。

## sub_resource: 埋め込みリソース

そのシーン専用の小さなリソース(インラインの GDScript、マテリアル、StyleBox など)をファイル内に埋める。

```
[sub_resource type="GDScript" id="GDScript_main"]
script/source = "extends Node2D

func _ready() -> void:
	print(\"hello\")
"
```

- `id="..."` … ファイル内で一意。ノードから `SubResource("GDScript_main")` で参照する。
- 文字列プロパティ内の `"` は `\"` にエスケープする。複数行文字列はそのまま改行を含めてよい。
- インライン GDScript のインデントはタブ。ロジックが増えたら別 `.gd` に切り出して ext_resource 参照へ移すのが読みやすい。

## node: ノード定義

```
[node name="Main" type="Node2D"]
script = SubResource("GDScript_main")

[node name="Label" type="Label" parent="."]
offset_left = 40.0
text = "Hello"
```

- 最初の `[node]` が**シーンルート**。ルートには `parent` を書かない。
- 2つ目以降は `parent="..."` でツリー上の位置を指定する。値はルートからの相対パス:
  - 直下 … `parent="."`
  - `Main` の子 … `parent="Main"`
  - `Main/Panel` の子 … `parent="Main/Panel"`
- `name` は**同じ親を持つ兄弟の間で一意**。重複するとエディタが自動リネームするか読み込みが崩れる。
- `type="..."` は Godot のクラス名(`Node2D`, `Control`, `Label`, `Button`, `Panel` など)。
- 別シーンをインスタンス化して子にする場合は `[node name="Enemy" parent="." instance=ExtResource("...")]` の形。

## id とパスの整合性ルール

手編集で壊す原因のほぼ全ては、この4つのどれか:

1. **id 重複** … sub_resource / ext_resource の `id` がファイル内で衝突。コピペ時に振り直し忘れがち。
2. **未宣言参照** … `SubResource("X")` / `ExtResource("Y")` の X/Y に対応する宣言ブロックが無い。
3. **パス切れ** … `path="res://..."` の先が存在しない(ファイル移動・改名の直し忘れ)。
4. **parent 不整合** … `parent="Foo"` の Foo が同じシーン内に存在しない、または名前がずれている。

編集後はこの4点を目視確認する。1ファイル内で `grep -n 'id="' foo.tscn` と
`grep -n 'Resource("' foo.tscn` を突き合わせると、宣言と参照のズレを見つけやすい。

## このリポジトリの main.tscn を読む

`game/main.tscn` は最小構成の実例:

```
[gd_scene load_steps=2 format=3 uid="uid://main_scene"]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = "extends Node2D

func _ready() -> void:
	print(\"Godot Web Template: ready\")
"

[node name="Main" type="Node2D"]
script = SubResource("GDScript_main")

[node name="Label" type="Label" parent="."]
offset_left = 40.0
offset_top = 40.0
offset_right = 400.0
offset_bottom = 80.0
text = "Godot Web Template — Hello!"
```

読み解き:ルート `Main`(Node2D)にインライン GDScript を付け、その直下(`parent="."`)に `Label` を1つ置いている。
`load_steps=2` は sub_resource 1個 + 1。ここに新しい UI を足すなら、`[node ... parent="."]` を追記し、
必要なら `load_steps` を1つ増やす。
