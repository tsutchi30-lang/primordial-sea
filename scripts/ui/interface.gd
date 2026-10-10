extends CanvasLayer

signal action_requested(action: String)
signal setting_changed(key: String, value: Variant)
const Controls = preload("res://scripts/player/controls.gd")
const Map = preload("res://data/biomes/world_map.gd")
const Items = preload("res://data/items/item_catalog.gd")
const INK := Color("071d25")
const PAPER := Color("deece8")
const AQUA := Color("8ce0d2")
const GOLD := Color("e7bb83")
var root: Control
var hud: Control
var overlay: ColorRect
var panel: PanelContainer
var menu_box: VBoxContainer
var objective: Label
var status: Label
var oxygen_bar: ProgressBar
var suit_bar: ProgressBar
var tool_label: Label
var hint_label: Label
var toast_label: Label
var direction_label: Label
var observation_label: Label
var marker_labels: Array[Label] = []
var page := "title"
var scroll: ScrollContainer

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_stylebox("normal", "Button", style(Color("163b43"), 8, Color("386167")))
	theme.set_stylebox("hover", "Button", style(Color("24545b"), 8, AQUA))
	theme.set_stylebox("pressed", "Button", style(Color("1e5d60"), 8, GOLD))
	theme.set_stylebox("focus", "Button", style(Color(0,0,0,0), 8, GOLD))
	theme.set_constant("outline_size", "Label", 3)
	theme.set_color("font_outline_color", "Label", Color(0.01,0.05,0.06,0.8))
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var brand := label("原初の海  /  時間調査艇 ORIGIN", 16, GOLD)
	place(brand, Vector2(28, 20), Vector2(580, 24))
	hud.add_child(brand)
	objective = label("", 22, PAPER)
	place(objective, Vector2(28, 56), Vector2(840, 42))
	hud.add_child(objective)
	direction_label = label("", 17, AQUA)
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	direction_label.anchor_left = 1
	direction_label.anchor_right = 1
	direction_label.offset_left = -360
	direction_label.offset_right = -28
	direction_label.offset_top = 20
	direction_label.offset_bottom = 70
	hud.add_child(direction_label)
	status = label("", 20, PAPER)
	status.anchor_top = 1
	status.anchor_bottom = 1
	status.offset_left = 28
	status.offset_right = 365
	status.offset_top = -138
	status.offset_bottom = -74
	hud.add_child(status)
	oxygen_bar = make_bar(AQUA, -67)
	suit_bar = make_bar(GOLD, -46)
	tool_label = label("", 18, PAPER)
	tool_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tool_label.offset_left = -630
	tool_label.offset_right = -28
	tool_label.offset_top = -88
	tool_label.offset_bottom = -26
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(tool_label)
	hint_label = label("", 21, GOLD)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -520
	hint_label.offset_right = 520
	hint_label.offset_top = -182
	hint_label.offset_bottom = -128
	hud.add_child(hint_label)
	toast_label = label("", 18, PAPER)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -410
	toast_label.offset_right = 410
	toast_label.offset_top = 122
	toast_label.offset_bottom = 188
	hud.add_child(toast_label)
	var crosshair := label("·", 34, AQUA)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -9
	crosshair.offset_top = -25
	crosshair.offset_right = 9
	crosshair.offset_bottom = 25
	hud.add_child(crosshair)
	observation_label = label("", 18, AQUA)
	observation_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	observation_label.offset_left = -280
	observation_label.offset_right = 280
	observation_label.offset_top = 36
	observation_label.offset_bottom = 80
	observation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(observation_label)
	for i in 9:
		var marker := label("", 16, AQUA if i == 0 else GOLD)
		marker.size = Vector2(230, 26)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hud.add_child(marker)
		marker_labels.append(marker)
	overlay = ColorRect.new()
	overlay.color = Color(0.01, 0.05, 0.065, 0.70)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(Color(0.025,0.11,0.14,0.97), 14, Color("3a6064")))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -315
	panel.offset_bottom = 315
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_theme_constant_override("separation", 13)
	scroll.add_child(menu_box)

