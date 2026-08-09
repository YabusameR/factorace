# Webエクスポートとデプロイ リファレンス

`main` への push で `.github/workflows/deploy.yml` が走り、Godot を headless で Web エクスポートして
GitHub Pages へ公開する。ここではその仕組みと、テキスト設定を触るときの落とし穴をまとめる。

## 目次

- [デプロイの流れ](#デプロイの流れ)
- [GODOT_VERSION はフル semver 必須](#godot_version-はフル-semver-必須)
- [export_presets.cfg の要点](#export_presetscfg-の要点)
- [GitHub Pages 側の初回設定](#github-pages-側の初回設定)
- [手動実行とローカル確認](#手動実行とローカル確認)
- [unityroom への公開](#unityroom-への公開)
- [よくある失敗と対処](#よくある失敗と対処)

## デプロイの流れ

`.github/workflows/deploy.yml` の `export-web` ジョブ:

1. `actions/checkout` でリポジトリ取得
2. `chickensoft-games/setup-godot` で Godot 本体+エクスポートテンプレートを用意
3. `godot --version` でバージョン確認
4. `mkdir -p build`
5. `cd game && godot --headless --export-release "Web" ../build/index.html`
6. `.nojekyll` を置く(GitHub Pages が `_` 始まりファイルを無視しないように)
7. `actions/upload-pages-artifact` で `build/` をアップロード

続く `deploy` ジョブが `actions/deploy-pages` で公開する。トリガーは `push: branches:[main]` と
`workflow_dispatch`(手動)。**PR上では走らない**ので、修正の実地検証は main へのマージか手動実行で行う。

## GODOT_VERSION はフル semver 必須

ワークフロー冒頭の環境変数:

```yaml
env:
  GODOT_VERSION: "4.4.0"   # ← "4.4" のように省略するとCIが落ちる
```

`chickensoft-games/setup-godot@v2` はフルの semver(`4.4.0` のように3桁)を要求する。`4.4` を渡すと
`Setup Godot` ステップが 0 秒で次のエラーを吐いて失敗する:

```
Error: ⛔️ Invalid version: 4.4
    at parseVersion (.../setup-godot/v2/dist/index.js)
```

**Godotのバージョンを上げるときは、必ず3桁で書く**(例 `4.3.0`, `4.4.1`)。実在するリリースであることも確認する。
`Setup Godot` が即座に失敗したら、まずこの値の書式を疑う。

エディタ側のバージョンと、CIが使うエクスポートテンプレートのバージョンがずれるとエクスポートで失敗する。
`GODOT_VERSION` は実際に開発で使っている Godot と揃えること(CLAUDE.md の方針)。

## export_presets.cfg の要点

`game/export_presets.cfg` に Web プリセットが1つ(`[preset.0]` name="Web")。手編集で触るときの注意:

- `export_path="../build/index.html"` … ワークフローの出力先とプリセットが一致していること。
  ここを変えるなら deploy.yml のエクスポート先も合わせる。
- `variant/thread_support=false` … **unityroom が Thread Support 未対応**なので合わせて OFF にしてある。
  マルチスレッド機能を使いたい場合はここを true にする必要があるが、unityroom 公開との両立は要検討。
- `runnable=true` を保つ。false だと `--export-release "Web"` の対象にならない。
- プリセット名 `"Web"` はワークフローの `--export-release "Web"` と文字列一致している必要がある。改名するなら両方直す。

## GitHub Pages 側の初回設定

リポジトリごとに一度だけ必要(テンプレートから新規リポジトリを作った直後は未設定):

**Settings → Pages → Source を "GitHub Actions" に変更する。**

これをしないと `deploy` ジョブが公開に失敗する。README にも書いてあるが、テンプレート派生リポジトリで
デプロイが通らないときは真っ先にここを疑う。公開先 URL は `https://<username>.github.io/<repo>/`。

## 手動実行とローカル確認

- **手動デプロイ** … GitHub の Actions タブから対象ワークフローを選び `Run workflow`(`workflow_dispatch`)。
  main にマージせず、任意ブランチの内容で試せる(ただし成功すれば実際に Pages へ公開される点に注意)。
- **ローカルエクスポート** … Godot がある環境なら CI と同じコマンドで再現できる:

  ```bash
  cd game
  godot --headless --export-release "Web" ../build/index.html
  ```

  事前に Web 用エクスポートテンプレートのインストールが必要。`build/index.html` をローカルサーバ
  (例 `python -m http.server`)経由で開いて動作確認する。`file://` 直開きは SharedArrayBuffer 等の制約で動かないことがある。

## unityroom への公開

GitHub Pages は開発中の随時確認用。節目のリリースは unityroom へ:

1. `build/` フォルダ(CI成果物 or ローカルエクスポート)を zip 化
2. unityroom へ手動アップロード(Godot の Web エクスポート形式に対応)

`thread_support=false` にしてあるのは unityroom 互換のため([export_presets.cfg の要点](#export_presetscfg-の要点)参照)。

## よくある失敗と対処

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| `Setup Godot` が0秒で `Invalid version` | `GODOT_VERSION` が省略形(`4.4`) | 3桁 semver に(`4.4.0`) |
| エクスポートでテンプレート不一致エラー | エディタ版とテンプレート版のズレ | `GODOT_VERSION` を開発環境と揃える |
| `deploy` ジョブが公開で失敗 | Pages の Source 未設定 | Settings → Pages → Source = GitHub Actions |
| Pages で `_` 始まりファイルが404 | Jekyll が無視 | `.nojekyll` を置く(既にワークフローに有り) |
| `--export-release "Web"` が対象を見つけない | プリセット名不一致 / `runnable=false` | プリセット名を `"Web"` に、`runnable=true` に |
| ブラウザで真っ黒/何も出ない | `run/main_scene` の不整合、重いアセット | `project.godot` の main_scene 確認、UI中心で軽量化 |
