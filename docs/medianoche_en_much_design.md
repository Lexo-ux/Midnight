# Medianoche en Much — Documento de diseño

Oct 10, 2026 · @Alex

## Visión

*Medianoche en Much* es un juego de misterio en bucle para Android: el mismo día se repite en la ciudad de Much, y solo dos vidas, Sazil (civil) y Akba (Despertado), pueden romperlo juntas.

**High concept:** Un día. Dos vidas. Una ciudad que se repite hasta que aprendas a unirlas.

El título es provisional. *Much* a secas también funciona como nombre del juego.

### Los nombres

| Nombre | Raíz en maya yucateco (aprox.) | Significado | Qué es en el juego |
| --- | --- | --- | --- |
| Akba | áak'ab | noche, oscuridad | El Despertado. Ve lo oculto y es más fuerte de noche. |
| Sazil | sáasil | luz, claridad | La persona civil. Ve a la gente y es más fuerte de día. |
| Much | múuch' | juntos, unión | La ciudad. Esta noche celebra la Noche de la Unión, y el final verdadero exige que los dos actúen juntos. |

La Noche de la Unión ocurre cada 52 años, un guiño a la Rueda Calendárica mesoamericana de 52 años. Las grafías de la tabla son aproximadas: conviene validarlas con una persona hablante y acreditarla.

La regla de respeto: el guiño vive en los nombres, la noche y la astronomía. Los glifos y símbolos sagrados mayas no se usan como decoración.

### Pilares

1. **Saber es avanzar.** No hay niveles ni dinero. Solo progresa lo que el jugador entiende.
2. **Dos miradas, una ciudad.** Sazil ve a las personas y Akba ve la grieta. Ninguno resuelve Much por su cuenta.
3. **Cada persona tiene un día.** Los 12 habitantes viven su propia rutina hora por hora, la mires o no.
4. **Pensar, no correr.** El reloj solo avanza cuando actúas. La presión de tiempo real es rara y opcional.
5. **Conocer es desvelar.** Todos empiezan como silueta. Pasar bucles con alguien revela su retrato, que diseña la comunidad.

### La esencia de LifeSim, traducida

| Esencia | En *Medianoche en Much* |
| --- | --- |
| Vidas reales repetidas, unidas por el Umbral | Cada bucle es una vida más del mismo día; el Umbral es lo que lo repite |
| La Convergencia | La medianoche de la Unión, cuando todo se reinicia |
| Despertados y civiles igual de valiosos | Akba y Sazil, con capacidades que no se solapan |
| Gente que importa | 12 habitantes con rutina, secreto y destino propios |
| Misterio que cruza vidas | El Cuaderno del Umbral y la pregunta: ¿quién sostiene el bucle, y por qué? |

## Personajes jugables: Sazil y Akba

Sazil ve a las personas y domina el día; Akba ve la grieta y domina la noche. Esa diferencia hace que el día mismo vaya cambiando cuál de los dos te conviene.

### Sazil: la claridad (civil)

Sazil reparte el correo en Much. Conoce cada puerta, cada nombre y cada chisme. No puede ver el Umbral, pero nota sus efectos: frío repentino, relojes que se atrasan, flores que se marchitan.

- **Repartir:** entra a cualquier dirección donde tenga una carta. Puede entregarla, retenerla, desviarla o leerla. Las cartas son los únicos objetos que existen dentro de un bucle.
- **Conversar:** la gente confía en Sazil. Su mazo de conversación tiene más cartas de *Escuchar* y *Verdad*.
- **Fijarse:** al observar a alguien, su horario del día se anota en el Cuaderno más rápido.
- **Invisible al Umbral:** los Cazadores rastrean huellas del Umbral, así que Sazil nunca es su objetivo.
- **Límites:** no ve fisuras ni ecos. Correos cierra a las 17:00 y después pierde la excusa para entrar a sitios. De noche es tan frágil como cualquiera.

### Akba: la oscuridad (Despertado)

Akba es vigilante nocturno del Observatorio de Much y despertó hace poco. De día duerme en un cuarto del Observatorio y su percepción es débil. Es el único que recuerda los bucles desde el principio.

- **Ver fisuras:** revela la capa oculta de un lugar (grietas, luces imposibles, lo que el Umbral esconde). Funciona plenamente de 18:00 a 06:00. De día solo funciona en sombras e interiores.
- **Escuchar ecos:** en un lugar, oye lo que ocurrió ahí a esa misma hora en el bucle anterior. Es la forma de espiar el pasado reciente.
- **Forzar:** abre lo cerrado o sostiene lo que cae usando el Umbral. Cada uso sube el **Rastro**.
- **Sellar:** cierra una fisura abierta. Solo funciona de noche o al lado de la fisura.
- **Límites:** la gente le teme y su mazo tiene más cartas de *Presión* y *Revelar*. No puede entrar a sitios con guardia. Si el Rastro llega al máximo, los Cazadores lo encuentran.

