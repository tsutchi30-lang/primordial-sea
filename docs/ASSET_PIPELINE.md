# ホガラの専用素材

通常のゲームと Windows export は `assets/models/hogara/hogara.glb`、同梱 PNG、Godot 材質を読みます。Blender のインストールや `.blend` の直接 import は不要です。生成済み素材もソース管理し、空の checkout から既存の `tools/verify.sh`／`tools/export_windows.sh` を使えます。

## 制作元と再生成

造形・UV・法線・テクスチャの制作元は `tools/art/generate_hogara.py`。**Blender 4.3.2** と、Blender に同梱された Python／NumPy を使います。再生成用シェルにはBash、Python 3、GNU timeout、ripgrepが必要です。追加アドオン、外部モデル、写真、画像 API は使用していません。固定シードは **50317115** です。

```bash
PRIMORDIAL_BLENDER_BIN=/usr/bin/blender tools/art/generate_hogara.sh
```

この入口は版を確認し、180秒の上限で GLB と PNG を再生成します。Blender の終了コードだけで判断せず、成功マーカーと例外・接線警告を検査し、出力 GLB の必要ノード、UV、法線、接線、材質、埋め込み画像を確認します。制作ログは `build/art/` に保存します。

編集可能な `.blend` も必要な場合は `--save-blend` を追加します。保存先は Git 管理外の `build/hogara-authoring.blend`。通常の再現元は Python です。GLB には Blender の exporter メタデータ等が含まれるため、別環境のバイト一致を造形再現の条件にせず、形状・名前・寸法・材質・依存を確認します。

## 造形

ホガラの上殻は、厚みが変わる連続した曲面です。背の低い稜線、摩耗した成長縁、平らに近い腹側の天井を分けています。殻から垂れる18枚の肋は広い根元と湾曲した板状断面を持ち、地面を踏む三本の支持脚とは形と先端の高さを変えました。

支持脚には、殻との付け根、硬い節、折れ目のある柔らかな関節、足首につながる細い節、広い三葉状の足底があります。`Upper`／`Lower` は長さ1m、ローカル +Y を長軸にした専用形状です。本編の足の状態と IK が姿勢を決めます。

帆は反りと厚さを持つ一枚の薄い曲面で、表裏と縁を作っています。主な放射筋は形状、小さな分枝と透け方は画像です。右側の深い欠けは個体の特徴として残しました。12房の濾過器官は腹側の左右へ配置し、中央の泳げる帯を空けています。

## 材質と画像

Godot の最終材質は `assets/materials/hogara/` にあります。GLB の同名材質を `scripts/creatures/hogara_model.gd` が置換するため、Blender の複雑なノードの再現をゲーム側へ期待しません。

