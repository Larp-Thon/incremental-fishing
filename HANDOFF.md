# Handoff — Incremental Buceo

Juego incremental **activo** en 3D y primera persona: eres un buzo que pesca con arpón, vende la captura y mejora su equipo para bajar cada vez más hondo. Está en fase de prototipo jugable: el bucle completo funciona, el arte son primitivas a propósito.

## Datos generales

- **Motor**: Godot 4.7.2 (Forward+), GDScript. Sin dependencias; el único asset externo es la fuente `Jersey10.ttf` (licencia OFL), aplicada como fuente global en `project.godot`.
- **Cómo abrirlo**: importar `project.godot` en Godot y pulsar F5. La escena principal es `main.tscn`.
- **Git**: repositorio activo en la rama `chatsito`.
- **Estilo visual**: low-poly de colores planos, sin texturas. Todo el decorado se genera por código con cajas, esferas, conos y cilindros. La atmósfera (niebla, luz que baja con la profundidad, brillo de peces) hace el trabajo pesado.
- **Principio de diseño**: las mejoras amplifican lo que el jugador hace con las manos, no lo reemplazan.

## Controles

| Tecla | Acción |
|---|---|
| WASD | Nadar hacia donde miras |
| Espacio / Ctrl | Subir / bajar |
| 1 / 2 / rueda del ratón | Elegir herramienta: arpón / sonar (si está comprado) |
| Clic izquierdo | Usar la herramienta: disparar el arpón o abrir la pantalla del sonar |
| V | Activar o guardar el vehículo (si está comprado); en marcha solo se usa su arpón montado |
| F | Encender / apagar la linterna comprada |
| E (junto a la estación) | Terminar el día y entregar |
| Esc | Soltar el ratón |

## Bucle de juego actual

1. **Día**: empiezas en la superficie junto a la estación flotante. El oxígeno (30 s de base) es la duración del día y solo baja bajo el agua.
2. **Pesca**: el arpón sale unido por un sedal, y no puedes volver a disparar hasta que se recoge. El pez clavado cuenta cuando llega a tu mano.
3. **Fin del día**: al acabarse el oxígeno, o pulsando E en la estación. Se vende todo lo pescado.
4. **Menú**: recuento (especie, rareza, cantidad, precio) → mejoras → "Iniciar día N".

### Mundo

Un cañón con acantilados que baja en 6 terrazas hacia -Z (hacia delante, más allá de la estación). Cada zona es 20 m más honda que la anterior, con su decorado, sus peces y cinco materiales recogibles para mejoras y recetas.

| Zona | Fondo | Decorado | Peces (valor) | Material |
|---|---|---|---|---|
| 1 · Bajío | 18 m | Arena, corales, almejas | Anchoa 1, Sardina 1, Jurel 2 | Perla |
| 2 · Bosque de algas | 38 m | Algas que se mecen, erizos | Dorada 5, Pez loro 8 | Espina de erizo |
| 3 · Roquedal | 58 m | Rocas, ostras gigantes | Pez globo 16, Barracuda 24 | Perla negra |
| 4 · Jardín luminoso | 78 m | Gusanos tubícolas, anémonas | Pez linterna 50, Morena 70 | Cristal |
| 5 · Fumarolas | 98 m | Chimeneas volcánicas | Rape abisal 150, Calamar vampiro 200 | Azufre |
| 6 · Fosa | 118 m | Agujas de cristal | Pez dragón 350, Celacanto 900 | Fragmento abisal |

Además hay dos peces con powerup instantáneo en cualquier zona (5 de cada uno): **Pez burbuja** (aire infinito 8 s) y **Pez rayo** (velocidad x1,8 durante 8 s). No se venden.

### Sitios, eventos y capturas legendarias (milestone 5)

- **Sitios fuera de la ruta** (`world.build_sites`): el **arrecife secreto** (entrante oeste de la zona 2, tapado por una cortina de algas; perlas y el pez mandarín, que solo vive ahí), el **pecio del Nereida** (zona 3; se entra por el costado partido; dos perlas negras) y la **cueva de cristal** (entrante este de la zona 4 con techo de losas; dos cristales). Al final del cañón está **el Latido**, el origen de la señal.
- **Diario**: 8 notas (cápsulas ámbar con un haz de luz) repartidas del bajío al Latido. Se leen al tocarlas, no reaparecen y se releen en la pestaña Diario. Cuentan la historia mínima: la expedición del Nereida bajó siguiendo un pulso que sale del fondo.
- **Eventos del día**: desde el día 3, un 40 % de los días trae uno al azar. **Tormenta**: más niebla, menos luz y el triple de variantes doradas/albinas. **Noche**: poca luz y tres especies nocturnas (pez luna, calamar luciérnaga, pez víbora). **Migración**: una especie normal aparece con el doble de ejemplares. Se anuncia al empezar el día y queda en el panel inferior.
- **Capturas legendarias**: una por zona, siempre un único ejemplar al día. Aguantan varios arponazos y **recuperan toda la resistencia** si pasan unos segundos sin recibir impacto. La primera captura de cada una deja un **trofeo** en la estación (se conserva al renacer).

