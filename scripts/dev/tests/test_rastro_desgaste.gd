extends "res://scripts/dev/tests/test_suite.gd"
## Rastro: bajo, Marcos patrulla la plaza a las 21:00; medio (3), adelanta la
## patrulla a las 19:00; alto (6, el máximo), va directo a donde esté Akba.
## Desgaste: forzar de día cuesta el doble; lleno, Akba pierde el resto de la hora.


func test_low_rastro_patrol_at_nine() -> bool:
	var state := new_state()
	routine_until(state, GameData.parse_time("19:00"))
	check(state.position_of("marcos") == "posada", "con Rastro 0, Marcos sigue en la posada a las 19:00")
	routine_until(state, GameData.parse_time("21:00"))
	check(state.position_of("marcos") == "plaza", "con Rastro 0, Marcos llega a la plaza a las 21:00")
	check(state.sim.s["flags"].has("marcos_va_por_beto"), "a las 21:00 va por Beto")
	return true


func test_medium_rastro_moves_patrol_to_seven() -> bool:
	var state := new_state()
	routine_until(state, GameData.parse_time("18:30"))
	patch_loop(state, {"rastro": state.data.threshold("medio")})
	routine_until(state, GameData.parse_time("19:00"))
	check(state.position_of("marcos") == "plaza", "con Rastro medio, Marcos llega a la plaza a las 19:00")
	check(state.sim.s["flags"].get("marcos_va_por_beto", -1) == GameData.parse_time("19:00"),
			"con Rastro medio, la patrulla va por Beto a las 19:00")
	routine_until(state, GameData.parse_time("19:30"))
	check(state.sim.s["flags"].has("beto_detenido") and not state.sim.s["flags"].has("tun_herido"),
			"a las 19:30 se llevan a Beto; Tun todavía no ha llegado a la plaza")
	return true


func test_high_rastro_sends_marcos_to_akba() -> bool:
	var state := new_state()
	state.switch_to("akba")
	act(state, "esperar", "mercado")
	patch_loop(state, {"rastro": state.data.rastro_max})
	act(state, "esperar", "mercado")
	check(state.position_of("marcos") == state.position_of("akba"), "con Rastro alto, Marcos va adonde está Akba")
	check(state.is_disabled("akba"), "Marcos atrapa a Akba")
	check(state.get_actions().is_empty() and state.can_switch(), "Akba atrapado no puede actuar, pero se puede cambiar a Sazil")
	state.switch_to("sazil")
	act(state, "esperar", "plaza")
	check(state.position_of("akba") == "cuartel", "a Akba se lo llevan al cuartel")
	return true


func test_forcing_by_day_costs_double_and_full_desgaste_costs_the_hour() -> bool:
	var state := new_state()
	state.switch_to("akba")
	act(state, "observar", "relojeria")
	check(state.has_clue("hecho_grieta_dormida"), "de día, en un interior, Akba ve la grieta dormida")
	act(state, "interactuar", "relojeria", "", "sellar_patio_dia")
	check(state.desgaste() == 2, "sellar de día cuesta el doble de Desgaste (2), no 1 (llevaba %d)" % state.desgaste())
	check(state.rastro() == 1, "sellar sube el Rastro")
	routine_until(state, GameData.parse_time("16:00"))
	act(state, "interactuar", "relojeria", "", "forzar_puerta_relojeria")
	check(state.desgaste() == state.data.desgaste_max, "otra vez de día: el Desgaste se llena")
	check(state.current_time() == GameData.parse_time("16:30"), "son las 16:30")
	var actions := state.get_actions()
	check(actions.size() == 1 and actions[0]["verb"] == "esperar", "con el Desgaste lleno, Akba solo puede esperar el resto de la hora")
	act(state, "esperar", actions[0]["place"])
	check(state.current_time() == GameData.parse_time("17:00") and state.get_actions().size() > 1,
			"a la hora siguiente Akba vuelve a actuar")
	for action: Dictionary in state.get_actions():
		check(action["verb"] != "interactuar" or state.data.interactions[action["id"]]["verb"] == "actuar",
				"sin Desgaste libre no se puede forzar ni sellar")
	return true


func test_forcing_by_night_costs_single() -> bool:
	var state := new_state()
	routine_until(state, GameData.parse_time("18:00"))
	state.switch_to("akba")
	act(state, "interactuar", "relojeria", "", "forzar_puerta_relojeria")
	check(state.desgaste() == 1, "de noche, forzar cuesta 1 de Desgaste")
	check(state.sim.s["flags"].has("akba_forzo"), "forzar deja la marca akba_forzo")
	return true
