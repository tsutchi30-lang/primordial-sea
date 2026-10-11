# M3の保存 — schema 1 / 2 → 3

現行版はschema 3です。`load_checkpoint()` は版ごとの検証後に1→2→3と明示変換し、読み込みだけではファイルを変更しません。正常な旧保存で欠けているM3項目だけを `return_core: "world"` / `game_completed: false` で追加します。M1/M2の進行・資材・装備・6ブイ、別ファイルの図鑑・設定を保持します。

schema 3では新項目の欠落を拒否します。コアは保存時 `world` / `stored` / `installed` のいずれか。`installed` と `game_completed: true` は相互に必要で、航法 `repaired` と安定化も必須です。安定化前の `stored` は正常です。M2の `parts` は従来の2IDだけで、コアを追加しません。

実行時の `carried` は `clone_runtime()` でそのまま保持し、`checkpoint()` だけが `world` へ戻します。コア保管・帰還開始は独立候補を作り、検証・一時ファイル書込・flush・読戻し照合・renameが成功した後に実状態へ確定します。失敗すると携行品や保存済み状態を保持して同じ画面から再試行できます。帰還成功の保存を演出開始より先に行うため、演出中の終了・Escスキップ・次回ロードでも達成済みです。再開時に演出は繰り返しません。

最初の移行保存前に、schema 1なら `checkpoint.schema1.backup.json`、schema 2なら `checkpoint.schema2.backup.json` へ原文バイト列を退避します。同名が別の原文なら上書きせず `checkpoint.schemaN.backup.<SHA256>.json` へ保存します。既存の同内容退避だけを再利用します。退避失敗・本体書込失敗・未知schemaでも旧本体を先に削除しません。

`tests/m3_save_test.gd` がschema 2の安定化前後、上限資材、装備、6ブイ、バックアップ競合、移行失敗と再試行、矛盾した状態とschema 4を扱います。`tests/save_migration_test.gd` はschema 1の未修理／修理済みを継続検証。`tests/m3_flow_test.gd` は実mainで先取り・一般枠満杯・中継・死亡・保管失敗・帰還失敗・演出途中の再開・クリア後の死亡を確認します。すべて隔離保存先を使います。

以下はM1/M2から維持する保存規則です。


進行は `user://checkpoint.json`、観察は `observations.json`、設定は `settings.json` に保存します。通常の進行保存点は救命ポッドです。中継での補給は保存点を更新しません。

## schema 1 → 2 → 3

`SaveStore.load_checkpoint()` は旧形式を検証してから、メモリ上でschema 2へ変換し、続けてM3項目を追加したschema 3を返します。この読み込みでは元ファイルを書き換えず、退避ファイルもまだ作りません。`loaded_schema_version == 1` と `migration_pending == true` により、変換した状態と保存済み状態を区別できます。

| 旧フィールド | 新しい状態 |
|---|---|
| `nav` | `wreck` / `stored` / `repaired` の意味を保持 |
| `stored_metal` | 0～1,000,000 の整数値を保持 |
| `tank_upgraded` | false → `tank_level=0`、true → 1 |
| `buoys` | 既存の配置を保持 |
| 新規項目 | 部品2点は `world`、新素材0、未安定化、カッター未改良 |
| 観察・設定 | 元の別ファイルをそのまま使用 |

最初の schema 3 保存前に、元の正常な schema 1 の**原文バイト列**を `checkpoint.schema1.backup.json` へ一度だけ退避します。退避も一時ファイルへの書込・flush・置換を使います。退避内容を元ファイルと照合してから、schema 3 の本体を書き込みます。

退避失敗なら本体は変更しません。本体書込だけが失敗した場合も、旧本体と退避の両方が残り、同じ候補で再試行できます。既存退避が現在の旧本体と一致すれば再利用し、異なる退避を見つけた場合は元の退避を保持し、原文SHA256を付けた別名へ現在の旧本体を退避します。移行後の通常保存で旧退避を上書きしません。

