extends CharacterBody2D
## Cuca — bruxa gigante, chefe do duelo. TOP-DOWN, controlada por IA. É uma
## lutadora puramente à DISTÂNCIA: tenta manter um afastamento do player
## (recua se ele chega perto, aproxima se ele foge, deriva de lado na faixa
## ideal) e ALTERNA entre os 3 feitiços em intervalos variados —
## independentemente da distância. Não tem golpe corpo-a-corpo.

signal health_changed(current: int, max_health: int)
signal died()

@export var max_health: int = 300
var health: int

const MOVE_SPEED: float = 120.0
const MIN_DISTANCE: float = 150.0   # perto demais → recua para reabrir espaço
const MAX_DISTANCE: float = 260.0   # longe demais → aproxima

# Na faixa ideal a Cuca fica PARADA encarando o player e, de vez em quando, dá
# um passinho curto para o lado (não fica andando à toa).
const STRAFE_SPEED: float = 70.0    # velocidade do passinho lateral
const IDLE_MIN: float = 1.4         # tempo parada antes do próximo passinho
const IDLE_MAX: float = 3.2
const DRIFT_MIN: float = 0.25       # duração do passinho
const DRIFT_MAX: float = 0.6

# Intervalo entre feitiços: sorteado nesta faixa a cada lançamento (variação).
const CAST_INTERVAL_MIN: float = 2.4
const CAST_INTERVAL_MAX: float = 3.6
# Quando perto (preferindo espinhos), o intervalo é MUITO maior — evita spammar
# espinhos/knockback na cara do player.
const CLOSE_CAST_INTERVAL_MIN: float = 5.5
const CLOSE_CAST_INTERVAL_MAX: float = 8.0

# "Cuca é mais forte": se a Caipora encostar/prender a Cuca (distância menor que
# isto), a Cuca empurra a Caipora para fora com esta força (por frame).
const PUSH_CONTACT_DIST: float = 58.0
const PUSH_FORCE: float = 340.0

