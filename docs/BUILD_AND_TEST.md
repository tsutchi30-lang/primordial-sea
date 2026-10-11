# 開発・検証・Windows ビルド

固定構成は Godot **4.7.2 stable 標準版**、GDScript、Compatibility、Windows x86_64。`.godot-version` がエディタと templates の唯一の版指定です。システムの `godot` が別版でも、必ず `tools/godot.sh` を使います。

## Linux の空の checkout から

Linux x86_64 上に Bash、curl、unzip、Python 3、GNU coreutils (`sha512sum`、`timeout`)、Git を用意します。Ubuntu 24.04 の GitHub-hosted runner には含まれます。約 1.3 GB のダウンロードと数 GB の空き容量が必要です。

```bash
tools/bootstrap.sh
python3 tools/generate_assets.py
tools/godot.sh --headless --path . --editor --import
tools/godot.sh --editor --path .
```

初回は公式 `github.com/godotengine/godot-builds/releases/download/4.7.2-stable/` から Linux エディタと同版 templates を取得し、公式 SHA512-SUMS.txt に載る固定ハッシュを検証します。展開した Windows と Linux templates の version.txt と、実際に実行するエディタの版も検証します。通信失敗は工程とホストを出して停止し、別の配布先へ切り替えません。

既定のインストール先はリポジトリの `.tools/`。2回目以降は検証済みマーカーと必要ファイルがあれば再利用し、再取得しません。`PRIMORDIAL_ENV_ROOT=/absolute/writable/path` を各コマンドに設定すれば共有の作業領域へ導入できます。同じ設定を次のシェルでも使ってください。システムの PATH は変更しません。

この開発環境の準備済み版を使う例:

```bash
export PRIMORDIAL_ENV_ROOT=/workspace/.primordial-sea-env
tools/bootstrap.sh
tools/godot.sh --version
```

これは環境固有の任意設定です。新しい clone と CI はこのパスに依存しません。`.tools/`、`.godot/`、音声生成結果、`build/` は Git 管理外、GDScript UID とフォント本体は Git 管理対象です。

## 共通検証入口

```bash
tools/verify.sh
```

`bootstrap → 決定的な音の生成 → Godot import → M1 smoke・ホガラ歩容 → 旧セーブ移行 → M2本編進行・各生態・地形 → M1遭遇とM2往復の実Input再生` を順に実行します。個別の smoke 呼出しは次の通りです。

```bash
tools/godot.sh --headless --path . --script res://tests/smoke_test.gd
```

各工程は timeout、終了コード、Godot の `SCRIPT ERROR` / `ERROR` / assertion を検査し、各試験固有の成功マーカーも必要です。失敗時は工程名とログを出し、export と配布候補 artifact を成功扱いにしません。import は180秒、smoke は既定180秒、ホガラは150秒、旧セーブ移行60秒、M2 flow180秒、平原・古生物90秒、墓場・地形・M2 UI120秒、M1ポッド入力再生120秒、M2経路600秒、export240秒。smoke の時間制限のみ `VERIFY_TIMEOUT_SECONDS` で変更できます。

ログは `build/logs/import.log`、`smoke.log`、成功記録は `VERIFIED.txt`。自動試験では通常のプレイ進行を使わず、専用の保存先を使います。生成音は Python 標準ライブラリだけで必要なPCM WAVを再生成し、音源サンプルや有料APIに依存しません。日本語の Noto Sans CJK フォントはリポジトリに同梱し、出所と公式ファイルとのハッシュ一致を `assets/licenses/SOURCES.txt` に記録しています。

## Windows 開発版

```bash
tools/export_windows.sh
```

この一つの入口で上の全検証を実行後、`Windows Desktop` preset から release export します。必要ファイルの存在と EXE/PCK の識別子を検査し、`build/windows/` に以下を揃えます。

