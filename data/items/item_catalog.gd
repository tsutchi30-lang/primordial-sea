extends RefCounted
## Stable IDs shared by collection, inventory, recipes and checkpoint validation.
const MAX_STORED := 1000000
const MAX_BUOYS := 6
const RESOURCE_IDS := ["metal", "repair_fiber", "shell_plate"]
const PART_IDS := ["damping_frame", "phase_regulator"]
const RESOURCES := {
	"metal": {"name": "金属片", "carried_limit": 12, "carried_field": "carried_metal", "stored_field": "stored_metal"},
	"repair_fiber": {"name": "補修繊維", "carried_limit": 8, "carried_field": "carried_fiber", "stored_field": "stored_fiber"},
	"shell_plate": {"name": "殻片", "carried_limit": 8, "carried_field": "carried_shell", "stored_field": "stored_shell"}
}
const PARTS := {
	"damping_frame": {"name": "制振フレーム", "biome": "白濁の平原"},
	"phase_regulator": {"name": "位相調整器", "biome": "殻の墓場"}
}

static func item_name(id: String) -> String:
	if RESOURCES.has(id):
		return RESOURCES[id].name
	if PARTS.has(id):
		return PARTS[id].name
	return "不明な回収物"

static func valid_amount(value: Variant, maximum: int = MAX_STORED) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and floor(value) == value