### Comparación rápida

|  | Sazil | Akba |
| --- | --- | --- |
| Mejor franja | 07:00 a 17:00 | 18:00 a 00:00 |
| Ve | personas, rutinas, cartas | fisuras, ecos, el Reloj |
| Recuerda los bucles | no; siente *déjà vu* hasta que Akba se lo cuenta | sí, desde el bucle 1 |
| Riesgo principal | daño físico | Rastro y Cazadores |
| Su recurso | cartas entregadas o retenidas | Desgaste por forzar (se recupera al reiniciar) |

### Encontrarse

En el día canónico, Akba y Sazil nunca se cruzan. Que se encuentren es el primer gran hito del juego, porque desbloquea:

- las **acciones conjuntas** cuando están en el mismo lugar a la misma hora (por ejemplo, Sazil distrae mientras Akba sella);
- que Akba le cuente los bucles a Sazil, lo que abre en su mazo las cartas de *Recordar*.

Para lograr la confianza en ese primer encuentro, Akba debe decir algo que solo Sazil podría saber, y eso solo es posible con lo aprendido en bucles anteriores.

## Core loop y sistema de tiempo

El día va de 06:00 a 00:00: son 18 horas con 2 acciones por hora, así que cada bucle da 36 acciones. Al inicio de cada hora eliges a quién controlas. Un bucle completo dura unos 12 a 15 minutos reales.

### Las cuatro escalas

1. **Segundo a segundo (una acción):** tocas un lugar o una persona en el mapa y eliges qué hacer: observar, hablar, seguir, entregar, forzar, sellar o esperar. Cada acción consume 30 minutos de reloj. El reloj no corre mientras piensas.
2. **Hora a hora (el relevo):** al comenzar cada hora, eliges entre Sazil y Akba. El personaje que no controlas sigue su rutina normal, salvo que una acción anterior la haya cambiado. Tu atención es el recurso escaso.
3. **Bucle a bucle (una vida del día):** a las 00:00 llega la Convergencia y todo se reinicia. Se pierden objetos, cartas, heridas y Rastro. Se conserva todo lo anotado en el Cuaderno del Umbral.
4. **Meta (la partida):** se descubren finales, se desvelan personas y se cierra el misterio central. Una partida completa ronda las 6 a 10 horas (estimado de diseño).

### Reglas del tiempo

- **Rutinas fijas:** si nadie interviene, el día es idéntico en cada bucle. Cada diferencia la causó el jugador.
- **Eventos con hora:** algunos hechos ocurren a una hora exacta (la fisura de las 15:00, los Cazadores a las 21:00). Si estás ahí, los ves; si no, los descubres después.
- **Mismo lugar, misma hora:** si Sazil y Akba coinciden y ya se conocen, aparece la opción de *acción conjunta*.
- **Rastro:** cada vez que Akba fuerza algo, sube el Rastro. Con Rastro bajo, los Cazadores llegan a las 21:00 a la plaza. Con Rastro medio, adelantan su llegada. Con Rastro alto, van directo a donde esté Akba.
- **Desgaste:** forzar de día cuesta el doble. Si el Desgaste se llena, Akba pierde el resto de la hora.

### Herramientas contra la repetición

- **Saltar a la hora:** avanza hasta una hora elegida con ambos personajes en su rutina.
- **Repetir mi ruta:** reproduce exactamente las acciones del bucle anterior hasta una hora elegida. Es posible porque la simulación es determinista.
- **Despertar antes:** cuando el Cuaderno conoce todo lo que ocurre antes de cierta hora, el bucle puede empezar directamente ahí.

### Por qué funciona en un teléfono

- Se juega en vertical y con una mano, tocando.
- Las sesiones son cortas: un bucle cabe en un viaje en bus.
- Se puede dejar a mitad de hora: el estado se guarda en cada acción.

## El Cuaderno del Umbral

El Cuaderno es la única progresión del juego: guarda lo que se sabe y sobrevive a cada medianoche. Dentro de la ficción es la memoria de Akba; en la interfaz es la pantalla a la que el jugador vuelve entre bucles.

### Tipos de entrada

| Entrada | Se obtiene | Qué desbloquea |
| --- | --- | --- |
| Horario | observar o seguir a alguien | saber dónde estará cada persona a cada hora |
| Hecho | presenciar un evento o escuchar un eco | nuevas acciones en lugares ("buscar en el patio") |
| Secreto | ganar una conversación o leer una carta | cartas de *Conocimiento* para usar en conversaciones |
| Rumor | Beto, chismes, cartas ajenas | una pista vaga hacia algo que todavía no sabes |
| Clave | contraseñas, dónde está una llave | atajos que ahorran acciones |
| Final | llegar a medianoche con ciertas condiciones | una página del desenlace y pistas hacia otros finales |

### Páginas

