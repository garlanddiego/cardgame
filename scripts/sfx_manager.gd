class_name SfxManager
## Procedural sound effects for battle — no external audio files needed.
## Each hero has distinct attack/block/hit sounds. Monsters share a generic set.

static var _player: AudioStreamPlayer = null

static func _ensure_player(tree: SceneTree) -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	tree.root.add_child(_player)
	return _player

## Generate a procedural WAV buffer (mono, 22050 Hz, 16-bit)
static func _make_wav(freq: float, duration: float, wave: String = "square",
		decay: float = 1.0, noise_mix: float = 0.0, pitch_sweep: float = 0.0,
		volume: float = 0.4) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var buf := PackedByteArray()
	buf.resize(num_samples * 2)  # 16-bit = 2 bytes per sample
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var progress: float = float(i) / num_samples
		var env: float = pow(1.0 - progress, decay) * volume  # amplitude envelope
		var f: float = freq + pitch_sweep * progress  # frequency with sweep
		var phase: float = t * f * TAU
		var sample: float = 0.0
		match wave:
			"sine":
				sample = sin(phase)
			"square":
				sample = 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0
			"saw":
				sample = 2.0 * fmod(t * f, 1.0) - 1.0
			"noise":
				sample = randf_range(-1.0, 1.0)
			"triangle":
				var p: float = fmod(t * f, 1.0)
				sample = 4.0 * absf(p - 0.5) - 1.0
		# Mix in noise
		if noise_mix > 0.0:
			sample = sample * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		sample *= env
		var s16: int = clampi(int(sample * 32000.0), -32768, 32767)
		buf[i * 2] = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = buf
	return stream

## Layer multiple tones into one buffer
static func _make_layered(layers: Array, duration: float, vol: float = 0.3) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var mix := PackedFloat32Array()
	mix.resize(num_samples)
	for li in range(layers.size()):
		var L: Dictionary = layers[li]
		var f: float = L.get("freq", 200.0)
		var w: String = L.get("wave", "square")
		var d: float = L.get("decay", 1.5)
		var nm: float = L.get("noise", 0.0)
		var ps: float = L.get("sweep", 0.0)
		var v: float = L.get("vol", 1.0)
		var delay_samples: int = int(L.get("delay", 0.0) * sample_rate)
		for i in range(num_samples):
			if i < delay_samples:
				continue
			var adj_i: int = i - delay_samples
			var t: float = float(adj_i) / sample_rate
			var progress: float = float(adj_i) / (num_samples - delay_samples)
			var env: float = pow(1.0 - progress, d) * v
			var phase: float = t * (f + ps * progress) * TAU
			var s: float = 0.0
			match w:
				"sine": s = sin(phase)
				"square": s = 1.0 if fmod(t * (f + ps * progress), 1.0) < 0.5 else -1.0
				"saw": s = 2.0 * fmod(t * (f + ps * progress), 1.0) - 1.0
				"noise": s = randf_range(-1.0, 1.0)
				"triangle":
					var p: float = fmod(t * (f + ps * progress), 1.0)
					s = 4.0 * absf(p - 0.5) - 1.0
			if nm > 0.0:
				s = s * (1.0 - nm) + randf_range(-1.0, 1.0) * nm
			s *= env
			mix[i] += s
	var buf := PackedByteArray()
	buf.resize(num_samples * 2)
	for i in range(num_samples):
		var s16: int = clampi(int(mix[i] * vol * 32000.0), -32768, 32767)
		buf[i * 2] = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = buf
	return stream

# =========================================================================
# PUBLIC API — call from battle_manager
# =========================================================================

