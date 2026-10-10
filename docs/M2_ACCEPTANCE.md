# M2 装置安定化編の受入結果

対象は `codex/m2-ecology-expansion`、起点M1.5は `5b6aefb`。2026-10-10 14:20:55 UTC の共通検証と、14:20:59 UTC のWindows exportを記録します。実行した入口は `tools/export_windows.sh`（内部で `tools/verify.sh` を実行）で、終了0でした。エンジンは `4.7.2.stable.official.ed1daf0bf` です。

この検証は、起点commitにM2の未コミット変更を加えた作業ツリーで行いました。manifestの `source_commit=5b6aefb…` だけをM2実装commitとみなしません。[経路の証拠台帳][route-evidence] に `source_tree=dirty` とソース入力hash、[BUILD_INFO][build-info] にローカル変更ありと記録されています。CI、クリーンなM2取得からの再ビルド、Windows実機の操作・聴取・実GPU性能は、この時点では未確認です。

「自動確認」は下記の本編処理・試験の通過を表します。位置を設定する状態遷移試験、通常Inputと本番衝突による区間走行、画像の生成、目視、実機操作は別の確認です。人による初見の通しプレイと難易度評価は未確認です。

## 21項目の受入状況

| ID | 状態 | 確認方法 | 結果 | 証拠 | 残る確認 |
|---|---|---|---|---|---|
| M2-01 | 自動確認 | M1 smoke・歩容・新規開始からM2のflow | smoke172、gait30、flow134通過。航法復旧・再開・11開口の往復を保持 | [smoke][log-smoke]、[gait][log-gait]、[flow][log-flow] | Windowsでの旧操作感 |
| M2-02 | 自動確認（分割試験） | schema1未回収・保管・復旧済みの読取と本編flow | 原文、金属最大100万、タンクI、ブイ、独立した観察・設定を保持 | [migration][log-save]、[flow][log-flow] | 同一旧ファイルからの人による連続プレイ |
| M2-03 | 自動確認・Input走行済み | 本番Diver形状と通常Input | 既存域から中継往復、両部品の主経路・迂回・引返しを完走。旧境界に押し戻されない | [world][log-world]、[routes][routes] | 初見での進路発見 |
| M2-04 | 衝突・走行確認、720p目視済み | 三出口の空殻・主経路と迂回、代表画像 | 実衝突と区間走行を確認。rootが720p一覧で両海域のランドマークを確認 | [world][log-world]、[routes][routes]、下記「描画確認」 | 正式1080p・動いて見た誘導の分かりやすさ |
| M2-05 | 自動確認、720p代表画像目視済み | 本編14種の実体、専用生態、図鑑UI | 既存7種＋新7種。古生物試験で実捕獲9回・餌再生も確認 | [smoke][log-smoke]、[palaeo][log-palaeo]、[interface][log-interface] | 全種の動きの映像目視 |
| M2-06 | 自動確認 | 網の接触・基本/改良切断・自然採餌 | 55%減速は重複せず、自己切断で解除。自然採餌で実開口、世代ごとの報酬は一度 | [plains][log-plains]、[routes][routes] | 通常入力の切断映像・視認性 |
| M2-07 | 自動確認 | 窓喰いの実移動と網のsweep接触 | 3.5秒拘束から網を破って脱出。追跡の上限を延長しない | [plains][log-plains] | 誘導と通過を合わせた動画 |
| M2-08 | 自動確認 | 壺の警告と刺激IDによる伝播 | 一刺激で3音、hop0/1/2、休止後に無限再生しない | [graveyard][log-graveyard]、[interface][log-interface] | 実際の音の聴取・伝播映像 |
| M2-09 | 自動確認 | 六面這いの実移動と同じ入口の衝突判定 | 10.47m離席で通路が開く。到達不能・時間切れから有限に復帰 | [graveyard][log-graveyard] | 音誘導から通行までの通常Input映像 |
| M2-10 | 自動確認・Input走行済み | 両部品の外縁/側面迂回と引返し | 誘餌0・パルス0、基本装備で主経路と別経路を完走 | [routes][routes]、[plains][log-plains] | 人による別解の発見 |
| M2-11 | 本編自動確認 | relay UI、距離/視線/遮蔽/deadガードと保存比較 | 酸素・スーツだけを補給。場所・携行品・生態・保存点は維持、中継後死亡/終了でも輸送なし | [flow][log-flow]、[interface][log-interface] | Windowsでの操作・案内確認 |
| M2-12 | Input走行・酸素実測済み | 480秒タンク、基本カッター、10区間の補給前計測 | 最小328.85秒＝68.51%。全区間で目標25%以上。詳細は下表 | [routes][routes]、[経路ログ][log-routes] | 観察・寄り道・迷いを含む初見の余裕 |
| M2-13 | 自動確認（分割試験） | 生態からの有限供給、資源上限、保管/改良取引 | 2素材の供給・携行/保管上限、2改良の効果/費用/単一購入/再開を確認。購入在庫は明示fixture | [plains][log-plains]、[migration][log-save]、[flow][log-flow] | 自然供給から回収・帰投・購入までの連続実操作 |
| M2-14 | 本編自動確認 | 順序反転・片方保管後死亡・中継後終了 | A→B/B→A、A保持/B復帰、installedの非再出現を確認 | [flow][log-flow] | 人による長い探索からの再挑戦 |
| M2-15 | 本編自動確認、720p完了UI目視済み | 候補保存→成功後に実状態へ確定 | 二部品＋航法条件、保存失敗時の未確定、再試行一回、完了後ロードが通過 | [flow][log-flow]、下記「描画確認」 | 正式1080p完了画像 |
| M2-16 | 本編・移行自動確認 | tmp位置のディレクトリによる確実な故障注入 | 帰投・改良・安定化で旧保存/資材を保持。原文退避一回、移行再試行、将来schema上書き拒否 | [migration][log-save]、[flow][log-flow]、[smoke][log-smoke] | Windows実ファイルシステムでの失敗時操作 |
| M2-17 | 本編自動確認、720p目視済み | 14実Buttonとscroll矩形、6ブイの実入力・帰投・ロード | 14種選択、未確認行動の非開示、7個目拒否、回収/再配置を確認。root目視で日本語欠落・パネル外文字なし | [interface][log-interface]、下記「描画確認」 | 1080pとWindowsのマウス操作 |
| M2-18 | 共通自動確認 | M1回帰とM2のpause/focus実physics | 網・壺・六面這い・古生物/餌・pickupの時計を停止/再開。入力解除、ライト復帰、M1砂煙/誘餌/ホガラも通過 | [smoke][log-smoke]、[gait][log-gait]、[interface][log-interface] | 音の体感・実機Alt+Tab |
| M2-19 | ローカルverify/export確認 | 共通入口からimport・全試験・Windows出力 | AMD64 PEと別PCKのヘッダ/サイズ、SHA256を確認。ビルド終了0 | [検証完了][verified]、[export][log-export]、[BUILD_INFO][build-info] | M2のクリーン取得再現、CI、Windows起動 |
| M2-20 | 経路証拠取得、720p静止画目視済み | routes manifestと生成画像を区別 | 最新経路10区間とソースhashを記録。720p16枚生成をrootが確認、一覧と指定原寸を目視 | [routes][routes]、[証拠台帳][route-evidence]、下記「描画確認」 | 正式1080p・2動画・実時間性能・公開artifact |
| M2-21 | 本編自動確認、720p完了UI目視済み | 安定化後のロード・出発 | 二部品はinstalledのまま再探索可能。M2完了とM3未実装の表示を確認 | [flow][log-flow]、下記「描画確認」 | Windowsでの完了後操作 |