- **Personas:** una ficha por habitante, con silueta, nivel de Velo, horario conocido y secretos.
- **Lugares:** qué se ha visto ahí, separado por hora y por personaje.
- **La línea del día:** de 06:00 a 00:00, con los eventos conocidos marcados. Lo que aún no se sabe aparece como hueco.
- **Preguntas abiertas:** el juego formula preguntas a partir de lo descubierto ("¿Por qué Ruth dijo *otra vez*?"). Cada pregunta apunta a dónde mirar.

### Pistas sin frustrar

El riesgo de los juegos de bucle es perderse. El Cuaderno lo resuelve en tres niveles que el jugador elige:

1. **Rumor:** una frase vaga dentro del mundo ("dicen que el taller cierra raro después de las tres").
2. **Pregunta dirigida:** nombra el lugar y la hora ("¿Qué pasa en la relojería a las 15:00?").
3. **Revelación:** dice qué hacer. Siempre es opcional y no penaliza.

## La ciudad de Much

Much es una ciudad pequeña de piedra caliza y calles en cuadrícula, construida alrededor de un antiguo observatorio. Esta noche celebra la Unión, que ocurre cada 52 años, y nadie vivo recuerda bien la anterior. Es una ciudad ficticia: no está en un país concreto.

El juego completo tiene 7 lugares. Cada uno se ve distinto según quién lo mire.

| Lugar | Abierto | Sazil ve | Akba ve |
| --- | --- | --- | --- |
| Oficina de Correos | 07:00 a 17:00 | la ruta del día, el cajón de cartas muertas (cerrado con llave) | nada fuera de lo común; el Umbral no toca este lugar |
| Mercado | 07:00 a 15:00 | puestos, chismes, a Lina y a la Dra. Ilse | un frío que viene del callejón hacia la relojería |
| Relojería de Ruth | 08:00 a 16:00 | a Ruth y a Tun trabajando, relojes que se atrasan | el patio trasero: ahí se abre la fisura de las 15:00 |
| Plaza de la Unión | todo el día; fiesta de 20:00 a 00:00 | a Beto, las flores de Rosa, la fiesta | flores marchitas que dibujan una espiral alrededor de la fuente |
| El Puente | todo el día | a Joaquín en su barca | una grieta bajo el arco que se abre a las 18:30 |
| Observatorio | de día solo con cita; Akba vive ahí | la puerta de servicio, donde entrega el correo de Nadia | el Reloj de Much, ecos, y a partir de las 23:30 a Itzel |
| Casa de Sazil | siempre | a su hermano Tun, la mesa de la cena y una foto antigua | (Akba no entra salvo que Sazil lo invite) |

**Expansión posterior:** la Alcaldía, con guardia en la puerta. Solo Sazil entra, y guarda el archivo de la Unión anterior.

### El Reloj de Much

Es un instrumento astronómico de bronce y piedra que mide la Unión. Todos creen que es solo un monumento. En realidad funciona como sello: mientras el Reloj siga funcionando, el día se repite en lugar de abrirse por completo. Es el centro del misterio y el lugar del final verdadero.

## Habitantes

Doce personas sostienen el día: cada una tiene una rutina, un secreto y un destino que cambia según lo que hagas. El rasgo de silueta es el único elemento visual fijo que define el estudio; el resto lo diseña la comunidad.

| Persona | Quién es | Rutina clave | Secreto | Si nadie interviene | Rasgo de silueta |
| --- | --- | --- | --- | --- | --- |
| Ruth | relojera, guardiana del Reloj | Relojería de 08:00 a 16:00; Observatorio desde las 22:00 | ajustó el Reloj como sello hace 52 años, tras perder a su hermana Itzel; recuerda fragmentos de los bucles | discute con Nadia a las 23:00 y la retrasa hasta medianoche | lupa de relojero en la frente |
| Tun | hermano menor de Sazil, aprendiz de Ruth | Relojería; a las 12:00 lleva una caja al Observatorio; a las 20:00 va a la plaza | anota en una libreta las frases que Ruth repite cada día | lo hieren a las 21:00 en la plaza al defender a Rosa | caja de madera bajo el brazo |
| Lina | panadera | Mercado de 07:00 a 15:00; a las 15:00 lleva pan a la relojería | de niña vio desaparecer a Itzel y nunca lo contó | la fisura del patio se la lleva a las 15:00 | canasta ancha |
| Marcos | capitán de los Cazadores | llega en el tren de las 14:00; patrulla la plaza a las 21:00 | fue aprendiz de Ruth; sabe que el Reloj es un sello y cree que los Despertados lo rompen | detiene a Rosa a las 21:00 | abrigo largo y farol |
| Celia | cazadora joven | acompaña a Marcos | su madre era Despertada; duda de su oficio | obedece a Marcos | red de hilo plateado al hombro |
| Efraín | jefe de Correos | Correos de 07:00 a 17:00; almuerza de 12:00 a 13:00 y deja el abrigo con la llave | guarda en el cajón de cartas muertas 52 años de cartas de Ruth a Itzel | nada: el cajón sigue cerrado | visera y gafas |
| Nadia | astrónoma, jefa de Akba | Observatorio de 10:00 a 00:00 | calculó que el Reloj retiene la Unión y quiere desmontarlo para demostrarlo | intenta desmontar el Reloj a las 23:00; Ruth la frena | telescopio plegable a la espalda |
| Beto | vendedor de periódicos | recorre la plaza y el mercado | sus titulares cambian un poco en cada bucle: el Umbral le susurra | vende el titular de la Unión | fajo de periódicos y gorra |
| Rosa | florista | Plaza de la Unión todo el día | está despertando sin saberlo; sus flores se marchitan cerca del Umbral | Marcos la detiene a las 21:00 | cubeta de flores |
| Dra. Ilse | médica | Mercado a las 13:00; fiesta desde las 20:00 | atendió a los heridos de la Unión anterior, siendo muy joven | a las 20:30 la llaman al Puente por Joaquín y deja la plaza | maletín |
| Joaquín | barquero | en el Puente todo el día | hay una carta de su hija sin entregar en la bolsa de Sazil | cae al río a las 18:30 | sombrero ancho y remo |
| Itzel | el eco: la hermana de Ruth, perdida en la Unión anterior | aparece a las 23:30 en el Observatorio; solo Akba la ve | ver la sección de preguntas abiertas | espera, y nadie la escucha | contorno de luz sin relleno |