- `PrimordialSea.exe` と `PrimordialSea.pck`
- 日本語の起動方法、操作、目的、保存場所
- `BUILD_INFO.txt` の固定 Godot 版、ゲーム版、ソース commit、未コミット変更の有無
- `VERIFICATION.txt`、Windows 実機の `PLAYTEST_日本語.md`
- エンジン、第三者ライブラリ、フォントのライセンスと出所
- EXE/PCK の `SHA256SUMS.txt`

フォルダごと配布し、EXEだけを抜き出さないでください。ゲーム実行に Godot の別インストールや外部サーバーは不要です。コード署名と公開 Release は本版の範囲外です。実機で聞いていない音、操作していない Windows、測っていない FPS は確認済みと扱いません。

## GitHub Actions

`.github/workflows/build.yml` は PR、main への push、手動実行で同じ `tools/export_windows.sh` を起動します。Markdown だけの変更では自動 export を省略し、必要なら手動実行します。権限は `contents: read`、45分のジョブ上限、同じブランチの古い実行のキャンセル、7日の artifact 保持、存在しない artifact の失敗扱いを設定しています。checkout v6.1.0 と upload-artifact v6.0.0 は公式タグを確認した commit SHA に固定しています。

GitHub の **Actions → Windows development build → 成功した実行 → Artifacts** から `PRIMORDIAL_SEA_Windows_M3_<commit>` を取得して展開してください。GitHub が ZIP にするため内部を二重ZIPにはしません。最初の workflow が main に入るまでは手動実行ボタンが出ない場合があります。初回は PR の実行結果を確認し、ユーザーのレビューとマージ後に main の実行を見ます。

workflow ファイルを作ったこと、ローカルで成功したこと、GitHub で実行結果を確認したことは別です。実際の検証結果と描画確認は `docs/PROGRESS.md`、実機確認は `docs/PLAYTEST.md` を参照してください。


## M3の共通ゲートと収録

`tools/export_windows.sh` は `tools/verify.sh` を呼ぶため、exportを使う場合に同じverifyを先に繰り返す必要はありません。既存M1/M2の全ゲートを保持し、schema1→3／2→3、M3実mainの回収・保存失敗・帰還・調査継続、環顎の感知・6m/10m横上下回避・実捕食・船内退避、基本装備の実Input往復を追加しています。

| 追加試験 | 成功マーカー | 出力 |
|---|---|---|
| m3_save_test.gd | M3_SAVE_OK | build/logs/m3-save.log |
| m3_flow_test.gd | M3_FLOW_OK | build/logs/m3-flow.log |
| m3_ecology_test.gd（fixed-fps60） | M3_ECOLOGY_OK | build/m3/ecology/manifest.json |
| m3_routes_test.gd（fixed-fps60） | M3_ROUTES_OK | build/m3/routes/routes-manifest.json |

```bash
tools/capture_m3.sh                     # 720p22画面＋4本のInput動画
tools/capture_m3.sh build/m3 probe       # 同じ24fps入力をheadlessで確認
tools/capture_m3.sh build/m3 visuals     # 画面のみ
tools/capture_m3.sh build/m3 kangaku     # 環顎の区間のみ（relay/core/returnも指定可能）
```

X11かXvfb、Mesa、ffmpeg、Python Pillowが必要です。静止画像は宣言したカメラ・進行・姿勢fixture。動画は各区間の始点と開始状態だけ設定し、以後は本番Input、Diverの衝突、酸素、AI、E操作と端末ボタンを通します。return区間だけは携行コアを持つポッド前が始点で、長い帰路は別のroute試験です。

動画は1280×720、24fps、h264/AAC。ffprobeで解像度・fps・manifestの経過時間と音声長を照合します。補間・早回し・色補正なし。フレーム列は元MP4のframe index/PTSを保存。`capture-source-all.json` は収録開始のソースをハッシュ化し、終了時の一致を検査します。収録中はコード／素材／ツールを編集しません。

