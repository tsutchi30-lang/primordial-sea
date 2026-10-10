# 原初の海 — 作業ルール

- 最上位の `PRIMORDIAL_SEA_CODEX_PROMPT.md` と `docs/PROGRESS.md` を読み、現在の段階の本編経路を維持する。
- Godot 4.7.2 stable 標準版、GDScript、Compatibility、Windows x86_64。`tools/godot.sh` を使用し、システムの別版を混ぜない。
- 操作・進行・保存は `scripts/game.gd` が接続し、地形、プレイヤー、生態、UI、音は各担当スクリプトへ分離する。
- 生態の時間は `ecosystem.tick(delta)` から進める。ポーズ・フォーカス喪失中に壁時計で酸素やAIを進めない。
- 本編の回帰確認は `tools/verify.sh`、配布候補は `tools/export_windows.sh`。画面は `tools/capture_visuals.sh`。成功マーカーとエラーログを両方検査する。
- 通常セーブをテストで変更しない。テスト用 SaveStore.directory を設定する。重要品の回収・保管・修理の一意性を維持する。
- 生成音は `tools/generate_assets.py` から再現する。エンジン、templates、`.godot/`、`build/`、実行ファイルはコミットしない。`.gd.uid` は保存する。
- import、ロジック試験、実描画の目視、Windows実機確認を区別して報告する。未実施の品質確認を合格としない。
- 並行担当を使う場合は所有ファイルを分け、importと同一ファイルの編集を同時に行わず、最後に本編で統合する。
