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

`bootstrap → 決定的な音の生成 → Godot import → 本編を使う smoke test → 接地・休息・通行試験 → ポッドから遭遇区間への入力再生` を順に実行します。個別の smoke 呼出しは次の通りです。

```bash
tools/godot.sh --headless --path . --script res://tests/smoke_test.gd
```

各工程は timeout、終了コード、Godot の `SCRIPT ERROR` / `ERROR` / assertion を検査し、試験は `SMOKE_OK` の明示も必要です。失敗時は工程名とログを出し、export と配布候補 artifact を成功扱いにしません。import は180秒、smoke は既定180秒、ホガラ接地・通行試験は150秒、ポッドからの入力再生は120秒、export は240秒。smoke の時間制限のみ `VERIFY_TIMEOUT_SECONDS` で変更できます。

ログは `build/logs/import.log`、`smoke.log`、成功記録は `VERIFIED.txt`。自動試験では通常のプレイ進行を使わず、専用の保存先を使います。生成音は Python 標準ライブラリだけで10本のPCM WAVを再生成し、音源サンプルや有料APIに依存しません。日本語の Noto Sans CJK フォントはリポジトリに同梱し、出所と公式ファイルとのハッシュ一致を `assets/licenses/SOURCES.txt` に記録しています。

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

GitHub の **Actions → Windows development build → 成功した実行 → Artifacts** から `PRIMORDIAL_SEA_Windows_M1_5_<commit>` を取得して展開してください。GitHub が ZIP にするため内部を二重ZIPにはしません。最初の workflow が main に入るまでは手動実行ボタンが出ない場合があります。初回は PR の実行結果を確認し、ユーザーのレビューとマージ後に main の実行を見ます。

workflow ファイルを作ったこと、ローカルで成功したこと、GitHub で実行結果を確認したことは別です。実際の検証結果と描画確認は `docs/PROGRESS.md`、実機確認は `docs/PLAYTEST.md` を参照してください。


## M1.5 の比較画像・動く本編

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

`evidence.json` はファイルのSHA256、撮影・抽出harnessのSHA256、実装ブランチhead、ビルドcheckout commit、未コミット変更の有無と、Git対象ファイル全体の内容fingerprintを記録します。PRのCIでは `PRIMORDIAL_SOURCE_COMMIT` に実装head、`PRIMORDIAL_BUILD_COMMIT` に検証用merge commitを渡します。Windowsの `BUILD_INFO.txt` も両者を区別し、M1.5の版情報を記録します。

CIはWindows版に加え、`PRIMORDIAL_SEA_Visuals_M1_5_<commit>` に改善前後PNG、MP4、frame列、manifest、ログ、レビュー文書を7日間保存します。描画や動画が失敗した場合はjobを失敗させ、成功した扱いにはしません。失敗時の部分的な証拠も取得できます。全体の実行上限は45分、各描画・収録にも個別timeoutがあります。PRのbaseをmainに限定していないため、M1実装ブランチへの積み重ねPRでも実行されます。