CIはM3を収録し、Windows、`PRIMORDIAL_SEA_M3_Evidence_<commit>`、検証ログを7日保存します。失敗時も部分出力を残します。実装headとPR検証mergeは別々に記録します。下記M1.5/M2の収録入口は歴史的な比較用として保持します。

## M2 の進行・経路・描画（既存入口）

共通verifyは既存M1の試験を残し、次を追加します。実際の合否は `docs/M2_ACCEPTANCE.md` と `build/logs/` で確認してください。入口が存在すること自体を合格とは扱いません。

| 試験 | 内容 | 成功マーカー |
|---|---|---|
| `save_migration_test.gd` | schema 1→3、原文退避、書込失敗・再試行、未来版拒否 | `SAVE_MIGRATION_OK` |
| `m2_flow_test.gd` | 実mainでM1→M2、両回収順、中継後の死亡・終了、保管・改良・安定化の保存失敗とUI再試行 | `M2_FLOW_OK` |
| `m2_interface_test.gd` | 15種のUI、720pスクロール、6ブイ、中継の距離/視線ガード、ポーズとフォーカス | `M2_INTERFACE_OK` |
| `plains_ecology_test.gd` | 網・切断・自然採餌・実接触した捕食者の拘束 | `PLAINS_ECOLOGY_OK` |
| `graveyard_ecology_test.gd` | 有限の音伝播、六面這いの調査・終了・防御・清掃 | `GRAVEYARD_ECOLOGY_OK` |
| `palaeo_ecology_test.gd` | 実在モデル3種の行動と独立した捕食対象の再供給 | `PALAEO_OK` |
| `m2_world_test.gd` | 新旧境界・地形と殻の物理経路 | `M2_WORLD_OK` |
| `m2_routes_test.gd` | 通常Inputと実衝突で主要往復、迂回、途中の引き返し、酸素記録 | `M2_ROUTES_OK` |

flowの回収地点への移動は明示した相互作用fixtureです。routeは基本480秒タンク・1.2秒カッター・誘餌/パルス0で、各独立ケースの初期M1完了checkpointと始点だけを設定します。その後は通常Input→Diverの慣性→`move_and_slide`、本編の酸素・生態を通します。通常の新規開始をM2へ変更しません。保存先は `user://automated-tests/` の実行ごとに異なる隔離ディレクトリです。

`build/m2/routes/routes-manifest.json` はポッド↔中継、中継↔各部品、部品携行中の中継→ポッド、主/別経路と引き返しについて、出発時容量・残量、経過ゲーム秒、実移動距離、**補給直前残量と区間中の最小残量**を保存します。補給後の満タンを余裕に数えません。道を把握した固定ルートの確認であり、初見の45〜90分や人の難易度評価とは区別します。

```bash
tools/capture_m2.sh                         # build/m2 に静止画・2動画・独立metricsを生成
tools/capture_m2.sh build/m2-draft probe     # 描画前に2生態をheadless実Inputで試走
tools/capture_m2.sh build/m2 visuals         # 720p/1080pの代表画面のみ
tools/capture_m2.sh build/m2 plains          # 平原の生態動画のみ
tools/capture_m2.sh build/m2 graveyard       # 墓場の生態動画のみ
tools/capture_m2.sh build/m2 metrics         # 1080p実時間計測のみ
```

非headlessの依存は次節と同じXvfb/Mesa、ffmpeg、Pillowです。静止画は本編進行を凍結し、カメラ位置、解像度、FOV、ライト、低粒子、UI画面と特別なfixtureを画像ごとのmanifestへ保存します。小型種は実寸を保持した観察ズームを明記します。通常FOVは80°。完了UIだけは両部品保管済みfixtureから実際の安定化保存処理を実行します。PNGはViewport生出力、contact sheetは元PNGを変更しない縮小一覧です。

