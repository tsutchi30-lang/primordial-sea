extends RefCounted
## Shared horizontal ranges, boundary flow, signals and authored swim corridors.
## POINTS / ROUTES store height above the local bed in y, not absolute depth.
const MAP_MIN := Vector2(-150.0, -592.0)
const MAP_MAX := Vector2(150.0, 60.0)
const CAMERA_FAR := 760.0
const BUOY_MIN_Y := -310.0
const BUOY_MAX_Y := 10.0
const WEB_LEARNING := Vector2(0, -189)
const WEB_GRAZING := Vector2(-12, -216)
const WEB_TRAP := Vector2(-5, -222)
const PLAINS_PREDATOR_HOME := Vector2(-5, -228)
const BIOMES := {
	"shallows": {"name": "目覚めの浅瀬", "min": Vector2(-150, -55), "max": MAP_MAX},
	"corridor": {"name": "灯の回廊", "min": Vector2(-150, -175), "max": Vector2(150, -55)},
	"milky_plain": {"name": "白濁の平原", "min": Vector2(-150, -298), "max": Vector2(150, -175)},
	"shell_graveyard": {"name": "殻の墓場", "min": Vector2(-150, -430), "max": Vector2(150, -298)},
	"ring_rift": {"name": "環状の裂け目", "min": MAP_MIN, "max": Vector2(150, -430)}
}
const POINTS := {
	"damping_frame": Vector3(-12, 1, -225),
	"relay": Vector3(28, 2, -275),
	"phase_regulator": Vector3(25, 1, -365),
	"plain_entrance": Vector3(0, 2.4, -181),
	"plain_wreck": Vector3(-12, 0, -225),
	"plain_fins": Vector3(30, 0, -243),
	"graveyard_entrance": Vector3(25, 2.4, -306),
	"shell_entrance": Vector3(25, 2.4, -347),
	"shell_rear_exit": Vector3(25, 2.4, -385),
	"shell_side_exit": Vector3(40, 2.4, -366),
	"crawler_home": Vector3(25, 0.55, -348),
	"urn_lure": Vector3(14, 0.4, -345),
	"urn_chain_1": Vector3(7, 0.015, -345),
	"urn_chain_2": Vector3(0, 0.015, -345),
	"urn_tutorial": Vector3(-10, 0.4, -311),
	"wiwaxia_shelf": Vector3(-8, 0.65, -185),
	"marrella_shelf": Vector3(16, 0.65, -357),
	"mineral_cache": Vector3(37, 0.45, -379),
	"crawler_mineral_home": Vector3(37, 2.4, -373),
	"crawler_cleaner": Vector3(22.5, 0.4, -74),
	"anomalocaris": Vector3(12, 4.5, -253)
}
const ABSOLUTE_POINTS := {"pod": Vector3(0, -2, -5), "nav": Vector3(0, -36, -130),
	"rift_shelf": Vector3(0, -244, -466),
	"return_core": Vector3(24, -268.8, -502),
	"rift_ship": Vector3(24, -270, -499),
	"ship_entrance": Vector3(24, -268, -484),
	"ship_exit": Vector3(32, -268, -508),
	"rift_cover": Vector3(42, -266, -499)}
# These routes are genuinely three-dimensional, including inside the wreck.
# No floor-height interpolation may move them through its ceiling.
const RIFT_ROUTES := {
	"shelf_ship": [Vector3(0,-244,-466), Vector3(-2,-257,-478), Vector3(16,-268,-481), Vector3(24,-268,-483), Vector3(24,-268,-491), Vector3(24,-268.8,-500.2)],
	"rift_detour": [Vector3(0,-244,-466), Vector3(-24,-252,-470), Vector3(-25,-265,-492), Vector3(-18,-267,-525), Vector3(35,-268,-526), Vector3(38,-268,-508), Vector3(28,-268,-508), Vector3(24,-268.8,-500.2)],
	"core_exit": [Vector3(24,-268.8,-500.2), Vector3(25,-268,-508), Vector3(35,-268,-508), Vector3(42,-266,-499), Vector3(40,-252,-482), Vector3(25,-243,-472), Vector3(0,-244,-466)]
}
const RIFT_ACCESS := [Vector3(28,2,-275),Vector3(28,5,-269),Vector3(39,5,-268),Vector3(48,5,-296),Vector3(48,5,-335),Vector3(46,5,-388),Vector3(25,5,-416),Vector3(0,5,-438),Vector3(0,5,-443),Vector3(0,5,-448),Vector3(0,5,-453),Vector3(0,5,-458),Vector3(0,5,-462)]
const RIFT_PATROL := [Vector3(-8,-253,-481), Vector3(18,-251,-470), Vector3(49,-251,-477), Vector3(51,-257,-530), Vector3(1,-261,-535), Vector3(-26,-255,-505)]
const RIFT_RETREATS := [Vector3(-32,-248,-490), Vector3(62,-243,-534), Vector3(-12,-252,-544)]
const CROSS_CURRENT_CENTER := Vector3(3,-258,-479)
const CROSS_CURRENT_HALF := Vector3(28,14,5)