### Cómo se enlazan

Las rutinas están entrelazadas a propósito, para que salvar a una persona mueva a otra:

- Si Joaquín no cae, a la Dra. Ilse no la llaman al Puente, se queda en la plaza y Tun sobrevive a las 21:00.
- Si Ruth no llega al Observatorio, nadie frena a Nadia y Much se rompe.
- Si Rosa no está en la plaza a las 21:00, Marcos no tiene a quién detener y busca a Akba.

## El día canónico

Si nadie interviene, el día de Much termina siempre igual: Lina, Joaquín y Tun caen, Ruth retrasa a Nadia hasta medianoche y la Convergencia reinicia todo. Este es el día que el jugador aprende a desarmar.

&#91;embedded content: día canónico de Much · 06:00 a 00:00\]

Sazil y Akba casi no se solapan: el día de Sazil termina a las 17:00 y Akba despierta a las 18:00. Esa hora vacía entre los dos es justo donde el jugador tiene que lograr que se encuentren.

## Cadenas de causalidad y árbol de pistas

El final verdadero depende de tres ramas que convergen a las 23:30: que Akba y Sazil se encuentren, que las cartas de Ruth lleguen a Itzel y que Nadia no desmonte el Reloj. Salvar a Lina, Joaquín y Tun no es obligatorio, pero cambia el epílogo.

&#91;embedded content: árbol de pistas · del descubrimiento al final verdadero\]

El árbol se lee de izquierda a derecha: cada pista abre un cambio, y cada cambio abre una pieza del final. Las ramas superiores son las más fáciles y enseñan el sistema; las inferiores exigen combinar a los dos personajes.

### Cadenas principales

1. **El pan de las tres.** El eco del patio revela la fisura de las 15:00. Hay tres formas de salvar a Lina: Sazil la convence en el mercado, Sazil retiene la carta que la manda al taller, o Akba sella el patio de día (con el Desgaste doble y el riesgo de Rastro).
2. **El puente y la plaza.** Si Sazil entrega antes de las 18:00 la carta de la hija de Joaquín, él se va a casa. La Dra. Ilse no sale de la plaza y Tun sobrevive a las 21:00. Una carta salva a dos personas.
3. **La noche de los Cazadores.** Si Rosa no está en la plaza a las 21:00 (Sazil le entrega un recado que la saca de ahí), Marcos no detiene a nadie y empieza a buscar a Akba. Convencer a Celia permite desviar la patrulla.
4. **Las cartas muertas.** La libreta de Tun da el nombre de Itzel. La llave de Efraín abre el cajón. Una de las cartas explica el sello, y es la prueba que Nadia necesita.
5. **Encontrarse.** Sazil va a la fiesta en lugar de ir a casa. Akba gana su confianza con algo que solo la familia sabría. Desde ahí existen las acciones conjuntas.
6. **La Unión.** A las 23:30, con Nadia convencida y las cartas en el Observatorio, los dos sostienen el Reloj juntos.

## Finales

Hay 7 finales más el estado por defecto. Todos, salvo el verdadero, devuelven al bucle tras mostrarse, y el Cuaderno los guarda con una pista hacia los demás. Solo el final verdadero produce un amanecer nuevo.

