extends RefCounted
const Map = preload("res://data/biomes/world_map.gd")
const Query = preload("res://scripts/interaction/interaction_query.gd")
const Mount = preload("res://scripts/interaction/core_mount.gd")
const Ending = preload("res://scripts/progression/return_sequence.gd")
var game
var core: Node3D
var mount: Node3D
var sequence: Node

func setup(owner_game) -> void:
	game = owner_game
	core = game.m2.add_pickup("return_core",Map.point("return_core",game.world),"return_core")
	mount = Mount.new()
	mount.position = core.position
	game.add_child(mount)
	sequence = Ending.new()
	game.add_child(sequence)
	sequence.setup(game)

func sync_core(reset := false) -> void:
	core.set_available(game.state.return_core == "world")
	if reset: mount.reset_mount(game.state.return_core == "world")
	else: mount.visible = game.state.return_core == "world"

func cut_available() -> bool:
	return game.state.return_core == "world" and not mount.unlocked and Query.score(game.player.camera, core.global_position, 3.0, 0.97) >= 0.0

func cancel_cut() -> void:
	if is_instance_valid(mount): mount.cancel_cut()

func cut(delta: float) -> void:
	if mount.cut(delta,game.state.cutter_seconds()):
		game.sound.play_effect("pickup")
		game.notify("固定具を切断。E で帰還コアを回収できます。",6,2)
		game.ecology.rift.stimulate(core.global_position,14.0,1.4)
	game.cut_progress = mount.progress
	game.cut_label = "固定具"

func return_status() -> Dictionary:
	var info: Dictionary = game.state.return_status()
	if game.mode != "play" or not game.player.in_pod:
		return {"allowed": false, "reason": "救命ポッド内で作動させてください。"}
	if not game.pending_checkpoint_action.is_empty() and game.pending_checkpoint_action != "final_return":
		return {"allowed": false, "reason": "保留中の保存を先に再試行してください。"}
	return info

func activate_return() -> bool:
	var info := return_status()
	if not info.allowed:
		return false
	var candidate = game.state.clone_runtime()
	if not candidate.complete_return(): return false
	if not game._save_checkpoint(candidate.checkpoint()):
		game._show_save_failure("final_return",game.saves.last_error)
		return false
	game.state = candidate
	game.pending_checkpoint_action = ""
	game.checkpoint_error = ""
	sync_core()
	game._stop_play()
	game.mode = "return"
	sequence.start()
	return true

func continue_research() -> void:
	if not game.state.game_completed or game.mode != "complete": return
	sequence.restore_scene()
	game.mode = "play"
	game.player.relocate(game.POD,true)
	game.resume_game()
	game.sound.ambience(true,true)
	game.notify("帰還達成済み。帰還直前の海で調査を続けます。",10,2)