const ROUTES := {
	# Transit swimmers pass visibly above Hogara's moving shell; its original
	# floor-level shelter encounter and all M1 scenery remain available below.
	"pod_relay": [Vector3(0, 6, -12), Vector3(0, 3, -42), Vector3(18, 9, -68), Vector3(18, 9, -108), Vector3(14, 5, -140), Vector3(0, 4, -162), Vector3(0, 3, -181), Vector3(-25, 3, -198), Vector3(-35, 3, -230), Vector3(-28, 3, -255), Vector3(10, 4, -267), Vector3(28, 2.4, -270), Vector3(28, 2, -275)],
	"plain_main": [Vector3(0, 2.4, -181), Vector3(0, 2.4, -197), Vector3(-12, 2.4, -207), Vector3(-12, 2.4, -216), Vector3(-12, 1.9, -224)],
	"plain_detour": [Vector3(0, 3, -181), Vector3(-33, 3, -197), Vector3(-35, 3, -225), Vector3(-25, 3, -234), Vector3(-20, 3, -220), Vector3(-12, 2.2, -220), Vector3(-12, 1.9, -224)],
	"relay_damping": [Vector3(28, 2, -275), Vector3(28, 3, -269), Vector3(16, 4, -251), Vector3(-26, 3, -243), Vector3(-28, 3, -230), Vector3(-20, 3, -220), Vector3(-12, 2.2, -220), Vector3(-12, 1.9, -224)],
	"relay_shell": [Vector3(28, 2, -275), Vector3(28, 3, -269), Vector3(39, 4, -268), Vector3(38, 4, -290), Vector3(30, 3, -321), Vector3(25, 2.4, -340), Vector3(25, 2.4, -350), Vector3(25, 1.9, -364)],
	"shell_detour": [Vector3(28, 2, -275), Vector3(28, 3, -269), Vector3(39, 4, -268), Vector3(48, 4, -296), Vector3(48, 3, -335), Vector3(46, 2.4, -366), Vector3(40, 2.4, -366), Vector3(29, 2.4, -366), Vector3(25, 1.9, -364)],
	"shell_rear": [Vector3(25, 1.9, -364), Vector3(25, 2.4, -377), Vector3(25, 2.4, -386), Vector3(46, 3, -388), Vector3(48, 3, -335), Vector3(48, 4, -296), Vector3(39, 4, -268), Vector3(28, 3, -269), Vector3(28, 2, -275)]
}

static func id_at(position: Vector3) -> String:
	for id: String in BIOMES:
		var bounds: Dictionary = BIOMES[id]
		if position.x >= bounds.min.x and position.x <= bounds.max.x and position.z >= bounds.min.y and position.z <= bounds.max.y:
			return id
	return "outside"

static func name_at(position: Vector3) -> String:
	var id := id_at(position)
	return "外縁の流れ" if id == "outside" else String(BIOMES[id].name)

static func boundary_current(position: Vector3) -> Vector3:
	var x := maxf(0.0, MAP_MIN.x + 12.0 - position.x) - maxf(0.0, position.x - MAP_MAX.x + 12.0)
	var z := maxf(0.0, MAP_MIN.y + 14.0 - position.z) - maxf(0.0, position.z - MAP_MAX.y + 18.0)
	return Vector3(x, 0, z) * 0.55

static func cross_current(position: Vector3) -> Vector3:
	var local := (position - CROSS_CURRENT_CENTER).abs() / CROSS_CURRENT_HALF
	var edge := maxf(local.x, maxf(local.y, local.z))
	return Vector3.RIGHT * 1.35 * (1.0 - smoothstep(0.6, 1.0, edge))

static func current_at(position: Vector3) -> Vector3:
	var boundary := boundary_current(position)
	return boundary if boundary.length_squared() > 0.001 else cross_current(position)

static func is_near_boundary(position: Vector3) -> bool:
	return boundary_current(position).length_squared() > 0.12

static func is_valid_buoy(position: Vector3) -> bool:
	return position.is_finite() and position.x >= MAP_MIN.x and position.x <= MAP_MAX.x and position.z >= MAP_MIN.y and position.z <= MAP_MAX.y and position.y >= BUOY_MIN_Y and position.y <= BUOY_MAX_Y

static func point(id: String, world: Node3D) -> Vector3:
	if ABSOLUTE_POINTS.has(id):
		return ABSOLUTE_POINTS[id]
	var offset: Vector3 = POINTS.get(id, Vector3.ZERO)
	return Vector3(offset.x, world.floor_height(offset.x, offset.z) + offset.y, offset.z)

static func route(id: String, world: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if id == "relay_rift":
		for offset in RIFT_ACCESS:
			result.append(Vector3(offset.x,world.floor_height(offset.x,offset.z)+offset.y,offset.z))
		result.append(ABSOLUTE_POINTS.rift_shelf)
		return result
	if RIFT_ROUTES.has(id):
		result.assign(RIFT_ROUTES[id])
		return result
	var offsets: Array = ROUTES.get(id, [])
	for index in offsets.size():
		var offset: Vector3 = offsets[index]
		if index > 0:
			var previous: Vector3 = offsets[index - 1]
			var steps := ceili(Vector2(offset.x - previous.x, offset.z - previous.z).length() / 5.0)
			for step in range(1, steps):
				var between := previous.lerp(offset, float(step) / steps)
				result.append(Vector3(between.x, world.floor_height(between.x, between.z) + between.y, between.z))
		result.append(Vector3(offset.x, world.floor_height(offset.x, offset.z) + offset.y, offset.z))
	return result
