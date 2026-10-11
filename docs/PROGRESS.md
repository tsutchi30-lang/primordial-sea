# 原初の海 — M3 / M2 / M1.5 / M1 実装・検証記録

## 現在のM3 — 帰還まで接続、最終ビルド・収録中

最新M2 PR #3（未マージ）の `208a292faa0dc56bc7efc9c4cf09af691ae81500` から `codex/m3-return-and-ux` を作成。baseは `codex/m2-ecology-expansion`。M1/M2の履歴を保持しています。

中継の可視画面と操作点、720p整備の主要ボタンと閉じる、進行に合う主目標と重要品通知を修正しました。殻の墓場の先に環状の裂け目、連続した帯の環顎、実天井と二出口の沈没調査艇を追加。固定具切断→帰還コアのE回収→中継補給→ポッド保管→保存成功後の28秒帰還→同じ海での調査継続が動きます。

schema1/2の原文退避と3への明示移行、M2部品と独立したコア、先取り・携行・死亡・保管・帰還の保存失敗と再試行を実装。6m/10mの通常入力で横・上下回避、二方向に誘った他方出口への離脱、船内からの実退避を検証しました。共通exportと正式画像・動画は最終実行後にこの節へ記録します。

基本タンク480秒、カッター未改良、誘餌0・パルス0の実Input経路は、棚往復249.43秒／補給前48.0%、主コア往復313.82秒／34.6%、西迂回358.67秒／25.3%。主経路は中継補給後ポッドまで泳ぎ、実際にコアを保管しています。初見時間は未測定です。

[構成と調整値](M3_IMPLEMENTATION.md)・[受入記録](M3_ACCEPTANCE.md)・[保存移行](SAVE_MIGRATION.md)・[Windowsの短い順路](PLAYTEST.md) を参照してください。Windows実機、物理マウス、連続動画再生、音の聴取、実GPU性能、初見の迷いやすさは未確認です。

以下は過去のM2/M1.5/M1の記録で、M3の検証結果とは分けます。



## M2時点の記録 — 装置安定化まで実装・共通検証済み

最新M1.5 `5b6aefbd92da3381b703b8cd9f4d75d042b967d8` から `codex/m2-ecology-expansion` を作成。M1.5 PR #2 は未マージのため、そのブランチをbaseとする積み重ねPRです。

白濁の平原では刃葉虫の採餌で開いた網を通り、残った網に窓喰いを誘導できます。殻の墓場では共鳴壺の有限な音の連鎖で六面這いが離れた通路を通り、空殻から位相調整器を回収できます。制振フレームと合わせてポッドに保管し、保存成功後に装置安定化が完了します。固定中継、追加7種、任意のタンクIIとカッター改良、6ブイ、14種の図鑑、schema2と旧保存移行を実装しました。仕様と調整値は [M2_IMPLEMENTATION.md](M2_IMPLEMENTATION.md)、受入は [M2_ACCEPTANCE.md](M2_ACCEPTANCE.md) を参照してください。

2026-10-10のGodot4.7.2による共通 `tools/export_windows.sh` は終了0で成功。import、M1 smoke172、歩容30、移行67、進行134、UI60、平原30、墓場34、古生物36、地形28、M1ポッド経路、M2入力経路89項目を通過し、Windows AMD64 EXE/PCKを生成しました。通常Inputで基本装備・誘餌/パルス0の10区間を走行し、最少の補給前酸素は328.85秒/480秒（68.51%）でした。墓場の入力probeでは六面這いが離れた同じ低い入口を通過してEで回収し、東側出口から退出しました。

720pの代表16画面を本編から生成し、全体一覧および図鑑・端末・古生物の原寸で目視しました。日本語の欠落やパネル外への文字は見られず、二海域の輪郭とランドマークを確認しました。静止配置による画像であり、経路の証拠は別の入力走行です。正式な720p/1080p各16枚と二動画各50.375秒を生成し、全画像一覧・主要原寸、動画の全区間と重要場面のフレーム列を目視しました。墓場は同じ低い入口への進入・E回収・側面退出を確認。Linux llvmpipeの独立1080p計測は平均143.521ms、p95 163.327msです。詳細な条件は受入表とmanifestに記録します。

