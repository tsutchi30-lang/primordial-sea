extends Node
## Presentation alone runs while simulation is paused. Achievement is already
## durable before start; presentation time is deliberately never saved.
const DURATION := 28.0
var game
var elapsed := 0.0
var running := false
var suspended := false
var layer: CanvasLayer
var wash: ColorRect
var caption: Label
var skip: Button
var camera: Camera3D
var saved_light := 1.0
var saved_color := Color.WHITE
var saved_emission := 0.7
var snapshot_taken := false

func setup(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	wash = ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(wash)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.offset_left = -510
	caption.offset_right = 510
	caption.offset_top = -205
	caption.offset_bottom = -96
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	caption.add_theme_font_size_override("font_size",26)
	caption.add_theme_constant_override("outline_size",7)
	caption.add_theme_color_override("font_outline_color",Color("153343"))
	layer.add_child(caption)
	skip = Button.new()
	skip.text = "帰還成功へ進む（Esc）"
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip.offset_left = -175
	skip.offset_right = 175
	skip.offset_top = -76
	skip.offset_bottom = -30
	skip.add_theme_font_override("font",load("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	skip.pressed.connect(finish)
	layer.add_child(skip)
	layer.hide()

func start() -> void:
	if running: return
	elapsed = 0
	running = true
	suspended = false
	saved_light = game.world._pod_light.light_energy
	saved_color = game.world._pod_light.light_color
	saved_emission = game.world._stability_material.emission_energy_multiplier
	snapshot_taken = true
	game.hud.hide_panel()
	game.sound.stop_all()
	game.sound.play_effect("success")
	camera = Camera3D.new()
	camera.position = Vector3(0,1.65,0.8)
	camera.fov = 68
	add_child(camera)
	camera.make_current()
	camera.look_at(Vector3(0,1.65,-3.7))
	layer.show()
	skip.grab_focus()
	_update_visual()

func _process(delta: float) -> void:
	if not running or suspended: return
	elapsed = minf(DURATION,elapsed+delta)
	_update_visual()
	if elapsed >= DURATION: finish()

func _update_visual() -> void:
	var rise := smoothstep(5,17,elapsed)
	var settle := smoothstep(18,27,elapsed)
	wash.color = Color(0.65,0.9,0.92,rise*0.48*(1.0-settle))
	game.world._pod_light.light_energy = lerpf(saved_light,2.0,rise)
	game.world._pod_light.light_color = saved_color.lerp(Color("f4e9d0"),settle)
	game.world._stability_material.emission_energy_multiplier = 0.7 + rise*1.1
	camera.position = Vector3(0,lerpf(1.65,2.25,rise),lerpf(0.8,-0.55,rise))
	game.world._water_material.set_shader_parameter("sea_time",game.world.visual_time+elapsed)
	if elapsed < 7:
		caption.text = "帰還コア接続\n航法座標と安定化装置を同期しています"
	elif elapsed < 17:
		caption.text = "時間航路を開いています\n調査記録を転送中"
	elif elapsed < 24:
		caption.text = "出発時の時間座標に到達\n救難信号の応答を受信"
	else:
		caption.text = "帰還成功\n調査記録を携えて、元の時代へ戻りました"

func set_suspended(value: bool) -> void:
	if not running: return
	suspended = value
	game.player.clear_input()
	skip.text = "演出を再開（E） / Esc でスキップ" if value else "帰還成功へ進む（Esc）"

func finish() -> void:
	if not running: return
	restore_scene()
	game.mode = "complete"
	var count := 0
	for records in game.observations.values():
		if "identified" in records: count += 1
	game.hud.show_panel("returned","帰還成功","調査記録を携えて、元の時代へ帰還しました。\n識別した生物：%d / %d 種\n\n帰還の記録は保存済みです。帰還直前の海へ戻り、\n同じ装備と記録で調査を続けられます。" % [count,game.ecology.get_species_data().size()],[["帰還直前の海を調査する","research"],["タイトルへ","title"]])

func restore_scene() -> void:
	running = false
	suspended = false
	layer.hide()
	if is_instance_valid(camera):
		camera.queue_free()
		camera = null
	game.player.camera.make_current()
	if snapshot_taken:
		game.world._pod_light.light_energy = saved_light
		game.world._pod_light.light_color = saved_color
		game.world._stability_material.emission_energy_multiplier = saved_emission
		game.world._water_material.set_shader_parameter("sea_time",game.world.visual_time)
		snapshot_taken = false
	game.player.clear_input()
	game.sound.stop_all()
