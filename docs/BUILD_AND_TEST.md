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

`bootstrap → 決定的な音の生成 → Godot import → 本編を使う smoke test` を順に実行します。個別の smoke 呼出しは次の通りです。

```bash
tools/godot.sh --headless --path . --script res://tests/smoke_test.gd
```

各工程は timeout、終了コード、Godot の `SCRIPT ERROR` / `ERROR` / assertion を検査し、試験は `SMOKE_OK` の明示も必要です。失敗時は工程名とログを出し、export と配布候補 artifact を成功扱いにしません。import は180秒、smoke は既定180秒、export は240秒。smoke の時間制限のみ `VERIFY_TIMEOUT_SECONDS` で変更できます。

ログは `build/logs/import.log`、`smoke.log`、成功記録は `VERIFIED.txt`。自動試験では通常のプレイ進行を使わず、専用の保存先を使います。生成音は Python 標準ライブラリだけで9本のPCM WAVを再生成し、音源サンプルや有料APIに依存しません。日本語の Noto Sans CJK フォントはリポジトリに同梱し、出所と公式ファイルとのハッシュ一致を `assets/licenses/SOURCES.txt` に記録しています。

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

`.github/workflows/build.yml` は PR、main への push、手動実行で同じ `tools/export_windows.sh` を起動します。Markdown だけの変更では自動 export を省略し、必要なら手動実行します。権限は `contents: read`、30分のジョブ上限、同じブランチの古い実行のキャンセル、7日の artifact 保持、存在しない artifact の失敗扱いを設定しています。checkout v6.1.0 と upload-artifact v6.0.0 は公式タグを確認した commit SHA に固定しています。

GitHub の **Actions → Windows development build → 成功した実行 → Artifacts** から `PRIMORDIAL_SEA_Windows_M1_<commit>` を取得して展開してください。GitHub が ZIP にするため内部を二重ZIPにはしません。最初の workflow が main に入るまでは手動実行ボタンが出ない場合があります。初回は PR の実行結果を確認し、ユーザーのレビューとマージ後に main の実行を見ます。

workflow ファイルを作ったこと、ローカルで成功したこと、GitHub で実行結果を確認したことは別です。実際の検証結果と描画確認は `docs/PROGRESS.md`、実機確認は `docs/PLAYTEST.md` を参照してください。
