extends Node2D
class_name AttackWave

signal wave_complete(wave:AttackWave)
signal wave_started(wave:AttackWave)


## Delay before this wave starts
@export var start_delay: float = 0.0  

## Duration this wave is active
@export var wave_duration: float = 10.0  

## Delay after wave before next one
@export var end_delay: float = 1.0  

## Stop children on wave end
@export var disable_child_attacks_on_finish: bool = true 

## Time bw attacks 
@export var stagger_attacks: bool = false  
@export var stagger_delay: float = 0.25  

## Some notes about this attack
@export_multiline var notes: String


var current_wave_timer: float = 0.0
var is_active: bool = false
var attacks:Array[BaseAttack]

var total_duration:
	get: 
		return start_delay + wave_duration + end_delay


func _ready():
	set_process(false)
	_setup()

func _setup():
	for child in get_children():
		if child is BaseAttack:
			attacks.append(child)
			child.visible = false
	self.visible = false

func _process(delta):
	if not is_active:
		return

	current_wave_timer += delta

	if current_wave_timer >= wave_duration:
		stop_wave()

func start_wave():
	is_active = true
	current_wave_timer = 0.0
	set_process(true)
	self.visible = true

	wave_started.emit(self)
	if stagger_attacks:
		_start_attacks_staggered()
	else:
		_start_attacks_all_together()

func stop_wave():
	is_active = false
	set_process(false)

	if disable_child_attacks_on_finish:
		for attack in attacks:
			attack.stop_attack()

	wave_complete.emit(self)

func _start_attacks_all_together():
	for attack in attacks:
		attack.start_attack()

func _start_attacks_staggered():
	start_staggered_attacks()

func start_staggered_attacks() -> void:
	await _stagger_children()

func _stagger_children():
	for attack in attacks:
		attack.start_attack()
		await get_tree().create_timer(stagger_delay).timeout
