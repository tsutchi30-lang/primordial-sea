extends Node3D
const School = preload("res://scripts/creatures/glow_school.gd")
const Kangaku = preload("res://scripts/creatures/kangaku.gd")
var host: Node3D
var kangaku: CharacterBody3D
var schools: Array[Node3D] = []
var stimuli: Array[Dictionary] = []

func setup(ecosystem: Node3D) -> void:
	host = ecosystem
	for at in [Vector3(-6,-249,-473),Vector3(53,-253,-527)]:
		var school := School.new()
		add_child(school)
		school.setup(at)
		schools.append(school)
		host.creatures.append(school)
	kangaku = Kangaku.new()
	add_child(kangaku)
	kangaku.setup(self)
	kangaku.hit_player.connect(host._on_player_hit)
	kangaku.event_started.connect(func(event: String):
		host.behavior_observed.emit(kangaku,event)
		if event in ["windup","locked"] and host.player.global_position.distance_to(kangaku.mouth_position()) < 20:
			host.resonance.emit(kangaku.mouth_position(),0.5 if event == "windup" else 0.75))
	host.creatures.append(kangaku)

func tick(delta: float) -> void:
	for i in range(stimuli.size()-1,-1,-1):
		stimuli[i].remaining -= delta
		if stimuli[i].remaining <= 0: stimuli.remove_at(i)
	for school in schools:
		var threats: Array[Vector3] = [kangaku.mouth_position()]
		school.tick(delta,null,threats,host.hogara,false,host.player.global_position)
	kangaku.tick(delta)

func food_for(at: Vector3) -> Node3D:
	var best: Node3D = null
	var distance := 16.0
	for school in schools:
		var d := at.distance_to(school.global_position)
		if school.density >= 0.65 and d < distance and host.has_clear_path(at,school.global_position):
			distance = d
			best = school
	return best

func stimulate(at: Vector3, radius: float, lifetime: float) -> void:
	if stimuli.size() >= 4: return
	stimuli.append({"position":at,"radius":radius,"remaining":lifetime})
	kangaku.stimulate(at,radius)

func set_low_particles(low: bool) -> void:
	for school in schools:
		for i in school.grains.size(): school.grains[i].visible = not low or i%2 == 0
