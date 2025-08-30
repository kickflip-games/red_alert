extends RichTextLabel

@export var target_word: String = "BISCUIT"
@export var collected_color: Color = Color.WHITE
@export var missing_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var wave_amplitude: float = 10.0
@export var wave_frequency: float = 5.0

var collected_letters: Array[String] = []
var spawner_reference: Node = null

func _ready():
	# Enable BBCode
	bbcode_enabled = true
	
	# Find the spawner to connect signals
	spawner_reference = get_tree().get_first_node_in_group("spawner")
	if spawner_reference:
		if spawner_reference.has_signal("letter_collected"):
			spawner_reference.letter_collected.connect(_on_letter_collected)
		if spawner_reference.has_signal("word_completed"):
			spawner_reference.word_completed.connect(_on_word_completed)
	
	# Initial display
	update_word_display()

func _on_letter_collected(letter: String):
	collected_letters.append(letter)
	update_word_display()
	
	# Optional: play letter collect animation
	animate_letter_collection()

func _on_word_completed(word: String):
	# Special animation when word is completed
	animate_word_completion()
	
	# Reset after a delay
	await get_tree().create_timer(2.0).timeout
	collected_letters.clear()
	update_word_display()

func update_word_display():
	var display_text = ""
	
	# Build the text with BBCode formatting
	for i in range(target_word.length()):
		var letter = target_word[i]
		
		if i < collected_letters.size():
			# Collected letter - floating with wave effect and colored
			display_text += "[wave amp=%s freq=%s][color=%s]%s[/color][/wave]" % [
				wave_amplitude,
				wave_frequency, 
				collected_color.to_html(), 
				letter
			]
		else:
			# Missing letter - static and dimmed
			display_text += "[wave amp=%s freq=%s][color=%s]%s[/color][/wave]" % [
				wave_amplitude,
				wave_frequency, 
				missing_color.to_html(), 
				letter
			]
		
		# Add space between letters for better readability
		if i < target_word.length() - 1:
			display_text += " "
	
	text = display_text

func animate_letter_collection():
	# Brief scale animation when a letter is collected
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func animate_word_completion():
	# Celebration animation when word is completed
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)
	tween.parallel().tween_property(self, "modulate", Color.GOLD, 0.3)
	
	await tween.finished
	
	var tween2 = create_tween()
	tween2.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	tween2.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)

func set_target_word(new_word: String):
	target_word = new_word.to_upper()
	collected_letters.clear()
	update_word_display()

func reset_progress():
	collected_letters.clear()
	update_word_display()

func get_progress_percentage() -> float:
	if target_word.length() == 0:
		return 0.0
	return float(collected_letters.size()) / float(target_word.length())