func style(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_border_width_all(1)
	result.border_color = border
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 9
	result.content_margin_bottom = 9
	return result

func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func place(node: Control, pos: Vector2, dimensions: Vector2) -> void:
	node.position = pos
	node.size = dimensions

func make_bar(color: Color, y: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 28
	bar.offset_right = 310
	bar.offset_top = y
	bar.offset_bottom = y + 9
	bar.add_theme_stylebox_override("background", style(Color("173d42"), 3, Color("31565b")))
	bar.add_theme_stylebox_override("fill", style(color, 3, color))
	hud.add_child(bar)
	return bar

func show_panel(new_page: String, title: String, body: String, buttons: Array) -> void:
	scroll.scroll_vertical = 0
	page = new_page
	menu_box.add_theme_constant_override("separation", 13)
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	overlay.show()
	panel.show()
	var eyebrow := label("P R I M O R D I A L   S E A   /   装置安定化編", 14, GOLD)
	menu_box.add_child(eyebrow)
	menu_box.add_child(label(title, 38 if new_page == "title" else 28, PAPER))
	var body_label := label(body, 18, PAPER)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_box.add_child(body_label)
	for option in buttons:
		add_button(option[0], option[1], option[2] if option.size() > 2 else false)

func add_button(text: String, action: String, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	button.disabled = disabled
	button.pressed.connect(func(): action_requested.emit(action))
	menu_box.add_child(button)
	return button

func hide_panel() -> void:
	page = ""
	panel.hide()
	overlay.hide()

func show_settings(settings: Dictionary) -> void:
	show_panel("settings", "潜水設定", "設定は進行と別に保存されます。F11でも画面表示を切り替えられます。", [])
	menu_box.add_theme_constant_override("separation", 6)
	for row in [["マウス感度", "sensitivity", 0.0005, 0.008, 0.0001], ["視野角", "fov", 60.0, 105.0, 1.0], ["被弾時のカメラ揺れ", "shake", 0.0, 1.0, 0.05], ["全体音量", "master", 0.0, 1.0, 0.05], ["環境音・BGM", "bgm", 0.0, 1.0, 0.05], ["効果音", "sfx", 0.0, 1.0, 0.05], ["UI音", "ui", 0.0, 1.0, 0.05]]:
		var box := HBoxContainer.new()
		var caption := label(row[0], 17, PAPER)
		caption.custom_minimum_size.x = 245
		box.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = settings[row[1]]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value): setting_changed.emit(row[1], value))
		box.add_child(slider)
		menu_box.add_child(box)
	for row in [["上下視点を反転", "invert_y"], ["粒子を減らす", "low_particles"], ["フルスクリーン", "fullscreen"]]:
		var checkbox := CheckButton.new()
		checkbox.text = row[0]
		checkbox.button_pressed = settings[row[1]]
		checkbox.toggled.connect(func(value): setting_changed.emit(row[1], value))
		menu_box.add_child(checkbox)
	add_button("設定を保存して戻る", "settings_back")

func update_game(game) -> void:
	hud.visible = game.mode != "title"
	objective.text = game.state.objective()
	var oxygen: float = game.state.oxygen
	status.text = "酸素  %03d 秒　%s\nスーツ  %d %%" % [ceili(oxygen), "補給中" if game.player.in_pod else ("外気呼吸" if game.player.breathing_air else "タンク呼吸"), game.state.suit]
	oxygen_bar.value = oxygen / game.state.capacity() * 100
	suit_bar.value = game.state.suit
	tool_label.text = "%s　%s\n%s ライト %s　%s 緊急パルス %d　%s 図鑑" % [str(game.selected_tool + 1), game.tool_names[game.selected_tool], Controls.label("light"), "ON" if game.player.light_on else "OFF", Controls.label("pulse"), game.state.pulse, Controls.label("journal")]
	if game.selected_tool == 2:
		tool_label.text = "誘餌ポッド  残り %d　/　持続 45 秒\n" % game.state.bait + tool_label.text.get_slice("\n", 1)
	if game.selected_tool == 4:
		tool_label.text = "目印ブイ  %d / 6 設置済み\n" % game.state.buoys.size() + tool_label.text.get_slice("\n", 1)
	var pod_distance: float = game.player.global_position.distance_to(Vector3(0, -2, -5))
	direction_label.text = Map.name_at(game.player.position)
	if not game.player.in_pod:
		direction_label.text += "\n深度 %d m　ポッド直線 %d m" % [maxi(0, -int(game.player.position.y)), pod_distance]
	hint_label.text = game.interaction_hint()
	toast_label.text = game.toast_text if game.toast_remaining > 0 else ""
	# This is the sole writer of the shared status label. Physics updates supply
	# state; the HUD gives urgent hypoxia priority on every rendered frame.
	if game.mode != "play" or game.state.dead:
		observation_label.text = ""
	elif oxygen <= 0 and not game.player.in_pod and not game.player.breathing_air:
		observation_label.text = "酸素切れ — 浮上してください！ 残り %.1f 秒" % game.state.anoxia_remaining()
	elif game.cut_progress > 0:
		observation_label.text = "粘糸を切断中  %d %%" % mini(100, int(game.cut_progress * 100))
	else:
		observation_label.text = "観察中  %d %%" % mini(100, int(game.observe_time / 2.3 * 100)) if game.observe_time > 0 else ""
	update_markers(game)

func update_markers(game) -> void:
	var points: Array = [[Vector3(0, 0, -4), "ポッド"]]
	if game.state.nav == "wreck":
		points.append([Vector3(0, -36, -130), "艇の信号"])
	if game.state.nav == "repaired":
		points.append([game.m2.relay_position(), "中継補給点"])
		var part: String = game.m2.target_part()
		if not part.is_empty():
			points.append([Map.point(part, game.world), Items.item_name(part)])
	for i in game.state.buoys.size():
		var xyz: Array = game.state.buoys[i]
		points.append([Vector3(xyz[0], xyz[1], xyz[2]), "目印 %d" % (i + 1)])
	var view: Vector2 = root.size
	var occupied: Array[Rect2] = []
	for i in marker_labels.size():
		var marker := marker_labels[i]
		marker.visible = not game.player.in_pod and i < points.size()
		if not marker.visible:
			continue
		var point: Vector3 = points[i][0]
		var local: Vector3 = game.player.camera.to_local(point)
		var behind: bool = local.z >= -game.player.camera.near
		# A newly placed buoy may be exactly on the camera plane. Projection at
		# z=0 divides by zero, so route near/behind signals to the edge first.
		var screen := Vector2(view.x - 127 if local.x > 0 else 129, view.y * 0.45)
		if not behind:
			screen = game.player.camera.unproject_position(point)
		var position := Vector2(clampf(screen.x - 115, 12, view.x - 242), clampf(screen.y, 210, view.y - 215))
		# Keep the centre free for creature observation and separate nearby labels.
		var aim := Rect2(view * 0.5 - Vector2(160, 90), Vector2(320, 180))
		if aim.intersects(Rect2(position, marker.size)):
			position.x = 14 if screen.x < view.x * 0.5 else view.x - 244
		for attempt in 10:
			var overlaps := false
			for rect in occupied:
				if rect.intersects(Rect2(position, marker.size)):
					overlaps = true
					break
			if not overlaps:
				break
			position.y += 29
			if position.y > view.y - 215:
				position.y = 210
				position.x = 14 if position.x > view.x * 0.5 else view.x - 244
		marker.position = position
		occupied.append(Rect2(position, marker.size))
		marker.text = ("◀ " if behind else "◇ ") + points[i][1] + "  %d m" % game.player.global_position.distance_to(point)
