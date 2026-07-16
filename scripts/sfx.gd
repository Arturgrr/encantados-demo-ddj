extends Node
## Autoload "Sfx": toca os efeitos sonoros do jogo.
##
## Cada "chave" aponta para uma LISTA de variações do mesmo som — sorteamos uma
## e ainda variamos o pitch levemente, para o som não ficar robótico quando
## repete muito (passos, principalmente).
##
## - `play_at()` cria um AudioStreamPlayer2D one-shot na posição do mundo (tem
##   atenuação por distância: a Cuca longe soa mais baixo que a Caipora).
## - `play_ui()` toca sem posição (menu, jingles), pendurado no próprio autoload
##   para sobreviver à troca de cena.
##
## Sons: packs CC0 do Kenney em res://assets/audio/ (rpg-audio, impact-sounds,
## ui-audio, music-jingles, sci-fi-sounds).

const A := "res://assets/audio/"

var _sounds: Dictionary = {}


func _ready() -> void:
	_sounds = {
		# --- Mixkit: só os dois que soaram bem ---
		# Lança da Caipora: corte rápido no ar.
		"spear": [_load(A + "custom/ataque_caipora.mp3")],
		# Poção sendo arremessada / quebrando no chão.
		"glass": [_load(A + "custom/pocao_quebra.mp3")],

		# --- Kenney (CC0): o resto voltou para estes ---
		# Passos (5 variações na grama). A Cuca usa o mesmo com pitch grave.
		"footstep": _load_list(A + "impact-sounds/Audio/footstep_grass_%03d.ogg", 5),
		# Tomar dano (pitch distingue Caipora e Cuca).
		"hurt": _load_list(A + "impact-sounds/Audio/impactSoft_medium_%03d.ogg", 5),
		# Espinhos rompendo o chão.
		"spike": _load_list(A + "impact-sounds/Audio/impactMining_%03d.ogg", 5),
		# Conjuração da Cuca (zumbido mágico).
		"cast": _load_list(A + "sci-fi-sounds/Audio/forceField_%03d.ogg", 5),
		# Agarrão da Cuca (arremesso).
		"throw": _load_list(A + "impact-sounds/Audio/impactPunch_heavy_%03d.ogg", 5),
		# Poça de veneno borbulhando.
		"slime": [
			_load(A + "sci-fi-sounds/Audio/slime_000.ogg"),
			_load(A + "sci-fi-sounds/Audio/slime_001.ogg"),
		],
		# Disparo da bolinha perseguidora.
		"laser": _load_list(A + "sci-fi-sounds/Audio/laserSmall_%03d.ogg", 5),
		# Cliques do menu.
		"click": [
			_load(A + "ui-audio/Audio/click1.ogg"),
			_load(A + "ui-audio/Audio/click2.ogg"),
			_load(A + "ui-audio/Audio/click3.ogg"),
		],
		# Jingles de fim de partida.
		"win": [_load(A + "music-jingles/Audio/Steel jingles/jingles_STEEL07.ogg")],
		"lose": [_load(A + "music-jingles/Audio/Steel jingles/jingles_STEEL09.ogg")],
	}


## Toca um som posicionado no mundo (one-shot, se destrói ao terminar).
func play_at(pos: Vector2, key: String, db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.08) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_var, pitch_var))
	p.max_distance = 1600.0
	host.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Toca um som sem posição (menu, jingles). Sobrevive à troca de cena.
func play_ui(key: String, db: float = 0.0) -> void:
	var stream := _pick(key)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Sorteia uma das variações da chave.
func _pick(key: String) -> AudioStream:
	if not _sounds.has(key):
		return null
	var list: Array = _sounds[key]
	if list.is_empty():
		return null
	return list[randi() % list.size()]


## Carrega uma sequência numerada (ex.: ..._000.ogg .. _004.ogg).
func _load_list(pattern: String, count: int) -> Array:
	var out: Array = []
	for i in count:
		var s := _load(pattern % i)
		if s != null:
			out.append(s)
	return out


## Carrega tolerando ausência (não derruba o jogo se faltar um arquivo).
func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("Sfx: som não encontrado: " + path)
		return null
	return load(path)
