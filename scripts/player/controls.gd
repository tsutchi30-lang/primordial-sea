extends RefCounted

const KEYS = {
	"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
	"ascend": KEY_SPACE, "descend": KEY_C, "sprint": KEY_SHIFT,
	"interact": KEY_E, "pulse": KEY_Q, "light": KEY_F,
	"journal": KEY_TAB, "pause": KEY_ESCAPE,
	"tool_1": KEY_1, "tool_2": KEY_2, "tool_3": KEY_3,
	"tool_4": KEY_4, "tool_5": KEY_5, "fullscreen": KEY_F11,
}

static func install() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = KEYS[action]
			InputMap.action_add_event(action, event)
	for pair in [["use_tool", MOUSE_BUTTON_LEFT], ["tool_next", MOUSE_BUTTON_WHEEL_DOWN], ["tool_previous", MOUSE_BUTTON_WHEEL_UP]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var event := InputEventMouseButton.new()
			event.button_index = pair[1]
			InputMap.action_add_event(pair[0], event)

static func label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return action
	if events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].physical_keycode)
	return "左クリック" if action == "use_tool" else "ホイール"

static func release_all() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
	Input.flush_buffered_events()

static func help_text() -> String:
	return "%s/%s/%s/%s 泳ぐ　%s 上昇　%s 下降　%s 加速\nマウス 視点　%s 調べる　%s ライト　%s 緊急パルス\n%s 道具を使う　1〜5 / ホイール 道具　%s 図鑑　%s ポーズ" % [label("forward"), label("left"), label("back"), label("right"), label("ascend"), label("descend"), label("sprint"), label("interact"), label("light"), label("pulse"), label("use_tool"), label("journal"), label("pause")]
