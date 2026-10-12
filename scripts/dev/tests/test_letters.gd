extends "res://scripts/dev/tests/test_suite.gd"
## Cartas: leer, retener, entregar y desviar. Retener el pedido quita el viaje
## de Lina a las 15:00. Las cartas vuelven a la bolsa al reiniciar el bucle.

const LETTER: String = "orden_lina"


func test_read_gives_secret_and_keeps_letter() -> bool:
	var state := new_state()
	act(state, "leer", "mercado", "", LETTER)
	check(state.letter_state(LETTER)["read"] and state.letter_state(LETTER)["state"] == "bolsa", "leer no gasta la carta")
	check(state.has_clue("secreto_pedido_tachado"), "leer el pedido da el secreto de la línea tachada")
	return true


func test_retained_letter_removes_linas_trip() -> bool:
	var state := new_state()
	act(state, "retener", "mercado", "", LETTER)
	check(state.letter_state(LETTER)["state"] == "retenida", "la carta queda retenida")
	routine_until(state, GameData.parse_time("15:00"))
	check(state.position_of("lina") == "mercado", "sin el pedido, Lina no va a la relojería a las 15:00")
	routine_until(state, GameData.parse_time("16:00"))
	check(not state.sim.s["flags"].has("lina_perdida"), "Lina se salva")
	return true


func test_delivered_letter_sends_lina() -> bool:
	var state := new_state()
	act(state, "entregar", "mercado", "lina", LETTER)
	check(state.letter_state(LETTER)["state"] == "entregada", "la carta queda entregada")
	routine_until(state, GameData.parse_time("15:00"))
	check(state.position_of("lina") == "relojeria", "con el pedido, Lina lleva el pan a la relojería")
	routine_until(state, GameData.parse_time("16:00"))
	check(state.sim.s["flags"].has("lina_perdida"), "sin nadie que la sostenga, la fisura se lleva a Lina")
	return true


func test_diverted_letter_goes_back_to_ruth() -> bool:
	var state := new_state()
	act(state, "desviar", "relojeria", "ruth", LETTER)
	check(state.letter_state(LETTER)["state"] == "desviada", "la carta queda desviada")
	check(state.has_clue("hecho_ruth_otra_vez"), "Ruth recibe su propio pedido y murmura «otra vez»")
	routine_until(state, GameData.parse_time("15:00"))
	check(state.position_of("lina") != "relojeria", "con el pedido desviado, Lina no va al taller")
	return true


func test_letters_reset_at_loop_end() -> bool:
	var state := new_state()
	act(state, "leer", "mercado", "", LETTER)
	act(state, "retener", "mercado", "", LETTER)
	routine_until(state, state.data.day_end)
	state.start_next_loop()
	check(state.letter_state(LETTER) == {"state": "bolsa", "read": false}, "al reiniciar, la carta vuelve sin abrir a la bolsa")
	check(state.has_clue("secreto_pedido_tachado"), "lo leído sigue en el Cuaderno")
	return true