| Final | Condición a medianoche | Qué se siente |
| --- | --- | --- |
| Otra vez (por defecto) | nada cambió lo suficiente | el día se reinicia; Akba recuerda, Sazil siente *déjà vu* |
| Much se rompe | Ruth no llega al Observatorio y Nadia desmonta el Reloj | el Umbral se abre por completo y la ciudad se pliega; es el final más oscuro |
| Cazado | el Rastro llega al máximo y Marcos atrapa a Akba | a Akba se lo llevan; Sazil vive el resto del día sintiendo que falta alguien |
| Un buen día | Sazil salva a Lina, Joaquín, Tun y Rosa, sin intervención de Akba | todos llegan vivos a medianoche, y aún así el día vuelve; es una victoria que no dura |
| La noche sola | Akba sella el Reloj sin Sazil, con el Desgaste al máximo | Much amanece, pero Akba se queda en el Umbral; es un sacrificio |
| El guardián | Ruth confía en Akba y él ajusta el Reloj en su lugar | el día se repetirá para siempre, sin muertes, y solo Akba lo sabrá |
| Cartas a Itzel | las cartas de Ruth llegan a Itzel, pero el sello no se cierra entre los dos | Ruth suelta el sello y amanece, pero las pérdidas de este bucle se vuelven permanentes |
| Much (la Unión), el verdadero | cartas entregadas, Nadia convencida y Akba y Sazil juntos en el Reloj a las 23:30 | la Unión se cierra en armonía y llega el día siguiente |

### El final verdadero no exige perfección

Para el final verdadero basta con la Unión. El epílogo cambia según quién sigue vivo: cada persona salvada aparece en la mañana siguiente con su retrato completo. Así, un final imperfecto sigue siendo un final, y el epílogo completo es la recompensa del jugador que vuelve.

Este final es el equivalente directo de la resolución *armónica* de LifeSim; *La noche sola* y *El guardián* corresponden a resoluciones *forzadas*.

## Momentos de quiebre y conversaciones con cartas

El juego tiene dos tipos de escena intensa: 4 momentos de quiebre físicos, con la tensión de sostener a alguien, y las conversaciones con cartas, donde lo que está en juego es una persona.

### Momentos de quiebre

Son el único lugar del juego con presión de tiempo real. Se juegan manteniendo pulsado: sostener cuesta y soltar es definitivo.

| Hora | Lugar | Qué pasa | Opciones |
| --- | --- | --- | --- |
| 15:00 | patio de la Relojería | Lina queda al borde de la fisura | Akba la sostiene (sube el Rastro); Sazil tira de ella solo si llegó a las 14:30 y Lina confía en Sazil |
| 18:30 | El Puente | la barca de Joaquín se hunde en la grieta | Akba sostiene la barca; Sazil le grita desde la orilla para que salte |
| 21:00 | Plaza de la Unión | Marcos va a por Rosa | Sazil se interpone (Marcos no la percibe como amenaza); Akba atrae a Marcos hacia sí (Rastro al máximo) |
| 23:30 | Observatorio | las manos en el Reloj | acción conjunta: los dos sostienen hasta que el anillo se alinea |

**Opciones de tiempo:** 20 segundos por defecto, una versión larga de 40 segundos, o sin tiempo. Mantener pulsado tiene alternativa de tocar para activar o desactivar. Ningún quiebre exige reflejos para avanzar.

### Conversaciones con cartas

Cada persona importante tiene **muros** (miedos) y **puertas** (lo que necesita oír). Al principio están ocultos. Al llegar a una puerta, la conversación se gana.

- **Turnos:** 4 por conversación. Un medidor de **Confianza** va de 0 a 5. Si llega a 0, la persona se cierra hasta el próximo bucle.
- **Mano:** 4 cartas del mazo del personaje más las cartas de *Conocimiento* que el Cuaderno haya ganado.
- **Ganar:** produce un secreto, un cambio de rutina ("no iré al taller a las tres") o ayuda en un momento posterior.

| Carta | Quién la tiene | Efecto |
| --- | --- | --- |
| Escuchar | sobre todo Sazil | revela un muro o una puerta |
| Verdad | sobre todo Sazil | abre una puerta si es la correcta; si no, cuesta Confianza |
| Silencio | ambos | la persona habla más: se gana un turno |
| Presión | sobre todo Akba | rompe un muro de golpe, pero baja la Confianza |
| Revelar | solo Akba | muestra el Umbral: convence o aterra, según la persona |
| Conocimiento | ambos, desde el Cuaderno | un secreto aprendido en otro bucle que abre una puerta concreta |
| Recordar | Sazil, después de conocer a Akba | trae un *déjà vu* compartido, con un efecto fuerte en personas cercanas |

**Forzar una conversación:** Akba puede ganar a la fuerza con Presión y Revelar. Funciona rápido, pero la persona queda *marcada*: su Velo baja un nivel y en el siguiente bucle lo recibe con miedo. Es la misma tensión de LifeSim entre poder y vínculo.