## 共通入口の実行結果

全stageは `tools/export_windows.sh` の同一実行に含まれます。各stageは終了コード、成功marker、エンジンERRORの不在を `tools/verify.sh` で検査しました。件数は検査範囲を表す値で、描画品質・実機プレイの合格数ではありません。

| stage | 実際の成功結果 | 証拠 |
|---|---|---|
| M1 smoke | `SMOKE_OK checks=172` | [smoke][log-smoke] |
| ホガラ歩容/出入口 | `HOGARA_GAIT_OK checks=30`、11開口往復・11口径遮断 | [gait][log-gait] |
| 保存移行 | `SAVE_MIGRATION_OK checks=67` | [migration][log-save] |
| M2本編取引/死亡 | `M2_FLOW_OK checks=134` | [flow][log-flow] |
| M2 UI/入力/停止 | `M2_INTERFACE_OK checks=60 viewport=1280x720` | [interface][log-interface] |
| 白濁の平原 | `PLAINS_ECOLOGY_OK checks=30` | [plains][log-plains] |
| 殻の墓場 | `GRAVEYARD_ECOLOGY_OK checks=34` | [graveyard][log-graveyard] |
| 新しい古生物 | `PALAEO_OK checks=36 captures=9 regenerated=true` | [palaeo][log-palaeo] |
| M2地形 | `M2_WORLD_OK checks=28` | [world][log-world] |
| M1ポッド→ホガラ付近 | `REPLAY_OK`、30.57ゲーム秒、72.99m、酸素449.45秒 | [pod-route][log-pod-route] |
| M2通常Input経路 | `M2_ROUTES_OK checks=89 segments=10` | [routes][log-routes] |
| Windows出力 | `WINDOWS_EXPORT_OK`、PE/PCK確認済み | [VERIFICATION][win-verified]、[export][log-export] |

## T01〜T18と実行済み試験の対応