| Zona | Legendaria | Valor | Mecánica |
|---|---|---|---|
| 1 | Mero gigante | 40 | 4 impactos, se recupera en 8 s |
| 2 | Pez vela | 120 | Huye a 9 m/s; 3 impactos |
| 3 | Tiburón del pecio | 400 | Guarda el pecio y embiste (-8 s); 5 impactos |
| 4 | Morena ancestral | 1200 | Se esconde en la cueva; 5 impactos |
| 5 | Calamar gigante | 3500 | Desaparece con la linterna encendida; 6 impactos |
| 6 | Leviatán | 12000 | Embiste (-10 s); 8 impactos, se recupera en 7 s |

- **Fauna que no se pesca** (`fauna.gd`): 3 tortugas en el bajío, 2 mantas, una ballena que cruza las zonas 3-5 a media agua (canta al acercarte) y dos bancos de medusas luminosas pequeñas y cian, que no pican. No tienen colisión y el arpón las atraviesa.

### Presión

- Presión en atm = 1 + profundidad / 10.
- El traje aguanta 3,0 atm de base y +0,4 atm por nivel (25 niveles; 5 niveles = una zona más).
- Por encima del soporte, el gasto de oxígeno se multiplica por `1 + exceso + 0,5 · exceso²` (exceso en atm).
- Aviso pequeño con el multiplicador en cuanto hay exceso; aviso grande a partir de 2 atm de exceso.

### Mejoras

| Mejora | Efecto | Coste |
|---|---|---|
| Tanque de oxígeno | +6 s de día | 10 · 1,6^nivel |
| Aletas | +1 m/s | 15 · 1,7^nivel |
| Sedal | +4 m de alcance | 12 · 1,6^nivel |
| Carrete | +25 % velocidad de disparo y recogida | 20 · 1,7^nivel |
| Aletas / vehículo | +1 m/s por nivel / scooter o minisubmarino con batería | Costes en la terminal |
| Linterna / sonar / red | Luz, marcas periódicas de peces, fuerza de arpón | Costes y receta material en la terminal |
| Estabilizador abisal | +0,2 atm por nivel | Coste y fragmento abisal en la terminal |
| Traje de presión | +0,4 atm de soporte | Base por tramo (30, 150, 450, 1300, 4000) · 1,3^(nivel dentro del tramo) **más 1 material** de la zona del tramo |

Los materiales se recogen tocándolos, **reaparecen cada día** (antes eran finitos y las recetas podían bloquear el traje: la zona 1 daba 5 perlas y pedía 8) y los recogidos se conservan aunque acabe el día.

### Interfaz

Marco de casco de buzo siempre visible (el color del aro cambia con el tramo del traje). Panel inferior con día, monedas, barra de oxígeno (parpadea en rojo con menos de 8 s) y presión actual / soporte. A la izquierda, indicador de profundidad por zonas con la raya del límite del traje. A la derecha, lista de captura del día. Sobre el panel inferior, la barra de herramientas (`hotbar.gd`): una ranura por objeto comprado con su tecla y estado (arpón, sonar con recarga, linterna ON/OFF, vehículo con batería).

## Archivos

