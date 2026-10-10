extends RefCounted
## UI and progression consume these same costs and effects.
const TANK_CAPACITIES := [480.0, 600.0, 780.0]
const CUTTER_SECONDS := [1.2, 0.6]
const RECIPES := {
	"tank_i": {"name": "タンクI", "costs": {"metal": 2}, "nav_required": false, "tank_required": 0, "tank_result": 1, "effect": "酸素容量 480 → 600 秒"},
	"tank_ii": {"name": "タンクII", "costs": {"metal": 3, "repair_fiber": 2}, "nav_required": true, "tank_required": 1, "tank_result": 2, "effect": "酸素容量 600 → 780 秒"},
	"cutter": {"name": "カッター改良", "costs": {"metal": 2, "shell_plate": 2}, "nav_required": true, "tank_required": 0, "tank_result": -1, "effect": "粘糸の切断 1.2 → 0.6 秒"}
}