static func play_hero_attack(tree: SceneTree, character: String) -> void:
	var stream: AudioStreamWAV
	match character:
		"silent":
			# Quick sharp swoosh — dagger slice
			stream = _make_layered([
				{"freq": 2000, "wave": "noise", "decay": 4.0, "vol": 0.8, "sweep": -1500},
				{"freq": 800, "wave": "saw", "decay": 5.0, "vol": 0.4, "sweep": -600},
			], 0.15, 0.35)
		"forger":
			# Heavy hammer impact — low thud + metallic ring
			stream = _make_layered([
				{"freq": 80, "wave": "sine", "decay": 2.0, "vol": 1.0},
				{"freq": 600, "wave": "square", "decay": 4.0, "vol": 0.5, "noise": 0.3},
				{"freq": 1200, "wave": "sine", "decay": 6.0, "vol": 0.3, "delay": 0.02},
			], 0.25, 0.35)
		"bloodfiend":
			# Savage claw slash — aggressive ripping
			stream = _make_layered([
				{"freq": 300, "wave": "saw", "decay": 3.0, "vol": 0.7, "sweep": 400},
				{"freq": 1500, "wave": "noise", "decay": 3.5, "vol": 0.6, "sweep": -800},
				{"freq": 150, "wave": "square", "decay": 2.0, "vol": 0.4},
			], 0.2, 0.35)
		_:
			stream = _make_wav(400, 0.15, "square", 3.0, 0.2, -200, 0.3)
	var p := _ensure_player(tree)
	p.stream = stream
	p.play()

static func play_hero_block(tree: SceneTree, character: String) -> void:
	var stream: AudioStreamWAV
	match character:
		"silent":
			# Light parry — quick high ting
			stream = _make_layered([
				{"freq": 1800, "wave": "triangle", "decay": 5.0, "vol": 0.6},
				{"freq": 2400, "wave": "sine", "decay": 6.0, "vol": 0.3, "delay": 0.01},
			], 0.12, 0.25)
		"forger":
			# Shield raise — solid metallic clank
			stream = _make_layered([
				{"freq": 400, "wave": "square", "decay": 3.0, "vol": 0.7, "noise": 0.15},
				{"freq": 900, "wave": "triangle", "decay": 4.0, "vol": 0.5},
				{"freq": 200, "wave": "sine", "decay": 2.0, "vol": 0.4},
			], 0.18, 0.3)
		"bloodfiend":
			# Dark energy barrier — low rumble shimmer
			stream = _make_layered([
				{"freq": 120, "wave": "saw", "decay": 2.5, "vol": 0.6},
				{"freq": 500, "wave": "sine", "decay": 4.0, "vol": 0.4, "sweep": 200},
			], 0.15, 0.25)
		_:
			stream = _make_wav(800, 0.12, "triangle", 4.0, 0.0, 0.0, 0.25)
	var p := _ensure_player(tree)
	p.stream = stream
	p.play()

static func play_block_absorb(tree: SceneTree, character: String) -> void:
	var stream: AudioStreamWAV
	match character:
		"silent":
			# Deflect — sharp ping + fade
			stream = _make_layered([
				{"freq": 2200, "wave": "sine", "decay": 5.0, "vol": 0.5},
				{"freq": 1000, "wave": "noise", "decay": 6.0, "vol": 0.3},
			], 0.1, 0.3)
		"forger":
			# Shield block — heavy metallic impact
			stream = _make_layered([
				{"freq": 150, "wave": "sine", "decay": 1.5, "vol": 0.8},
				{"freq": 700, "wave": "square", "decay": 3.0, "vol": 0.6, "noise": 0.25},
				{"freq": 1400, "wave": "triangle", "decay": 5.0, "vol": 0.3, "delay": 0.015},
			], 0.22, 0.35)
		"bloodfiend":
			# Flesh/armor absorb — wet thud
			stream = _make_layered([
				{"freq": 100, "wave": "sine", "decay": 2.0, "vol": 0.7},
				{"freq": 350, "wave": "saw", "decay": 3.0, "vol": 0.4, "noise": 0.2},
			], 0.15, 0.3)
		_:
			stream = _make_wav(600, 0.15, "square", 3.0, 0.15, 0.0, 0.3)
	var p := _ensure_player(tree)
	p.stream = stream
	p.play()

static func play_enemy_attack(tree: SceneTree) -> void:
	# Generic monster attack — threatening whoosh + impact
	var stream := _make_layered([
		{"freq": 200, "wave": "saw", "decay": 2.0, "vol": 0.6, "sweep": -100},
		{"freq": 100, "wave": "sine", "decay": 1.5, "vol": 0.5},
		{"freq": 800, "wave": "noise", "decay": 4.0, "vol": 0.4, "delay": 0.05},
	], 0.2, 0.3)
	var p := _ensure_player(tree)
	p.stream = stream
	p.play()