| Archivo | Qué contiene |
|---|---|
| `main.tscn` | Escena única: entorno, sol, superficie, mundo, estación, jugador, arpón y todo el HUD |
| `main.gd` | Estado y reglas: especies, mejoras, días, presión, tienda, HUD. Es el archivo central |
| `world.gd` | Terreno en terrazas (`floor_y`), entrantes laterales (`ALCOVES`), sitios y notas (`build_sites`), decorado por zona y materiales recogibles |
| `player.gd` | Cámara en primera persona, nado con inercia, límites del cañón y del fondo |
| `harpoon.gd` | Lanza con sedal (estados HELD / OUT / BACK) y fusil en mano |
| `fish.gd` | Pez: comportamientos, resistencia, peso y calidad de captura |
| `station.gd` | Estación flotante hecha con primitivas |
| `sfx.gd` | Efectos, música y ambientes sintetizados (superficie y bajo el agua) |
| `juice.gd` | Partículas, burbujas y rayos de luz |
| `sonar.gd` | Sonar de mano: modelo, pantalla de especies por zona, sondas y marcas |
| `vehicle.gd` | Modelo del scooter/minisubmarino en primera persona (manos, hélice, arpón montado) y piezas de equipo compartidas |
| `hotbar.gd` | Barra de herramientas del HUD |
| `hazards.gd` | Medusas, corrientes y señales visuales de peligro |
| `fauna.gd` | Fauna no pescable: tortugas, mantas, ballena y medusas luminosas |
| `terminal.gd` | Mejoras agrupadas, requisitos, récords, enciclopedia de especies y diario |
| `tests_milestone.gd` | Comprobaciones de integración de pesca, sonar, peligros y terminal |
| `depth_gauge.gd` | Dibujo del indicador de zonas |
| `fish.gdshader` | Ondulación de nado, facetado low-poly, color y brillo por instancia |
| `water.gdshader` | Superficie del agua vista por arriba y por abajo |
| `helmet.gdshader` | Marco del casco |
| `kelp.gdshader` | Algas que se mecen |

Para equilibrar, casi todo está en constantes al principio de `main.gd` (`SPECIES`, `NOTES`, `EVENTS`, `upgrades`, `SUIT_BASE_COST`, `BASE_SUPPORT`, `SUIT_STEP`) y de `world.gd` (`BOUNDS`, `ALCOVES`, `MATERIALS`).

**Las especies nuevas se añaden siempre al final de `SPECIES`**: récords y trofeos guardan el índice. Claves opcionales de una especie: `site` (vive en `world.sites`), `night`, `dark` (evita la linterna), `legend`, `regen`, `flee` (velocidad de huida), `bite` (daño de la embestida) y `desc` (enciclopedia).

## Limitaciones y atajos conocidos

- El jugador usa colisiones físicas. Los impactos con peces usan segmentos y distancia; las paredes interceptan el arpón con un rayo físico.
- El guardado conserva progreso y récords; una inmersión a medias se reinicia al cargar.
- **Sin grabaciones de audio**: efectos, música y ambientes se sintetizan por código.
- Controles reasignables desde las opciones, incluidos sonar, linterna y vehículo.
- **Equilibrio sin probar**: duración del día, precios y costes son primeras estimaciones.
- **HUD pensado para ventanas de unos 1150 px de ancho o más**; en más estrecho el panel inferior puede cortarse.
- El primer movimiento del ratón al arrancar puede girar la cámara de golpe.
- `main.gd` acepta argumentos de arranque solo para capturas automáticas (`cam=x,y,z,pitch,yaw`, `catch`, `end`, `shop`, `event=storm|night|migration`). No afectan al juego normal.
- **La cueva no es una cueva de terreno**: el suelo es un mapa de alturas, así que es un entrante en la pared con losas sólidas por techo. Se puede nadar por encima de las losas.
- Los peces de sitio y la fauna no tienen colisión: pueden atravesar el pecio o las losas.
- El sonar lista al pez mandarín y a las legendarias aunque no se hayan descubierto: sirve de pista para encontrar los sitios.
- Equilibrio sin probar también aquí: valor y resistencia de las legendarias, frecuencia de eventos y premio del arrecife.
- Todo lo que se comprobó fue por arranque sin errores y capturas estáticas; nadie ha verificado por automatización el flujo jugado con input real.

## Lista de mejoras

### 1. Base imprescindible (ya hecho)

- **Guardado y carga** (monedas, niveles, materiales, día), con autoguardado al terminar el día.
- **Colisiones reales**: pasar el jugador a `CharacterBody3D` y dar colisión al terreno, al decorado y a la estación.
- **Sonido**: respiración que se acelera con poco oxígeno, disparo y recogida del arpón, ambiente por zona, aviso de presión, música.
- **Menús**: principal, pausa, opciones (sensibilidad, volumen, teclas vía InputMap).
- **Tutorial ligero** el primer día: hacia dónde bajar, qué es la presión, para qué sirven las perlas.
- **Git** para poder experimentar sin miedo.

### 2. Tacto y "juice" (hecho)

- Retroceso y sacudida leve al disparar; tensión visible en el sedal; el pez forcejea al ser arrastrado.
- Partículas en suspensión, burbujas del buzo, cáusticas en la zona 1 y rayos de luz desde la superficie.
- Números flotantes y sonido al capturar; animación de monedas en el recuento.
- Efectos de casco: vaho, gotas al salir del agua, grietas o viñeta roja con presión extrema.
- Cardúmenes: peces comunes en grupo que huyen juntos al fallar un disparo.

