extends RichTextLabel

@export var target_word: String = "BISCUIT"
@export var collected_color: Color = Color.WHITE
@export var missing_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var wave_amplitude: float = 10.0
@export var wave_frequency: float = 5.0
@export var letter_spacing: float = 10.0

@export var word_fx: GPUParticles2D


var collected_letters: Array[String] = []

func _ready():
	bbcode_enabled = true
	update_word_display()

func _on_letter_collected(letter: String):
	collected_letters.append(letter.to_upper())
	update_word_display()
	animate_letter_collection()
	word_fx.emitting = true
	
	# Check for word completion
	if collected_letters.size() == target_word.length():
		on_word_completed()

func on_word_completed():
	animate_word_completion()
	word_fx.emitting = true
	await get_tree().create_timer(2.0).timeout
	collected_letters.clear()
	update_word_display()

func update_word_display():
	var display_text = ""
	
	# Build the text with BBCode formatting
	for i in range(target_word.length()):
		var letter = target_word[i].to_upper()
		var color_to_use = collected_color if i < collected_letters.size() else missing_color
		
		# Build the BBCode string for the current letter
		var letter_bbcode = "[wave amp=%s freq=%s][color=%s]%s[/color][/wave]" % [
			wave_amplitude,
			wave_frequency,
			color_to_use.to_html(),
			letter
		]
		
		display_text += letter_bbcode
		
		# Add spacing between letters using invisible characters
		if i < target_word.length() - 1:
			var space_count = int(letter_spacing / 10.0)
			for j in range(space_count):
				display_text += "[color=00000000]_[/color]"
	
	# Center the display text
	text = "[center]%s[/center]" % display_text

func animate_letter_collection():
	# Brief scale animation when a letter is collected
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func animate_word_completion():
	# Celebration animation when the word is completed
	var tween = create_tween().set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)
	tween.parallel().tween_property(self, "modulate", Color.GOLD, 0.3)
	
	await tween.finished
	
	var tween2 = create_tween().set_trans(Tween.TRANS_QUAD)
	tween2.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	tween2.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)
