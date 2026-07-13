extends Node2D
## Cena principal do duelo final (fase final de "Encantados").
## Instancia o cenário (floresta), a Caipora (player), a Cuca (chefe) e o HUD,
## liga as barras de vida e conduz a partida:
##   1. Fala de abertura (as duas trocam farpas) — a luta fica congelada.
##   2. O duelo.
##   3. Quando alguém morre, a fala de encerramento (uma para cada final) e só
##      então a tela de fim.
## O resultado vai em Boot.last_result porque change_scene não passa argumentos.

const END_SCREEN: String = "res://scenes/end/end_screen.tscn"
const DEATH_PAUSE: float = 1.0 # respiro após a morte, antes da fala final

const COR_CUCA := Color(0.55, 0.85, 0.35)
const COR_CAIPORA := Color(0.95, 0.55, 0.3)

## Retratos das falas: recortamos rosto + peito das poses PARADAS viradas para o
## sul (as mesmas do jogo, já sem o fundo rosa). Braços e pernas ficam de fora —
## a região abaixo do peito é simplesmente cortada.
const POSE_CUCA: Texture2D = preload("res://actors/cuca/Idle/sul.png")
const POSE_CAIPORA: Texture2D = preload("res://actors/caipora/Idle/sul.png")
const RECORTE_CUCA := Rect2(200, 60, 640, 610)
const RECORTE_CAIPORA := Rect2(300, 170, 550, 500)

## Antes da luta: a Cuca provoca, a Caipora responde.
const FALAS_INICIO: Array = [
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Sente esse cheiro, menina? É o da mata morrendo. Demorei anos pra deixar tudo assim tão bonito."},
	{"speaker": "Caipora", "color": COR_CAIPORA,
		"text": "Cada bicho e cada folha daqui estão sob a minha guarda, bruxa. Você foi longe demais."},
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Faz mil anos que eu não durmo, Caipora... e você acha que vai me pôr pra dormir hoje?"},
	{"speaker": "Caipora", "color": COR_CAIPORA,
		"text": "Não vim te pôr pra dormir. Vim te tirar da minha floresta."},
]

## Final bom: a Caipora venceu.
const FALAS_VITORIA: Array = [
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Impossível... uma menina do mato... me derrubando..."},
	{"speaker": "Caipora", "color": COR_CAIPORA,
		"text": "Não fui eu, Cuca. Foi a mata inteira. Você só nunca soube escutar."},
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Eu volto... eu sempre volto... e a floresta vai estar me esperando..."},
	{"speaker": "Caipora", "color": COR_CAIPORA,
		"text": "E eu também vou."},
]

## Final ruim: a Cuca venceu.
const FALAS_DERROTA: Array = [
	{"speaker": "Caipora", "color": COR_CAIPORA,
		"text": "A mata... me perdoa... eu não consegui..."},
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Shhh. Dorme, guardiã. Faz mil anos que eu não durmo — pode dormir por nós duas."},
	{"speaker": "Cuca", "color": COR_CUCA,
		"text": "Agora a floresta é minha. E eu vou cuidar dela do meu jeitinho."},
]

@onready var _hud: CanvasLayer = $BattleHUD
@onready var _dialogue: CanvasLayer = $DialogueBox
@onready var _caipora: CharacterBody2D = $World/Caipora
@onready var _cuca: CharacterBody2D = $World/Cuca

var _finished: bool = false


func _ready() -> void:
	_hud.bind_player(_caipora)
	_hud.bind_boss(_cuca)

	_cuca.died.connect(_on_cuca_died)
	_caipora.died.connect(_on_caipora_died)

	_dialogue.portraits = {
		"Cuca": _retrato(POSE_CUCA, RECORTE_CUCA),
		"Caipora": _retrato(POSE_CAIPORA, RECORTE_CAIPORA),
	}

	# Abertura: congela as duas, troca as falas e só então libera a luta.
	_set_actors_active(false)
	_dialogue.play(FALAS_INICIO)
	await _dialogue.finished
	_set_actors_active(true)


func _on_cuca_died() -> void:
	_finish("victory")


func _on_caipora_died() -> void:
	_finish("defeat")


## Registra o resultado, dá um respiro, mostra a fala do final correspondente e
## então vai para a tela de fim. Protegido para rodar só uma vez.
func _finish(result: String) -> void:
	if _finished:
		return
	_finished = true
	Boot.last_result = result

	_set_actors_active(false)
	await get_tree().create_timer(DEATH_PAUSE).timeout
	_dialogue.play(FALAS_VITORIA if result == "victory" else FALAS_DERROTA)
	await _dialogue.finished
	get_tree().change_scene_to_file(END_SCREEN)


## Monta o retrato recortando uma região da pose. AtlasTexture aponta para a
## imagem original (não duplica nada em disco nem na memória).
func _retrato(pose: Texture2D, recorte: Rect2) -> AtlasTexture:
	var face := AtlasTexture.new()
	face.atlas = pose
	face.region = recorte
	return face


## Liga/desliga o processamento das duas lutadoras — durante as falas ninguém
## anda, ataca ou conjura (o input e a IA ficam parados).
func _set_actors_active(active: bool) -> void:
	for actor in [_caipora, _cuca]:
		if is_instance_valid(actor):
			actor.set_physics_process(active)