schema 4以降など未知の schema は読み込み・進行保存を拒否し、元ファイルを保持します。タイトルから新規開始を選んでも、未知の将来形式をこの版の初期状態で置き換えません。JSON 自体が破損した従来の保存は、明示的な新規開始で作り直せます。読み取り不能なファイルは上書きしません。

## schema 2・3 の検証

保存する意味は `nav`、`parts`、`stabilized`、`stored_metal` / `stored_fiber` / `stored_shell`、`tank_level`、`cutter_upgraded`、`tracked_part`、`buoys` です。

- 精密部品 ID は `damping_frame` と `phase_regulator` のみ。保存点の所在は `world` / `stored` / `installed` です。
- 安定化済みの場合に限り両部品が `installed` で、航法も `repaired` である必要があります。片方だけの組込、携行状態の保存、未知 ID を拒否します。
- タンク段階は0～2、タンクIIとカッター改良は航法復旧済みの場合に限ります。
- 素材は各0～1,000,000の整数です。負数、小数、非有限値を拒否します。回収・保管・保存・読み込みは `data/items/item_catalog.gd` の上限を共有します。
- ブイは6個まで、数値かつ有限な三次元座標で、`WorldMap.is_valid_buoy()` の海域範囲内に限ります。旧形式の通常の本編配置を保持します。旧検証が形式上許していた範囲外の ±500 等は、消去やクランプをせず、元データを保持して明確なエラーにします。
- 新しい候補も同じ検証を通してから書き込みます。前のファイルを先に削除しません。

低水準の `write_json()` は設定・観察用です。進行の本編呼出しは必ず `save_checkpoint()` を使い、移行・検証・未知版の保護を通します。試験で不正ファイルを用意するときだけ低水準書込を使います。

## 携行品・補給・保存候補

実行中の部品は `world → carried → stored → installed` と進みます。一般素材が満杯でも精密部品を回収できます。金属12、補修繊維8、殻片8が各携行上限で、重要品は別枠です。

`clone_runtime()` は、携行素材、部品の携行状態、酸欠経過、消耗品、警告、ブイを含めた完全な独立コピーです。帰投・整備ではこの候補に `deposit()` / `upgrade(id)` / `stabilize()` を適用し、保存成功後に本編へ確定します。保存失敗なら実状態の資材と所在を保持したまま再試行できます。

`checkpoint()` は再開用で、携行素材を含めず、携行中の航法ユニットを `wreck`、精密部品を `world` にします。したがって候補作成に checkpoint を代用しません。死亡・水中終了では未保管の部品が回収地点へ戻り、保管済みの別部品だけが残ります。

`relay_refill()` は生存中の酸素・スーツを回復し、酸欠経過と酸素警告を解除します。誘餌・パルス、携行・保管数、重要品、無敵時間、チェックポイントを変更せず、死亡済みなら失敗します。既存の `refill()` はポッドでの再出発用 API として、蘇生・基本道具の補充を保持しています。

## 検証入口

`tests/save_migration_test.gd` を固定版 Godot から実行します。通常セーブには触れず、実行ごとの `user://automated-tests/migration-<pid>-<ticks>/` を使用します。

```bash
timeout --kill-after=10 60 tools/godot.sh --headless --path . --script res://tests/save_migration_test.gd
```

成功時は `SAVE_MIGRATION_OK`、失敗時は非ゼロ終了と対象の説明を出します。旧未完了・完了、元ファイルと独立記録の保持、退避・移行書込の失敗と再試行、未知版、完全な実行時コピーと再開用状態の違い、中継、資材境界、状態の不整合、6ブイを扱います。書込失敗は一時ファイルの場所をディレクトリにして再現するため、root 実行でも再現可能です。

本編の実回収、帰投 UI、安定化・装備改良の保存失敗と再試行は `m2_flow_test.gd` で別途確認します。検証の実行結果は `docs/PROGRESS.md` / `docs/M3_ACCEPTANCE.md` と実際のログを参照してください。この文書のコマンド掲載だけでは実行済みを意味しません。
