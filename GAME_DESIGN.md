# Cabin Chaos — Diseño del juego

## Concepto
Party game multijugador cómico ambientado en un vuelo comercial. Personajes 3D low-poly simples (primitivas). La comedia **emerge** de física torpe, tropiezos, objetos voladores, objetivos en conflicto y la comunicación entre amigos por Discord. No hay diálogos ni escenas escritas.

## Pilares
1. **Caos emergente:** lo gracioso surge de las interacciones entre jugadores y entorno.
2. **Objetivos en conflicto:** cada rol tiene razones para actuar distinto.
3. **Fácil de entender:** controles y objetivos simples.
4. **Momentos memorables:** cada partida genera anécdotas.
5. **Rejugabilidad:** cambiar de rol y de misión cambia la experiencia.
6. **Diversión antes que complejidad:** ningún sistema existe solo por ser interesante técnicamente.

## Partida
- 4 jugadores: 1 Piloto, 1 Aeromozo, 2 Pasajeros. Duración objetivo ≈ 5 min.
- Flujo: Preparación → Despegue (~30 s, cinturón forzado) → Crucero (~3:30, tormentas e incidentes) → Descenso (~60 s, cinturón forzado) → Aterrizaje → Resultados → Revancha.

## Roles

### Piloto (cabina)
Rol de **información y control del ritmo**, no simulador de aviación. El avión no rota ni se desplaza: el vuelo son estados e indicadores.
- **Monitor de cámaras** (`SubViewport`): ve el pasillo y avisa por Discord. Es lo que le da protagonismo cómico.
- **Señal de cinturón** (toggle): encendida, un pasajero de pie es infractor y el aeromozo puede capturarlo legítimamente (+satisfacción). Apagada, caminar es legal.
- **Altitud simplificada** para esquivar frentes de tormenta anunciados por el host con antelación.
- **Maniobra brusca** (cooldown): turbulencia provocada. Tumba pasajeros en misión pero derrama bebidas y baja satisfacción.
- **Piloto automático:** puede salir de la cabina un tiempo limitado; mientras está fuera la estabilidad se degrada.
- Indicadores: estabilidad, alertas e incidentes.

### Aeromozo
- Sirve bebidas con un carrito (se agarra y se lleva; ver `NETWORKING.md`).
- Mantiene la satisfacción, atiende incidentes, vigila pasajeros.
- **Captura:** sujeta a un pasajero → inmovilizado un tiempo limitado, suelta lo que lleva y pierde progreso de misión. Con cooldown; el pasajero puede forcejear para escapar antes.
- Debe priorizar (¿derrame o perseguir al que abrió el compartimento?).

### Pasajeros
Cada uno recibe una misión secreta distinta (la identidad de pasajero no es secreta; el *qué* sí). Las misiones exigen exposición, riesgo e interacción, no un clic.

Misiones iniciales:
1. **Upgrade ilegal:** acumular 40 s (no consecutivos) en primera clase. Si te capturan allí, pierdes 10 s de progreso.
2. **Souvenir:** robar un objeto concreto del carrito y llevarlo a tu asiento. Se ve en la mano; al ser capturado lo sueltas.
3. **Equipaje misterioso:** abrir el compartimento marcado, sacar la maleta y esconderla en el baño con el seguro puesto. Un compartimento abierto baja satisfacción.

## Victoria (resultado único y binario)
- **Pasajeros ganan** si al aterrizar se completó **al menos 1 misión**, **o** si la satisfacción llegó a 0.
- **En cualquier otro caso gana la tripulación.**

No hay puntuación, estadísticas persistentes ni progresión. La pantalla de resultados muestra el ganador y 3–5 momentos destacados.

## Satisfacción (0–100)
Barra de "vida" de la tripulación. Valores en `GameBalance` (ajustables).
- Sube: bebida servida correctamente, incidente resuelto, pasajeros sentados durante turbulencia, problema del avión atendido, infractor de cinturón capturado.
- Baja: bebida derramada, carrito volcado, pasajeros corriendo en momentos críticos, compartimento abierto, incidente sin resolver, turbulencia excesiva.

## Incidentes (MVP: 1–2, en Fase 8)
Candidatos: **equipaje caído** (hay que recogerlo) y **baño atascado** (bloquea el baño un rato). Deben crear oportunidades (también para pasajeros), no castigos arbitrarios.

## Sospecha
No hay sistema numérico de sospecha. La sospecha la generan los humanos (Discord + cámaras). Las acciones sospechosas deben ser **visibles** (compartimento abierto, alguien en primera clase, objeto en la mano).

## Fuera del MVP
Matchmaking, lobbies públicos, Steam, chat de voz in-game, menús elaborados, guardado, personalización, progresión, múltiples aviones/mapas, bots, simulación aeronáutica, ragdoll avanzado, inventarios complejos.

## Escenario (greybox, Fase 4)
Cabina · pasillo central (ancho justo para que dos personajes se estorben) · filas de asientos · primera clase separada por cortina · baño con puerta y seguro · compartimentos superiores · galley con carrito.