## Spritesheets de caminhada (grade de 6 colunas). Cada direção tem seu próprio
## número de frames e sua própria linha dos "pés". Oeste = espelho do leste.
## Nota: o sheet do leste tem célula mais larga (853) que os demais (480).
const WALK := {
	"n": {"tex": preload("res://actors/cuca/WALKING/norte.png"),
		"frames": 9, "cell_w": 480.0, "cell_h": 640.0, "feet": 622.0, "scale": 0.275},
	"ne": {"tex": preload("res://actors/cuca/WALKING/nordeste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 570.0, "scale": 0.275},
	"e": {"tex": preload("res://actors/cuca/WALKING/leste.png"),
		"frames": 8, "cell_w": 853.0, "cell_h": 640.0, "feet": 602.0, "scale": 0.275},
	"se": {"tex": preload("res://actors/cuca/WALKING/sudeste.png"),
		"frames": 7, "cell_w": 480.0, "cell_h": 640.0, "feet": 630.0, "scale": 0.275},
	"s": {"tex": preload("res://actors/cuca/WALKING/sul.png"),
		"frames": 6, "cell_w": 480.0, "cell_h": 640.0, "feet": 630.0, "scale": 0.275},
}
const WALK_FPS: float = 9.0

## Poses PARADAS (uma imagem por direção, 1086x1448, fundo rosa já removido por
## chroma key). Escala por direção para todas darem ~176px (o dobro da Caipora).
const IDLE := {
	"n": {"tex": preload("res://actors/cuca/Idle/norte.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1399.0, "scale": 0.1329},
	"ne": {"tex": preload("res://actors/cuca/Idle/nordeste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1378.0, "scale": 0.1349},
	"e": {"tex": preload("res://actors/cuca/Idle/leste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1391.0, "scale": 0.1335},
	"se": {"tex": preload("res://actors/cuca/Idle/sudeste.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1415.0, "scale": 0.1282},
	"s": {"tex": preload("res://actors/cuca/Idle/sul.png"),
		"frames": 1, "cell_w": 1086.0, "cell_h": 1448.0, "feet": 1357.0, "scale": 0.1377},
}

# Os 3 feitiços. A Cuca alterna entre eles em ordem (garante que os 3 apareçam).
const SPELL_SCENES: Array[PackedScene] = [
	preload("res://actors/cuca/spells/homing_spell.tscn"),
	preload("res://actors/cuca/spells/poison_pool.tscn"),
	preload("res://actors/cuca/spells/rising_spikes.tscn"),
]
const HOMING_INDEX: int = 0               # índice de homing_spell em SPELL_SCENES
const SPIKES_INDEX: int = 2               # índice de rising_spikes em SPELL_SCENES
# Se a Caipora estiver mais perto que isto, a Cuca prefere os ESPINHOS. Precisa
# ficar ABAIXO de MIN_DISTANCE: assim só dispara quando a Caipora fura a zona de
# conforto dela, e não o tempo todo enquanto ela descansa na distância dela.
const CLOSE_PREF_DISTANCE: float = 130.0
# Ao conjurar espinhos ou a bolinha (homing), a Cuca fica parada este tempo
# (é a janela da animação de conjuração).
const CAST_FREEZE_TIME: float = 0.7

# AGARRÃO: se a Caipora ficar coladinha na Cuca por GRAB_TIME segundos seguidos,
# a Cuca a arremessa para bem longe e causa dano. Pune ficar "grudado" nela.
const GRAB_DIST: float = 100.0
const GRAB_TIME: float = 2.0
const THROW_FORCE: float = 1300.0
const THROW_DAMAGE: int = 20

# ENCURRALADA: se a Caipora a prensa contra a borda do mapa (ou uma árvore) e a
# Cuca não consegue mais recuar, ela arremessa a Caipora para longe e se solta.
const CORNERED_COOLDOWN: float = 2.5

var _dead: bool = false
var _facing: int = 1 # 1 = olhando para a direita, -1 = espelhado
var _cast_cooldown: float = 0.0
var _spell_index: int = 0 # índice do próximo feitiço na rotação
var _strafe_dir: int = 1
## Contagem para o próximo passinho lateral, e quanto dele ainda falta.
var _idle_timer: float = 0.0
var _drift_timer: float = 0.0
## Enquanto > 0, a Cuca fica parada conjurando (espinhos / bolinha).
var _cast_freeze: float = 0.0
## Há quanto tempo a Caipora está colada na Cuca (para o agarrão).
var _close_timer: float = 0.0
## Espera até ela poder arremessar de novo por estar encurralada.
var _cornered_cd: float = 0.0
## Última direção usada no sprite (para congelar a pose ao morrer).
var _last_facing: Vector2 = Vector2.RIGHT

## Animação atual (chave de WALK/IDLE), para só trocar quando mudar.
var _cur_anim: String = ""

## Pegadas: a Cuca é o dobro do tamanho, então marca maior e passada mais longa.
const STEP_DISTANCE: float = 58.0
const FOOT_SIZE: float = 2.0
const FOOT_COLOR := Color(0.10, 0.07, 0.04, 0.5)
var _step_accum: float = 0.0
var _step_side: int = 1

@onready var _visual: Node2D = $Visual
@onready var _sprite: AnimatedSprite2D = $Visual/Sprite


func _ready() -> void:
	add_to_group("boss")
	health = max_health
	health_changed.emit(health, max_health)

	_sprite.sprite_frames = WalkSprites.build(WALK, WALK_FPS)
	WalkSprites.add_set(_sprite.sprite_frames, IDLE, 1.0, "idle_")
	_update_sprite(Vector2.RIGHT, false)
	_cast_cooldown = randf_range(CAST_INTERVAL_MIN, CAST_INTERVAL_MAX)
	# Começa a rotação de feitiços num ponto aleatório, para variar entre partidas.
	_spell_index = randi() % SPELL_SCENES.size()
	_strafe_dir = 1 if randf() < 0.5 else -1
	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target := get_tree().get_first_node_in_group("player")
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	var dir: Vector2 = to_target.normalized() if distance > 0.0 else Vector2.RIGHT

	# Lado para o qual a Cuca está voltada (usado como origem dos feitiços).
	_facing = 1 if to_target.x >= 0.0 else -1

	# Agarrão: conta o tempo com a Caipora colada (vale mesmo conjurando).
	if distance < GRAB_DIST:
		_close_timer += delta
		if _close_timer >= GRAB_TIME:
			_close_timer = 0.0
			_throw_player(target, dir)
	else:
		_close_timer = 0.0

	# Conjurando: fica parada encarando o player durante a janela da animação.
	if _cast_freeze > 0.0:
		_cast_freeze -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite(dir, false)
		_update_cast(delta, target, distance)
		return

	# Movimento para manter distância: recua se perto, aproxima se longe. Na
	# faixa ideal ela PARA e só dá passinhos ocasionais (ver _update_drift).
	if distance < MIN_DISTANCE:
		velocity = -dir * MOVE_SPEED
	elif distance > MAX_DISTANCE:
		velocity = dir * MOVE_SPEED
	else:
		_update_drift(delta, dir)

	move_and_slide()

	# Se a deriva/recuo bateu numa parede, inverte o sentido lateral.
	if get_slide_collision_count() > 0 and velocity.length() > 0.0:
		_strafe_dir = -_strafe_dir

	# Encurralada: está tentando recuar (a Caipora está em cima dela) mas bateu
	# na borda do mapa / numa árvore. Sem espaço para fugir, ela arremessa a
	# Caipora para longe e se solta.
	if _cornered_cd > 0.0:
		_cornered_cd -= delta
	if _cornered_cd <= 0.0 and distance < MIN_DISTANCE and _blocked_by_scenery():
		_cornered_cd = CORNERED_COOLDOWN
		_close_timer = 0.0
		_throw_player(target, dir)

	# Animação: caminha na direção em que se move; parada, encara o player.
	var moving := velocity.length() > 10.0
	var move_dir := velocity.normalized() if moving else dir
	_update_sprite(move_dir, moving)
	_update_footprints(delta, moving, move_dir)

	# Cuca é mais forte: se a Caipora está colada (prendendo a Cuca contra a
	# parede), a Cuca a empurra para fora — o player não segura a Cuca no corpo.
	if distance < PUSH_CONTACT_DIST and target.has_method("apply_knockback"):
		target.apply_knockback(dir * PUSH_FORCE)

	_update_cast(delta, target, distance)


## Conta o cooldown e, quando zera, lança um feitiço. Se a Caipora estiver perto
## (< CLOSE_PREF_DISTANCE), prefere os ESPINHOS para empurrá-la para longe; caso
## contrário, alterna entre os 3 na rotação. Re-sorteia o intervalo em seguida.
func _update_cast(delta: float, target: Node, distance: float) -> void:
	_cast_cooldown -= delta
	if _cast_cooldown > 0.0:
		return
	if distance < CLOSE_PREF_DISTANCE:
		_cast_spell(SPIKES_INDEX, target)
		# Ritmo bem mais lento quando perto (não spamma espinhos).
		_cast_cooldown = randf_range(CLOSE_CAST_INTERVAL_MIN, CLOSE_CAST_INTERVAL_MAX)
	else:
		_cast_spell(_spell_index, target)
		_spell_index = (_spell_index + 1) % SPELL_SCENES.size()
		_cast_cooldown = randf_range(CAST_INTERVAL_MIN, CAST_INTERVAL_MAX)


## Instancia o feitiço de índice `index` e chama cast(origin, target) conforme
## o contrato.
func _cast_spell(index: int, target: Node) -> void:
	var spell := SPELL_SCENES[index].instantiate()
	# Adiciona no mesmo pai da Cuca (o World y-sortado) para o feitiço também
	# entrar na ordenação por profundidade. Fallback: a cena atual.
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene
	host.add_child(spell)
	var origin: Vector2 = global_position + Vector2(50.0 * _facing, -40.0)
	if spell.has_method("cast"):
		spell.cast(origin, target)
	_cast_gesture()
	# Zumbido mágico da conjuração, grave (bruxa).
	Sfx.play_at(global_position, "cast", -6.0, 0.7, 0.06)
	# Espinhos e bolinha travam a Cuca por um instante (janela da animação).
	if index == SPIKES_INDEX or index == HOMING_INDEX:
		_cast_freeze = CAST_FREEZE_TIME


## Na distância confortável a Cuca fica PARADA encarando o player. A cada
## IDLE_MIN..IDLE_MAX segundos ela dá um passinho curto para um lado sorteado
## (DRIFT_MIN..DRIFT_MAX de duração) — só para não ficar estática demais.
func _update_drift(delta: float, dir: Vector2) -> void:
	if _drift_timer > 0.0:
		_drift_timer -= delta
		var perp := Vector2(-dir.y, dir.x)
		velocity = perp * STRAFE_SPEED * float(_strafe_dir)
		return

	velocity = Vector2.ZERO
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		# Hora de um passinho: sorteia lado, duração e a próxima espera.
		_strafe_dir = 1 if randf() < 0.5 else -1
		_drift_timer = randf_range(DRIFT_MIN, DRIFT_MAX)
		_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)


## A Cuca esbarrou em algo SÓLIDO do cenário (parede da borda ou tronco de
## árvore) no último move_and_slide? Filtramos por StaticBody2D de propósito:
## encostar na Caipora (que é CharacterBody2D) também conta como colisão, mas
## isso é o agarrão, não estar encurralada.
func _blocked_by_scenery() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody2D:
			return true
	return false


## Agarrão: a Cuca é muito mais forte — arremessa a Caipora para bem longe
## (na direção oposta a ela) e causa dano. Punição por ficar grudado nela.
func _throw_player(target: Node, dir: Vector2) -> void:
	if target.has_method("apply_knockback"):
		target.apply_knockback(dir * THROW_FORCE)
	if target.has_method("take_damage"):
		target.take_damage(THROW_DAMAGE)
	_cast_gesture()
	Sfx.play_at(global_position, "throw", 0.0, 0.8, 0.05)


## Deixa uma pegada a cada STEP_DISTANCE percorridos, alternando os pés.
func _update_footprints(delta: float, moving: bool, move_dir: Vector2) -> void:
	if not moving:
		_step_accum = STEP_DISTANCE * 0.6
		return
	_step_accum += velocity.length() * delta
	if _step_accum < STEP_DISTANCE:
		return
	_step_accum = 0.0
	_step_side = -_step_side
	Footprints.drop(self, move_dir, _step_side, FOOT_SIZE, FOOT_COLOR)
	# Passo grave e mais alto: ela é enorme.
	Sfx.play_at(global_position, "footstep", -5.0, 0.6, 0.08)


## Escolhe a animação de caminhada pela direção informada (espelhando para as
## direções oeste) e ancora o sprite pelos pés. Parada, fica no primeiro quadro.
func _update_sprite(facing: Vector2, moving: bool) -> void:
	_last_facing = facing
	var info := WalkSprites.dir_for(facing)
	var key: String = info[0]
	_sprite.flip_h = info[1]

	var set_dict: Dictionary = WALK if moving else IDLE
	var anim: String = key if moving else "idle_" + key
	if anim != _cur_anim:
		_cur_anim = anim
		var d: Dictionary = set_dict[key]
		# Sobe o sprite para os pés caírem na origem do nó (usada pelo Y-sort).
		_sprite.offset.y = float(d["cell_h"]) * 0.5 - float(d["feet"])
		_sprite.scale = Vector2(float(d["scale"]), float(d["scale"]))
		_sprite.animation = anim

	if moving:
		if not _sprite.is_playing():
			_sprite.play(anim)
	elif _sprite.is_playing():
		_sprite.stop()


## Pequeno "impulso" de conjuração: uma esticada rápida no visual, lida como
## esforço ao lançar/arremessar.
## Anima só scale.y para não brigar com o scale.x usado no espelhamento (facing).
func _cast_gesture() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "scale:y", 1.16, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale:y", 1.0, 0.16).set_ease(Tween.EASE_IN)


func take_damage(amount: int) -> void:
	if _dead:
		return
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	_flash_damage()
	Sfx.play_at(global_position, "hurt", -2.0, 0.75, 0.08)
	if health <= 0:
		_die()


## Pisca em vermelho ao tomar dano: acende o parâmetro `flash` do shader e faz
## ele voltar a 0 com um tween rápido.
func _flash_damage() -> void:
	var mat := _visual.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_property(mat, "shader_parameter/flash", 0.0, 0.22)


func _die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	# Encerra a caminhada e fica parada na pose da direção atual.
	_update_sprite(_last_facing, false)
	died.emit()