### 3. Profundidad de la pesca (hecho)

- Comportamientos: huida, embestida anunciada por brillo, refugios con ventanas de reaparición y peces que evitan la linterna (pez linterna y calamar vampiro).
- Resistencia: un disparo causa un solo impacto; el arpón regresa tras golpear. La red aplica dos puntos. Las paredes interceptan el disparo.
- Tamaño visible, peso y precio variables. Récords por especie de peso, mejor venta y cantidad, guardados y visibles en la pestaña Récords; se conservan al renacer.
- Capacidad de bolsa mejorable, hasta 55 capturas (implementada en el milestone 4).
- Peligros: medusas (-4 s de oxígeno), depredadores (-5 s) y corrientes laterales delimitadas por partículas. Protección de 2 s entre golpes; se pueden esquivar.
- Las variantes raras doradas y albinas están implementadas con probabilidad baja, apariencia propia y precio multiplicado.

Sonar de mano: es la herramienta 2 del inventario. Con él en la mano, el clic abre su pantalla (el buzo queda quieto, el oxígeno sigue corriendo): especies agrupadas por zona con el precio del día, su variación y el encargo marcado con ★. Al elegir una especie salen 1-3 sondas (una por nivel) hacia los ejemplares más cercanos; al llegar se quedan como baliza brillante visible a través del decorado durante 20/25/30 s. No hay texto sobre los peces: los datos (precio, variación) se consultan en la pantalla del sonar y el tiempo restante de las balizas aparece en su ranura de la barra de herramientas. Espera de 3 s entre lanzamientos. Las marcas se invalidan al capturar/reaparecer el pez. Ya no hay barridos automáticos.

Terminal: pestañas Buceo, Pesca, Vehículos, Estación, Especialidad, Récords, Especies, Diario y Prestigio. **Especies** es la enciclopedia: cada especie capturada muestra rareza, dónde vive y su descripción; las demás salen como "???" con su zona. **Diario** reúne las notas leídas y los trofeos. Cada mejora muestra nivel, efecto, precio, receta y motivo de bloqueo. El botón de empezar el día permanece visible.

Validación: ejecutar Godot con `--headless --path . --script tests.gd` y `--headless --path . --script tests_milestone.gd -- smoke`. El segundo usa un guardado temporal independiente; comprueba inventario, sonar, scooter, reaparición de materiales, resistencia, peligros, bolsa, récords y terminal, y del milestone 5: entrantes y límite de pared, notas, eventos, peces de sitio, fauna, regeneración y trofeo de las legendarias, guardado y enciclopedia. Para captura visual, ejecutar sin headless con `--rendering-method gl_compatibility --script tests_milestone.gd -- smoke --capture`.

### 4. Progresión y economía (hecho)

- Bolsa de captura con capacidad inicial de 5 peces y mejoras de +5 por nivel (hasta 55); la bolsa llena impide guardar capturas nuevas.
- El mercado asigna un precio diario aleatorio a cada especie y el recuento muestra el total realmente pagado.
- Encargo diario de una especie con recompensa adicional por completar el objetivo.
- Scooter submarino y minisubmarino desbloqueable, ambos con batería que se recarga al volver a la superficie.
- Ramas de linterna, sonar, arpón de red y estabilizador abisal; el sonar marca peces cercanos y la red refuerza cada impacto.
- Elección excluyente entre Cazador (mayor precio de venta) y Explorador (más oxígeno y batería).
- Almacén, acuario, laboratorio y trampas amplían visualmente la estación y aportan capacidad, bonificaciones de venta, calidad y capturas pasivas.
- Las recetas iniciales de los módulos consumen materiales de las seis zonas; sus niveles posteriores cuestan monedas. El fragmento abisal se recoge en la fosa.
- Prestigio disponible al completar el traje y reunir 100 000 monedas: reinicia la progresión y materiales, y da +25 % permanente al valor de venta por renacimiento.
- Las trampas aportan hasta dos peces comunes por día y respetan la capacidad de la bolsa.

### 5. Mundo y contenido (hecho)

- Variedad lateral: arrecife secreto, pecio hundido y cueva de cristal, fuera de la ruta principal.
- Fauna no pescable: tortugas, mantas, una ballena y bancos de medusas luminosas.
- Eventos: tormenta, noche con especies propias y migraciones.
- Una captura legendaria por zona con resistencia que se regenera y trofeo en la estación.
- Enciclopedia de especies (descripción y dónde encontrarlas) y diario con las notas coleccionables.
- Historia mínima: las 8 notas del Nereida llevan hasta el Latido, al final de la fosa.

