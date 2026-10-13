extends Control
## Conversación con cartas (scripts/conversation.gd) a pantalla completa, sin
## cambiar de escena. Se juega aquí carta a carta sin tocar la partida; al
## terminar (o al salir habiendo jugado cartas) cuenta como una acción «hablar»
## de 30 minutos con las cartas jugadas (GameState.commit_conversation()).
## Irse sin jugar ninguna carta no gasta tiempo.
##
## Arriba: la cara según el Velo, la Confianza (puntos), los turnos y las manos
## (alcanzan al jugar, esperan). Luego, fichas de los muros y puertas (por
## forma: ladrillos, ladrillos partidos, arco cerrado, arco abierto; «?» sin
## descubrir), lo último que se ha dicho y, abajo del todo, la mano de cartas en
## 2 columnas (icono de su tipo, título y texto). Con texto Normal todo cabe sin
## desplazar; con texto grande se desplaza esa parte. Abajo, siempre a mano:
## Terminar, el resultado o la confirmación de salir.
## Ganar a la fuerza (Akba) hace temblar la hoja y lo avisa en rosa.

const GameData := preload("res://scripts/game_data.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const CardButton := preload("res://scripts/card_button.gd")
const ConvIcon := preload("res://scripts/conv_icon.gd")
const CHIP_ICON: float = 48.0
## Lo que tarda en irse la carta jugada antes de repartir la mano otra vez.
const DISCARD_SECONDS: float = 0.12
## Frases que se ven a la vez (las últimas).
const VISIBLE_LINES: int = 2
const REACH_SECONDS: float = 0.2

signal closed

@onready var _sheet: PanelContainer = %Sheet
@onready var _portrait: Control = %Portrait
@onready var _name: Label = %Name
@onready var _velo: Label = %Velo
@onready var _pips: Control = %Pips
@onready var _counters: Label = %Counters
@onready var _elements: HFlowContainer = %Elements
@onready var _body: ScrollContainer = %Body
@onready var _lines: VBoxContainer = %Lines
@onready var _hands: Control = %Hands
@onready var _cards: GridContainer = %Cards
@onready var _result: VBoxContainer = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_text: Label = %ResultText
@onready var _result_banner: PanelContainer = %ResultBanner
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
## Cartas en pantalla: id -> botón (para animar la que se juega).
var _card_buttons: Dictionary = {}
## La mano que se ve (para repartir con animación solo cuando cambia).
var _hand_key: String = ""
## Una carta se está yendo: no se puede jugar otra hasta repartir.
var _busy: bool = false


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
	_hand_key = ""
	_busy = false
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


## Una ficha por muro o puerta: icono por forma y su nombre (o «?»).
func _render_elements() -> void:
	var data := GameState.data
	_clear(_elements)
	for element: Dictionary in data.conversations[conv["conversation"]]["elements"]:
		var id: String = element["id"]
		var wall: bool = element["kind"] == "wall"
		var known: bool = conv["revealed"].has(id) or conv["broken"].has(id)
		var text: String = "%s · %s" % [data.text("conv_muro" if wall else "conv_puerta"),
				data.clues[element["clue"]]["title"] if known else "?"]
		var icon := "wall" if wall else "door"
		if conv["broken"].has(id):
			text += " · " + data.text("conv_roto")
			icon = "wall_broken"
		elif conv["result"] == "win" and conv["door"] == id:
			text += " · " + data.text("conv_abierta")
			icon = "door_open"
		if not known:
			icon = "unknown"
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"ChipKnown" if known else &"ChipUnknown"
		var row := HBoxContainer.new()
		row.theme_type_variation = &"HBoxTight"
		chip.add_child(row)
		var picture := TextureRect.new()
		picture.texture = ConvIcon.make(icon, CHIP_ICON)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
		var label := Label.new()
		label.text = text
		label.theme_type_variation = &"PaperLabel" if known else &"PaperMuted"
		row.add_child(label)
		_elements.add_child(chip)


## El texto de la ficha de un muro o puerta (para los tests).
func element_text(index: int) -> String:
	var chip := _elements.get_child(index)
	for label: Node in chip.find_children("*", "Label", true, false):
		return (label as Label).text
	return ""


func _render_lines() -> void:
	_clear(_lines)
	var lines: Array = conv["lines"]
	for i: int in range(maxi(0, lines.size() - VISIBLE_LINES), lines.size()):
		var label := Label.new()
		label.text = "«%s»" % lines[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"PaperLabel" if i == lines.size() - 1 else &"PaperMuted"
		_lines.add_child(label)


## La mano: una carta por botón. Al cambiar la mano, las cartas se reparten
## con un fundido escalonado (nada con movimiento reducido).
func _render_cards(enabled: bool) -> void:
	var data := GameState.data
	_clear(_cards)
	_card_buttons.clear()
	_busy = false
	_cards.visible = enabled
	if not enabled:
		return
	var key := ",".join(PackedStringArray(conv["hand"]))
	var deal := key != _hand_key
	_hand_key = key
	var reduced: bool = GameState.settings["reduced_motion"]
	for i: int in conv["hand"].size():
		var card: String = conv["hand"][i]
		var type := GameState.Conversation.card_type(data, card)
		var button: Button = CardButton.new()
		button.theme_type_variation = &"CardKnowledge" if type == "conocimiento" else &"Card"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var texts := _card_texts(data, card)
		button.setup(type, texts[0], texts[1])
		button.pressed.connect(_play.bind(card))
		_cards.add_child(button)
		_card_buttons[card] = button
		if deal:
			UiMotion.pop_in(button, i, reduced)


## [título, texto] de una carta.
func _card_texts(data: GameData, card: String) -> PackedStringArray:
	var type := GameState.Conversation.card_type(data, card)
	if type == "conocimiento":
		var clue := GameState.Conversation.knowledge_clue(card)
		return PackedStringArray([data.cards["conocimiento"]["title"], data.clues[clue]["title"]])
	return PackedStringArray([data.cards[card]["title"], data.cards[card]["text"]])


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
	_result_banner.visible = marked
	_result_text.visible = marked
	_result_text.text = data.text("conv_marcada").format({"nombre": data.people[conv["person"]]["name"]}) if marked else ""
	_continue.text = data.text("conv_continuar")


func _play(card: String) -> void:
	if _busy:
		return
	var revealed_before: int = conv["revealed"].size() + conv["broken"].size()
	var played: Button = _card_buttons.get(card)
	if not GameState.play_card(conv, card):
		return
	AudioDirector.play_event("card_play")
	Haptics.play("card")
	if conv["revealed"].size() + conv["broken"].size() > revealed_before:
		AudioDirector.play_event("card_flip")
	var reduced: bool = GameState.settings["reduced_motion"]
	if conv["result"] == "win":
		AudioDirector.play_event("door_open")
		Haptics.play("success")
		if conv["forced"]:
			UiMotion.shake(_sheet, reduced)
	_show_hands("reach", REACH_SECONDS)
	if reduced or played == null or not played.is_inside_tree():
		_render()
		return
	# La carta jugada sube y se va; luego se reparte la mano nueva.
	_busy = true
	var tween := create_tween().set_parallel()
	tween.tween_property(played, "modulate:a", 0.0, DISCARD_SECONDS)
	tween.tween_property(played, "position:y", played.position.y - 40.0, DISCARD_SECONDS)
	tween.chain().tween_callback(func() -> void:
		_busy = false
		_render())


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
