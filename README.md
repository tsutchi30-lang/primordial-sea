# 原初の海 — 航法復旧編

Godot 4.7.2 / GDScript / Compatibility で作る、Windows x86_64 向けの一人称海洋探索ゲーム。オフラインで動作する航法復旧編です。今回の **M1.5** は、M1を引き継ぐホガラと遭遇区間の見た目改善版です。

ホガラは専用の殻・湾曲した帆・節のある三本脚・濾過房を持ち、足を海底に置いて一歩ずつ進みます。ポッドを出て艇の信号方向へ潜り、深度20m前後の海綿群落を越えた右手の砂地で大きな帆を探してください。腹側は自分で泳いで入退場でき、光が弱まる休息予兆の間は外へ出て観察できます。

酸欠の警告表示、保存失敗時の再試行、金属保管数の読み込みも修正しています。旧M1の正常なセーブ形式を維持します。[見た目と動く本編の確認記録](docs/VISUAL_REVIEW_M1_5.md)と[素材の再生成](docs/ASSET_PIPELINE.md)に、実際の検証範囲を記録します。

救命ポッドから古代の海へ潜り、浅瀬の金属片 **2 個**と、沈んだ調査艇の**航法ユニット**を回収します。ポッドで保管し、整備端末から航法を修理すると「航法復旧編 完了」。その後も観察を続けられます。全編の帰還・M2・M3 は今回の範囲に含みません。

7種の形と行動を観察できます。灯粒虫の群れを誘餌で移動させる、泥ほどきの砂煙で透明な窓喰いを見る、ホガラの腹側へ自分で泳いで並走する、といった生態利用が実際の移動・捕食・衝突へ接続されています。回廊には直進路と迂回路があり、全種の記録はクリア条件ではありません。

## Windowsで遊ぶ

[今回のWindows開発版をダウンロード](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540/artifacts/11665797204)（実装 `85faf4a`、2026-10-17 09:23 UTCまで保存）。[比較画像・映像・撮影条件](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540/artifacts/11666022353)も取得できます。

GitHub の **Actions → Windows development build → 成功した実行 → Artifacts** から `PRIMORDIAL_SEA_Windows_M1_5_<commit>` をダウンロードし、フォルダ全体を展開して `PrimordialSea.exe` を起動します。`PrimordialSea.pck` とライセンス類を同じフォルダに保持してください。比較画像・映像・撮影条件は別の `PRIMORDIAL_SEA_Visuals_M1_5_<commit>` へ保存します。

初回の workflow は PR のチェックから確認できます。`workflow_dispatch` の手動ボタンは、workflow が main に入るまで表示されないことがあります。PRをレビュー・マージした後は main の実行結果を確認してください。CIの実行結果とローカル検証の記録は [進捗](docs/PROGRESS.md) に分けて記載しています。

| 操作 | キー |
|---|---|
| 視点・泳ぐ | マウス、WASD |
| 上昇・下降・加速 | Space、C、Shift |
| 調べる・回収・ポッド端末 | E |
| 観察器・カッター・誘餌・パルス・ブイ | 1〜5、ホイールで選び、左クリック |
| 緊急パルス / ライト | Q / F |
| 図鑑・持ち物 / ポーズ・マウス解放 | Tab / Esc |
| フルスクリーン切替 | F11 |

観察器は左クリックを約2秒押し続けると記録します。小型種は近づいて拡大してください。ポッドでは E で端末を開き、出発・修理・タンク改良を選べます。

ポッド帰還時に資材を保管し、酸素・スーツ・パルス・誘餌を補給します。水面では外気呼吸へ切り替わり、酸素は減りませんが増えません。水中で終了・死亡した場合は最後のポッド保存点から再出発し、未保管の航法ユニットは残骸に戻ります。観察記録と設定は進行とは別に保存されます。

保存先は `%APPDATA%\PrimordialSea\`。新規開始で上書きする前にはゲーム内で確認を表示します。

## 開発・検証

Linux x86_64 の空の clone から、次を実行します。Bash、curl、unzip、Python 3、GNU coreutils、Git が必要です。

```bash
tools/verify.sh             # 固定版準備 → 音生成 → import → 本編の回帰試験
tools/export_windows.sh     # 同じ検証後、build/windows/ へ EXE/PCK と説明書を生成
tools/godot.sh --path .     # Linuxで本編を起動
tools/capture_visuals.sh    # Xvfb/OpenGLによる720p・1080pの画面生成
tools/capture_comparison.sh # 改善前後19組、遭遇・休息の映像、独立した実時間計測
```

初回は公式のエディタとtemplatesを取得・SHA512検証します。システムPATHのGodotに依存しません。開発環境で既に用意した版を利用する場合のみ `PRIMORDIAL_ENV_ROOT=/workspace/.primordial-sea-env` を設定してください。

- [ビルドと検証の詳細](docs/BUILD_AND_TEST.md)
- [Windowsでのプレイ確認手順](docs/PLAYTEST.md)
- [確認済み範囲・残る確認](docs/PROGRESS.md)
- [実装の構成と調整値](docs/IMPLEMENTATION_NOTES.md)

ホガラの専用モデルと材質は同梱GLB/PNGから読み込み、制作元のBlenderスクリプトも保存しています。通常ビルドにBlenderは不要です。その他の形状・シェーダー・音は同梱コードで生成します。Noto Sans CJKとGodotの出所・ライセンスは `assets/licenses/` に同梱しています。史実を参考にした生物でも、生態と配色には創作を含みます。
