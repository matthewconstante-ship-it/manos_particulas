# Paso 2: envia las manos de MediaPipe a Processing por OSC.
#
# Uso: en la Textport de TouchDesigner:
#   run(open('/Users/matthew/Desktop/pruebas claude/manos_particulas/touchdesigner/manos_bridge.py', encoding='utf-8').read())
#
# Crea /project1/manos_bridge, que lee el hand_tracking conectado a MediaPipe y
# envia a 127.0.0.1:12000, por cada mano (h1, h2):
#   /h1/x, /h1/y   punta del dedo indice, 0..1 (y hacia arriba)
#   /h1/pinch      distancia pulgar-indice (pequena = pinza)
#   /h1/on         1 si la mano se ve, 0 si no (todo ceros = no detectada)

PROCESSING_HOST = '127.0.0.1'
PROCESSING_PORT = 12000

# Layout de hand_tracking (hand_parser.py del plugin):
#   normalized_data: por mano 21 x, 21 y, 21 z, Leftness, Rightness (65 canales)
#   helpers: por mano pinch_midpoint x, y, z, rotation, distance (5 canales)
INDEX_TIP = 8
JOINT_CHANS = 65
PINCH_CHANS = 5

CALLBACKS = '''
# Script CHOP: input 0 = normalized_data, input 1 = helpers (de hand_tracking)
def onCook(scriptOp):
	scriptOp.clear()
	scriptOp.numSamples = 1
	joints = scriptOp.inputs[0] if len(scriptOp.inputs) > 0 else None
	helpers = scriptOp.inputs[1] if len(scriptOp.inputs) > 1 else None
	for h in range(2):
		base = h * %(JOINT_CHANS)d
		x = y = pinch = on = 0.0
		if joints is not None and joints.numChans >= base + %(JOINT_CHANS)d:
			x = joints[base + %(INDEX_TIP)d][0]
			y = joints[base + 21 + %(INDEX_TIP)d][0]
			# Una mano no detectada es todo ceros
			on = 1.0 if abs(x) + abs(y) + abs(joints[base][0]) > 0 else 0.0
		if helpers is not None and helpers.numChans >= (h + 1) * %(PINCH_CHANS)d:
			pinch = helpers[h * %(PINCH_CHANS)d + 4][0]
		for name, value in (('x', x), ('y', y), ('pinch', pinch), ('on', on)):
			scriptOp.appendChan('h%%d/%%s' %% (h + 1, name))[0] = value
	return
''' % {'JOINT_CHANS': JOINT_CHANS, 'INDEX_TIP': INDEX_TIP, 'PINCH_CHANS': PINCH_CHANS}


def make(parent, optype, name, x, y):
	o = parent.create(optype, name)
	o.nodeX, o.nodeY = x, y
	return o


# Puede haber varios hand_tracking (el MediaPipe trae uno interno sin conectar):
# usamos el que tiene algo conectado a su entrada.
candidates = root.findChildren(name='hand_tracking')
connected = [c for c in candidates if c.inputConnectors and c.inputConnectors[0].connections]
ht = (connected or candidates or [None])[0]
if ht is None:
	raise Exception('[manos_bridge] No encuentro el componente hand_tracking de MediaPipe')

project = op('/project1')
old = project.op('manos_bridge')
if old:
	old.destroy()

net = project.create(baseCOMP, 'manos_bridge')
net.nodeX, net.nodeY = 0, -600

joints = make(net, selectCHOP, 'joints', 0, 100)
joints.par.chop = ht.path + '/normalized_data'
helpers = make(net, selectCHOP, 'helpers', 0, -50)
helpers.par.chop = ht.path + '/helpers'

cb = make(net, textDAT, 'hands_callbacks', 150, -200)
cb.text = CALLBACKS

hands = make(net, scriptCHOP, 'hands', 200, 25)
hands.par.callbacks = cb.name
hands.inputConnectors[0].connect(joints)
hands.inputConnectors[1].connect(helpers)

out = make(net, nullCHOP, 'hands_out', 350, 25)
out.inputConnectors[0].connect(hands)
out.viewer = True

osc = make(net, oscoutCHOP, 'osc_out', 500, 25)
osc.par.netaddress = PROCESSING_HOST
osc.par.port = PROCESSING_PORT
osc.inputConnectors[0].connect(out)

print('[manos_bridge] Leyendo manos de', ht.path)
print('[manos_bridge] Enviando OSC a {}:{}'.format(PROCESSING_HOST, PROCESSING_PORT))
