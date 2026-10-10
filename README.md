# 原初の海 — 航法復旧・装置安定化編

Godot 4.7.2 / GDScript / Compatibility で作る、Windows x86_64 向けのオフライン一人称海洋探索ゲームです。M1.5のホガラと既存の航法復旧を保持し、**M2の二海域・追加7種・装置安定化**へ続きます。

浅瀬と回廊で金属片2個と航法ユニットを回収し、ポッドで航法を修理。その奥の**白濁の平原**では、糸庭虫の網を切ったり刃葉虫が削る切れ目を使ったりして制振フレームを回収します。残った網は窓喰いの突進を短時間止めます。**殻の墓場**では共鳴壺の音を六面這いへ伝え、空いた通路から空殻内の位相調整器を探します。双方に消耗品なしで使える迂回路があります。

航法復旧後は、二海域の接続付近にある**中継補給点**で酸素とスーツを補給できます。部品は救命ポッドへ持ち帰って保管し、端末で「装置を安定化」を選ぶとM2完了。14種の観察と探索は続けられます。帰還コアと全編の帰還はM3で実装予定です。

任意のタンクII・カッター改良、手動ブイ6個、追跡部品の選択を追加しています。形態の参考と創作の区分は [M2の生物資料](docs/M2_SPECIES_SOURCES.md)、旧ホガラ資産は [制作手順](docs/ASSET_PIPELINE.md) を参照してください。

## Windowsで遊ぶ

[M2 Windows開発版をダウンロード](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704/artifacts/11672747591)。実装 `0369240` / 検証merge `0758fbe5`、2026-10-17 14:31 UTCまで保存。GitHubへのログインが必要な場合があります。期限後はActionsの最新成功runまたは手動実行から取得できます。詳しい条件は [最新の進捗](docs/PROGRESS.md) を参照してください。フォルダ全体を展開し、`PrimordialSea.exe` を起動してください。EXEとPCK・ライセンスを同じフォルダに保持します。

[新海域の画面・二つの生態利用動画・経路の酸素記録・撮影条件](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704/artifacts/11672403942) は `PRIMORDIAL_SEA_M2_Evidence_0758fbe5` に含みます（2026-10-17 14:39 UTCまで）。Windowsへのexportと、Windows OSで人が操作した検収は別です。実際の確認結果は [受入表](docs/M2_ACCEPTANCE.md) に記載します。

| 操作 | キー |
|---|---|
| 視点・泳ぐ | マウス、WASD |
| 上昇・下降・加速 | Space、C、Shift |
| 調べる・回収・ポッド端末・中継設備 | E |
| 観察器・カッター・誘餌・パルス・ブイ | 1〜5、ホイールで選び、左クリック |
| 緊急パルス / ライト | Q / F |
| 図鑑・持ち物 / ポーズ・マウス解放 | Tab / Esc |
| フルスクリーン切替 | F11 |

観察器は左クリックを約2秒押し続けると記録します。小型種は近づいて拡大してください。粘糸はカッターを選び、左クリックを1.2秒（改良後0.6秒）押し続けて切ります。重要部品は E で回収します。ポッドでは E で端末を開き、出発・修理・改良・装置安定化を選べます。

ポッド帰還時に資材を保管し、酸素・スーツ・パルス・誘餌を補給します。水面では外気呼吸へ切り替わり、酸素は減りませんが増えません。水中で終了・死亡した場合は最後のポッド保存点から再出発し、未保管の航法ユニットとM2部品は元の回収地点に戻ります。中継では携行品を保管せず、誘餌・パルスも補充しません。観察記録と設定は進行とは別に保存されます。

保存先は `%APPDATA%\PrimordialSea\`。旧M1/M1.5からは「続きから」を選びます。最初の保存前に元のschema 1を `checkpoint.schema1.backup.json` へ退避し、schema 2へ移行します。未知の将来版は上書きしません。[移行と失敗時の扱い](docs/SAVE_MIGRATION.md)を参照してください。新規開始は現在の進行を上書きするため、引き継ぐときには選ばないでください。

## 開発・検証

Linux x86_64 の空の clone から、次を実行します。Bash、curl、unzip、Python 3、GNU coreutils、Git が必要です。

```bash
tools/verify.sh             # 固定版準備 → 音生成 → import → 本編の回帰試験
tools/export_windows.sh     # 同じ検証後、build/windows/ へ EXE/PCK と説明書を生成
tools/godot.sh --path .     # Linuxで本編を起動
tools/capture_visuals.sh    # Xvfb/OpenGLによる720p・1080pの画面生成
tools/capture_m2.sh         # M2代表画面・生態利用の入力動画・独立した実時間計測
tools/capture_comparison.sh # 任意：M1.5の改善前後比較
```

初回は公式のエディタとtemplatesを取得・SHA512検証します。システムPATHのGodotに依存しません。開発環境で既に用意した版を利用する場合のみ `PRIMORDIAL_ENV_ROOT=/workspace/.primordial-sea-env` を設定してください。

- [ビルドと検証の詳細](docs/BUILD_AND_TEST.md)
- [Windowsでのプレイ確認手順](docs/PLAYTEST.md)
- [確認済み範囲・残る確認](docs/PROGRESS.md)
- [M2の構成と調整値](docs/M2_IMPLEMENTATION.md)

ホガラの専用モデルと材質は同梱GLB/PNGから読み込み、制作元のBlenderスクリプトも保存しています。通常ビルドにBlenderは不要です。その他の形状・シェーダー・音は同梱コードで生成します。Noto Sans CJKとGodotの出所・ライセンスは `assets/licenses/` に同梱しています。史実を参考にした生物でも、生態と配色には創作を含みます。