Godot の GLB import は `gltf/embedded_image_handling=0`（Discard All Textures）です。材質名を保持したまま、ゲームでは専用 `.tres` と `assets/textures/hogara/` の画像だけを使います。これにより、GLB から抽出される別名 PNG とその import／export 依存の重複を避けます。制作確認用の GLB 自体には画像を埋め込んでおり、Blender 等では単体で読めます。[公式 GLTFState の定義](https://docs.godotengine.org/en/latest/classes/class_gltfstate.html)と使用中の Godot 4.7.2 バイナリの選択肢を確認して設定しました。

| 材質 | 表現・入力 |
|---|---|
| Carapace | くすんだ青緑、成長筋、場所で変わる粗さ、控えめな法線 |
| Ivory | 支持脚と薄い成長縁の骨色、硬い節の筋 |
| Tissue / Filter | 腹側・濾過房の赤褐色、柔らかい表面 |
| Joint | 暗い青緑、折り畳む関節の低い光沢 |
| Sail | UV に応じた厚み・透明度と反り。Compatibility 用の小さな shader |
| Vein | 青白い細い筋。弱い発光に限定し、休息予兆で暗くなる |
| Sand | 後側の限られた場所にある摩耗・堆積 |

主な albedo／normal／roughness は1024角、軟組織は512角、帆の厚みと透け方は1024角。albedo と帆の RGB は色として読み、normal と roughness はデータとして扱います。法線と接線、UV を GLB に明示的に書き出しています。画像は GLB にも埋め込み、Godot 材質用の PNG も管理します。

帆の動きは `tick_visual()` が受け取ったゲーム時間からのみ進みます。shader の `TIME`、壁時計、自動再生アニメーションを使いません。ポーズ・フォーカス喪失で生態と同じく停止します。

## 寸法と物理の接続

座標は Godot の1単位＝1m、Y上、頭側は -Z。GLB の原点は、初期姿勢の地面基準です。主な股の位置は `(-2.45,3.25,-2.05)`、`(2.45,3.25,-2.05)`、`(0,3.25,2.7)`。初期足底位置は `(-4,0,-2.7)`、`(4,0,-2.7)`、`(0,0,4.5)` です。

腹側の天井中央は約2.96m。外肋の通行帯は高さ約0.8〜2.4m、肋幅約0.6m、隣との間隔1.7mです。通路の中心は既存の左右 Z±0.85／±2.55m などを維持しました。肋は地面を踏まず、先端を約0.5〜0.6mで止めます。実際の通過可否は、本編のプレイヤー球0.6mと捕食者口器1.4mを使う回帰試験で確認します。

`hogara_model.gd` は次を公開します。

- `build()`：GLB と部位別材質を構築する。複数回呼んでも重複しない。
- `get_hip_positions()`／`get_rest_feet()`：基準寸法。
- `get_collision_meshes()`：上殻、硬い肋、脚の硬い部位の実メッシュ31個。肋18枚は実表面の三角形形状、ほか13個は凸形状を歩行側で一度作り、描画と同じ変換に追従させる。肋の広い付け根を単一の凸形状にすると、見えている通路へ存在しない壁を張るため、肋だけは三角形形状を使う。
- `get_exit_gaps()`：実開口に対応した内側・外側の経由点。
- `set_limb_pose()`：接地と踏み出しから計算した各関節を反映。
- `tick_visual()`：帆の遅れ、濾過房の位相差、休息時の肋の折り畳みと筋の減光。

通行と休息の安全性は `hogara.gd` と本編の物理試験が担当します。素材のファイル検査だけで確認済みにはしません。

## 記録と出所

第2造形版は **83,966三角形、77メッシュ、8材質**。`assets/models/hogara/geometry_manifest.json` に現在の正確な数、制作版、寸法、SHA256 を記録します。主役1体向けで、細部はメッシュへまとめ、以前の大量の基本形ノードより部品単位を整理しています。この数は性能や画質の合格を意味しません。

全造形と PNG は本リポジトリ用に新規生成したオリジナル素材です。第三者の復元画・モデル・テクスチャを同梱していません。Blender と Godot は制作・実行ツールであり、ツール本体をモデルとして同梱しません。既存のエンジン・フォントのライセンス情報は `assets/licenses/` を維持します。

通常画面での見え方、ライトON/OFF、透明面の重なり、歩行・休息の映像と未確認点は `docs/VISUAL_REVIEW_M1_5.md` に分けて記録します。Blender で出力できたこと、GLB の整合検査、本編で実際に目視できたことは別の結果です。

## 再生成の実測

Blender 4.3.2 で同じスクリプトを連続実行し、第2造形版の形状・材質・画像の再現を確認しました。GLB 全体の SHA256 は exporter 内のシリアライズ順で変わりましたが、`tools/art/fingerprint_hogara.py` で三角形の頂点属性（位置・法線・接線・UV）、巻き方向、各ノードの変換、材質定義、埋め込まれた10枚の PNG バイト列を比較すると一致しました。float は 1e-5 単位で比較します。

```bash
python3 tools/art/fingerprint_hogara.py assets/models/hogara/hogara.glb build/art/before.json
PRIMORDIAL_BLENDER_BIN=/usr/bin/blender tools/art/generate_hogara.sh
python3 tools/art/fingerprint_hogara.py assets/models/hogara/hogara.glb build/art/after.json
cmp build/art/before.json build/art/after.json
```

最終的に成長縁を殻と同じ座標式へ合わせ、殻へ食い込んでいた細い黒線を修正しました。この版の連続再生成では、上殻の位置・法線・UV・三角形は一致しましたが、exporter の接線丸めにより6579頂点中3点の tangent 成分に最大0.000100017の差が出ました。位置や衝突形状には影響しません。厳密な fingerprint の不一致をそのまま造形差と決めず、次の比較入口では接線だけ2e-4の許容値で分けて検査します。位置・法線・UV・巻き方向は1e-5、材質・画像・変換は従来どおり比較します。

```bash
cp assets/models/hogara/hogara.glb build/art/before.glb
PRIMORDIAL_BLENDER_BIN=/usr/bin/blender tools/art/generate_hogara.sh
python3 tools/art/compare_hogara.py build/art/before.glb assets/models/hogara/hogara.glb
```

この確認は制作データの再現性です。通常のゲーム画面や足の接地の合格を、この一致から判断しません。
