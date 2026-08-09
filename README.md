# Godot Web Template

Claude Code + GitHub Actions + GitHub Pages で、新しいGodotプロジェクトを始めるためのテンプレートリポジトリ。

## 構成

```
game/                      Godotプロジェクト本体
  project.godot
  main.tscn
  export_presets.cfg       Webエクスポート設定
  icon.svg
.github/workflows/
  deploy.yml                push時にheadless exportしてGitHub Pagesへ自動デプロイ
```

## 使い方

### 1. このリポジトリをテンプレートとして新規リポジトリを作成

GitHub上で "Use this template" から新規リポジトリを作成する(もしくはそのままclone)。

### 2. GitHub Pagesの設定(初回のみ)

対象リポジトリの Settings → Pages → Source を **"GitHub Actions"** に変更する。
(これをしないとワークフローがデプロイに失敗する)

### 3. ローカル/Claude Codeでの開発

`game/` 配下がGodotプロジェクト本体。GDScript(`.gd`)やシーン(`.tscn`)はすべてテキストファイルなので、Claude Codeで直接編集できる。

Godotエディタで開いて動作確認する場合は `game/project.godot` を開く。

### 4. デプロイ

`main` ブランチにpushすると自動的に:
1. Godot(headless)でWebエクスポートを実行
2. `build/` の成果物をGitHub Pagesにデプロイ

デプロイ先URL: `https://<username>.github.io/<repo>/`

手動でワークフローを実行したい場合は Actions タブから `workflow_dispatch` で起動できる。

### 5. unityroomへの公開(節目リリース用)

GitHub Pagesは開発中の随時確認用。ある程度形になったら:
1. ローカル or CI成果物の `build/` フォルダをzip化
2. unityroomへ手動アップロード(Godot製ゲームのWebエクスポート、PCKファイル形式に対応)

## Godotバージョンについて

`.github/workflows/deploy.yml` の `GODOT_VERSION` を、実際に開発で使っているGodotのバージョンと合わせること。エディタのバージョンとエクスポートテンプレートのバージョンがずれるとビルドに失敗する。

## Web export時の注意

- `variant/thread_support` は既定でOFF(unityroomがThread Support未対応のため合わせてある)。マルチスレッドを使う場合は要検討
- 重いアセット/シェーダーはブラウザ性能に依存するので、UI中心のゲームから始めるのが無難