**Ejemplo, Nadia a las 22:30 con Akba:** su muro es el miedo a que no la tomen en serio y su puerta son las pruebas. La carta *Conocimiento: carta de Ruth sobre el sello* abre la puerta y Nadia no desmonta el Reloj.

## Recorrido de ejemplo

Este es un camino posible hacia el final verdadero en 6 bucles. Otros jugadores llegarán en otro orden, y eso es bueno, porque da de qué hablar en comunidad.

1. **Bucle 1, el tutorial.** Controlas a Sazil de 06:00 a 17:00 y a Akba de 18:00 a 00:00, sin relevo libre. Sazil reparte el correo, ve a Lina ir hacia la relojería a las 15:00 y no volver. Oye a Ruth murmurar *otra vez* al cerrar. Ya de noche, Akba ve desde el Observatorio la grieta del Puente y oye el alboroto de la plaza a las 21:00. A medianoche, todo se reinicia. El Cuaderno queda con 4 hechos y 3 preguntas.
2. **Bucle 2: mirar.** Se desbloquea el relevo libre. Despiertas a Akba a las 14:00 y lo llevas a las sombras de la relojería. Al *escuchar el eco* del patio a las 15:00, oye a Ruth decir *otra vez* antes de que pase nada. Nueva pregunta: ¿Ruth recuerda los bucles?
3. **Bucle 3: el primer rescate, mal hecho.** Sazil convence a Lina de no ir al taller, y Lina vive. De noche, Akba sostiene la barca de Joaquín a las 18:30, pero el Rastro se dispara y los Cazadores llegan al Puente a las 19:30. Final: *Cazado*. Aprendes que forzar tiene un precio.
4. **Bucle 4: la carta.** Sazil entrega a las 16:00 la carta de la hija de Joaquín, y él se va a casa a leerla. Sin accidente en el Puente, la Dra. Ilse se queda en la plaza y Tun sobrevive. A las 23:30, Akba ve por primera vez a Itzel.
5. **Bucle 5: el cajón.** Tun le muestra a Sazil su libreta: Ruth repite cada día *Querida Itzel*. A las 12:00, mientras Efraín almuerza, Sazil toma la llave y abre el cajón de cartas muertas: 52 años de cartas sin dirección. A las 20:00, Sazil va a la fiesta y se encuentra con Akba. Él gana su confianza citando la libreta de Tun.
6. **Bucle 6: la Unión.** Con *Repetir mi ruta*, las salvaciones de la mañana toman un minuto. Akba convence a Nadia con la carta de Ruth sobre el sello. A las 23:30, Sazil sube al Observatorio con las cartas, Akba las pone en manos de Itzel, y los dos sostienen el Reloj juntos. Amanece el día siguiente.

## Siluetas, el Velo y la comunidad

El estudio dibuja solo siluetas, y la comunidad dibuja los rostros. Dentro del juego, conocer a alguien es literalmente desvelarlo.

### Niveles de Velo por persona

| Nivel | Cómo se gana | Qué se ve |
| --- | --- | --- |
| 0, Silueta | inicio | contorno negro con su rasgo fijo (la lupa de Ruth, el farol de Marcos) |
| 1, Rasgos | conocer su horario completo | colores de la ropa y postura |
| 2, Rostro | ganar una conversación | la cara, con expresión neutra |
| 3, Retrato | descubrir su secreto o salvarla | el retrato completo diseñado por la comunidad, con crédito a quien lo hizo |

Akba y Sazil se quedan como siluetas durante todo el juego. Sus retratos solo aparecen en el final verdadero, y ese diseño sería la última gran convocatoria de la comunidad.

### La Convocatoria del Velo (mensual)

1. El estudio publica una ficha: la silueta, el rasgo fijo, una biografía corta y las reglas (ser legible en tamaño pequeño, respetar la paleta, no copiar personajes existentes).
2. Hay 2 o 3 semanas para enviar propuestas en Discord o itch.io.
3. La comunidad vota y el estudio tiene la decisión final, para mantener la coherencia.
4. El retrato ganador entra en la siguiente actualización, con crédito en el juego y en el Cuaderno.

### Reglas que hay que tener antes de la primera convocatoria

- **Licencia:** quien envía conserva su autoría y da al estudio una licencia no exclusiva y permanente para usar el retrato en el juego y en su promoción. Hay que redactarlo con claridad y, en lo posible, revisarlo con alguien que sepa de derecho de autor.
- **Arte con IA:** hay que decidir antes si se aceptan propuestas hechas con IA. La recomendación es no aceptarlas en las convocatorias, para que la comunidad de artistas confíe en el proceso.
- **Menores:** si se aceptan propuestas de menores de 18, se necesita autorización de un adulto responsable. También hay que definir la edad mínima del Discord.

### Qué más hace la comunidad