Aは制振フレーム、Bは位相調整器です。通常セーブには触れず、毎回隔離した保存先を使います。

| ID | 確認する経路 | 実行済みの確認と範囲 |
|---|---|---|
| T01 | 未完了schema1から航法復旧→M2 | migrationで旧wreck/storedの意味と資源を保持。本編smoke/flowで航法復旧→M2を別途通過。**同一旧ファイルからの全行程を一つの走行にした試験ではない** |
| T02 | 完了schema1の資材・装備・ブイ・観察保持 | migrationでrepaired、最大100万金属、タンクI、3ブイ、独立ファイルを保持。flowのM1完了fixtureからM2を確認 |
| T03 | 新規開始→M1→M2回収・保管・安定化 | flowで本編の実拾得物・照準/距離/遮蔽判定・取引・再開を通過。各拾得場所への位置fixtureを使用、走行はroutesで別確認 |
| T04 | A保管→B携行中死亡 | flowでAはstored、Bはworldへ復帰し、表示/取得可否も一致 |
| T05 | A携行→中継→死亡/終了 | flowで両終了方法を確認。中継前後のcheckpoint原文は同じで、Aと未保管素材は輸送されない |
| T06 | A→B、B→A | flowで両順序、別々の帰投、一部だけでは安定化不可、両方で完了 |
| T07 | 保存失敗→再試行で一回確定 | flowで帰投・安定化・タンクII・カッター改良のtmp書込を故障させ、実retryボタンで復旧。旧byte列/資材を保持し重複購入を拒否 |
| T08 | 複数網接触→基本切断→重複報酬なし | plainsで2区画接触でも55%、1.2秒の自己切断と減速解除、同世代の再入力無報酬。interfaceでメニュー時のカッター入力解除も確認 |
| T09 | 窓喰いの網接触→拘束→脱出 | plainsで実sweep接触・3.5秒拘束・破断・追跡時間継続を確認 |
| T10 | 自然採餌による実開口 | plainsで入力なしに刃葉虫が区画を削る。routes R5で通常生態を動かした主経路から部品回収/迂回帰着 |
| T11 | 一刺激の有限伝播 | graveyardで同一刺激IDの3音・最大2hop、期限/重複拒否、休止後の自動再発なし |
| T12 | 六面這いの離席・到達不能・時間切れ | graveyardで同じ低い入口が通行可能へ変化、10.47m移動、通常状態への有限復帰と障害物による中断 |
| T13 | 誘餌/パルス0の別経路 | routesの全ケースで双方0。R4は殻側面、R5/R6は平原外縁、R7は両回収先へ向かう途中から引返し |
| T14 | 新海域の6ブイとUI/再開一致 | interfaceで本編道具入力、7個目拒否、E回収・再配置・帰投保存・ロード。実marker座標と0.1mm以内で照合 |
| T15 | 旧境界を越える出入り | worldで旧境界の連続性/流れ、新範囲を確認。routes R1でポッドから中継往復、R3/R4で墓場往復 |
| T16 | pause/focusの停止と復帰 | interfaceで本編physicsを使い網再生・壺警告/音イベント・crawler・古生物/餌・pickupの全時計停止→再開、Shift/道具解除、ライト復帰を確認。実際の音の聴取は未実施 |
| T17 | M1.5回帰 | smoke172＋gait30。ホガラ入退場/休息退出、酸欠HUDの複数フレーム、保存再試行、金属上限、砂煙/誘餌を確認 |
| T18 | 移行失敗・将来schema保護 | migrationでbackup失敗、本体書込失敗、再試行、退避原文保持、異なる既存backup拒否、schema3の読取/新規上書き拒否 |

## 経路と補給前酸素の実測

数値は最新共通検証の [build/m2/routes/routes-manifest.json][routes] の `supply_segments` から転記しました。SHA256は `b3bf05f2063552d99df9eefc0f4d1f1132273ac5e63415e8ccc2b2f406261f51`、台帳生成は2026-10-10 14:20:54 UTCです。草稿の `build/m2-draft/routes/` は使用していません。

条件は基本容量480秒、カッター1.2秒、誘餌/パルス0、通常遊泳上限2.8m/s、経路追従入力の目標は最大2.6m/sです。通常Inputと本番 `move_and_slide`、通常生態・酸素処理を使い、途中のプレイヤーテレポート0・生物状態の強制変更0。各独立ケースの開始時だけM1完了保存を用意し、R1は通常出発、R2/R3/R4/R7は中継、R5/R6は平原入口へ初期配置しています。

全行の出発容量/酸素は **480/480秒**。時間はゲーム内の経過で、headless固定60fpsの処理に要した実時間や性能値ではありません。距離は実際の移動量の積算です。回収では本編の距離・照準・遮蔽判定と2.5秒の接近確認待ちを含みます。生態を眺める寄り道や人の迷いは含まず、予め道を知る自動操縦です。

