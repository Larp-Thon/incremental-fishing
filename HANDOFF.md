# Handoff — Incremental Buceo

Juego incremental **activo** en 3D y primera persona: eres un buzo que pesca con arpón, vende la captura y mejora su equipo para bajar cada vez más hondo. Está en fase de prototipo jugable: el bucle completo funciona, el arte son primitivas a propósito.

## Datos generales

- **Motor**: Godot 4.7.2 (Forward+), GDScript. Sin dependencias ni assets externos.
- **Cómo abrirlo**: importar `project.godot` en Godot y pulsar F5. La escena principal es `main.tscn`.
- **Sin control de versiones**: la carpeta no es un repositorio git todavía.
- **Estilo visual**: low-poly de colores planos, sin texturas. Todo el decorado se genera por código con cajas, esferas, conos y cilindros. La atmósfera (niebla, luz que baja con la profundidad, brillo de peces) hace el trabajo pesado.
- **Principio de diseño**: las mejoras amplifican lo que el jugador hace con las manos, no lo reemplazan.

## Controles

| Tecla | Acción |
|---|---|
| WASD | Nadar hacia donde miras |
| Espacio / Ctrl | Subir / bajar |
| Clic izquierdo | Disparar el arpón |
| E (junto a la estación) | Terminar el día y entregar |
| Esc | Soltar el ratón |

## Bucle de juego actual

1. **Día**: empiezas en la superficie junto a la estación flotante. El oxígeno (30 s de base) es la duración del día y solo baja bajo el agua.
2. **Pesca**: el arpón sale unido por un sedal, y no puedes volver a disparar hasta que se recoge. El pez clavado cuenta cuando llega a tu mano.
3. **Fin del día**: al acabarse el oxígeno, o pulsando E en la estación. Se vende todo lo pescado.
4. **Menú**: recuento (especie, rareza, cantidad, precio) → mejoras → "Iniciar día N".

### Mundo

Un cañón con acantilados que baja en 6 terrazas hacia -Z (hacia delante, más allá de la estación). Cada zona es 20 m más honda que la anterior, con su decorado, sus peces y 5 materiales de mejora.

| Zona | Fondo | Decorado | Peces (valor) | Material |
|---|---|---|---|---|
| 1 · Bajío | 18 m | Arena, corales, almejas | Anchoa 1, Sardina 1, Jurel 2 | Perla |
| 2 · Bosque de algas | 38 m | Algas que se mecen, erizos | Dorada 5, Pez loro 8 | Espina de erizo |
| 3 · Roquedal | 58 m | Rocas, ostras gigantes | Pez globo 16, Barracuda 24 | Perla negra |
| 4 · Jardín luminoso | 78 m | Gusanos tubícolas, anémonas | Pez linterna 50, Morena 70 | Cristal |
| 5 · Fumarolas | 98 m | Chimeneas volcánicas | Rape abisal 150, Calamar vampiro 200 | Azufre |
| 6 · Fosa | 118 m | Agujas de cristal | Pez dragón 350, Celacanto 900 | — |

Además hay dos peces con powerup instantáneo en cualquier zona (5 de cada uno): **Pez burbuja** (aire infinito 8 s) y **Pez rayo** (velocidad x1,8 durante 8 s). No se venden.

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
| Traje de presión | +0,4 atm de soporte | Base por tramo (30, 150, 450, 1300, 4000) · 1,3^(nivel dentro del tramo) **más 1 material** de la zona del tramo |

Los materiales se recogen tocándolos, no reaparecen y se conservan aunque acabe el día.

### Interfaz

Marco de casco de buzo siempre visible (el color del aro cambia con el tramo del traje). Panel inferior con día, monedas, barra de oxígeno (parpadea en rojo con menos de 8 s) y presión actual / soporte. A la izquierda, indicador de profundidad por zonas con la raya del límite del traje. A la derecha, lista de captura del día.

## Archivos

| Archivo | Qué contiene |
|---|---|
| `main.tscn` | Escena única: entorno, sol, superficie, mundo, estación, jugador, arpón y todo el HUD |
| `main.gd` | Estado y reglas: especies, mejoras, días, presión, tienda, HUD. Es el archivo central |
| `world.gd` | Terreno en terrazas (`floor_y`), decorado por zona y materiales recogibles |
| `player.gd` | Cámara en primera persona, nado con inercia, límites del cañón y del fondo |
| `harpoon.gd` | Lanza con sedal (estados HELD / OUT / BACK) y fusil en mano |
| `fish.gd` | Pez: aparece en su zona, deambula y se mantiene dentro de ella |
| `station.gd` | Estación flotante hecha con primitivas |
| `depth_gauge.gd` | Dibujo del indicador de zonas |
| `fish.gdshader` | Ondulación de nado, facetado low-poly, color y brillo por instancia |
| `water.gdshader` | Superficie del agua vista por arriba y por abajo |
| `helmet.gdshader` | Marco del casco |
| `kelp.gdshader` | Algas que se mecen |

Para equilibrar, casi todo está en constantes al principio de `main.gd` (`SPECIES`, `upgrades`, `SUIT_BASE_COST`, `BASE_SUPPORT`, `SUIT_STEP`) y de `world.gd` (`BOUNDS`, `MATERIALS`).

## Limitaciones y atajos conocidos

