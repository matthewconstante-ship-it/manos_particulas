# manos_particulas — Pinceles de partículas con las manos

Tus manos (cámara del Mac) controlan partículas generativas.

## Versión 1: TouchDesigner + Processing  (etiqueta `v1-td-processing`)

```
Cámara ─▶ TouchDesigner + MediaPipe: detecta las manos
             │  OSC 127.0.0.1:12000  (/h1/x, /h1/y, /h1/pinch, /h1/on, igual para h2)
             ▼
          Processing: cada mano suelta partículas; pinza = atrae
```

Estado: **paso 2 funcionando** (las manos llegan a Processing y dibujan).
Pendiente: paso 3 (Processing envía las partículas a TD para renderizarlas) y
paso 4 (panel de control y efectos en TD).

### Archivos

| Archivo | Qué es |
|---|---|
| `touchdesigner/mediapipe/release/manos_particulas.toe` | **Proyecto de TouchDesigner** (MediaPipe + `manos_bridge`). Debe quedarse en esta carpeta: usa los `.tox` de `toxes/` |
| `touchdesigner/mediapipe/` | Plugin MediaPipe TouchDesigner v0.6.0 ([descarga](https://github.com/torinmb/mediapipe-touchdesigner/releases/tag/v0.6.0)) — no está en git |
| `touchdesigner/manos_bridge.py` | Script que crea `/project1/manos_bridge` (manos → OSC) |
| `processing/manos_particulas/manos_particulas.pde` | Sketch de Processing (recibe manos, dibuja partículas) |

### Cómo arrancarlo

1. Abre `touchdesigner/mediapipe/release/manos_particulas.toe`.
2. En el componente **MediaPipe**: elige la webcam y deja activado solo **Detect Gestures**
   (desactiva Images, Segments, Faces, Poses, Objects… para que vaya fluido).
3. Si `/project1/manos_bridge` no existe, en la Textport:
   ```python
   run(open('/Users/matthew/Desktop/pruebas claude/manos_particulas/touchdesigner/manos_bridge.py', encoding='utf-8').read())
   ```
4. Abre el sketch en Processing (necesita la librería **oscP5**) y pulsa ▶.

Teclas en Processing: `m` espejo, `d` ver manos, `c` borrar.

## Versión 2: solo Processing + ayudante Python  (etiqueta `v2-processing-python`)

```
Cámara ─▶ python/manos.py (MediaPipe): detecta las manos
             │  OSC 127.0.0.1:12000  (mismos mensajes que la versión 1)
             ▼
          Processing: el mismo sketch processing/manos_particulas
```

| Archivo | Qué es |
|---|---|
| `python/manos.py` | Detector de manos con MediaPipe → OSC (con ventana de vista previa) |
| `python/run_manos.sh` | Lanzador (`./run_manos.sh`, opciones `--no-preview`, `--camera N`) |
| `python/requirements.txt` | Paquetes de Python |
| `python/.venv/`, `python/hand_landmarker.task` | Entorno y modelo — no están en git, se recrean así ↓ |

Instalación (solo la primera vez, o si se borra `.venv`):
```bash
cd "/Users/matthew/Desktop/pruebas claude/manos_particulas/python"
python3.13 -m venv .venv && .venv/bin/pip install -r requirements.txt
curl -L -o hand_landmarker.task https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task
```

Arrancar: **cierra TouchDesigner** (si no, también manda datos al puerto 12000),
ejecuta `python/run_manos.sh` y después el sketch de Processing.

## Pizarrón → repositorio propio

El pizarrón (antes versión 3 aquí, etiqueta `v3-pizarron`) ahora es un proyecto aparte:
**[pizarron-manos](https://github.com/matthewconstante-ship-it/pizarron-manos)**.

### Notas aprendidas

- En Mac Apple Silicon la librería **Syphon para Processing no funciona** (solo Intel). Por eso
  todo pasa por OSC.
- El ejemplo de MediaPipe trae dos `hand_tracking`; el bueno es `/project1/hand_tracking`
  (el de dentro de `MediaPipe` no está conectado). `manos_bridge.py` elige el conectado.
- TouchDesigner lee los scripts como ASCII: usa `encoding='utf-8'` al abrirlos.
