extends RefCounted
## M1 + M2. Colours and ecological behaviour are fictional, including fossil-inspired species.
const DATA: Dictionary = {
	"opabinia": {
		"name": "オパビニア", "origin": "実在の古生物を参考", "habitat": "光の浅棚・微生物膜", "size": "体長 約7cm",
		"description": "五つの目と、先端で餌をつかむ長い吻。左右の遊泳器官を波打たせる。配色と行動は創作。",
		"morphology": "五眼・把握器のある吻・左右の遊泳葉・尾扇",
		"states": ["swim", "feeding"], "senses": {"food_m": 1.5, "occlusion": true}, "warning": "危険なし", "attack": {},
		"relationships": "微生物膜の上を採餌する", "events": {"feeding": "吻の先を開閉して、海底の餌をつかんでいる。"},
		"appearance": {"colour": "朱と薄青", "length_m": 0.07, "fin_wave_hz": 2.5}, "max_count": 3, "update_hz": 30
	},
	"hallucigenia": {
		"name": "ハルキゲニア", "origin": "実在の古生物を参考", "habitat": "光の浅棚・海綿の根元", "size": "体長 約3cm",
		"description": "細長い体を細い脚で支え、背に長い棘が並ぶ。海綿にしがみついて進む。配色と行動は創作。",
		"morphology": "細長い胴・七対の脚・七対の背棘", "states": ["cling", "feeding"], "senses": {"surface": true, "occlusion": true},
		"warning": "危険なし", "attack": {}, "relationships": "海綿表面で採餌",
		"events": {"cling": "細い脚を順番に動かして表面につかまる。"},
		"appearance": {"colour": "淡い珊瑚色", "length_m": 0.03, "leg_wave_hz": 1.2}, "max_count": 3, "update_hz": 20
	},
	"olenoides": {
		"name": "三葉虫〈オレノイデス〉", "origin": "実在の古生物を参考", "habitat": "光の浅棚・砂地", "size": "体長 約9cm",
		"description": "分節した外骨格と縁の棘。腹側の多数の脚で海底を歩く。配色と行動は創作。",
		"morphology": "頭楯・三葉の分節殻・腹側の多数の脚・尾棘", "states": ["crawl", "feeding"],
		"senses": {"seabed_food": true, "occlusion": true}, "warning": "危険なし", "attack": {}, "relationships": "微生物膜のある砂地をたどる",
		"events": {"feeding": "立ち止まり、前脚で海底の微生物膜をかき取る。"},
		"appearance": {"colour": "銅緑の殻", "length_m": 0.09, "leg_wave_hz": 3.0}, "max_count": 3, "update_hz": 20
	},
	"glowgrain": {
		"name": "灯粒虫", "origin": "オリジナル種", "habitat": "浅棚・回廊の緩い流れ", "size": "体長 約1.5cm・群れで生息",
		"description": "透明な螺旋の体に三つの光点。光の波が群れの向きを示す。",
		"morphology": "螺旋状の体・三つの発光器", "states": ["forage", "bait", "dimming", "shelter"],
		"senses": {"bait_m": 12.0, "large_movement_m": 7.0, "occlusion": true}, "warning": "大きな動きに近い側から消灯する", "attack": {},
		"relationships": "誘餌へ集まる。ホガラと窓喰いの餌。周辺から群れへ流入する",
		"events": {"bait": "誘餌の12m以内にいる群れは、少しずつ餌へ集まる。", "dimming": "大きな動きに近い側から光が弱まる。光だけでは相手の種類は分からない。", "shelter": "ホガラの腹側には、小さな群れが流れ込む。"},
		"appearance": {"colour": "青白い三光点", "length_m": 0.015, "individuals_per_school": 42}, "max_count": 5, "update_hz": 20
	},
	"mudunraveler": {
		"name": "泥ほどき", "origin": "オリジナル種", "habitat": "回廊入口の柔らかい泥底", "size": "体長 約30cm",
		"description": "螺旋状の胴と櫛状の短い脚。半身を泥に埋め、微生物をすくう。",
		"morphology": "螺旋の胴・短い櫛脚", "states": ["feeding", "shiver", "burrow", "rest"],
		"senses": {"sprint_m": 3.0, "rest_s": 15.0, "occlusion": true}, "warning": "潜る直前に持ち上がり震える", "attack": {},
		"relationships": "潜った後の砂煙が透明な膜に付着する。砂煙は約12秒で薄れる",
		"events": {"burrow": "3m以内でShift加速すると、震えて潜り砂煙を上げる。休息は15秒。", "silt": "砂煙は透明な膜にも付着する。自分の視界も濁るので、輪郭を見て進む。"},
		"appearance": {"colour": "砂色の螺旋", "length_m": 0.30, "cloud_radius_m": 5.5}, "max_count": 3, "update_hz": 20
	},
	"hogara": {
		"name": "帆殻獣〈ホガラ〉", "origin": "オリジナル種", "habitat": "浅棚から回廊の餌場", "size": "全長 約8m",
		"description": "欠けた半透明の帆殻と三本の太い脚。腹側には房状の濾過器官が揺れる。",
		"morphology": "三脚・欠けた帆殻・発光する殻筋・濾過房", "states": ["walk", "feeding", "rest_warning", "rest"],
		"senses": {"school_m": 8.0, "occlusion": true}, "warning": "休息の5秒前に減速し、脚を折り、殻筋が暗くなる", "attack": {},
		"relationships": "殻と外周の突起は遮蔽。幅1.1mの隙間へ人は通れるが口器幅1.4mの窓喰いは入れない",
		"events": {"shelter": "腹側へ泳いで入れる。自分で並走すれば、殻と外周の隙間が捕食者を遮る。酸素は補給されない。", "rest_warning": "殻筋が弱まり、脚が折れ始めたら休息の合図。5秒ほどで止まり、腹側から安全に退出する。", "feeding": "房状の器官で灯粒虫を濾し取る。人を追いかけない。"},
		"appearance": {"colour": "青緑の帆と骨白の三脚", "length_m": 8.0, "speed_mps": 0.75, "passage_width_m": 1.1}, "max_count": 1, "update_hz": 30
	},
	"windoweater": {
		"name": "窓喰い", "origin": "オリジナル種", "habitat": "海綿の回廊・白濁の平原の岩間", "size": "全長 約2.6m・口器幅1.4m",
		"description": "四隅が折れる透明な膜。細い光る縁と、不自然な粒子の並びが存在を示す。",
		"morphology": "四枚の透明膜・折りたたむ四隅・立体的な硬い口器", "states": ["ambush", "attention", "windup", "dash", "recover", "search", "return", "feed", "stunned", "snared"],
		"senses": {"player_m": 8.0, "school_m": 14.0, "occlusion": true, "pursuit_s": 12.0, "home_limit_m": 25.0},
		"warning": "発光する縁・粒子の偏り・灯粒虫の空隙・突進前1秒の収縮", "attack": {"mouth_width_m": 1.4, "damage": 28, "dash_m": 7.0, "dash_s": 1.15, "recovery_s": 3.0},
		"relationships": "砂煙で露出。灯粒虫を捕食。岩とホガラに遮られる。残った粘糸に絡まるが、やがて破る",
		"events": {"silt": "砂煙が膜の表面に付着し、透明な体の輪郭を浮かび上がらせる。", "feed": "灯粒虫の群れを追い、待ち伏せ場所を離れて捕食する。", "bait_feed": "誘餌へ集まった灯粒虫を追い、待ち伏せ場所を離れて捕食した。空いた側を通れる。", "windup": "膜をすぼめた約1秒後、定めた方向へ短く突進する。横へ避け、回復中に離れる。", "return": "遮蔽で見失うと捜索をやめる。一連の追跡は12秒以内、ホームから25m以内で終わる。", "stunned": "4m以内の緊急パルスで約2秒ひるむ。回復前に距離と遮蔽を作る。", "predator_snared": "粘糸に触れて膜が引かれ、約3.5秒止まった。残った網は破られるため、空いた側へ離れる。"},
		"appearance": {"colour": "透明膜・青銀の縁・砂色の付着粒子", "length_m": 2.6}, "max_count": 2, "update_hz": 30
	},
	"threadgardener": {
		"name": "糸庭虫", "origin": "オリジナル種", "habitat": "白濁の平原・岩間の粘糸", "size": "本体 約40cm",
		"description": "五枚の板を花びらのように開き、岩へ粘糸を張る。糸の付着粒子から網の位置が分かる。",
		"morphology": "五枚の硬い板・中央の本体・粘糸の接続点", "states": ["feed", "weave"],
		"senses": {"web_contact": true, "regrow_s": 120.0, "safe_regrow_distance_m": 4.0, "predator_regrow_distance_m": 3.0},
		"warning": "糸に付着した粒子と光の反射。触れると遊泳速度が約55%になる", "attack": {},
		"relationships": "漂う小生物を濾す網を張る。刃葉虫が網を削る。残った網には窓喰いが絡まる",
		"events": {"feed": "付着した粒子を本体へ寄せて取り込んでいる。", "weave": "切れた場所に新しい粘糸を張る。泳いでいる人のすぐ周りには再生しない。", "web_cut": "カッターで一区画を切ると通れる。補修繊維はポッドでの改良に使える。", "web_grazed": "刃葉虫が網の一区画を削り、人が通れる自然な切れ目ができた。"},
		"appearance": {"colour": "淡い陶色の板・細い粘糸", "length_m": 0.4, "web_segments_total": 9}, "max_count": 3, "update_hz": 60, "distant_visual_hz": 5
	},
	"bladeworm": {
		"name": "刃葉虫", "origin": "オリジナル種", "habitat": "白濁の平原・粘糸の採餌場", "size": "体長 約60cm",
		"description": "薄い葉を重ねた体を泳ぐと開く。粘糸へ近づいて削り、急な接近には葉の縁を持ち上げる。",
		"morphology": "重なった葉状の体・硬い葉縁", "states": ["swim", "approach", "graze", "finish", "bait", "return", "warning", "defend", "molt"],
		"senses": {"bait_m": 9.0, "home_limit_m": 12.0, "bait_follow_s": 8.0, "bait_cooldown_s": 22.0, "occlusion": true},
		"warning": "葉を閉じ縁を上げる。約0.8秒の予兆後に近距離へ一度反撃", "attack": {"damage": 8, "warning_s": 0.8, "leave_m": 2.5},
		"relationships": "網の一部を食べる。植物性の誘餌に短時間だけ反応。脱皮殻は殻片になる",
		"events": {"web_grazed": "粘糸を削って一区画を切り離した。その切れ目は実際に通れる。", "bait": "9m以内の植物性の誘餌へ向かった。誘導は短時間で終わり、採餌場へ戻る。", "defense": "葉の縁を立てて警戒する。近距離に残らず数m離れよう。", "molt": "古い葉状の殻を残した。拾える脱皮殻はカッター改良に使える。"},
		"appearance": {"colour": "青緑の葉・淡い硬質の縁", "length_m": 0.58, "molt_interval_s": 90.0, "molts_max": 3}, "max_count": 2, "update_hz": 60, "distant_visual_hz": 5
	},
	"resonance_urn": {
		"name": "共鳴壺", "origin": "オリジナル種", "habitat": "殻の墓場・入口と殻の側道", "size": "高さ 約30〜80cm",
		"description": "壺状の群体が膜を動かして水を取り込む。強い振動を受けると膜が膨らみ、短く共鳴する。",
		"morphology": "開口のある壺殻・膨張する薄膜", "states": ["idle", "warning", "rest"],
		"senses": {"sprint_m": 3.0, "propagation_m": 9.0, "propagation_hops": 2, "stimulus_lifetime_s": 6.0, "rest_s": 12.0},
		"warning": "発音の約1秒前に膜が膨らむ", "attack": {},
		"relationships": "近い群体へ有限に音が伝わる。六面這いはその音源を調べに行く",
		"events": {"urn_resonated": "近くの加速による振動に反応して鳴いた。周囲9mほど、最大二段先の群体まで伝わり、しばらく休む。"},
		"appearance": {"colour": "骨色の壺・薄い青の膜", "height_m": 0.65}, "max_count": 4, "update_hz": 60, "distant_idle_hz": 10
	},
	"hexacrawler": {
		"name": "六面這い", "origin": "オリジナル種", "habitat": "殻の墓場・巣と殻面、ホガラの休息地", "size": "体長 約70cm〜1m",
		"description": "六角の板が重なる体で、向きを変えずに横へ歩く。鉱物を運び、殻の付着物を掃除する。",
		"morphology": "重なる六角板・周囲へ広がる関節脚", "states": ["forage", "investigate", "examine", "return", "carry", "clean"],
		"senses": {"home_limit_m": 15.0, "reaction_limit_s": 15.0, "examine_s": 4.0, "blocked_limit_s": 1.5, "occlusion": true},
		"warning": "縁を上げて脚を鳴らす。約0.8秒の予兆後に近距離へ一度反撃", "attack": {"damage": 10, "warning_s": 0.8},
		"relationships": "共鳴壺の音へ実際に移動する。巣から遠くまで追わない。休息したホガラの低い殻縁を掃除",
		"events": {"crawler_investigated": "共鳴した場所まで歩いて調べた。数秒で巣へ戻るので、空いた側を通れる。", "mineral_carried": "拾える鉱物を巣へ運び終えた。運搬するたびに新しい鉱物が増えるわけではない。", "shell_cleaned": "休息中のホガラの低い殻縁を掃除し、付着物を取り除いた。", "defense": "巣のそばで縁を上げて警戒している。距離を取れば追い続けない。"},
		"appearance": {"colour": "灰青の板・骨白の脚", "length_m": 0.9}, "max_count": 3, "update_hz": 60, "distant_idle_hz": 10
	},
	"wiwaxia": {
		"name": "ウィワクシア", "origin": "実在の古生物を参考", "habitat": "白濁の平原・入口の低い泥棚", "size": "体長 約4cm",
		"description": "丸みのある体を鱗状の硬い部分が覆い、二列の長い棘を背負う。柔らかな腹側で進む。配色・採餌動作・この海での配置は創作。",
		"morphology": "丸い体・重なる鱗状硬組織・背の長い棘・柔らかい腹側", "states": ["crawl", "feeding"],
		"senses": {"shelf_food": true, "range_m": 0.12}, "warning": "危険なし", "attack": {},
		"relationships": "観察棚の付着物をゆっくり採餌する。素材を落とす敵ではない",
		"events": {"feeding": "移動を止め、腹側の口を小さく動かして採餌している。この動作はゲーム内の創作。"},
		"appearance": {"colour": "黄土の鱗・淡い棘・珊瑚色の腹側", "length_m": 0.04}, "max_count": 3, "update_hz": 20, "distant_update_hz": 2,
		"reference_url": "https://burgess-shale.rom.on.ca/fossils/wiwaxia-corrugata/"
	},
	"marrella": {
		"name": "マーレラ", "origin": "実在の古生物を参考", "habitat": "殻の墓場・空殻内の観察棚", "size": "体長 約2cm",
		"description": "頭部の棘が左右と後方へ伸び、細かい体節に付属肢が並ぶ。殻の縁で小さく移動する。配色・採餌動作・共存関係は創作。",
		"morphology": "頭部から曲がって伸びる棘・細かい体節・多数の付属肢", "states": ["crawl", "feeding"],
		"senses": {"shelf_food": true, "range_m": 0.12}, "warning": "危険なし", "attack": {},
		"relationships": "近づける殻の観察棚で付着物を採餌する",
		"events": {"feeding": "その場で付属肢の動きを速め、殻の表面を調べている。この採餌行動はゲーム内の創作。"},
		"appearance": {"colour": "薄い銅色の体節・象牙の棘・青緑の付属肢", "length_m": 0.02}, "max_count": 3, "update_hz": 20, "distant_update_hz": 2,
		"reference_url": "https://burgess-shale.rom.on.ca/fossils/marrella-splendens/"
	},
	"anomalocaris": {
		"name": "アノマロカリス", "origin": "実在の古生物を参考", "habitat": "白濁の平原・中継手前の水中", "size": "全長 約90cm",
		"description": "関節のある前方付属肢、波打つ側方の遊泳器官、腹側の口、扇状の尾を持つ。配色と柔らかな小生物を狙う行動は創作で、食性の確定説ではない。",
		"morphology": "関節のある一対の前付属肢・側方の遊泳葉・腹側の口・尾扇", "states": ["swim", "approach", "capture", "depart"],
		"senses": {"prey_m": 5.0, "home_limit_m": 6.0, "approach_limit_s": 9.0, "blocked_limit_s": 1.5, "occlusion": true},
		"warning": "人を襲わない", "attack": {},
		"relationships": "周辺の柔らかな小生物へ近づき、捕らえて離れる。灯粒虫の群れとは別の餌場",
		"events": {"prey_captured": "小生物へ泳いで近づき、前方の付属肢で捕らえた。捕食対象はゲーム独自の設定で、史実の食性を断定しない。"},
		"appearance": {"colour": "赤銅の体・淡い遊泳葉・暗い眼", "length_m": 0.90, "model_scale_m": 0.80, "soft_prey_max": 4, "prey_regrow_s": 45.0}, "max_count": 1, "update_hz": 30, "distant_update_hz": 2,
		"reference_url": "https://burgess-shale.rom.on.ca/fossils/anomalocaris-canadensis/"
	},
	"kangaku": {
		"name": "環顎〈カンガク〉", "origin": "オリジナル種", "habitat": "環状の裂け目", "size": "全長 約10.4m",
		"description": "硬い外面と柔らかな内面を持つ帯状の捕食者。前半身を輪に曲げ、内側の櫛状の歯列で小生物を捕らえる。",
		"morphology": "連続する帯状の体・内側の歯列・後方の遊泳葉", "states": ["patrol","forage","attention","windup","dash","recover","search","retreat"],
		"senses": {"normal_m":8.0,"sprint_m":16.0,"occlusion":true,"encounter_s":18.0,"dash_limit":2,"reacquire_s":10.0},
		"warning": "輪を作り、歯列を揃えて進路を固定する。横や上下へ泳ぎ、岩柱の陰へ。", "attack": {"damage":35,"windup_s":1.6,"locked_s":0.7,"speed_m_s":9.0,"recover_s":4.0},
		"relationships": "灯粒虫の群れを狙う。横流れは人にも環顎にも作用する。小さな誘餌とパルスには反応しない。",
		"events": {"windup":"前半身を輪に曲げ、歯列を向けている。", "locked":"歯列が揃った後は突進の方向を変えない。", "prey_captured":"実際の群れを捕食し、灯りの密度が減った。", "recover":"突進後は約4秒、体をほどいて回復する。", "retreat":"長く追い続けず、出入口から離れた場所へ戻った。"},
		"appearance": {"length_m":10.4,"colour":"青灰の外殻・骨色の歯・砂色の内面"},"max_count":1,"update_hz":60,"distant_visual_hz":5
	}
}
