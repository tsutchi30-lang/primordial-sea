extends Node

var loops: Dictionary = {}
var effects: Dictionary = {}
var footfall_player: AudioStreamPlayer3D

func _exit_tree() -> void:
	stop_all()

func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()

func _ready() -> void:
	for bus in ["BGM", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for name in ["pod_hum", "water", "warning", "pulse", "pickup", "success", "membrane", "hogara", "ui"]:
		var path: String = "res://assets/audio/" + name + ".wav"
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.bus = "BGM" if name in ["pod_hum", "water"] else ("UI" if name == "ui" else "SFX")
		if name in ["ui", "success"]:
			player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		if name in ["pod_hum", "water"]:
			if player.stream is AudioStreamWAV:
				player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				player.stream.loop_end = int(player.stream.get_length() * player.stream.mix_rate)
			loops[name] = player
		else:
			effects[name] = player
	footfall_player = AudioStreamPlayer3D.new()
	footfall_player.stream = load("res://assets/audio/footfall.wav")
	footfall_player.bus = "SFX"
	footfall_player.unit_size = 4.0
	footfall_player.max_distance = 24.0
	footfall_player.volume_db = -7.0
	add_child(footfall_player)

func play_footfall(at: Vector3, strength: float) -> void:
	# A single muted contact pulse per planted step; never a continuous smoke/rumble.
	footfall_player.global_position = at
	footfall_player.pitch_scale = lerpf(0.9, 1.02, clampf(strength, 0.0, 1.0))
	footfall_player.play()

func ambience(in_pod: bool, playing: bool) -> void:
	for name in loops:
		var wanted: bool = playing and ((name == "pod_hum") == in_pod)
		if wanted and not loops[name].playing:
			loops[name].play()
		elif not wanted:
			loops[name].stop()

func play_effect(name: String) -> void:
	if effects.has(name):
		effects[name].play()

func apply_settings(settings: Dictionary) -> void:
	for pair in [["Master", "master"], ["BGM", "bgm"], ["SFX", "sfx"], ["UI", "ui"]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, settings[pair[1]])))
		AudioServer.set_bus_mute(index, settings[pair[1]] <= 0)