動く資料は平原・墓場それぞれ50秒を目安とする720p/24fpsのMovieMaker収録です。M1完了済みの隔離保存と1回だけの初期ダイバー配置を宣言し、以後はInputで泳ぎます。生物の状態・位置・速度を途中で上書きしません。通常の自然採餌・捕食者の実接触、Shiftによる発音・伝播・六面這いの実移動が起きたかを条件として判定します。描画前のprobeも正式動画と同じ24fpsで操作系列を確認しますが、映像の証拠とは区別します。墓場は入口手前で通常Inputにより整列し、初期の六面這いが占めていた低い通路（床上0.55m）を通ることも検査します。

MP4はh264/AACへ符号化し、50秒以上の映像・音声、1280×720、24fpsをffprobeで検査します。補間・早回し・色補正はしません。元frame indexとPTSで抽出した全編2秒刻みの一覧と反応部分の連続フレームを補助資料にします。連続再生・聴取の検収を意味しません。`metrics` は固定fpsを指定せず独立実行し、1秒準備後のフレーム間隔・平均・p95/p99を記録します。Linux llvmpipeをWindows GPUの測定として扱いません。

同じソースでのimportと描画を並行実行しないでください。正式収録中はコード・素材・harnessを凍結します。`capture-source-*.json` は開始時の実装headとcheckout、未コミット状態、実行素材・コード・制作/検証ツールのSHA256を記録し、終了時に同じ入力だったか照合します。変更があれば収録入口は失敗します。各撮影manifestの起動元を後から書き換えません。

M2時点のCIはM1.5の19組比較の代わりにこのM2入口を実行し、`PRIMORDIAL_SEA_M2_Evidence_<commit>` に画像・MP4・manifest・経路・ログ・レビュー文書を7日保存します。失敗時も部分的な証拠とログをアップロードします。Windows artifactと合わせ、末尾commitはPR検証checkoutである可能性があり、実装headはmanifest/BUILD_INFOで区別します。M1.5比較の入口は関連する描画を再検討するときに使えます。

## M1.5 の比較画像・動く本編（独立した既存入口）

```bash
tools/capture_visuals.sh                 # build/m1-5/after/
tools/capture_encounter.sh               # build/m1-5/motion/
tools/capture_comparison.sh              # 改善前も Git から再生成し、一式を揃える
```

非headlessの描画に Linux の X11 または Xvfb、Mesa OpenGL が必要です。映像には ffmpeg、補助の連続フレーム画像には Python の Pillow が必要です。Ubuntu の追加依存は `xvfb xauth libgl1-mesa-dri mesa-utils ffmpeg python3-pil`。Godot は既存の固定版wrapperを使います。同じソースディレクトリのimportを並行実行しないでください。

静止画は通常のFOV **80°**、固定seed **4702**（地形503171）、本編の初期状態、絶対カメラ位置を前後で共用します。720pではS01・S02・S05、1080pではS01〜S08とライトON/OFF・低粒子・砂付着の計16枚、合わせて19枚です。`manifest.json` に各画像のカメラ・向き・ライト・粒子・生物位置・状態・照明と霧の値を残します。比較静止画だけは両版のホガラの向きを新しい通常の初期進路 `-atan2(8,18)` に揃え、旧版の接地を補正せず、canopyの傾きと姿勢は本編のまま記録します。動く映像ではこの姿勢設定を行いません。PNGはViewportの生出力で、外部の明るさ補正や合成はありません。

静止画では本編進行を止めています。S07の砂は本番の砂煙・露出処理を使う撮影fixtureです。S08は帆の背後に既存の捕食者を置いた透明面の重なり検査で、自然な遭遇配置の証明ではありません。画像生成と目視の判定は分けます。

`contact-sheet-*.jpg` は19枚を見渡すための縮小・caption付き補助一覧です。元のフル解像度PNGを加工・置換しません。

