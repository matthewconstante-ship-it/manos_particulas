# manos_particulas — Pinceles de partículas con las manos

Tus manos (cámara del Mac) controlan partículas generativas.

## Versión 1: TouchDesigner + Processing  (etiqueta git `v1-td-processing`)

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

### Notas aprendidas

- En Mac Apple Silicon la librería **Syphon para Processing no funciona** (solo Intel). Por eso
  todo pasa por OSC.
- El ejemplo de MediaPipe trae dos `hand_tracking`; el bueno es `/project1/hand_tracking`
  (el de dentro de `MediaPipe` no está conectado). `manos_bridge.py` elige el conectado.
- TouchDesigner lee los scripts como ASCII: usa `encoding='utf-8'` al abrirlos.
