extends Node3D
## Bounded local reactions. This manager never advances a wall-clock timer.
const Urn = preload("res://scripts/creatures/resonance_urn.gd")
const Crawler = preload("res://scripts/creatures/hexacrawler.gd")
const Map = preload("res://data/biomes/world_map.gd")
const Controls = preload("res://scripts/player/controls.gd")
signal resonance(at: Vector3, strength: float)
signal behavior_observed(creature: Node3D, event_id: String)
signal defense_rattle(at: Vector3)
const STIMULUS_TTL := 6.0
var host: Node3D
var urns: Array[Node3D] = []
var crawlers: Array[CharacterBody3D] = []
var age := 0.0
var stimulus_serial := 0
var propagated_count := 0
var hint_given := false
var mineral_reserved := false
var _distant_accumulators: Dictionary = {}

func setup(ecosystem: Node3D) -> void:
	host = ecosystem
	# One isolated, safe example before the three-colony chain beside the door.
	for id in ["urn_tutorial", "urn_lure", "urn_chain_1", "urn_chain_2"]:
		var definition: Vector3 = Map.POINTS[id]
		var point := Vector2(definition.x, definition.z)
		var urn := Urn.new()
		add_child(urn)
		urn.setup(_floor(point, 0.015), float(urns.size()) * 1.7)
		urn.resonated.connect(_on_resonated)
		urns.append(urn)
		host.creatures.append(urn)
	var entrance: Vector3 = Map.POINTS.crawler_home
	_spawn_crawler(Vector2(entrance.x, entrance.z), false)
	var cache: Vector3 = Map.POINTS.mineral_cache
	var carrier := _spawn_crawler(Vector2(cache.x, cache.z), false)
	carrier.position.y += 0.15
	carrier.home = Map.point("crawler_mineral_home", host.world)
	carrier.mineral_waiting = true
	carrier.mineral_source = carrier.position
	var resting_site: Vector3 = Map.POINTS.crawler_cleaner
	var cleaner := _spawn_crawler(Vector2(resting_site.x, resting_site.z), true)
	if is_instance_valid(host.hogara):
		cleaner.bind_cleaning(host.hogara)

func _spawn_crawler(point: Vector2, is_cleaner: bool) -> CharacterBody3D:
	var crawler := Crawler.new()
	add_child(crawler)
	crawler.setup(host, host.player, _floor(point, Crawler.BODY_CLEARANCE), is_cleaner)
	crawler.hit_player.connect(host._on_player_hit)
	crawler.event_started.connect(func(event_id: String):
		behavior_observed.emit(crawler, event_id)
		if event_id == "defense":
			defense_rattle.emit(crawler.global_position))
	crawlers.append(crawler)
	host.creatures.append(crawler)
	return crawler

func _floor(point: Vector2, offset: float) -> Vector3:
	return Vector3(point.x, float(host.world.floor_height(point.x, point.y)) + offset, point.y)

func tick(delta: float) -> void:
	if delta <= 0.0 or get_tree().paused:
		return
	age += delta
	var observer: CharacterBody3D = host.player
	for urn in urns:
		var distance: float = observer.global_position.distance_to(urn.observation_position())
		if urn.state == "idle" and bool(observer.get("sprinting")) and distance <= Urn.STIMULUS_RADIUS:
			# Solid rock blocks the diver's local water displacement as well.
			if host.has_clear_path(observer.global_position, urn.observation_position()):
				stimulus_serial += 1
				urn.receive_stimulus(stimulus_serial, 0, age + STIMULUS_TTL, age)
		if not hint_given and distance < 5.0 and host.has_clear_path(observer.global_position, urn.observation_position()):
			hint_given = true
			host.hint.emit("薄い膜が水を吸い込んでいる。3m以内で%s加速すると膨らみ、近くの壺へ音が伝わる。" % Controls.label("sprint"))
		var step := _step_for(urn, delta, distance > 40.0 and urn.state == "idle")
		if step > 0.0:
			urn.tick(step, age)
	_try_mineral()
	for crawler in crawlers:
		var distant: bool = observer.global_position.distance_squared_to(crawler.global_position) > 1600.0
		var step := _step_for(crawler, delta, distant and crawler.state == "forage" and not crawler.cleaner)
		if step > 0.0:
			crawler.tick(step)

func _step_for(creature: Node3D, delta: float, reduced: bool) -> float:
	var id := creature.get_instance_id()
	var accumulated: float = float(_distant_accumulators.get(id, 0.0)) + delta
	if reduced and accumulated < 0.1:
		_distant_accumulators[id] = accumulated
		return 0.0
	_distant_accumulators[id] = 0.0
	return accumulated

func _on_resonated(source: Node3D, stimulus_id: int, hop: int, expires_at: float) -> void:
	resonance.emit(source.observation_position(), 1.0 - hop * 0.18)
	behavior_observed.emit(source, "urn_resonated")
	for crawler in crawlers:
		crawler.hear_sound(source.global_position)
	if hop >= Urn.MAX_HOPS or age >= expires_at:
		return
	for neighbor in urns:
		if neighbor == source or neighbor.global_position.distance_to(source.global_position) > Urn.PROPAGATION_RADIUS:
			continue
		if neighbor.receive_stimulus(stimulus_id, hop + 1, expires_at, age):
			propagated_count += 1

func _try_mineral() -> void:
	if mineral_reserved or crawlers.size() < 2:
		return
	# At this feeding patch the approaching swimmer makes the crawler retreat
	# with its real fragment. The transport can therefore be witnessed on arrival;
	# once started it continues off-screen without resets or new resources.
	if host.player.global_position.distance_to(crawlers[1].global_position) > 12.0:
		return
	var excluded: Array[RID] = [crawlers[1].get_rid()]
	if not host.has_clear_path(host.player.global_position, crawlers[1].observation_position(), excluded):
		return
	var game := host.get_parent()
	if game == null or game.get("pickups") == null:
		return
	# Move a single actual, collectable resource. No event manufactures stock.
	for pickup in game.pickups:
		if pickup.kind == "metal" and pickup.global_position.distance_to(Map.point("mineral_cache", host.world)) < 1.0:
			if crawlers[1].take_mineral(pickup):
				mineral_reserved = true
			return
