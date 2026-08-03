## The Mender's crystallization rig — a stationary attackable objective (the
## Act 1 boss fight's real target). Reuses EnemyController's damage intake,
## click-targeting, and death plumbing, but runs no AI: it never moves, never
## attacks, and ignores gravity (it is planted into the tear).
class_name VeilRig
extends EnemyController

## Phase 3: Liris channels against the rig and it takes bonus damage.
var vulnerable: bool = false

signal healed(amount: int)

func _physics_process(_delta: float) -> void:
	pass

func receive_damage(amount: int, from: Vector3 = Vector3.INF) -> void:
	if vulnerable:
		amount = int(amount * 1.5)
	super.receive_damage(amount, from)

## Anchor Surge repairs the rig.
func heal(amount: int) -> void:
	if character == null or _dead:
		return
	character.stats.current_hp = mini(character.stats.max_hp,
		character.stats.current_hp + amount)
	hp_changed.emit(character.stats.current_hp, character.stats.max_hp)
	healed.emit(amount)