- **Sin colisiones físicas**: solo hay una altura mínima sobre el terreno y los límites del cañón. Se atraviesan el decorado y la estación. Los impactos del arpón son por distancia, sin motor de física.
- **Sin guardado**: todo el progreso se pierde al cerrar.
- **Sin sonido ni música.**
- **Teclas fijas** (no usan el InputMap de Godot) y sin menú de opciones ni pausa.
- **Equilibrio sin probar**: duración del día, precios y costes son primeras estimaciones.
- **HUD pensado para ventanas de unos 1150 px de ancho o más**; en más estrecho el panel inferior puede cortarse.
- El primer movimiento del ratón al arrancar puede girar la cámara de golpe.
- `main.gd` acepta argumentos de arranque solo para capturas automáticas (`cam=x,y,z,pitch,yaw`, `catch`, `end`, `shop`). No afectan al juego normal.
- Todo lo que se comprobó fue por arranque sin errores y capturas estáticas; nadie ha verificado por automatización el flujo jugado con input real.

## Lista de mejoras

### 1. Base imprescindible (ya hecho)

- **Guardado y carga** (monedas, niveles, materiales, día), con autoguardado al terminar el día.
- **Colisiones reales**: pasar el jugador a `CharacterBody3D` y dar colisión al terreno, al decorado y a la estación.
- **Sonido**: respiración que se acelera con poco oxígeno, disparo y recogida del arpón, ambiente por zona, aviso de presión, música.
- **Menús**: principal, pausa, opciones (sensibilidad, volumen, teclas vía InputMap).
- **Tutorial ligero** el primer día: hacia dónde bajar, qué es la presión, para qué sirven las perlas.
- **Git** para poder experimentar sin miedo.

### 2. Tacto y "juice"

- Retroceso y sacudida leve al disparar; tensión visible en el sedal; el pez forcejea al ser arrastrado.
- Partículas en suspensión, burbujas del buzo, cáusticas en la zona 1 y rayos de luz desde la superficie.
- Números flotantes y sonido al capturar; animación de monedas en el recuento.
- Efectos de casco: vaho, gotas al salir del agua, grietas o viñeta roja con presión extrema.
- Cardúmenes: peces comunes en grupo que huyen juntos al fallar un disparo.

### 3. Profundidad de la pesca

- **Comportamientos por especie**: unos huyen, otros atacan o embisten, otros se esconden en el decorado, otros solo salen con poca luz.
- **Peces con resistencia**: los grandes necesitan varios arponazos o un minijuego de recogida con el carrete.
- **Tamaños y calidad**: cada captura con peso variable y precio en consecuencia; récords por especie.
- **Capacidad de la bolsa** como límite y mejora, para decidir qué merece la pena cargar.
- **Peligros**: medusas que quitan oxígeno, corrientes, depredadores en las zonas profundas.
- **Variantes raras** (doradas, albinas) de cada especie con valor multiplicado.

### 4. Progresión y economía

- **Vehículo** (ya previsto): scooter submarino y después minisubmarino, con batería propia, para acortar el viaje a las zonas lejanas.
- **Más ramas de mejora**: linterna, sonar que marca peces o materiales, arpón múltiple o con red, traje con propulsión.
- **Árbol de habilidades** en lugar de lista plana, con elecciones excluyentes para que dos partidas sean distintas.
- **Estación ampliable**: acuario, laboratorio, almacén, cada módulo con su mejora pasiva.
- **Mercado con precios variables** por día y **encargos** ("trae 3 barracudas") con recompensa extra.
- **Materiales con más usos**: que cada zona tenga recetas además de subir el traje.
- **Prestige**: reiniciar con un multiplicador permanente, o una segunda fosa más profunda al completar la primera.
- **Automatización que no quite el juego activo**: trampas o redes que pescan comunes mientras tú vas a por los raros.

### 5. Mundo y contenido

- **Más zonas y variedad lateral**: cuevas, un pecio hundido, un arrecife secreto fuera de la ruta principal.
- **Fauna no pescable** que dé vida: tortugas, mantas, ballenas al fondo, bancos de medusas luminosas.
- **Eventos**: día de tormenta (poca visibilidad, peces raros), migraciones, noche con especies distintas.
- **Jefes o capturas legendarias** por zona, con mecánica propia y trofeo en la estación.
- **Coleccionables y enciclopedia** de especies, con descripción y dónde encontrarlas.
- **Historia mínima**: restos, notas o señales que den un motivo para llegar al fondo.

### 6. Arte

- Sustituir primitivas por modelos low-poly de una sola fuente o estilo: buzo, fusil, peces con silueta propia, estación.
- Paleta definida por zona y revisión de la niebla y la luz en cada una.
- Tipografía e iconos propios para el HUD; rediseño del casco por nivel de traje.

### 7. Técnica

- Separar `main.gd` (estado, tienda y HUD) en piezas cuando siga creciendo.
- Pasar las especies y mejoras a recursos (`.tres`) editables desde el editor.
- `MultiMesh` para decorado y peces si se multiplican las cantidades.
- Escalado del HUD para cualquier resolución.
- Pruebas automáticas de las fórmulas (presión, costes) y una pasada de equilibrio con datos reales de partidas.

### Orden sugerido

Guardado → colisiones → sonido y juice → comportamientos de peces → vehículo → encargos y mercado → contenido nuevo → arte definitivo. Las cuatro primeras son las que más cambian la sensación de "juego de verdad" con menos trabajo.