Queda fuera: una séptima zona de profundidad (el traje, los materiales y el indicador asumen 6), recompensa por completar el diario o los trofeos, y lluvia u oleaje visibles en la tormenta.

### 6. Retroalimentación de juego: ciclo del día, mapa y estación (pendiente)

Retroalimentación del autor tras jugar el milestone 5. Cambia el bucle central, así que conviene hacerlo en este orden: primero el ciclo del día (de él dependen oxígeno, entrega y recuento), luego el mapa, y al final el equilibrio.

**Ciclo de día y noche**

- El día pasa a durar un **tiempo propio** (reloj del día), separado del oxígeno. Ahora mismo el oxígeno es la duración del día: hay que desacoplarlos.
- El **oxígeno se regenera al salir a la superficie**. Equilibrarlo contra la duración del día: el límite real pasa a ser el reloj, y el oxígeno limita cuánto dura cada inmersión.
- Al **empezar un día**: título grande con el número del día y, debajo, un contador animado que baja y luego se recoloca en un sitio fijo de la pantalla para poder seguirlo con la vista.
- **Al agotarse el tiempo cae la noche** y aparece un **enemigo que te caza y puede matarte**. Morir hace perder lo que llevas encima. La noche da un margen extra de tiempo: seguir pescando es una apuesta a riesgo propio.
- Decidir qué pasa con el evento "Noche" del milestone 5 (hoy es un día oscuro al azar con especies nocturnas): lo natural es que esas especies salgan en la fase de noche de cada día.

**Entrega obligatoria en la nave**

- **Volver a la nave es obligatorio para cobrar**: lo pescado solo cuenta al entregarlo. Quedarse sin oxígeno o morir ya no vende la captura.
- **E** entrega los peces mientras aún es de día (se puede entregar varias veces y volver a bajar); **mantener E** termina el día.

**Estación y recuento**

- Hacer de la estación un lugar más importante, no solo un punto donde pulsar E.
- **Recuento paso a paso**: de menor a mayor rareza, mostrando cuánto generó el conjunto de peces de cada rareza, con animaciones que escalan con la cantidad de monedas y la rareza de lo capturado.
- El menú de mejoras pasa a ser **su propio apartado dentro de la nave**, con más presencia que el panel actual.

**Mapa**

- **Zonas muchísimo más grandes**, a lo largo y a lo ancho.
- El mapa deja de ser una escalera hacia abajo en una sola dirección: se extiende **en todas direcciones desde el epicentro**, que es la nave. Hoy es un cañón recto hacia -Z (`world.BOUNDS`, `steps`, `floor_y`, `wall`) y casi todo asume esa forma: zona del jugador y de los peces por `z`, corrientes, sitios laterales, notas, fauna, indicador de zonas y límites del jugador. Es el cambio más caro de la lista.
- **Más oscuro cuanto más se baja**, hasta hacer casi obligatoria la linterna.

**Peces**

- Que los peces tengan **colisión**: hoy atraviesan decorado, pecio y losas, y el arpón los detecta por distancia.

**Equilibrio**

- **Vehículos**: hacen el juego mucho más fácil y son baratísimos (scooter 220, minisubmarino 1800). Subir el coste o añadir coste de uso. Revisarlo después de agrandar el mapa, porque con zonas grandes pasan de comodidad a necesidad.

### 7. Arte

- Sustituir primitivas por modelos low-poly de una sola fuente o estilo: buzo, fusil, peces con silueta propia, estación.
- Paleta definida por zona y revisión de la niebla y la luz en cada una.
- Tipografía e iconos propios para el HUD; rediseño del casco por nivel de traje.

### 8. Técnica

- Separar `main.gd` (estado, tienda y HUD) en piezas cuando siga creciendo.
- Pasar las especies y mejoras a recursos (`.tres`) editables desde el editor.
- `MultiMesh` para decorado y peces si se multiplican las cantidades.
- Escalado del HUD para cualquier resolución.
- Pruebas automáticas de las fórmulas (presión, costes) y una pasada de equilibrio con datos reales de partidas.

### Orden sugerido

Guardado → colisiones → sonido y juice → comportamientos de peces → vehículo → encargos y mercado → contenido nuevo → arte definitivo. Las cuatro primeras son las que más cambian la sensación de "juego de verdad" con menos trabajo.