`capture_comparison.sh` は固定M1 commit **7a2375487f39cdb17356c795cb7a6a8659b622ba** を `/tmp` に `git archive` し、現在と同じ撮影harnessだけをコピーして改善前を再描画します。ゲームコードと素材は当該commitのものです。Git履歴が浅く当該commitがなければ失敗します。比較用PNGをGitへコミットする必要はありません。

### 入力再生と動画の違い

`capture_encounter.sh [出力先] [all|pod-route|encounter|gait|metrics]` で個別実行できます。

- `pod-route`: 新規開始→本番の出発処理→通常のInput actionで泳いで遭遇区間へ到達。途中teleportなし。headlessの到達・酸素・距離・衝突の記録です。
- `encounter`: 44秒程度の接近→全身→脚と殻→見える隙間から入場→並走→退出。本編の初期生物状態をそのまま使い、プレイヤーだけ最初に遭遇手前へ配置します。
- `gait`: 46秒程度の足元→休息予兆→休息→再始動。初期位置の設定以外、生物の状態・速度・経路・時間を書き換えません。
- `metrics`: 1080p、FOV80、通常粒子の同じ本編を **実時間** で動かし、1秒の準備期間後のフレーム間隔、平均・95/99パーセンタイル・最悪値を記録します。

移動は `Input.action_press/release` → 本番Diverの慣性・`move_and_slide` を通ります。撮影方向は滑らかに再生しますが、毎フレーム位置を設定する処理はありません。AI・酸素・物理・生態の時計が動き続けます。半秒ごとの位置、入力、酸素、当たり判定、腹側滞在と移動距離、休息の遷移をJSONに記録し、必要条件を満たさなければ `REPLAY_FAIL` になります。

動画は **720p・24fpsのMovie Makerオフライン収録**をMP4へ符号化したものです。エンコード時の補間、倍速、カラー補正は行いません。滑らかな24fpsのMP4は、実時間で24fps動いた証明ではありません。`metrics` の実時間結果とは別々に読みます。Linux llvmpipeの数値をWindows実機の性能として扱いません。

`*-video-info.json` は完成MP4をffprobeで読み取った映像・音声ストリーム情報です。解像度、24fps、予定の尺、音声トラックの長さを検査してから中間AVIを削除します。この検査は音の聴取を意味しません。

`frames-encounter/`、`frames-gait/` は実際のMP4をデコードしたフレームと、時刻を付けた補助一覧です。2秒間隔の全編と足元8fpsの短い連続列を出します。元のフレーム番号を直接選び、実際のPTSをcaptionと `selected-frames.json` に記録します。ffmpegのfps再標本化は使いません。これらの一覧だけで動画再生や音の聴取を確認済みとはしません。静止画の目視、時系列フレームの目視、実時間の動画再生、聴取、Windowsでの操作は `VISUAL_REVIEW_M1_5.md` に分けて記録します。

### 証拠と配布の識別

`evidence.json` はファイルのSHA256、撮影・抽出harnessのSHA256、実装ブランチhead、ビルドcheckout commit、未コミット変更の有無と、Git対象ファイル全体の内容fingerprintを記録します。PRのCIでは `PRIMORDIAL_SOURCE_COMMIT` に実装head、`PRIMORDIAL_BUILD_COMMIT` に検証用merge commitを渡します。Windowsの `BUILD_INFO.txt` も両者を区別し、現在のゲーム版を記録します。

M1.5時点のCIは `PRIMORDIAL_SEA_Visuals_M1_5_<commit>` に改善前後PNG、MP4、frame列、manifest、ログ、レビュー文書を7日間保存していました。現在のCIは上記M3証跡へ切り替えています。描画や動画が失敗した場合はjobを失敗させ、成功した扱いにはしません。失敗時の部分的な証拠も取得できます。全体の実行上限は45分、各描画・収録にも個別timeoutがあります。PRのbaseをmainに限定していないため、M1実装ブランチへの積み重ねPRでも実行されます。
