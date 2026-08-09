# プロジェクトについて

Godot 4系のWebゲームプロジェクト。`game/` 配下がGodotプロジェクト本体。

## 開発方針

- GDScript中心。シーンは `.tscn`、スクリプトは `.gd`。すべてテキストなので直接編集してよい
- `main` ブランチへのpushで自動的にWebビルド→GitHub Pagesへデプロイされる(`.github/workflows/deploy.yml`)
- UI中心の設計を優先し、重いシェーダー/アセットは避ける(Webエクスポートの負荷を抑えるため)

## 変更時に気をつけること

- `project.godot` の `run/main_scene` が常に正しいシーンを指しているか確認する
- 新しいノード/シーンを追加したら `.tscn` ファイルの整合性([sub_resource]のid重複など)に注意する
- Godotバージョンを上げる場合は `.github/workflows/deploy.yml` の `GODOT_VERSION` も合わせて更新する
- ゲームロジックを触ったら `cd game && godot --headless --script res://tools/headless_check.gd` を通す
  (全ステージのシミュレーションと全画面の生成を確認する。失敗時は終了コード1)
- UIに新しい日本語を足すときは、同梱のサブセットフォントに字が入っているか気をつける
  (`game/assets/fonts/` 。無い字は豆腐になる。詳細はREADME)
- ゲームのルールやバランスの意図は `game/src/core/` のコメントに書く。数値だけ変えると理由が失われる
