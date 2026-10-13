extends Control
## Conversación con cartas (scripts/conversation.gd) a pantalla completa, sin
## cambiar de escena. Se juega aquí carta a carta sin tocar la partida; al
## terminar (o al salir habiendo jugado cartas) cuenta como una acción «hablar»
## de 30 minutos con las cartas jugadas (GameState.commit_conversation()).
## Irse sin jugar ninguna carta no gasta tiempo.
##
## Arriba: la cara según el Velo, la Confianza (puntos) y los turnos. Luego,
## en una zona que se desplaza si no cabe (texto grande): los muros y puertas
## (los descubiertos con su nombre), lo último que se ha dicho, las manos
## (alcanzan al jugar, esperan) y la mano de cartas en 2 columnas. Abajo, siempre
## a mano: Terminar, el resultado o la confirmación de salir.

const GameData := preload("res://scripts/game_data.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
## Frases que se ven a la vez (las últimas).
const VISIBLE_LINES: int = 2
const REACH_SECONDS: float = 0.2

signal closed

@onready var _portrait: Control = %Portrait
@onready var _name: Label = %Name
@onready var _velo: Label = %Velo
@onready var _pips: Control = %Pips
@onready var _counters: Label = %Counters
@onready var _elements: VBoxContainer = %Elements
@onready var _body: ScrollContainer = %Body
@onready var _lines: VBoxContainer = %Lines
@onready var _hands: Control = %Hands
@onready var _cards: GridContainer = %Cards
@onready var _result: VBoxContainer = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _continue: Button = %Continue
@onready var _confirm: VBoxContainer = %Confirm
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo
@onready var _finish: Button = %Finish

var _art: ArtLibrary
## La conversación en juego ({} si no hay).
var conv: Dictionary = {}
var _hands_tween: Tween


func _ready() -> void:
	_finish.pressed.connect(_on_finish)
	_continue.pressed.connect(_commit_and_close)
	_confirm_yes.pressed.connect(func() -> void:
		GameState.finish_conversation(conv)
		_commit_and_close())
	_confirm_no.pressed.connect(func() -> void:
		_confirm.hide()
		_render())


func bind(art: ArtLibrary) -> void:
	_art = art
	_hands.bind(art)


## Empieza una conversación con `person` (el protagonista activo habla).
func open(person: String) -> void:
	conv = GameState.start_conversation(person)
	_confirm.hide()
	_body.scroll_vertical = 0
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	_show_hands("wait", 0.0)
	_render()


func is_open() -> bool:
	return visible and not conv.is_empty()


## Botón «atrás» de Android: confirma antes de dejar una conversación con cartas jugadas.
func back() -> void:
	if conv.is_empty():
		hide()
	elif conv["result"] != "":
		_commit_and_close()
	elif conv["played"].is_empty():
		_close()
	elif _confirm.visible:
		_confirm.hide()
		_render()
	else:
		_confirm.show()
		_render()


func _render() -> void:
	if conv.is_empty():
		return
	var data := GameState.data
	var person: String = conv["person"]
	var level := GameState.velo_level(person)
	_portrait.show_person(data, _art, person, level)
	_name.text = data.people[person]["name"]
	_velo.text = data.text("velo_%d" % mini(level, 3))
	_pips.set_value(conv["confianza"], data.card_rules["confianza_max"])
	_counters.text = "%s · %s" % [data.text("conv_confianza").format({"n": conv["confianza"], "max": data.card_rules["confianza_max"]}),
			data.text("conv_turnos").format({"n": conv["turns"]})]
	_render_elements()
	_render_lines()
	var done: bool = conv["result"] != ""
	var confirming := _confirm.visible
	_render_cards(not done and not confirming)
	_result.visible = done
	_finish.visible = not done and not confirming
	_finish.text = data.text("conv_terminar" if not conv["played"].is_empty() else "conv_irse")
	_confirm_text.text = data.text("conv_confirmar_salir")
	_confirm_yes.text = data.text("conv_salir_si")
	_confirm_no.text = data.text("conv_salir_no")
	if done:
		_render_result()


func _render_elements() -> void:
	var data := GameState.data
	_clear(_elements)
	for element: Dictionary in data.conversations[conv["conversation"]]["elements"]:
		var id: String = element["id"]
		var known: bool = conv["revealed"].has(id) or conv["broken"].has(id)
		var text: String = "%s · %s" % [data.text("conv_muro" if element["kind"] == "wall" else "conv_puerta"),
				data.clues[element["clue"]]["title"] if known else "?"]
		if conv["broken"].has(id):
			text += " · " + data.text("conv_roto")
		elif conv["result"] == "win" and conv["door"] == id:
			text += " · " + data.text("conv_abierta")
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"PaperLabel" if known else &"PaperMuted"
		_elements.add_child(label)


func _render_lines() -> void:
	_clear(_lines)
	var lines: Array = conv["lines"]
	for i: int in range(maxi(0, lines.size() - VISIBLE_LINES), lines.size()):
		var label := Label.new()
		label.text = "«%s»" % lines[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"PaperLabel" if i == lines.size() - 1 else &"PaperMuted"
		_lines.add_child(label)


func _render_cards(enabled: bool) -> void:
	var data := GameState.data
	_clear(_cards)
	_cards.visible = enabled
	if not enabled:
		return
	for card: String in conv["hand"]:
		var button := Button.new()
		button.text = _card_text(data, card)
		UiStyle.touch(button, &"CardKnowledge" if GameState.Conversation.card_type(data, card) == "conocimiento" else &"Card")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_play.bind(card))
		_cards.add_child(button)


func _card_text(data: GameData, card: String) -> String:
	var type := GameState.Conversation.card_type(data, card)
	if type == "conocimiento":
		var clue := GameState.Conversation.knowledge_clue(card)
		return "%s\n%s" % [data.cards["conocimiento"]["title"], data.clues[clue]["title"]]
	return "%s\n%s" % [data.cards[card]["title"], data.cards[card]["text"]]


func _render_result() -> void:
	var data := GameState.data
	match conv["result"]:
		"win":
			_result_title.text = data.text("conv_ganada")
		"closed":
			_result_title.text = data.text("conv_cerrada")
		_:
			_result_title.text = data.text("conv_neutral")
	var marked: bool = conv["result"] == "win" and conv["forced"]
	_result_text.visible = marked
	_result_text.text = data.text("conv_marcada").format({"nombre": data.people[conv["person"]]["name"]}) if marked else ""
	_continue.text = data.text("conv_continuar")


func _play(card: String) -> void:
	var revealed_before: int = conv["revealed"].size() + conv["broken"].size()
	if not GameState.play_card(conv, card):
		return
	AudioDirector.play_event("card_play")
	Haptics.play("card")
	if conv["revealed"].size() + conv["broken"].size() > revealed_before:
		AudioDirector.play_event("card_flip")
	if conv["result"] == "win":
		AudioDirector.play_event("door_open")
		Haptics.play("success")
	_show_hands("reach", REACH_SECONDS)
	_render()


func _on_finish() -> void:
	if conv["played"].is_empty():
		_close()
		return
	GameState.finish_conversation(conv)
	_render()


func _commit_and_close() -> void:
	var finished := conv
	_close()
	GameState.commit_conversation(finished)


func _close() -> void:
	conv = {}
	hide()
	closed.emit()


## Manos que alcanzan al jugar una carta y vuelven a esperar.
func _show_hands(state: String, seconds: float) -> void:
	if _hands_tween != null and _hands_tween.is_valid():
		_hands_tween.kill()
	var reduced: bool = GameState.settings["reduced_motion"]
	var actor: String = conv.get("actor", GameState.active_actor())
	_hands.show_hands(actor, state, 0.0 if reduced else seconds)
	if state == "reach":
		_hands_tween = create_tween()
		_hands_tween.tween_interval(0.6)
		_hands_tween.tween_callback(_show_hands.bind("wait", 0.0 if reduced else seconds))


## Quita los hijos ya (no al final del fotograma), para redibujar sin restos.
func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
