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
