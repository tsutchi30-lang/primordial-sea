# 原初の海 — 作業ルール

- 最上位の `PRIMORDIAL_SEA_CODEX_PROMPT.md` と `docs/PROGRESS.md` を読み、現在の段階の本編経路を維持する。
- Godot 4.7.2 stable 標準版、GDScript、Compatibility、Windows x86_64。`tools/godot.sh` を使用し、システムの別版を混ぜない。
- 操作・進行・保存は `scripts/game.gd` が接続し、地形、プレイヤー、生態、UI、音は各担当スクリプトへ分離する。
- 生態の時間は `ecosystem.tick(delta)` から進める。ポーズ・フォーカス喪失中に壁時計で酸素やAIを進めない。
- 本編の回帰確認は `tools/verify.sh`、配布候補は `tools/export_windows.sh`。画面は `tools/capture_visuals.sh`。成功マーカーとエラーログを両方検査する。
- M1.5の比較は `tools/capture_comparison.sh`。基準commitの本編から同条件画像を再生成し、通常Input・実衝突で遭遇と休息の映像を収録する。静止配置、オフライン収録、実時間計測を混同しない。
- M3仕様は `PRIMORDIAL_SEA_CODEX_M3_RETURN_AND_UX.md`。本編進行は `m3_controller.gd`、帰還演出は `return_sequence.gd`。M3画像・入力動画は `tools/capture_m3.sh`、基本装備往復は `tests/m3_routes_test.gd`。schema1/2の原文退避と3の不変条件、保存失敗後の再試行を共通verifyで維持する。
- M2仕様は `PRIMORDIAL_SEA_CODEX_M2_ECOLOGY_EXPANSION.md`。M2の画面・生態利用は `tools/capture_m2.sh`、基本装備の酸素往復は `tests/m2_routes_test.gd`。必ず補給前と区間最小酸素を記録する。M1.5比較全件は関連資産を変更した場合に実施する。
- 海域・境界・ブイは `WorldMap`、素材・部品は `Items`、改良は `Upgrades` の共通定義を使う。重要品は一般携行枠と分離し、中継では保管・checkpoint・生態resetを行わない。
- 進行取引の候補は `clone_runtime()`。再開用 `checkpoint()` で代用しない。schema1/2は初回schema3保存前に原文退避し、未来schemaを上書きしない。
- ホガラ素材の制作元と再生成手順は `docs/ASSET_PIPELINE.md`。GLBとPNGはコミットし、通常のverify/exportではBlenderを要求しない。gaitの接地・退出試験もverify入口に含める。
- 通常セーブをテストで変更しない。テスト用 SaveStore.directory を設定する。重要品の回収・保管・修理の一意性を維持する。
- 生成音は `tools/generate_assets.py` から再現する。エンジン、templates、`.godot/`、`build/`、実行ファイルはコミットしない。`.gd.uid` は保存する。
- import、ロジック試験、実描画の目視、Windows実機確認を区別して報告する。未実施の品質確認を合格としない。
- 並行担当を使う場合は所有ファイルを分け、importと同一ファイルの編集を同時に行わず、最後に本編で統合する。