- **Canal de teorías:** ¿quién es Itzel? ¿Por qué Beto acierta los titulares?
- **Reto del bucle (semanal):** por ejemplo, "salva a las 4 personas en un solo bucle sin que Akba fuerce nada".
- **Rutas compartidas:** como la simulación es determinista, una ruta se puede compartir como código y otra persona la reproduce igual.

## Dirección de arte, sonido y accesibilidad

La dirección de arte es minimalista e inquietante: una ciudad plana y serena donde el Umbral aparece como fisuras de luz imposible y de muchos colores. El paso del día a la noche es el arco visual de cada bucle.

### Arte

- **De día (Sazil):** piedra caliza, cal blanca, ocres y sombras cortas. Formas planas casi sin textura. Se lee claro y tranquilo.
- **De noche (Akba):** índigo profundo, puntos de estrellas y siluetas recortadas. Las fisuras emiten luz iridiscente, con muchos colores a la vez, que no ilumina lo que tiene alrededor como lo haría una luz real.
- **Geometría anómala:** en lugares tocados por el Umbral, las líneas no cierran bien: una esquina sobra, una sombra va en la dirección equivocada. Nunca es exagerado.
- **La ciudad:** un diorama visto desde arriba en vertical. Cada lugar es una tarjeta que se despliega al tocarla, sin transiciones de diapositiva.
- **El relevo:** al cambiar de personaje no hay corte. La luz barre la pantalla desde el lado de quien entra.
- **La Convergencia:** el cielo se pliega hacia el Observatorio y la ciudad se dobla como papel antes del reinicio.
- **Fuentes de inspiración:** la astronomía, el cielo nocturno y la piedra. No se usan glifos ni iconografía sagrada maya.

### Sonido

- **El Reloj** hace tic-tac de fondo, y su ritmo se desajusta cerca de las fisuras.
- **De día:** mercado, campanas y voces lejanas. **De noche:** grillos, el zumbido del Observatorio y la fiesta a lo lejos.
- **Motivo de los dos:** dos notas, una grave para Akba y una aguda para Sazil, que suenan en cada relevo. En la Unión se resuelven en un acorde.
- **El Umbral:** un sonido de cristal tensado, siempre bajo, nunca un susto.

### Accesibilidad

- **Sin reflejos obligatorios:** el reloj avanza solo por acciones, y los 4 quiebres permiten desactivar el tiempo.
- **Mantener pulsado** siempre tiene alternativa de tocar para activar o desactivar.
- **Color:** día y noche, Akba y Sazil, se distinguen también por forma e icono, no solo por color.
- **Movimiento reducido:** las fisuras y la Convergencia tienen una versión sin parpadeo ni deformación.
- **Texto:** tamaño ajustable, alto contraste y sin texto importante metido dentro de imágenes.
- **Toque:** áreas táctiles grandes (la guía de Android sugiere unos 48 dp) y juego completo con una mano.
- **Guardado:** automático en cada acción, y nada se pierde al salir de la aplicación.

## Arquitectura técnica (Godot 4)

El juego es una simulación determinista por pasos de 30 minutos, con todo el contenido en datos JSON. Lo que se lleva de LifeSim son las ideas probadas (PRNG con semilla, condiciones ALL/ANY/NOT, guardados con versión, simulaciones como pruebas). El código se reescribe en GDScript.

### Datos

| Archivo | Contiene |
| --- | --- |
| `locations.json` | lugares, horarios de apertura y qué ve cada personaje |
| `npcs.json` | personas, rasgo de silueta y rutina por hora |
| `events.json` | eventos con hora, condiciones y variantes |
| `clues.json` | entradas del Cuaderno y qué desbloquean |
| `cards.json` | cartas de conversación, muros y puertas por persona |
| `endings.json` | condiciones de cada final y variantes del epílogo |

Ejemplo de evento:

```json
{
  "id": "fisura_patio",
  "hora": "15:00",
  "lugar": "relojeria",
  "requiere": { "NOT": ["patio_sellado"] },
  "variantes": [
    { "si": { "ALL": ["lina_en_patio"] }, "efecto": "quiebre_lina" },
    { "si": { "NOT": ["lina_en_patio"] }, "efecto": "fisura_vacia" }
  ]
}
```

### Estado

- **Estado del bucle (se reinicia):** hora, a quién controlas, posición de cada persona, banderas del bucle, cartas en la bolsa de Sazil, Rastro, Desgaste y la ruta grabada.
- **Conocimiento (permanente):** banderas del Cuaderno, niveles de Velo, finales vistos y ajustes.
- **Guardado:** JSON en `user://` con un número de versión y migraciones, igual que el sobre versionado de LifeSim. Se guarda tras cada acción.

### Un paso de simulación (30 minutos)

1. Se aplica la acción del personaje controlado.
2. El otro personaje y los habitantes avanzan en su rutina, con los cambios que dicten las banderas.
3. Se evalúan los eventos de esa hora cuyas condiciones se cumplen.
4. Se escriben en el Cuaderno las entradas nuevas.
5. Si es medianoche, se evalúan los finales y se reinicia el bucle.

