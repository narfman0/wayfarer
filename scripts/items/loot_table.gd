## Static loot table library + weighted roll logic.
##
## Each table entry: {name, weight, type, min_qty, max_qty, heal, roll_heal,
##                    color, description, buy_price, sell_price}
## name="" = empty slot (no item for that roll).
##
## Usage:
##   var rng := RandomNumberGenerator.new()
##   rng.seed = some_seed
##   var result := LootTable.roll(rng, "dungeon_basic")
##   # result = {gold: int, items: Array[Dictionary]}
class_name LootTable
extends RefCounted

# ── Item blueprints (re-used across multiple tables) ─────────────────────────

const _HEALING_POTION := {
	name="Healing Potion", type="consumable", heal=10, roll_heal=true,
	color=[0.45, 1.0, 0.55], description="Restores 2d4+2 HP",
	buy_price=50, sell_price=25
}
const _GREATER_HEALING := {
	name="Greater Healing Potion", type="consumable", heal=28, roll_heal=false,
	color=[0.3, 0.9, 0.4], description="Restores 4d4+4 HP",
	buy_price=150, sell_price=75
}
const _ANTITOXIN := {
	name="Antitoxin", type="consumable", heal=0, roll_heal=false,
	color=[0.7, 1.0, 0.7], description="Neutralises one poison dose",
	buy_price=50, sell_price=20
}
const _TORCH := {
	name="Torch", type="consumable", heal=0, roll_heal=false,
	color=[1.0, 0.7, 0.3], description="Burns for 1 hour",
	buy_price=5, sell_price=2
}
const _RATIONS := {
	name="Rations", type="consumable", heal=0, roll_heal=false,
	color=[0.8, 0.7, 0.5], description="One day of food",
	buy_price=5, sell_price=2
}
const _ROPE := {
	name="Rope (50ft)", type="misc", heal=0, roll_heal=false,
	color=[0.75, 0.65, 0.45], description="Hempen rope",
	buy_price=10, sell_price=4
}
const _THIEVES_TOOLS := {
	name="Thieves' Tools", type="misc", heal=0, roll_heal=false,
	color=[0.65, 0.75, 0.85], description="+2 to lockpicking & traps",
	buy_price=25, sell_price=12
}

# ── Table definitions ─────────────────────────────────────────────────────────
# rolls:      [min_rolls, max_rolls]
# gold_range: [min_gold, max_gold]
# entries:    Array of {base_item, weight, min_qty, max_qty}
#             base_item may be a const dict or an inline dict

const TABLES: Dictionary = {

	"bandit": {
		rolls=[1, 2], gold_range=[3, 14],
		entries=[
			{base={}, weight=28},   # empty
			{base=_HEALING_POTION,  weight=22, min_qty=1, max_qty=1},
			{base=_TORCH,           weight=20, min_qty=1, max_qty=2},
			{base=_RATIONS,         weight=18, min_qty=1, max_qty=2},
			{base=_ANTITOXIN,       weight=8,  min_qty=1, max_qty=1},
			{base=_THIEVES_TOOLS,   weight=4,  min_qty=1, max_qty=1},
		]
	},

	"brute": {
		rolls=[1, 2], gold_range=[8, 20],
		entries=[
			{base={}, weight=20},
			{base=_HEALING_POTION,  weight=30, min_qty=1, max_qty=1},
			{base=_ANTITOXIN,       weight=15, min_qty=1, max_qty=1},
			{base=_RATIONS,         weight=20, min_qty=1, max_qty=3},
			{base=_ROPE,            weight=15, min_qty=1, max_qty=1},
		]
	},

	"dungeon_basic": {
		rolls=[2, 3], gold_range=[8, 28],
		entries=[
			{base={}, weight=14},
			{base=_HEALING_POTION,  weight=28, min_qty=1, max_qty=1},
			{base=_TORCH,           weight=18, min_qty=1, max_qty=3},
			{base=_ANTITOXIN,       weight=14, min_qty=1, max_qty=1},
			{base=_RATIONS,         weight=14, min_qty=1, max_qty=2},
			{base=_GREATER_HEALING, weight=8,  min_qty=1, max_qty=1},
			{base=_THIEVES_TOOLS,   weight=4,  min_qty=1, max_qty=1},
		]
	},

	"dungeon_elite": {
		rolls=[2, 4], gold_range=[18, 45],
		entries=[
			{base=_HEALING_POTION,  weight=20, min_qty=1, max_qty=2},
			{base=_GREATER_HEALING, weight=28, min_qty=1, max_qty=1},
			{base=_ANTITOXIN,       weight=20, min_qty=1, max_qty=2},
			{base=_THIEVES_TOOLS,   weight=12, min_qty=1, max_qty=1},
			{base=_ROPE,            weight=10, min_qty=1, max_qty=1},
			{base={}, weight=10},
		]
	},

	"dungeon_boss": {
		rolls=[3, 5], gold_range=[30, 70],
		entries=[
			{base=_GREATER_HEALING, weight=32, min_qty=1, max_qty=2},
			{base=_HEALING_POTION,  weight=22, min_qty=1, max_qty=2},
			{base=_ANTITOXIN,       weight=20, min_qty=1, max_qty=2},
			{base=_THIEVES_TOOLS,   weight=14, min_qty=1, max_qty=1},
			{base=_ROPE,            weight=12, min_qty=1, max_qty=1},
		]
	},

}

# ── Roll ──────────────────────────────────────────────────────────────────────

## Roll loot using a pre-seeded RNG. Returns {gold: int, items: Array[Dictionary]}.
static func roll(rng: RandomNumberGenerator, table_key: String) -> Dictionary:
	var table: Dictionary = TABLES.get(table_key, {})
	if table.is_empty():
		return {gold=0, items=[]}

	var gold_range: Array = table.get("gold_range", [0, 0])
	var gold: int = rng.randi_range(gold_range[0], gold_range[1])

	var rolls_range: Array = table.get("rolls", [1, 1])
	var num_rolls: int = rng.randi_range(rolls_range[0], rolls_range[1])
	var entries: Array = table.get("entries", [])

	var result_items: Array = []
	for _i in num_rolls:
		var entry = _weighted_pick(rng, entries)
		if entry == null:
			continue
		var base: Dictionary = entry.get("base", {})
		if base.is_empty() or not base.has("name"):
			continue   # empty slot
		var qty: int = rng.randi_range(
			entry.get("min_qty", 1),
			entry.get("max_qty", 1))
		var item := base.duplicate()
		item["quantity"] = qty
		# Stack matching items
		var merged := false
		for existing in result_items:
			if existing.get("name") == item.get("name"):
				existing["quantity"] = existing.get("quantity", 0) + qty
				merged = true
				break
		if not merged:
			result_items.append(item)

	return {gold=gold, items=result_items}

## Weighted random pick from entries list.
static func _weighted_pick(rng: RandomNumberGenerator, entries: Array):
	if entries.is_empty():
		return null
	var total: int = 0
	for e in entries:
		total += int(e.get("weight", 1))
	if total <= 0:
		return null
	var r: int = rng.randi_range(0, total - 1)
	var cumul: int = 0
	for e in entries:
		cumul += int(e.get("weight", 1))
		if r < cumul:
			return e
	return entries[-1]

## Returns true if a named table exists.
static func has_table(key: String) -> bool:
	return TABLES.has(key)

## All defined table keys.
static func all_keys() -> Array:
	return TABLES.keys()
