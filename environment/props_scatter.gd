extends Node2D
## Espalha a vegetação e os props do mundo por código. Este nó fica DENTRO do
## World y-sortado da batalha (junto de Caipora/Cuca), então cada sprite criado
## aqui é ordenado por profundidade pela sua posição Y — o player passa ATRÁS
## das árvores/pedras quando está "acima" delas.
##
##  - Borda: anel DENSO de árvores fechando o mapa, colado nas paredes.
##  - Interior: arbustos, pedras e algumas árvores na FAIXA DE GRAMA entre o
##    círculo de terra e a borda — NUNCA em cima da terra (clareira limpa).
##  - Props: covil de bruxa da Cuca.
##
## COLISÃO: árvores e pedras viram StaticBody2D (camada World=1). A árvore só
## bloqueia no TRONCO (bloquinho pequeno na base) — dá pra andar por cima das
## folhas. Arbustos e itens mágicos NÃO têm colisão (atravessáveis).
##
## Semente fixa no RNG → layout idêntico toda vez.

const TEX_TREES: Array[Texture2D] = [
	preload("res://assets/extracted/tree_a.png"),
	preload("res://assets/extracted/tree_b.png"),
]
const TEX_ROCK: Texture2D = preload("res://assets/extracted/rock.png")
const TEX_BUSH: Texture2D = preload("res://assets/extracted/bush.png")
# Props temáticos do covil da bruxa (Cuca).
const TEX_ALCHEMY: Texture2D = preload("res://assets/extracted/props/alchemy_table.png")
const TEX_POTION: Texture2D = preload("res://assets/extracted/props/potion.png")
const TEX_CRYSTAL: Texture2D = preload("res://assets/extracted/props/crystal.png")
const TEX_LANTERN: Texture2D = preload("res://assets/extracted/props/lantern.png")

# Tipo de colisão de um prop.
const BLOCK_NONE: int = 0   # atravessável (arbustos, itens mágicos)
const BLOCK_TRUNK: int = 1  # bloquinho só no tronco (árvores)
const BLOCK_ROCK: int = 2   # corpo da pedra

const MAP_SIZE: Vector2 = Vector2(2304, 1296)
# Arena jogável — DEVE casar com as paredes de colisão em forest.tscn.
const ARENA := Rect2(230, 250, 1844, 796)
# Círculo de terra central. Nenhuma vegetação nasce dentro deste raio.
const DIRT_CENTER := Vector2(1152, 648)
const DIRT_CLEAR_RADIUS: float = 480.0

const BORDER_STEP: float = 90.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260717
	_build_tree_border(rng)
	_scatter_interior(rng)
	_place_witch_props()


## Preenche a moldura ao redor da arena com árvores sobrepostas, avançando ~40px
## para DENTRO da arena, então encostam nas paredes.
func _build_tree_border(rng: RandomNumberGenerator) -> void:
	var inner := ARENA.grow(-40.0)
	var y := 10.0
	while y < MAP_SIZE.y:
		var x := 10.0
		while x < MAP_SIZE.x:
			if not inner.has_point(Vector2(x, y)):
				var jp := Vector2(
					x + rng.randf_range(-22.0, 22.0),
					y + rng.randf_range(-22.0, 22.0)
				)
				_add_tree(rng, jp)
			x += BORDER_STEP
		y += BORDER_STEP


## Decoração na faixa de grama (fora do círculo de terra e dentro da arena).
func _scatter_interior(rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 3000:
		tries += 1
		var p := _random_grass_point(rng)
		if p == Vector2.INF:
			continue
		_add_prop(TEX_BUSH, p, rng.randf_range(0.9, 1.4), rng.randf() < 0.5, BLOCK_NONE)
		placed += 1
	placed = 0
	tries = 0
	while placed < 8 and tries < 3000:
		tries += 1
		var p := _random_grass_point(rng)
		if p == Vector2.INF:
			continue
		_add_prop(TEX_ROCK, p, rng.randf_range(0.8, 1.3), rng.randf() < 0.5, BLOCK_ROCK)
		placed += 1
	placed = 0
	tries = 0
	while placed < 6 and tries < 3000:
		tries += 1
		var p := _random_grass_point(rng)
		if p == Vector2.INF:
			continue
		_add_tree(rng, p)
		placed += 1


## Sorteia um ponto na grama (dentro da arena, fora do círculo de terra).
## Retorna Vector2.INF se caiu na terra (o chamador tenta de novo).
func _random_grass_point(rng: RandomNumberGenerator) -> Vector2:
	var p := Vector2(
		rng.randf_range(ARENA.position.x + 30.0, ARENA.end.x - 30.0),
		rng.randf_range(ARENA.position.y + 30.0, ARENA.end.y - 30.0)
	)
	if p.distance_to(DIRT_CENTER) < DIRT_CLEAR_RADIUS:
		return Vector2.INF
	return p


## Covil da Cuca + itens mágicos soltos (todos atravessáveis — sem colisão).
func _place_witch_props() -> void:
	_add_prop(TEX_ALCHEMY, Vector2(1748.0, 560.0), 2.2, false, BLOCK_NONE)
	_add_prop(TEX_POTION, Vector2(1672.0, 596.0), 1.9, false, BLOCK_NONE)
	_add_prop(TEX_CRYSTAL, Vector2(1812.0, 600.0), 1.7, false, BLOCK_NONE)
	_add_prop(TEX_LANTERN, Vector2(1624.0, 508.0), 1.9, true, BLOCK_NONE)
	_add_prop(TEX_CRYSTAL, Vector2(540.0, 470.0), 1.6, false, BLOCK_NONE)
	_add_prop(TEX_POTION, Vector2(470.0, 900.0), 1.6, false, BLOCK_NONE)
	_add_prop(TEX_CRYSTAL, Vector2(1760.0, 980.0), 1.4, true, BLOCK_NONE)


func _add_tree(rng: RandomNumberGenerator, pos: Vector2) -> void:
	var tex: Texture2D = TEX_TREES[rng.randi() % TEX_TREES.size()]
	_add_prop(tex, pos, rng.randf_range(1.5, 2.4), rng.randf() < 0.5, BLOCK_TRUNK)


## Cria um Sprite2D base-anchored (a copa fica para cima do ponto). Se `block`
## pedir colisão, embrulha num StaticBody2D (camada World=1) com um shape:
##  - BLOCK_TRUNK: bloquinho pequeno só na base (tronco) — copa atravessável.
##  - BLOCK_ROCK: cobre a maior parte do corpo da pedra.
func _add_prop(tex: Texture2D, pos: Vector2, scale: float, flip: bool, block: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	sprite.scale = Vector2(scale, scale)
	sprite.flip_h = flip

	if block == BLOCK_NONE:
		sprite.position = pos
		add_child(sprite)
		return

	# Com colisão: StaticBody2D (World) na base, sprite como visual.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.add_child(sprite)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = tex.get_width() * scale
	var h: float = tex.get_height() * scale
	if block == BLOCK_TRUNK:
		# Só o tronco: estreito e baixo, na base (a copa fica livre).
		rect.size = Vector2(maxf(w * 0.24, 10.0), 16.0)
		col.position = Vector2(0.0, -9.0)
	else: # BLOCK_ROCK
		rect.size = Vector2(w * 0.72, h * 0.5)
		col.position = Vector2(0.0, -h * 0.32)
	col.shape = rect
	body.add_child(col)

	add_child(body)
