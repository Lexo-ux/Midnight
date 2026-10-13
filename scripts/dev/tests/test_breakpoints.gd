extends "res://scripts/dev/tests/test_suite.gd"
## Momentos de quiebre: la máquina de estados de sostener (scripts/sustain_controller.gd)
## con un reloj inyectado, en los tres modos, con pausa; y en la partida, que la
## simulación solo recibe la decisión: «soltó» deja el mismo mundo que esperar
## allí, «sostuvo» hace la interacción, y la decisión queda en la ruta.

const SustainController := preload("res://scripts/sustain_controller.gd")
const BUEN_DIA_QUIEBRES: String = "res://data/dev/walkthrough_un_buen_dia_quiebres.json"

## Reloj falso: milisegundos que el test mueve a mano.
var _now: int = 0


func test_hold_mode() -> bool:
	var sustain := _controller("hold", 20000)
	sustain.tap()
	check(sustain.state == "idle", "en «mantener», tocar no empieza")
	sustain.press()
	_now += 5000
	sustain.update()
	check(sustain.state == "holding" and is_equal_approx(sustain.progress(), 0.25), "a los 5 s de 20 va por la cuarta parte")
	sustain.release()
	check(sustain.state == "done" and sustain.result == "soltó", "soltar antes de llenar es soltar")
	sustain = _controller("hold", 20000)
	sustain.press()
	_now += 20000
	sustain.update()
	check(sustain.result == "sostuvo", "mantener hasta llenar es sostener")
	sustain.release()
	check(sustain.result == "sostuvo", "soltar después no cambia nada")
	return true


func test_toggle_mode() -> bool:
	var sustain := _controller("toggle", 40000)
	sustain.press()
	check(sustain.state == "idle", "en «tocar», pulsar no empieza (se empieza tocando)")
	sustain.tap()
	_now += 10000
	sustain.tap()
	check(sustain.result == "soltó", "tocar otra vez antes de llenar es soltar")
	sustain = _controller("toggle", 40000)
	sustain.tap()
	_now += 40000
	sustain.update()
	check(sustain.result == "sostuvo", "esperar a que se llene es sostener, sin mantener el dedo")
	return true


func test_no_time_mode() -> bool:
	var sustain := _controller("hold", 0)
	check(not sustain.is_timed() and sustain.progress() == 0.0, "sin tiempo no hay anillo que llenar")
	sustain.press()
	sustain.tap()
	_now += 100000
	sustain.update()
	check(sustain.state == "idle", "sin tiempo, ni pulsar ni esperar deciden nada")
	sustain.confirm()
	check(sustain.result == "sostuvo", "sin tiempo se decide con calma: sostener")
	sustain = _controller("toggle", 0)
	sustain.let_go()
	check(sustain.result == "soltó", "o soltar")
	return true


func test_pause_never_counts_as_letting_go() -> bool:
	var sustain := _controller("hold", 20000)
	sustain.press()
	_now += 5000
	sustain.pause()
	_now += 600000
	sustain.update()
	check(sustain.state == "paused" and is_equal_approx(sustain.progress(), 0.25), "en pausa el tiempo no corre")
	sustain.resume()
	check(sustain.state == "resuming", "al volver espera otro toque")
	_now += 60000
	sustain.update()
	check(sustain.result == "" and is_equal_approx(sustain.progress(), 0.25), "volver no es ni soltar ni seguir")
	sustain.press()
	_now += 15000
	sustain.update()
	check(sustain.result == "sostuvo", "se sigue desde donde iba")
	sustain = _controller("toggle", 20000)
	sustain.pause()
	sustain.resume()
	check(sustain.state == "idle", "una pausa antes de empezar deja todo igual")
	sustain.let_go()
	check(sustain.result == "soltó", "soltar a propósito vale en cualquier modo")
	return true


func test_letting_go_is_the_same_world_as_waiting() -> bool:
	var released := _until_breakpoint()
	var waited := _until_breakpoint()
	var action := _breakpoint_action(released, "tirar_de_lina")
	if not check(not action.is_empty(), "a las 15:00 Sazil tiene el quiebre de Lina"):
		return true
	check(released.resolve_breakpoint(action, "soltó"), "soltar es una decisión válida")
	check(waited.perform({"verb": "esperar", "place": "relojeria", "target": "", "id": ""}), "esperar allí")
	check(world_without_view(released) == world_without_view(waited), "soltar deja el mismo mundo que esperar allí")
	check(released.current_time() == GameData.parse_time("15:30"), "el quiebre cuesta media hora")
	var command: Dictionary = released.sim.s["route"][-1]["command"]
	check(command.get("decision", "") == "soltó", "la ruta guarda la decisión, no el tiempo: %s" % [command])
	return true


func test_sustaining_applies_the_interaction() -> bool:
	var state := _until_breakpoint()
	var action := _breakpoint_action(state, "tirar_de_lina")
	check(state.resolve_breakpoint(action, "sostuvo"), "sostener es una decisión válida")
	check(state.sim.s["flags"].has("lina_salvada"), "sostener a Lina la salva")
	var bad := _until_breakpoint()
	check(not bad.resolve_breakpoint(action, "a medias"), "una decisión desconocida no vale")
	check(not bad.perform({"verb": "esperar", "place": "relojeria", "target": "", "id": "", "decision": "sostuvo"}),
			"una decisión solo vale en un quiebre")
	return true


func test_breakpoint_decisions_replay() -> bool:
	var state := new_state()
	play_walkthrough(state, read_json(BUEN_DIA_QUIEBRES))
	check(state.ending_id() == "un_buen_dia", "el recorrido con quiebres llega a «Un buen día»")
	var at_end := world_without_view(state)
	check(state.start_next_loop() and state.replay_route(state.data.day_end), "se repite la ruta entera")
	check(world_without_view(state) == at_end, "repetir la ruta repite las conversaciones y las decisiones de los quiebres")
	return true


func test_breakpoint_settings() -> bool:
	var state := new_state()
	check(state.settings["breakpoint_mode"] == "hold" and state.settings["breakpoint_time"] == "20"
			and not state.settings["breakpoint_chosen"], "por defecto: mantener, 20 s, sin elegir aún")
	state.set_breakpoint_mode("toggle")
	state.set_breakpoint_time("none")
	state.set_breakpoint_mode("deslizar")
	state.set_breakpoint_time("5")
	check(state.settings["breakpoint_mode"] == "toggle" and state.settings["breakpoint_time"] == "none",
			"se guardan los modos válidos y se ignoran los demás")
	return true


func _controller(mode: String, milliseconds: int) -> SustainController:
	_now = 0
	return SustainController.new(mode, milliseconds, func() -> int: return _now)


## Sazil espera en la relojería, escucha a Lina y llega a las 15:00 (el quiebre de Lina).
func _until_breakpoint() -> GameStateScript:
	var state := new_state()
	var steps: Array = read_json(BUEN_DIA_QUIEBRES)["steps"]
	play_walkthrough(state, {"steps": steps.slice(0, 2)})
	return state


func _breakpoint_action(state: GameStateScript, id: String) -> Dictionary:
	for action: Dictionary in state.breakpoint_actions():
		if action["id"] == id:
			return action
	return {}
