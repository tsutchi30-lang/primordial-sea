# 『原初の海』Codex Cloud・GitHub 開始ガイド

作成日：2026-10-09（日本時間）

## このガイドで始める構成

- ゲーム：Godot 4.7.2 stable標準版＋GDScript。
- 開発場所：Codex Cloud。
- コードと履歴：自分の非公開GitHubリポジトリ。
- ビルド：GitHub Actions。
- 遊ぶ場所：自分のWindows PC。
- 最初の到達点：30分前後で「航法復旧編」を遊べるM1開発版。

Godotの基準版は[公式配布ページ](https://godotengine.org/download/archive/4.7.2-stable/)で確認したもの。エディタと書き出し用テンプレートを同じ版に揃える方針です。

今回の2つのMarkdownは、開発を始めるための文書です。ゲーム本体やGitHubリポジトリは、この文書だけで既に作成されているわけではありません。

## 1．役割を知る

| 名前 | 今回の役割 |
|---|---|
| GitHub | ゲームのソース、素材、設計文書、変更履歴を置く場所 |
| Codex Cloud | そのリポジトリを読み、コードや素材を作って検証する開発環境 |
| Godot | 3Dの画面、操作、生物、物理、音、UIを動かすゲームエンジン |
| GitHub Actions | 変更を元に検証とWindows版の書き出しを行う仕組み |
| PR | 作った変更を、mainへ取り込む前に確認する単位 |
| artifact | Actionsで生成し、ダウンロードできるゲームや検証結果 |

クラウドで開発しても、完成品はWindowsの実行ファイルにできます。GodotのWindows exportはゲームデータと実行用バイナリをまとめるため、書き出し済みのゲームを遊ぶ人がGodotエディタを用意する必要はありません。[GodotのWindows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

現在のCodex Cloudでは、リポジトリと必要な道具を含む環境を用意してから、その環境で開発タスクを開始します。タスクはクラウド側で進み、PCがスリープしていても作業を継続できます。[Codex Cloud公式ガイド](https://learn.chatgpt.com/docs/cloud)

## 2．GitHubに新しいリポジトリを作る

1. GitHubへログインする。アカウントがなければ作成する。
2. [新しいリポジトリの作成画面](https://github.com/new)を開く。
3. リポジトリ名を primordial-sea などにする。
4. 公開範囲を Private にする。
5. READMEを作成する設定をオンにする。
6. リポジトリを作成する。

既存のゴキブリのゲームとは別のリポジトリにします。最初にREADMEを入れておくと、mainに最初のコミットがある状態で始められます。

GitHubの操作の根拠：[新規リポジトリの作成](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)

### 文書をアップロードする

作ったリポジトリの最上位に、次の2ファイルを置きます。

- PRIMORDIAL_SEA_CODEX_PROMPT.md
- PRIMORDIAL_SEA_CLOUD_START.md

リポジトリ画面の Add file → Upload files からアップロードし、コミットします。この2ファイルは同じ階層へ置いてください。

GitHubの操作の根拠：[ファイルの追加](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository)

## 3．Codex Cloudの環境を作る

2026-10-09確認時点の公式手順に沿っています。画面の言語や利用している画面によって、名称が多少違う場合があります。

1. ChatGPTのウェブ版またはデスクトップアプリで、新しい作業を開く。
2. 作業場所で Work in → Cloud を選ぶ。
3. 環境の選択画面を開き、新しい環境の作成を選ぶ。
4. GitHub接続を求められたら、自分のアカウントを接続する。
5. primordial-sea リポジトリを選び、環境の準備を始める。
6. このゲーム用のGodotと必要な道具を準備するよう、次の文を送る。

GitHubのアクセス範囲を選べる場合は、今回のリポジトリを含めます。別の場所でGitHubを接続済みでも、この環境から対象リポジトリを参照できることを確認してください。

### 環境セットアップで送る文

~~~text
このリポジトリは、新規のGodot製3Dゲーム『原初の海』です。
最上位のPRIMORDIAL_SEA_CODEX_PROMPT.mdを読み、まず開発環境を準備してください。

Godot 4.7.2 stableの標準版、GDScript、Compatibilityレンダラー、Windows x86_64向けを使います。
Linux用のGodotエディタと、完全に同じ版のexport templates、必要な補助ツールを準備してください。
Godotの版とテンプレートを確認し、可能なら小さな起動・export確認を行ってください。
実描画が利用できる場合は、仮想ディスプレイやソフトウェアOpenGLによる確認経路も準備してください。

この段階では、環境準備と再利用できるセットアップを優先してください。
既存の2つのMarkdownを維持し、ゲーム本体のM0＋M1実装は環境の準備後に開始します。
必要なネットワーク先やアクセスが不足する場合は、具体的なホストと用途を教えてください。
~~~

Godot本体やテンプレートの取得に必要なアクセスが不足した場合は、Codexが示した公式配布先を環境設定へ追加します。最初から独自のインストールスクリプトを自分で書く必要はなく、現在のCloudでは会話で準備内容を調整できます。[環境作成・準備の公式手順](https://learn.chatgpt.com/docs/environments/cloud-environments)

### 準備を終えたら

セットアップ結果を確認して保存し、Publish を選びます。ここで保存する対象は、自分のタスクで再利用する開発環境です。環境を利用できる人は、自分のみの設定で始めます。

環境の準備完了を待って、その環境から新しいタスクを開始してください。

## 4．最初のゲーム開発を依頼する

同じリポジトリを含む、準備済みのCloud環境で送ります。

### 最初に送る開発依頼

~~~text
リポジトリ最上位のPRIMORDIAL_SEA_CODEX_PROMPT.mdを全文読み、M0＋M1を実装してください。

『原初の海』の航法復旧編を、Windows x86_64で起動から区切りまで遊べる開発版にしてください。
Godot 4.7.2 stable標準版、GDScript、Compatibilityを使い、初回は指定された7種と小さな海域に集中してください。

計画だけで終わらず、ゲーム本体、保存と再開、入力の不具合対策、生態連鎖、検証入口、Windows export、GitHub Actionsまで進めてください。
可能な実描画確認も行い、headlessの検証とWindows実機確認は分けて報告してください。

作業ブランチへ変更を保存し、可能ならレビュー用PRを用意してください。
mainへのマージや公開配布は行わず、実際に遊べる範囲、成果物の場所、確認済み・未確認の項目を日本語でまとめてください。
~~~

「文書を読んで」と伝えるだけでなく、今回作る段階をM0＋M1と明示するのがポイントです。文書にはM2以降の完成形も入っているため、初回にすべてを広く浅く実装するのを避けられます。

同じ基盤を作る初回は、一つの開発タスクを中心に進めます。並列作業を行う場合も、担当を分けて最後に統合するようプロンプトへ記載済みです。

## 5．変更を確認し、mainへ取り込む

Codexから結果が返ったら、少なくとも以下を見ます。

- 航法復旧まで本当に進む実装になっているか。
- 窓喰いの砂煙による可視化、誘餌の連鎖、ホガラの避難場所があるか。
- Windows exportが成功したか。
- 実描画の確認を実施できたか。
- どの操作や品質がWindowsで未確認か。

問題があれば、同じタスクへ具体的に修正を依頼します。結果がよければ、PRの変更内容と確認結果を見て、mainへマージします。

現在のCloudでは、各タスクに固有の作業状態があります。重要な成果はGitへコミットし、次の新しいタスクに未コミットの変更が自動的に引き継がれると考えないでください。[Cloudの保存状態とリポジトリ](https://learn.chatgpt.com/docs/environments/cloud-environments)

環境そのものに新しいツールや依存を追加した場合は、環境の編集と再公開も行い、新しいタスクでその準備を利用します。ソースの保存と環境の準備は、それぞれ確認します。

## 6．Windows版をダウンロードして遊ぶ

1. GitHubリポジトリの Actions を開く。
2. mainのビルドが成功した実行を開く。
3. 実行結果の Artifacts 欄から、PRIMORDIAL_SEA_Windows_M1_ で始まる成果物をダウンロードする。
4. ZIPをフォルダへ展開する。
5. 同梱の説明を読み、PrimordialSea.exe を起動する。

exeと同じ場所にあるPCKなどのファイルは、まとめて保持します。成果物がさらにZIPを内包している構成なら、同梱手順に従ってそちらも展開します。

GitHubのartifactは、ログインし、対象リポジトリを読む権限があるアカウントで取得します。[artifactの取得手順と条件](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)

### ビルドがまだ動いていない場合

最初のworkflowがmainへ入ったあと、Actionsの手動実行からビルドを開始できます。手動実行には、そのworkflowがデフォルトブランチにあることが必要です。[workflowの手動実行](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)

workflowファイルを作っただけなら、まだWindows用artifactは存在しません。Codexの報告で「作成した」「実行した」「成功した」を区別して確認してください。

## 7．最初のWindows確認

まず5〜10分で次を確かめ、続いて航法復旧まで遊びます。

- 日本語が読める。
- 視点を左右へ何周も回せる。
- Shiftを離すと加速が止まる。
- Escでマウスが解放される。
- Alt＋Tabから戻っても勝手に移動・加速しない。
- ライトが切り替わり、ポッド出入り後も動く。
- 水面と水中で酸素の表示が整合する。
- 音量が適切で、設定で調整できる。
- 窓喰いの予兆が見え、攻撃から逃げ直せる。
- ホガラの腹側で閉じ込められない。
- 航法ユニットを持ち帰り、修理して完了できる。
- タイトルへ戻り、「続きから」で保存状態を読み込める。

クラウドのheadless検証は、画面・音・操作感の確認とは分けてあります。Windowsで発見した不具合は、いつ・どこで・何をしたら起きたかを短く伝えると修正しやすくなります。

例：

~~~text
M1をWindowsで確認しました。
ホガラの腹側に入った状態でホガラが休息すると、岩と体の間から出られなくなります。
場所は航法ユニットへ向かう回廊の入口です。
この閉じ込めを修正し、歩行・旋回・休息の3状態で入退場を確認して、Windows版を更新してください。
~~~

## 8．詰まったとき

| 症状 | 次に確認すること |
|---|---|
| Cloudを選べない | 利用中のアカウント、ワークスペース、Cloudの利用設定。表示中の案内を優先する |
| リポジトリが一覧に出ない | GitHub接続に今回のリポジトリへのアクセスが含まれているか |
| Godotが見つからない | 選択した環境と、Godotの準備が次のタスクにも使える状態か |
| export templatesがない | Godot本体と同じ完全なバージョンのtemplatesが導入されているか |
| ダウンロードが止まる | 環境のネットワーク設定と、報告された正式な配布先ホスト |
| Actionsの手動ボタンがない | workflowがmainへ入っているか、手動実行設定を持つか |
| Actionsは成功だがゲームがない | 正しい実行のArtifacts欄を見ているか、artifact生成工程が実行されたか |
| exeを起動してデータが読めない | 同梱ファイル一式を展開しているか。export対象からデータが抜けていないか |
| 新しいタスクで古い状態になる | 作業をGitへ保存したか、対象ブランチが正しいか、必要な環境変更を反映したか |

## 9．費用と保存の考え方

この構成では、Codexの利用枠と、GitHub Actionsの実行時間・artifact保存容量を使います。無料枠や上限はアカウントと設定で変わるので、無制限とは考えず、アカウントの利用状況で確認してください。

初版のプロンプトは、標準的なrunner、短いartifact保持期間、ソースへビルドZIPを入れない運用を指定しています。必要な開発版は手元にも保存してください。

根拠：[GitHub Actionsの課金と利用枠](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## 10．公式情報へのリンク

- [Codex Cloudの開始](https://learn.chatgpt.com/docs/cloud)
- [Codex Cloudの環境準備](https://learn.chatgpt.com/docs/environments/cloud-environments)
- [旧Cloud環境の案内](https://learn.chatgpt.com/docs/environments/cloud-environment)
- [GitHubリポジトリの作成](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)
- [GitHubへのファイル追加](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository)
- [GitHub artifactのダウンロード](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)
- [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/)
- [Godotのコマンドライン開発](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [GodotのWindows書き出し](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

旧Cloudの画面や解説に出会った場合は、現在の環境ガイドを基準にしてください。旧環境向けの設定名と、現行の環境作成画面は一致しないことがあります。