統合時に、航法修理後の新目標、保存取引候補への携行状態の保持、JSON整数比較、カメラ平面上のブイ投影、ホガラ上方の入力経路、六面這いの斜面移動と15秒内の復帰を確認・修正しました。M1.5のモデル資産は変更していません。

Windows OS上の起動・物理マウス・Alt+Tab・音の聴取・実GPU性能、人の初見通しプレイは未確認です。確認手順は [PLAYTEST.md](PLAYTEST.md)。M3と全編帰還は未実装です。

### M2の引き渡し（2026-10-10）

- 作業ブランチ `codex/m2-ecology-expansion`、実装commit `0369240e4f6938d6726cf0d6623f55d25998d972`。[Draft PR #3](https://github.com/tsutchi30-lang/primordial-sea/pull/3) は未マージの #2 に依存し、baseは `codex/m1-5-visual-pass`。
- [CI run 38059702704](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704) は空checkoutから全検証・Windows export・32画面・二動画・独立性能計測・artifactアップロードまで全工程成功。jobログも取得して成功markerとソース191入力の不変性を照合。
- [Windows開発版](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704/artifacts/11672747591)：`PRIMORDIAL_SEA_Windows_M2_0758fbe5`、67,101,359 bytes、2026-10-17 14:31:05 UTCまで。
- [画像・映像・経路・条件](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704/artifacts/11672403942)：`PRIMORDIAL_SEA_M2_Evidence_0758fbe5`、72,788,860 bytes、2026-10-17 14:39:27 UTCまで。
- [CI検証ログ](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38059702704/artifacts/11672224257)：`verification-logs-38059702704-1`、9,908 bytes、2026-10-17 14:39:31 UTCまで。
- artifact末尾 `0758fbe5` はPR検証用merge commitで、実装head `0369240` と区別。Windows ZIPにEXE/PCK、説明・旧保存手順、ライセンス、検証結果、BUILD_INFO、SHA256を含みます。取得にはGitHubログインが必要な場合があります。
- 目視したローカル原寸・映像・manifestは `build/m2/`。CI画像は生成とログを確認し、別途全件目視したとは扱いません。ローカル `build/windows/` はcommit前の統合試作なので、配布用には上のCI artifactを使用してください。
- 最新の目視・CI結果と取得先の追記は文書のみの後続commit。CI artifact内の文書はビルド時点の記録です。現在の受入表と併せて確認してください。mainへのマージと公開Releaseは行っていません。

以下のM1.5/M1成果物と確認結果は過去版の履歴です。M2の成果物と混同しません。


## M1.5改善の履歴

起点はM1の `7a2375487f39cdb17356c795cb7a6a8659b622ba`。専用モデルを通常本編へ組み込み、厚い殻・欠けた帆・節のある三脚・板状の肋・腹側の濾過房を作りました。各足の接地、体重移動、遅れて動く帆と濾過房、足元の砂と低い接地音を追加しています。遭遇区間の砂、岩、海綿、局所的な殻片を整えました。

酸欠警告の上書き、帰投・修理時の保存失敗を成功として扱う問題、999を超える保管金属を読み込めない問題を修正しました。保存失敗は資材を保持して安全なポッドで再試行できます。採集・保管・保存・読込の上限を1,000,000に統一し、旧schema 1を保持します。

既存の航法ユニット回収・保管・修理・完了・再開、7種の生態、入力解除を継続しています。M2以降は今回の範囲外です。M1.5の確認結果と実際の証拠は [VISUAL_REVIEW_M1_5.md](VISUAL_REVIEW_M1_5.md)、再生成元は [ASSET_PIPELINE.md](ASSET_PIPELINE.md) に記録します。

### 今回修正した描画・物理の問題

- 初期の新モデルは殻が平たく肋が棒状に見えたため、殻の盛り上がり・脚の太さ・肋の連続した根元を作り直しました。
- 肋全体の凸衝突が見える開口を塞いでいたため、18枚の肋は可視メッシュの三角形衝突へ変更しました。殻と脚の13形状は凸衝突を維持します。
- 厚い殻による自己遮蔽でホガラの拡大観察ができない問題を修正しました。観察対象自身の衝突だけを除外し、岩の向こうの観察と捕食者の視線は引き続き遮断します。
- 群れの光の補助球の内部へ入ると画面を半透明の大きな面が覆うため、補助光だけをカメラ近傍10〜35cmで消します。実寸の器官と群れの行動は保持します。
- 殻の成長縁が表面へ食い込む細い線と、海底の明るさを通常画面で見つけて調整しました。
- 足底内に隠れて見えなかった接地砂を、地面に沿う足外周の小さな輪へ変更し、原寸の時間違い2フレームで確認しました。
- 動画補助フレームの時刻が元動画とずれる抽出を修正し、元フレームのindexとPTSを残します。

### 検証入口

`tools/verify.sh` は音10本の生成・import・本編回帰・三脚と安全退出・ポッドから遭遇地点への実入力移動を実行します。`tools/export_windows.sh` は同じ検証後にWindows EXE/PCKを出力します。`tools/capture_comparison.sh` はM1のGit commitを別ディレクトリへ展開して前後19組の条件を照合し、遭遇・休息の動画と独立した実時間計測を出力します。通常ビルドにBlenderは不要です。

### M1.5の実測・実行結果

- 最終実装 `85faf4a` の空clone（`.godot/`・生成音・buildなし）から音生成、import、smoke172項目、歩容30項目、ポッドからの本番Input移動、Windows EXE/PCK exportが終了0で成功しました。通常ビルドでBlenderは使いません。ソースのない空フォルダからPCK単独のLinux/headless起動も30フレーム・終了0で成功しました。
- 改善前後19組のカメラ・FOV・seed・ライトを照合し、全組の一覧と主要部位の原寸を目視しました。遭遇44.375秒・足元46.375秒のMP4、時刻付きフレーム列を生成し、全区間を時系列目視しました。連続再生・聴取の検収とは区別しています。
- 本番Inputで腹側に9.18秒滞在し6.35m並走、退出を確認。専用試験では接地滑り・地形誤差0、11開口で人が往復、口器は遮断、6位置からの退出と閉塞時の中止が成功しました。
- 独立した1080pのLinux llvmpipe測定は平均218.884ms（約4.57fps）、p95 241.508ms。Windows実GPUの結果ではありません。詳細と最終収録の条件はmanifestに記録します。
- モデルのBlender再生成は全メッシュの位置・法線・UV・巻き順を照合し成功。接線のみ許容誤差0.0002内（最大0.000100017）です。
- Windows OS上の起動、マウス、Alt+Tab、音の聴取、操作感、実GPU FPSは未確認です。`docs/PLAYTEST.md` に短い確認手順を残します。

### M1.5の引き渡し（2026-10-10）

- 作業ブランチ `codex/m1-5-visual-pass`、実装commit `85faf4a3e85632674d748b7578fd92b27ac4fcbd`。[Draft PR #2](https://github.com/tsutchi30-lang/primordial-sea/pull/2) は未マージのM1ブランチをbaseにしています。
- [CI run 38041156540](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540) の全工程が成功。import・172項目・30項目・ポッドからの入力移動・Windows export・前後19組の条件照合・2本のMP4・実時間計測・artifactアップロードをログで確認しました。
- [Windows開発版](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540/artifacts/11665797204)：`PRIMORDIAL_SEA_Windows_M1_5_df7511ef`、66,962,296 bytes、2026-10-17 09:23:34 UTCまで保存。
- [比較画像・映像・撮影条件・レビュー](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540/artifacts/11666022353)：`PRIMORDIAL_SEA_Visuals_M1_5_df7511ef`、162,171,498 bytes、2026-10-17 09:35:40 UTCまで保存。
- [CI検証ログ](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38041156540/artifacts/11665857673)：artifact `11665857673`。末尾 `df7511ef` はPR用の検証merge commitで、実装head `85faf4a` と区別します。
- ローカルのWindows配布物は `build/windows/`。同commitのclean cloneで作成し、EXE/PCKのSHA256を照合済み。`build/m1-5/` に原寸画像・最終動画・照合情報を残しました。
- CIはUbuntu 24.04／Mesa 25.2.8／llvmpipe LLVM 20.1.2。静止画起動時のV-Sync変更非対応警告4回を記録し、ERRORなし・描画完了を確認しました。ローカルの目視と性能値はLLVM 19.1.7の別環境です。
- この取得先・最終結果の追記は文書のみの後続commitです。実装と制作・検証コードは `85faf4a` のままで、CI済みの成果物を試してください。Windows実機・連続動画再生・音の聴取は上記の未確認項目です。

## M0＋M1の引き渡し履歴（以下は改善前の記録）


対象は『原初の海』航法復旧編。M2以降の海域・生物・全編帰還は実装範囲外です。

## 実装済みの遊べる範囲

タイトル → ポッド → 潜水 → 浅瀬の採集・拡大観察 → 回廊の生態利用 → 艇の航法ユニット回収 → ポッドで保管 → 金属片2個で修理 → 航法復旧編完了 → 継続探索。死亡後とタイトルからの再開も同じ本編を使います。

7種の固有モデルと行動、岩の遮蔽、砂煙、誘餌から灯粒虫・窓喰いへつながる移動と捕食、ホガラの物理的な隙間・並走・休息時の退出を実装しました。ポッドチェックポイント、独立した観察記録と設定、入力解除、外気呼吸、再補給、タンク改良、3個のブイを含みます。

## 検証の区別

| 工程 | 実施内容と結果 |
|---|---|
| 版・依存 | Godot 4.7.2 stable標準版と同版templates。公式配布SHA512を照合。空の `/tmp/primordial-clean-bootstrap` に実取得・展開・版確認・再実行成功 |
| 素材再現 | Pythonで音9本を生成し、再生成のバイト一致を確認。Noto Sans CJK 2.004と公式配布のSHA256一致・OFL同梱 |
| import | `tools/godot.sh --headless --path . --editor --import` を実行し、スクリプトと資源を読込、エラーなしで成功 |
| ロジック・本編 | `tests/smoke_test.gd` は本編を直接インスタンス化。酸素・入力・保存・回収・死亡・帰投・修理・生態・物理経路を検証。`tools/verify.sh` が **SMOKE_OK checks=112 / VERIFY_OK**、終了0、ERROR・WARNINGなしで成功。成功記録は `build/logs/VERIFIED.txt` と `smoke.log` |
| 実描画 | Xvfb＋Mesa llvmpipeのCompatibility、固定シード・固定カメラ。720p/1080pの画像は `build/screenshots/`。各13枚・計26枚を生成して全枚を目視。形態・透明膜の通常/砂付着差・日本語UI・設定全項目・図鑑の閉じる案内・完了表示を確認。実機プレイやFPS測定ではない |
| Windows export | 空のソースコピーと実装commit `26de99a` のcleanな本repoで `tools/export_windows.sh` が成功。EXEのPE machine=0x8664を確認。空コピーのPCKを単独でLinuxから読込・10フレーム起動も成功。日本語説明・ライセンスを同梱。本repoの成果物は `build/windows/`、実行情報は同フォルダの `BUILD_INFO.txt` |
| GitHub Actions | [run 38031387770](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38031387770) の全工程が成功。jobログを取得し、`SMOKE_OK checks=112`・`VERIFY_OK`・`WINDOWS_EXPORT_OK` とartifactのアップロード成功を確認。Windowsでの実行ではなくLinux runner上の検証・Windows export |
| Windows実機 | 未実施。Windows OS上の起動・マウス・Alt+Tab・音・体感FPSは確認待ち |
| 音 | 波形生成と再生処理・音量バス・解放を確認。音声出力の聴取は未実施 |
| プレイ時間 | 初見25〜40分は目標。人の初見プレイ時間・操作感は未測定 |

本編進行試験ではCI時間を短縮するためプレイヤーを試験地点へ移しますが、回収の距離・照準・遮蔽検査、状態・保存・死亡・修理は本編処理を呼びます。地形の直進・迂回は別途、プレイヤー断面の実際の物理形状で各地点と区間を検査します。これはWindowsで人が操作した通しプレイの代わりではありません。

ソースの空コピーは `.godot/`、WAV、build、Gitメタデータを含まず、音を再生成してimport→112項目→exportを実行しています。LinuxでのPCK起動確認はWindows実機起動とは異なります。

## 引き渡し記録（2026-10-10）

- 作業ブランチ: `codex/m0-m1-navigation`。実装commit: `26de99a5c287e9b58737ba33bf548ba8db56fbf3`。本記録の更新は文書のみで、ゲーム本体はこのcommitと同じです。
- レビュー用の [Draft PR #1](https://github.com/tsutchi30-lang/primordial-sea/pull/1) を作成。mainへのマージと公開Releaseは行っていません。
- [Windows開発版をダウンロード](https://github.com/tsutchi30-lang/primordial-sea/actions/runs/38031387770/artifacts/11662123900)。artifact名は `PRIMORDIAL_SEA_Windows_M1_c44f3d35`、55,540,407 bytes。末尾はPR検証用merge commitで、実装元は上記commitです。保存期限は2026-10-17 06:34 UTCです。
- ローカルの同実装の配布物は `build/windows/`。`BUILD_INFO.txt` のSource commitは `26de99a`、Source treeは `clean`。`VERIFICATION.txt` とEXE/PCKの `SHA256SUMS.txt` を同梱しています。
- 実行入口は `tools/verify.sh`（音生成・import・112項目）、`tools/capture_visuals.sh`（26画面）、`tools/export_windows.sh`（検証再実行・Windows export）。この環境では準備済みのGodotを使うため `PRIMORDIAL_ENV_ROOT=/workspace/.primordial-sea-env` を指定しました。
- 目視対象は両解像度のポッド、浅瀬、小型3種、ホガラ全身・腹側、窓喰い通常・砂付着、残骸、図鑑、設定、完了画面。日本語の欠落や設定の画面外は見られませんでした。動画・Windowsドライバ差・操作感を確認した記録ではありません。

## 受入基準

| ID | 実装・確認 | 残る確認 |
|---|---|---|
| A01–A02 | 本編のタイトル・新規開始・ポッド目標と操作案内 | Windowsで初見の分かりやすさ |
| A03 | 衝突付き遊泳、直進・迂回の球形状と区間cast、地面と描画の高さ | 実機の操作感 |
| A04 | Shift解除、メニュー中の解除、フォーカス喪失と復帰、再開時の入力ロック | Windowsの物理キー・Alt+Tab |
| A05–A06 | 消費倍率、外気呼吸・補給・酸欠猶予、ライト切替 | 出入りと再起動の手操作 |
| A07–A08 | 7種の本編インスタンス、観察器のズーム・記録・独立保存、小型形態の実描画 | 生物の見つけやすさ |
| A09–A10 | 泥ほどきの刺激→砂煙→露出と解除、誘餌→群れ移動→捕食者の離席・捕食 | 人が隙を利用して通過する体験 |
| A11–A12 | ホガラの1.1m隙間を0.6mの人が通り、1.4mの口器を遮断。休息時の安全退出 | 動く体への並走・操作感 |
| A13–A14 | 予兆・有限突進・回復・捜索終了・撤退、別経路の衝突 | 人の回避しやすさ |
| A15–A17 | 本編の回収→死亡→再回収→保管→修理→再開。重要品の消失・二重化防止 | Windows実機の通しプレイ |
| A18–A19 | 日本語、浅瀬・深度差・生物・透明膜・砂付着・HUD・メニューの描画 | Windowsドライバ差 |
| A20–A21 | 固定版bootstrap、共通verify/export、EXE/PCK確認、GitHub Actions成功と成果物アップロードを確認 | Windows起動は実機で確認 |
| A22 | 実施・未実施を本書、ログ、最終報告で分離 | 新しい検証時も区別を保持 |

## 修正した問題

- 実描画で海底メッシュの表裏と強い黄緑の白飛びを発見し、面の向き・色・光を修正。深度に応じて照明と霧を変化させました。
- ホガラの外周を箱から有機的な突起と殻に変更し、物理的な通路寸法は維持しました。
- 誘餌へ群れが動く前に捕食されるケースを修正し、集積後に捕食者が実際に離席する時間を確保しました。
- 破損JSONの処理でエンジンERRORを出す読込を変更し、復旧可能な日本語エラーにしました。
- 終了時の音声資源の残留を修正し、停止とミキサー解放の待機を追加しました。

## 既知の制限・再開点

進行不能になる既知の再現不具合は、自動試験の対象範囲では残っていません。Windows実機の挙動、聴取、操作感、初見の発見速度、実時間のプレイバランスは未確認です。実描画の自動キャプチャは固定カメラの検証用配置であり、通常プレイの到達ログではありません。

次は `docs/PLAYTEST.md` の順にWindowsで操作し、特にホガラの並走、窓喰いの回避と誘餌の隙、拡大観察の発見性を評価してください。問題が出たら場所・直前の操作・再現回数・`godot.log` を記録し、M2へ広げる前にM1を修正します。sourceのビルドは `tools/export_windows.sh`、描画の再現は `tools/capture_visuals.sh` です。