| case / manifest ID | 区間・到着時携行品 | 距離 m | ゲーム秒 | 補給直前/到着酸素 秒 | 区間最小 秒 | 残量 |
|---|---|---:|---:|---:|---:|---:|
| R1 / `pod-to-relay` | ポッド→中継、部品なし | 356.00 | 151.15 | 328.85 | 328.85 | 68.51% |
| R1 / `relay-to-pod` | 中継→ポッド、部品なし | 356.78 | 150.78 | 329.22 | 329.22 | 68.59% |
| R2 / `relay-frame-relay` | 中継→A回収→中継、A携行 | 224.83 | 100.27 | 379.73 | 379.73 | 79.11% |
| R2 / `carried-frame-relay-to-pod` | 中継→ポッド、A携行 | 356.78 | 150.78 | 329.22 | 329.22 | 68.59% |
| R3 / `relay-phase-main-rear-relay` | 中継→殻正面→B回収→後方出口→中継、B携行 | 318.60 | 139.13 | 340.87 | 340.87 | 71.01% |
| R4 / `relay-phase-side-relay` | 中継→殻側面迂回→B回収→同経路で中継、B携行 | 293.84 | 129.27 | 350.73 | 350.73 | 73.07% |
| R5 / `plain-main-outer-return` | 平原入口→主経路→A回収→外縁→入口、A携行。補給なし | 157.47 | 69.98 | 410.02 | 410.02 | 85.42% |
| R6 / `plain-outer-roundtrip` | 平原入口→外縁迂回→A回収→同経路で入口、A携行。補給なし | 216.20 | 94.50 | 385.50 | 385.50 | 80.31% |
| R7 / `turnback-relay_damping` | 中継→A側途中で引返し→中継、部品なし | 105.28 | 47.00 | 433.00 | 433.00 | 90.21% |
| R7 / `turnback-relay_shell` | 中継→B側途中で引返し→中継、部品なし | 99.99 | 45.22 | 434.78 | 434.78 | 90.58% |

8つの独立ケース・10計測区間の総移動量は2,485.78m、総ゲーム時間1,078.08秒です。一本の新規開始からの通しプレイ時間ではありません。全区間の最小残量は328.85秒（68.51%）で、既知経路の初期目標25%以上を満たしました。**補充後の100%を余裕として集計していません。** R5/R6は補給設備のない初期配置地点に戻って終わり、表にはその時点の残量を載せています。

## 描画確認と未確認

rootの目視報告：720p静止画16枚を生成し、2枚の全体contact sheet、S08 MarrellaとS10ポッドの原寸を確認しました。日本語欠落・パネル外文字は見つからず、14種一覧の末尾、安定化完了UI、両海域ランドマークを確認しています。これは静止配置の代表画像確認で、動画の再生確認ではありません。

720pの実ファイルは [manifest](../build/m2-preview/visuals/1280x720/manifest.json)、[contact sheet 1](../build/m2-preview/visuals/contact-sheet-01.jpg)、[contact sheet 2](../build/m2-preview/visuals/contact-sheet-02.jpg) にあります。撮影担当の `capture-source-visuals.json` は入力191ファイルに撮影前後の変更なしを記録しています。正式出力先 `build/m2/` とは区別します。

rootはソースのない `/tmp/primordial-m2-packed-check` で、出力PCK単独をLinux headlessから30フレーム起動し、終了0・ERRORなしを確認しました。これは梱包資産の起動確認で、Windows実機確認ではありません。

正式1080p画像、白濁平原/殻の墓場の動画、実時間性能、CI、クリーンなM2 checkoutの再現、Windows実機操作・音の聴取は未確認です。画像生成や自動試験だけを根拠に、それらを合格扱いしません。

[log-smoke]: ../build/logs/smoke.log
[log-gait]: ../build/logs/hogara-gait.log
[log-save]: ../build/logs/save-migration.log
[log-flow]: ../build/logs/m2-flow.log
[log-interface]: ../build/logs/m2-interface.log
[log-plains]: ../build/logs/plains-ecology.log
[log-graveyard]: ../build/logs/graveyard-ecology.log
[log-palaeo]: ../build/logs/palaeo-ecology.log
[log-world]: ../build/logs/m2-world.log
[log-pod-route]: ../build/logs/pod-route.log
[log-routes]: ../build/logs/m2-routes.log
[log-export]: ../build/logs/export.log
[verified]: ../build/logs/VERIFIED.txt
[win-verified]: ../build/windows/VERIFICATION.txt
[build-info]: ../build/windows/BUILD_INFO.txt
[routes]: ../build/m2/routes/routes-manifest.json
[route-evidence]: ../build/m2/routes/evidence.json