No hay azar en el día canónico. Si se añade algo de variación (frases de ambiente, por ejemplo), sale de un PRNG con semilla fija por bucle y con flujos separados por dominio, como en LifeSim. Así, la función *Repetir mi ruta* y las rutas compartidas reproducen siempre lo mismo.

### Escenas

`Main` → `CityMap` (el diorama) → `Location` (una por lugar) → `Conversation` (cartas) → `Breakpoint` (quiebre) → `Notebook` (Cuaderno) → `LoopEnd` (medianoche y finales).

### Validador de bucles (con Claude Code)

Es una herramienta fuera del juego que lee los JSON y comprueba:

- que todas las referencias existen (lugares, personas, banderas);
- que cada pista y cada final son alcanzables, recorriendo en anchura una versión simplificada del estado;
- que ningún final exige algo que la hora hace imposible;
- y genera un grafo de pistas para revisarlo a ojo.

Es el mismo tipo de simulación que se usó en las auditorías de LifeSim, pero sobre un grafo mucho más pequeño.

### Android

- Pantalla vertical, entrada táctil y exportación AAB para Play y APK para itch.io.
- Los textos van en CSV con el sistema de traducción de Godot: español primero, inglés después.
- El nivel de API objetivo y la configuración de firma deben verificarse con la documentación vigente de Google Play antes de cada publicación.

## Alcance del MVP y hoja de ruta

Lo primero es comprobar que el relevo entre Sazil y Akba es divertido, antes de dibujar nada. Cada fase termina en una puerta medible, y si la puerta no se cruza, se ajusta el diseño antes de crecer.

&#91;embedded content: hoja de ruta · 5 fases y 4 puertas\]

La Fase 0 puede hacerse en web con lo que ya sabes de LifeSim. Godot entra en la Fase 1, cuando el núcleo ya demostró que funciona. El requisito de prueba cerrada de Google Play (12 testers durante 14 días para cuentas personales nuevas) debe revisarse con la documentación vigente antes de la Fase 3.

### Lo que entra en la rebanada vertical (Fase 1)

- [ ] Mapa con 3 lugares: Relojería, Mercado y Plaza
- [ ] 5 personas con rutina: Ruth, Lina, Tun, Marcos y Beto
- [ ] Relevo libre entre Sazil y Akba, de 14:00 a 00:00
- [ ] Cuaderno con horarios, hechos y preguntas abiertas
- [ ] Un momento de quiebre: Lina a las 15:00
- [ ] Una conversación con cartas: Lina
- [ ] Dos finales: *Otra vez* y una versión corta de *Un buen día*
- [ ] Saltar a la hora y Repetir mi ruta
- [ ] Validador de bucles corriendo sobre los JSON

## Riesgos y preguntas abiertas

El riesgo mayor no es técnico: es que el jugador se pierda o se aburra de repetir. Casi todo el diseño del Cuaderno y las herramientas de repetición existe para eso.

### Riesgos

| Riesgo | Mitigación |
| --- | --- |
| El jugador no sabe qué hacer | pistas en 3 niveles, preguntas abiertas en el Cuaderno, rumores de Beto |
| Repetir el día aburre | *Saltar a la hora*, *Repetir mi ruta*, *Despertar antes* |
| La causalidad crece sin control | eventos con variantes acotadas, no simulación libre, y el validador en cada cambio |
| Escribir cuesta más que programar | alcance cerrado: 7 lugares, 12 personas, 8 finales; se amplía solo si la demo funciona |
| La comunidad no participa al principio | empezar con una sola convocatoria pequeña, con crédito visible, y retos semanales sencillos |
| El guiño maya se lee como apropiación | validar nombres con una persona hablante, acreditarla y no usar iconografía sagrada |

### Preguntas abiertas (decisiones de Alex)

- [ ] **Género y edad de Akba y Sazil.** Las siluetas permiten cualquier opción. ¿Se fija o se deja abierto para la comunidad?
- [ ] **El canon de Itzel.** Propuesta: Akba y Sazil son las dos mitades del alma de Itzel, que la Unión anterior separó en oscuridad y claridad (y el nombre Itzel suele asociarse al lucero de la tarde, que está entre el día y la noche). ¿Entra al canon, o choca con lo que ya existe en LifeSim?
- [ ] **¿Cuánto recuerda Ruth?** Fragmentos (la propuesta actual) o todo.
- [ ] **Quiebres con tiempo por defecto** o sin tiempo por defecto.
- [ ] **Modelo de negocio:** demo gratis y juego completo de pago único, o gratis con donaciones.
- [ ] **Título final:** *Medianoche en Much*, *Much* u otro.
- [ ] **Arte con IA en las convocatorias:** sí, no o etiquetado.
- [ ] **Relación con LifeSim:** juego independiente en el mismo universo o reemplazo del proyecto web.
