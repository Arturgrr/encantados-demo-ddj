class_name WalkSprites
extends RefCounted
## Utilitário compartilhado por Caipora e Cuca para montar as animações de
## caminhada em 8 direções a partir de 5 spritesheets (norte, nordeste, leste,
## sudeste, sul). As direções OESTE são o espelho (flip_h) das LESTE:
##   oeste = espelho de leste, noroeste = espelho de nordeste,
##   sudoeste = espelho de sudeste.
##
## Os sheets são uma grade de 6 colunas (linha a linha, da esquerda pra direita).
## Cada direção tem o seu próprio número de frames e o seu próprio tamanho de
## célula, então cada uma é descrita num dicionário (ver WALK em caipora.gd/cuca.gd).

const COLS: int = 6


## Monta o SpriteFrames com uma animação por direção-base ("n","ne","e","se","s").
## `defs` = { chave: {tex, frames, cell_w, cell_h, feet, scale} }
static func build(defs: Dictionary, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	# SpriteFrames nasce com uma animação "default" que não usamos.
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	add_set(sf, defs, fps, "")
	return sf


## Adiciona mais um conjunto de animações a um SpriteFrames existente, com um
## prefixo no nome (ex.: "idle_" para as poses paradas).
##
## `duration` > 0 SINCRONIZA o conjunto: cada direção ganha o fps necessário
## (frames/duração) para todas durarem o MESMO tempo, mesmo tendo quantidades
## de frames diferentes. Se for 0, usa o `fps` informado para todas.
static func add_set(sf: SpriteFrames, defs: Dictionary, fps: float, prefix: String,
		duration: float = 0.0, loop: bool = true) -> void:
	for key in defs:
		var d: Dictionary = defs[key]
		# `key` vem do Dictionary como Variant → converte explicitamente.
		var anim: String = prefix + String(key)
		sf.add_animation(anim)
		var anim_fps: float = fps
		if duration > 0.0:
			anim_fps = float(d["frames"]) / duration
		sf.set_animation_speed(anim, anim_fps)
		sf.set_animation_loop(anim, loop)

		var tex: Texture2D = d["tex"]
		var cw: float = d["cell_w"]
		var ch: float = d["cell_h"]
		for i in int(d["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			# Frames em ordem: linha a linha, 6 por linha.
			at.region = Rect2((i % COLS) * cw, (i / COLS) * ch, cw, ch)
			sf.add_frame(anim, at)


## Converte uma direção (Vector2) na animação a usar e se precisa espelhar.
## Retorna [chave: String, flip_h: bool]. Em Godot +X = leste e +Y = SUL.
static func dir_for(facing: Vector2) -> Array:
	# Divide o círculo em 8 fatias de 45°: 0=L, 1=SL, 2=S, 3=SO, 4=O, 5=NO, 6=N, 7=NL
	var idx := posmod(int(roundf(facing.angle() / (PI / 4.0))), 8)
	match idx:
		0: return ["e", false]   # leste
		1: return ["se", false]  # sudeste
		2: return ["s", false]   # sul
		3: return ["se", true]   # sudoeste = espelho do sudeste
		4: return ["e", true]    # oeste = espelho do leste
		5: return ["ne", true]   # noroeste = espelho do nordeste
		6: return ["n", false]   # norte
		_: return ["ne", false]  # nordeste
