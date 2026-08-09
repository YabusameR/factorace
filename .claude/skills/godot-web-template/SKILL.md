---
name: godot-web-template
description: >-
  Godot 4系のWebゲーム(このリポジトリ)を開発・デプロイするための実務ガイド。
  シーン(.tscn)やスクリプト(.gd)をテキストとして直接編集するとき、新しいノード/シーンを追加するとき、
  Webエクスポートやデプロイ(GitHub Actions → GitHub Pages / unityroom)をいじるとき、
  `project.godot` や `export_presets.cfg`、`.github/workflows/deploy.yml` を変更するときは必ずこのスキルを使うこと。
  「シーンを追加して」「ノードを増やして」「Godotのバージョンを上げて」「デプロイが失敗する」「Web書き出しの設定」
  といった依頼はエディタを開けない環境で起きがちで、テキスト編集特有の落とし穴(sub_resourceのid重複、uid、main_sceneの不整合、
  headlessエクスポートの前提)を踏みやすいので、明示的にGodotと言われなくても該当したら参照する。
---

# Godot Web Template 開発ガイド

このリポジトリは Godot 4系のWebゲームプロジェクトのテンプレート。`game/` 配下が Godot プロジェクト本体で、
`main` への push で GitHub Actions が headless エクスポート → GitHub Pages へ自動デプロイする。

エディタを開かずにテキストとして `.tscn` / `.gd` / `.cfg` を編集するのが基本の前提。だからこそ Godot エディタが
自動でやってくれる整合性チェックが効かず、手で守るべきルールがある。このスキルはその落とし穴を先回りして避けるためのもの。

## まず全体像をつかむ

作業を始める前に、いま何を触ろうとしているかで読む場所を決める:

- **シーン/スクリプトの中身を書く・直す** → 下の「シーンとスクリプトを編集する」
- **新しいノード/シーンを追加する** → 下の「新しいノード・シーンを追加する」
- **Web書き出し・デプロイ・バージョン・CIの不調** → `references/web-export.md` を読む
- **.tscn の書式で詰まった(sub_resource, ext_resource, uid, load_steps の意味)** → `references/tscn-format.md` を読む

`game/project.godot` の `run/main_scene` が常に実在するシーンを指しているか、これだけは何を変えても最後に確認する。
ここがずれると起動時に何も表示されない・エクスポートが空になる、という一番わかりにくい壊れ方をする。

## シーンとスクリプトを編集する

`.tscn` も `.gd` も全部プレーンテキストなので直接編集してよい。ただし `.tscn` は独自書式で、
壊すとエディタが読み込めなくなる。安全に編集するための要点:

- **スクリプトは `.gd` に分けるのが基本**。`main.tscn` は最小構成として `[sub_resource type="GDScript"]` に
  インラインでスクリプトを埋めているが、ロジックが増えるなら `res://foo.gd` として切り出し、
  ノードから `script = ExtResource("...")` で参照する方が読みやすく差分も追いやすい。書式は `references/tscn-format.md`。
- **インデントはタブ**。GDScript はインデントで構造を決める言語で、このプロジェクトはタブで統一している。
  スペースと混ぜるとパースエラーになるので、既存行に合わせる。
- **`.tscn` 内のリソースIDは重複させない**。`[sub_resource ... id="GDScript_main"]` のような id は
  ファイル内で一意でなければならない。コピペで増やすとき id をそのままにしがちなので必ず振り直す。詳細は tscn-format.md。
- **UI中心で軽く保つ**。Webエクスポートはブラウザ性能に依存する。重いシェーダーや大きなアセットは避け、
  Label や Control 系ノード中心で組むのがこのテンプレートの方針(CLAUDE.md より)。

## 新しいノード・シーンを追加する

Godot エディタなら GUI で足せるが、テキスト編集では書式と参照の整合性を自分で守る必要がある。手順:

1. **ノードを既存シーンに足す場合**、`[node name="..." type="..." parent="."]` ブロックを追加する。
   `parent` はシーンルートからの相対パス(直下なら `"."`、`Main` の下なら `"Main"`)。名前は兄弟間で重複させない。
2. **新しいシーンファイルを作る場合**、`game/○○.tscn` を新規作成する。先頭は
   `[gd_scene load_steps=N format=3 uid="uid://..."]`。`load_steps` はそのファイルが参照する
   sub_resource / ext_resource の数+1が目安(ずれても致命的ではないが、書式は tscn-format.md を見て合わせる)。
3. **そのシーンを起動シーンにするなら**、`game/project.godot` の `run/main_scene="res://○○.tscn"` を更新する。
   逆に、起動シーンを別ファイルに変えたのに `project.godot` を直し忘れる、が一番ありがちな事故。
4. **外部リソース(別シーン・画像・スクリプト)を参照するなら**、`[ext_resource type="..." path="res://..." id="..."]`
   を宣言してから `ExtResource("id")` で使う。path が実在するか、id が一意かを確認する。

追加後のチェックリスト(どれか一つでも崩れると読み込み失敗や無表示になる):

- [ ] `project.godot` の `run/main_scene` が実在するシーンを指している
- [ ] 変更した `.tscn` 内の sub_resource / ext_resource の id がファイル内で一意
- [ ] `ExtResource(...)` / `SubResource(...)` で参照している id が全て宣言済み
- [ ] `path="res://..."` で指すファイルが実在する
- [ ] GDScript のインデントがタブで揃っている

## Webエクスポートとデプロイ

`main` に push すると `.github/workflows/deploy.yml` が動く。仕組み・設定・つまずきどころ(特に
`GODOT_VERSION` はフルの semver でないと `Invalid version` で落ちる、`thread_support` は unityroom 互換のため OFF、
GitHub Pages の Source 設定が初回に必要、など)は `references/web-export.md` にまとめてある。
デプロイ関連を触る前に必ずそちらを読むこと。

## 変更後の確認(共通)

Godot がインストールされている環境なら、コミット前に検証できると事故が減る:

```bash
cd game
godot --headless --check-only --script res://foo.gd   # 特定スクリプトの構文チェック(任意)
godot --headless --quit                                 # プロジェクトが読み込めるかの起動確認
```

Godot が無い環境では、上のチェックリストを手で確認するのが次善策。`.tscn` を壊していないか不安なときは
`references/tscn-format.md` の書式と照らし合わせる。
