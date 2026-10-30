// manos_particulas — paso 2: las manos (desde TouchDesigner) dibujan partículas
//
// TD -> Processing por OSC al puerto 12000, por cada mano (h1, h2):
//   /h1/x, /h1/y  punta del índice, 0..1 (y hacia arriba)
//   /h1/pinch     distancia pulgar-índice (pequeña = pinza)
//   /h1/on        1 si la mano se ve
//
// Mano abierta: suelta partículas que siguen fluyendo solas.
// Pinza (pulgar + índice juntos): deja de soltar y atrae las partículas.
//
// Teclas: m = espejo on/off, d = ver/ocultar manos, c = borrar
//
// Librería: oscP5 (Sketch > Import Library > Manage Libraries)

import oscP5.*;

final int LISTEN_PORT = 12000;
final int MAX_PARTICLES = 3000;
final float PINCH_THRESHOLD = 0.06;

OscP5 osc;

Hand[] hands = { new Hand(20), new Hand(190) };  // tono: naranja, azul
ArrayList<Particle> particles = new ArrayList<Particle>();

boolean mirror = true;
boolean showHands = true;
volatile int oscCount = 0;  // mensajes recibidos (para el estado en consola)
volatile String lastAddress = "-";

void setup() {
  size(1280, 720, P2D);
  pixelDensity(1);  // más rápido en pantallas retina
  colorMode(HSB, 360, 100, 100, 100);
  osc = new OscP5(this, LISTEN_PORT);
  background(0);
}

void draw() {
  // Estela: no se borra la pantalla, se oscurece poco a poco
  blendMode(BLEND);
  noStroke();
  fill(0, 0, 0, 8);
  rect(0, 0, width, height);

  for (Hand h : hands) h.update();
  for (Hand h : hands) h.emit();

  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    if (p.dead()) particles.remove(i);
  }

  // Todas las partículas en una sola forma: mucho más rápido que un line() por partícula
  blendMode(ADD);
  beginShape(LINES);
  for (Particle p : particles) p.show();
  endShape();

  blendMode(BLEND);
  if (showHands) for (Hand h : hands) h.showCursor();

  if (frameCount % 120 == 0) {
    println("[estado] fps=" + nf(frameRate, 0, 1)
      + "  osc/2s=" + oscCount
      + "  mano1=" + (hands[0].on ? "si" : "no")
      + "  mano2=" + (hands[1].on ? "si" : "no")
      + "  particulas=" + particles.size()
      + "  | h1 x=" + nf(hands[0].rawX, 0, 2) + " y=" + nf(hands[0].rawY, 0, 2)
      + " pinch=" + nf(hands[0].pinch, 0, 3) + " on=" + hands[0].rawOn
      + "  ultimo=" + lastAddress);
    oscCount = 0;
  }
}

void keyPressed() {
  if (key == 'm') mirror = !mirror;
  if (key == 'd') showHands = !showHands;
  if (key == 'c') { particles.clear(); background(0); }
}

// Llega en otro hilo: solo guardamos los valores
void oscEvent(OscMessage m) {
  oscCount++;
  String a = m.addrPattern();
  lastAddress = a;
  if (a.startsWith("/")) a = a.substring(1);
  if (a.length() < 4 || a.charAt(0) != 'h' || m.arguments().length == 0) return;

  int i = a.charAt(1) - '1';
  if (i < 0 || i >= hands.length) return;
  float v = m.get(0).floatValue();
  String field = a.substring(3);

  if (field.equals("x")) hands[i].rawX = v;
  else if (field.equals("y")) hands[i].rawY = v;
  else if (field.equals("pinch")) hands[i].pinch = v;
  else if (field.equals("on")) hands[i].rawOn = v > 0.5;
}

class Hand {
  volatile float rawX, rawY, pinch;
  volatile boolean rawOn;
  boolean on, pinching;
  PVector pos = new PVector(), prev = new PVector(), vel = new PVector();
  float hue;

  Hand(float hue) { this.hue = hue; }

  void update() {
    boolean wasOn = on;
    on = rawOn;
    pinching = on && pinch > 0 && pinch < PINCH_THRESHOLD;

    float x = (mirror ? 1 - rawX : rawX) * width;
    float y = (1 - rawY) * height;
    prev.set(pos);
    if (!wasOn) prev.set(x, y);         // evita un salto al aparecer
    pos.lerp(x, y, 0, wasOn ? 0.5 : 1);  // suaviza el temblor
    vel = PVector.sub(pos, prev);
  }

  void emit() {
    if (!on) return;
    if (pinching) {
      for (Particle p : particles) p.attract(pos);
      return;
    }
    // Más velocidad = más partículas, repartidas a lo largo del trazo
    int n = int(constrain(2 + vel.mag() * 0.8, 2, 30));
    for (int k = 0; k < n && particles.size() < MAX_PARTICLES; k++) {
      PVector at = PVector.lerp(prev, pos, k / (float) n);
      particles.add(new Particle(at, vel, hue));
    }
  }

  void showCursor() {
    if (!on) return;
    noFill();
    stroke(hue, 60, 100, 80);
    strokeWeight(2);
    circle(pos.x, pos.y, pinching ? 18 : 36);
  }
}

class Particle {
  PVector pos, vel;
  float hue, life, maxLife, size;

  Particle(PVector at, PVector handVel, float baseHue) {
    pos = at.copy();
    vel = handVel.copy().mult(0.3).add(PVector.random2D().mult(random(0.5, 2)));
    hue = (baseHue + random(-25, 25) + 360) % 360;
    maxLife = life = random(120, 360);
    size = random(1, 3.5);
  }

  void update() {
    // Campo de flujo: las partículas siguen corrientes de ruido Perlin
    float a = noise(pos.x * 0.002, pos.y * 0.002, frameCount * 0.003) * TWO_PI * 3;
    vel.add(PVector.fromAngle(a).mult(0.12));
    vel.mult(0.97);
    pos.add(vel);
    life--;
  }

  void attract(PVector target) {
    PVector d = PVector.sub(target, pos);
    float dist = max(d.mag(), 20);
    vel.add(d.setMag(min(1.5, 400 / dist)));
    life = min(maxLife, life + 1);  // mientras atraes, no se mueren
  }

  void show() {
    float t = life / maxLife;  // 1 al nacer, 0 al morir
    stroke(hue, 80 - t * 30, 100, t * 60);
    strokeWeight(size * (0.5 + t));
    vertex(pos.x - vel.x, pos.y - vel.y);
    vertex(pos.x, pos.y);
  }

  boolean dead() { return life <= 0; }
}
