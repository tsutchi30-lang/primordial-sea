extends RefCounted
## M1 only. Ecological behaviours and colours are fictional, including fossil-inspired species.
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
		"name": "窓喰い", "origin": "オリジナル種", "habitat": "海綿の回廊・岩の間", "size": "全長 約2.6m・口器幅1.4m",
		"description": "四隅が折れる透明な膜。細い光る縁と、不自然な粒子の並びが存在を示す。",
		"morphology": "四枚の透明膜・折りたたむ四隅・立体的な硬い口器", "states": ["ambush", "attention", "windup", "dash", "recover", "search", "return", "feed", "stunned"],
		"senses": {"player_m": 8.0, "school_m": 14.0, "occlusion": true, "pursuit_s": 12.0, "home_limit_m": 25.0},
		"warning": "発光する縁・粒子の偏り・灯粒虫の空隙・突進前1秒の収縮", "attack": {"mouth_width_m": 1.4, "damage": 28, "dash_m": 7.0, "dash_s": 1.15, "recovery_s": 3.0},
		"relationships": "砂煙で露出。餌へ集まる灯粒虫を捕食。岩とホガラに遮られ、4mの緊急パルスでひるむ",
		"events": {"silt": "砂煙が膜の表面に付着し、透明な体の輪郭を浮かび上がらせる。", "feed": "灯粒虫の群れを追い、待ち伏せ場所を離れて捕食する。", "bait_feed": "誘餌へ集まった灯粒虫を追い、待ち伏せ場所を離れて捕食した。空いた側を通れる。", "windup": "膜をすぼめた約1秒後、定めた方向へ短く突進する。横へ避け、回復中に離れる。", "return": "遮蔽で見失うと捜索をやめる。一連の追跡は12秒以内、ホームから25m以内で終わる。", "stunned": "4m以内の緊急パルスで約2秒ひるむ。回復前に距離と遮蔽を作る。"},
		"appearance": {"colour": "透明膜・青銀の縁・砂色の付着粒子", "length_m": 2.6}, "max_count": 1, "update_hz": 30
	}
}
