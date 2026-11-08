import Phaser from 'phaser';

// The heroine mascot. She is drawn with code (no image files) from simple shapes,
// so her outfit can change per level and her face/arms animate per mood.
// Replace with your own sprites later if you want: keep the same public methods.

const SKIN = 0xffd9c2;
const SKIN_SHADE = 0xf0b89a;
const HAIR = 0x5a2e1a;
const HAIR_LIGHT = 0x7a4128;
const EYE = 0x3b7dd8;
const LINE = 0x2a1a14;

export default class Heroine extends Phaser.GameObjects.Container {
  constructor(scene, x, y) {
    super(scene, x, y);
    scene.add.existing(this);
    this.baseY = y;

    this.cape = scene.add.graphics();
    this.hairLong = scene.add.graphics().setPosition(0, -150);
    this.legs = scene.add.graphics();
    this.torso = scene.add.graphics();
    this.armL = scene.add.graphics().setPosition(-36, -145);
    this.armR = scene.add.graphics().setPosition(36, -145);
    this.head = scene.add.container(0, -150);
    this.headBase = scene.add.graphics();
    this.face = scene.add.graphics();
    this.hairFront = scene.add.graphics();
    this.hat = scene.add.graphics();
    this.head.add([this.headBase, this.face, this.hairFront, this.hat]);

    this.add([this.cape, this.hairLong, this.legs, this.torso, this.armL, this.armR, this.head]);

    this.mood = 'smile';
    this.eyes = 'normal';
    this.busy = false;
    this.poseTweens = [];
    this.nextBlink = 2000;
    this.blinking = false;
  }

  // ---------- outfit ----------
  setTheme(theme) {
    this.theme = theme;
    this.drawCape();
    this.drawHairLong();
    this.drawLegs();
    this.drawTorso();
    this.drawArm(this.armL, -1);
    this.drawArm(this.armR, 1);
    this.drawHeadBase();
    this.drawHairFront();
    this.drawHat();
    this.drawFace();
  }

  drawCape() {
    const g = this.cape; g.clear();
    if (this.theme.key !== 'fantasy') return;
    g.fillStyle(0xb0124a, 1);
    g.fillPoints([{ x: -40, y: -150 }, { x: 40, y: -150 }, { x: 95, y: 168 }, { x: -95, y: 168 }], true);
    g.fillStyle(0xffd700, 1);
    g.fillRect(-95, 162, 190, 6);
  }

  drawHairLong() {
    const g = this.hairLong; g.clear();
    g.fillStyle(HAIR, 1);
    const long = this.theme.key === 'space' ? 70 : 120;
    g.fillRoundedRect(-52, -70, 104, long + 70, 30);
    g.fillStyle(HAIR_LIGHT, 1);
    g.fillRoundedRect(-40, -40, 10, long + 20, 5);
  }

  drawLegs() {
    const g = this.legs; g.clear();
    const k = this.theme.key;
    g.fillStyle(SKIN, 1);
    g.fillRoundedRect(-28, 0, 22, 165, 10);
    g.fillRoundedRect(6, 0, 22, 165, 10);
    if (k === 'beach') {
      g.fillStyle(0xff7a59, 1);
      g.fillRoundedRect(-32, 160, 30, 10, 4); g.fillRoundedRect(2, 160, 30, 10, 4);
      g.fillStyle(0xffffff, 1);
      g.fillRect(-20, 156, 6, 6); g.fillRect(14, 156, 6, 6);
    } else if (k === 'neon') {
      g.fillStyle(0x1b1b2e, 1);
      g.fillRoundedRect(-31, -4, 27, 160, 8); g.fillRoundedRect(4, -4, 27, 160, 8);
      g.fillStyle(0x00f0ff, 1);
      g.fillRect(-31, 10, 4, 140); g.fillRect(27, 10, 4, 140);
      g.fillStyle(0xff2bd6, 1);
      g.fillRoundedRect(-34, 148, 32, 22, 6); g.fillRoundedRect(2, 148, 32, 22, 6);
    } else if (k === 'space') {
      g.fillStyle(0xeef2ff, 1);
      g.fillRoundedRect(-32, -4, 29, 160, 10); g.fillRoundedRect(3, -4, 29, 160, 10);
      g.fillStyle(0xff8a3d, 1);
      g.fillRect(-32, 60, 29, 8); g.fillRect(3, 60, 29, 8);
      g.fillStyle(0x8a90a8, 1);
      g.fillRoundedRect(-36, 140, 36, 30, 8); g.fillRoundedRect(0, 140, 36, 30, 8);
    } else {
      g.fillStyle(0xffd700, 1);
      g.fillRoundedRect(-32, 160, 28, 10, 4); g.fillRoundedRect(4, 160, 28, 10, 4);
    }
  }

  drawTorso() {
    const g = this.torso; g.clear();
    const k = this.theme.key;
    const body = [{ x: -36, y: -150 }, { x: 36, y: -150 }, { x: 24, y: -62 }, { x: 31, y: 6 }, { x: -31, y: 6 }, { x: -24, y: -62 }];
    g.fillStyle(SKIN, 1); g.fillPoints(body, true);

    if (k === 'beach') {
      // sporty one-piece swimsuit + pareo wrap skirt
      g.fillStyle(0xff7a59, 1);
      g.fillPoints([{ x: -30, y: -126 }, { x: 30, y: -126 }, { x: 24, y: -62 }, { x: 32, y: 10 }, { x: -32, y: 10 }, { x: -24, y: -62 }], true);
      g.fillRect(-24, -150, 8, 26); g.fillRect(16, -150, 8, 26);
      g.fillStyle(0xffffff, 0.9);
      [[-14, -100], [10, -90], [-6, -60], [14, -40], [-16, -20]].forEach(([x, y]) => g.fillCircle(x, y, 4));
      g.fillStyle(0x4ecdc4, 0.95);
      g.fillPoints([{ x: -36, y: -4 }, { x: 36, y: -4 }, { x: 42, y: 80 }, { x: -6, y: 100 }, { x: -40, y: 70 }], true);
      g.fillStyle(0x2a9d94, 1);
      g.fillCircle(30, 0, 8);
    } else if (k === 'neon') {
      g.fillStyle(0x1b1b2e, 1); g.fillPoints(body, true);
      g.fillStyle(0x2a2a48, 1);
      g.fillPoints([{ x: -38, y: -152 }, { x: -6, y: -152 }, { x: -6, y: -40 }, { x: -28, y: -40 }], true);
      g.fillPoints([{ x: 38, y: -152 }, { x: 6, y: -152 }, { x: 6, y: -40 }, { x: 28, y: -40 }], true);
      g.lineStyle(3, 0x00f0ff, 1);
      g.lineBetween(-6, -150, -6, -40); g.lineBetween(6, -150, 6, -40);
      g.fillStyle(0xff2bd6, 1); g.fillRect(-31, -6, 62, 8);
      g.fillStyle(0xfaff00, 1); g.fillRect(-4, -8, 8, 12);
    } else if (k === 'space') {
      g.fillStyle(0xeef2ff, 1); g.fillPoints(body, true);
      g.fillStyle(0xc9d1f0, 1); g.fillRoundedRect(-20, -120, 40, 40, 6);
      g.fillStyle(0x00e676, 1); g.fillCircle(-10, -108, 4);
      g.fillStyle(0xff5252, 1); g.fillCircle(2, -108, 4);
      g.fillStyle(0x40c4ff, 1); g.fillRect(-12, -96, 24, 6);
      g.fillStyle(0xff8a3d, 1); g.fillRect(-30, -40, 60, 8);
      g.lineStyle(10, 0xc9d1f0, 1); g.strokeEllipse(0, -152, 80, 22);
    } else {
      // royal gown
      g.fillStyle(0x7b3fc4, 1);
      g.fillPoints([{ x: -32, y: -132 }, { x: 32, y: -132 }, { x: 24, y: -62 }, { x: 70, y: 162 }, { x: -70, y: 162 }, { x: -24, y: -62 }], true);
      g.fillStyle(0x9b5fe4, 1);
      g.fillPoints([{ x: -10, y: -60 }, { x: 10, y: -60 }, { x: 24, y: 162 }, { x: -24, y: 162 }], true);
      g.fillStyle(0xffd700, 1);
      g.fillRect(-26, -66, 52, 8);
      g.fillRect(-72, 156, 144, 8);
      g.fillCircle(0, -120, 6);
      g.fillRect(-32, -136, 64, 6);
    }
  }

  drawArm(g, side) {
    g.clear();
    const k = this.theme.key;
    g.fillStyle(SKIN, 1);
    g.fillRoundedRect(-9, 0, 18, 115, 9);
    g.fillCircle(0, 118, 11);
    if (k === 'beach') {
      g.fillStyle(0x4ecdc4, 1); g.fillRect(-9, 98, 18, 5);
    } else if (k === 'neon') {
      g.fillStyle(0x2a2a48, 1); g.fillRoundedRect(-11, -4, 22, 98, 9);
      g.fillStyle(0x00f0ff, 1); g.fillRect(-11, 88, 22, 6);
      g.fillStyle(0xff2bd6, 1); g.fillRect(side * 7 - 2, 6, 4, 70);
    } else if (k === 'space') {
      g.fillStyle(0xeef2ff, 1); g.fillRoundedRect(-12, -4, 24, 104, 10);
      g.fillStyle(0xff8a3d, 1); g.fillRect(-12, 50, 24, 6);
      g.fillStyle(0x8a90a8, 1); g.fillCircle(0, 116, 13);
    } else {
      g.fillStyle(0x9b5fe4, 1); g.fillEllipse(0, 14, 34, 40);
      g.fillStyle(0x7b3fc4, 1); g.fillRoundedRect(-10, 20, 20, 80, 8);
      g.fillStyle(0xffd700, 1); g.fillRect(-10, 96, 20, 6);
    }
  }

  drawHeadBase() {
    const g = this.headBase; g.clear();
    g.fillStyle(HAIR, 1); g.fillCircle(0, -66, 54);
    g.fillStyle(SKIN_SHADE, 1); g.fillRect(-9, -26, 18, 30);
    g.fillStyle(SKIN, 1);
    g.fillCircle(-45, -58, 9); g.fillCircle(45, -58, 9);
    g.fillCircle(0, -60, 46);
    g.fillEllipse(0, -34, 70, 40);
  }

  drawHairFront() {
    const g = this.hairFront; g.clear();
    g.fillStyle(HAIR, 1);
    g.fillEllipse(-24, -100, 54, 36);
    g.fillEllipse(12, -104, 64, 34);
    g.fillEllipse(36, -90, 30, 42);
    g.fillRoundedRect(-54, -92, 16, 76, 8);
    g.fillRoundedRect(38, -92, 16, 76, 8);
    g.fillStyle(HAIR_LIGHT, 1);
    g.fillEllipse(6, -110, 26, 8);
  }

  drawHat() {
    const g = this.hat; g.clear();
    const k = this.theme.key;
    if (k === 'beach') {
      g.fillStyle(0xf4d58d, 1); g.fillEllipse(0, -102, 160, 30);
      g.fillEllipse(0, -116, 86, 50);
      g.fillStyle(0xff7a59, 1); g.fillRect(-42, -112, 84, 9);
      g.fillStyle(0xffffff, 1); g.fillCircle(32, -108, 7);
    } else if (k === 'neon') {
      g.lineStyle(7, 0x00f0ff, 1);
      g.beginPath(); g.arc(0, -64, 58, Math.PI * 1.05, Math.PI * 1.95); g.strokePath();
      g.fillStyle(0xff2bd6, 1);
      g.fillRoundedRect(-62, -78, 18, 36, 6); g.fillRoundedRect(44, -78, 18, 36, 6);
      g.fillStyle(0x00f0ff, 0.6);
      g.fillCircle(-53, -60, 5); g.fillCircle(53, -60, 5);
    } else if (k === 'space') {
      g.fillStyle(0x8a90a8, 1); g.fillRoundedRect(44, -74, 14, 28, 5);
      g.lineStyle(3, 0x8a90a8, 1); g.lineBetween(51, -74, 60, -120);
      g.fillStyle(0xff5252, 1); g.fillCircle(60, -122, 5);
      g.lineStyle(3, 0x8a90a8, 1); g.lineBetween(46, -50, 20, -28);
      g.fillStyle(0x40c4ff, 1); g.fillCircle(-30, -104, 6);
    } else {
      g.fillStyle(0xffd700, 1);
      g.fillPoints([{ x: -34, y: -106 }, { x: -34, y: -136 }, { x: -18, y: -118 }, { x: 0, y: -144 }, { x: 18, y: -118 }, { x: 34, y: -136 }, { x: 34, y: -106 }], true);
      g.fillStyle(0xff2b6a, 1); g.fillCircle(0, -118, 5);
      g.fillStyle(0x2bd6ff, 1); g.fillCircle(-22, -114, 4); g.fillCircle(22, -114, 4);
    }
  }

  // ---------- face ----------
  drawFace() {
    const g = this.face; g.clear();
    const eyes = this.blinking && this.eyes === 'normal' ? 'blink' : this.eyes;
    const ex = 17, ey = -58;

    const drawEye = (x, type) => {
      if (type === 'happy') {
        g.lineStyle(4, LINE, 1);
        g.beginPath(); g.moveTo(x - 9, ey + 3); g.lineTo(x, ey - 6); g.lineTo(x + 9, ey + 3); g.strokePath();
      } else if (type === 'blink') {
        g.lineStyle(3, LINE, 1); g.lineBetween(x - 8, ey + 1, x + 8, ey + 1);
      } else {
        g.fillStyle(0xffffff, 1); g.fillEllipse(x, ey, 16, 20);
        g.fillStyle(EYE, 1); g.fillCircle(x, ey + 1, 6.5);
        g.fillStyle(0x10131f, 1); g.fillCircle(x, ey + 1, 3.2);
        g.fillStyle(0xffffff, 1); g.fillCircle(x + 2.5, ey - 3, 2.2);
        g.lineStyle(3, LINE, 1); g.lineBetween(x - 9, ey - 10, x + 9, ey - 10);
      }
    };

    if (eyes === 'wink') { drawEye(-ex, 'normal'); drawEye(ex, 'happy'); }
    else { drawEye(-ex, eyes); drawEye(ex, eyes); }

    // brows
    g.lineStyle(3, HAIR, 1);
    if (eyes === 'sad') {
      g.lineBetween(-26, -76, -10, -80); g.lineBetween(10, -80, 26, -76);
    } else if (eyes === 'surprised') {
      g.lineBetween(-26, -82, -10, -84); g.lineBetween(10, -84, 26, -82);
    } else {
      g.lineBetween(-26, -76, -10, -78); g.lineBetween(10, -78, 26, -76);
    }
    if (eyes === 'sad') {
      g.fillStyle(0x6ec6ff, 0.9); g.fillCircle(-22, -40, 4); g.fillTriangle(-26, -40, -18, -40, -22, -48);
    }

    // blush
    g.fillStyle(0xff8fa3, 0.45);
    g.fillEllipse(-30, -42, 16, 9); g.fillEllipse(30, -42, 16, 9);
    // nose
    g.fillStyle(SKIN_SHADE, 1); g.fillCircle(0, -45, 2.5);

    // mouth
    const my = -32;
    if (this.mood === 'grin') {
      g.fillStyle(0x8a1c2b, 1);
      g.slice(0, my - 2, 12, 0, Math.PI, false); g.fillPath();
      g.fillStyle(0xff7a8a, 1); g.fillEllipse(0, my + 6, 12, 5);
    } else if (this.mood === 'frown') {
      g.lineStyle(3, 0x8a1c2b, 1);
      g.beginPath(); g.arc(0, my + 10, 9, Math.PI * 1.15, Math.PI * 1.85); g.strokePath();
    } else if (this.mood === 'o') {
      g.fillStyle(0x8a1c2b, 1); g.fillEllipse(0, my + 2, 9, 11);
    } else {
      g.lineStyle(3, 0x8a1c2b, 1);
      g.beginPath(); g.arc(0, my - 4, 9, Math.PI * 0.15, Math.PI * 0.85); g.strokePath();
    }
  }

  setExpression(eyes, mood) {
    this.eyes = eyes; this.mood = mood; this.drawFace();
  }

  // ---------- poses ----------
  stopPose() {
    this.poseTweens.forEach(t => t.stop());
    this.poseTweens = [];
    if (this.resetTimer) { this.resetTimer.remove(); this.resetTimer = null; }
  }

  tw(cfg) {
    const t = this.scene.tweens.add(cfg);
    this.poseTweens.push(t);
    return t;
  }

  pose(armL, armR, headRot, dur = 250) {
    this.tw({ targets: this.armL, rotation: armL, duration: dur, ease: 'Sine.easeOut' });
    this.tw({ targets: this.armR, rotation: armR, duration: dur, ease: 'Sine.easeOut' });
    this.tw({ targets: this.head, rotation: headRot, duration: dur, ease: 'Sine.easeOut' });
  }

  idle() {
    this.stopPose();
    this.busy = false;
    this.setExpression('normal', 'smile');
    this.pose(0.15, -0.15, 0, 400);
    this.tw({ targets: this, y: this.baseY, scaleX: 1, scaleY: 1, duration: 300 });
  }

  backToIdle(ms) {
    this.resetTimer = this.scene.time.delayedCall(ms, () => this.idle());
  }

  cheer() {
    this.stopPose();
    this.busy = true;
    this.setExpression('happy', 'grin');
    this.pose(2.6, -2.6, -0.08, 180);
    this.y = this.baseY;
    this.tw({ targets: this, y: this.baseY - 34, duration: 220, yoyo: true, repeat: 1, ease: 'Quad.easeOut' });
    this.backToIdle(1300);
  }

  surprised() {
    if (this.busy) return;
    this.stopPose();
    this.setExpression('surprised', 'o');
    this.pose(0.9, -0.9, 0, 150);
    this.y = this.baseY;
    this.tw({ targets: this, y: this.baseY - 16, duration: 140, yoyo: true });
    this.backToIdle(900);
  }

  sad() {
    this.stopPose();
    this.busy = true;
    this.setExpression('sad', 'frown');
    this.pose(0.02, -0.02, 0.22, 400);
    this.tw({ targets: this, y: this.baseY + 8, scaleY: 0.97, duration: 400 });
    this.backToIdle(1900);
  }

  victory() {
    this.stopPose();
    this.busy = true;
    this.setExpression('wink', 'grin');
    this.pose(0.55, -2.5, -0.14, 300);
    this.tw({ targets: this.armR, rotation: -2.9, duration: 260, yoyo: true, repeat: -1, delay: 300, ease: 'Sine.easeInOut' });
    this.tw({ targets: this, y: this.baseY - 10, duration: 500, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
  }

  // Spin-change outfit: half turn, redraw, turn back.
  changeOutfit(theme, onDone) {
    this.stopPose();
    this.busy = true;
    this.scene.tweens.add({
      targets: this, scaleX: 0, duration: 220, ease: 'Sine.easeIn',
      onComplete: () => {
        this.setTheme(theme);
        this.scene.tweens.add({
          targets: this, scaleX: 1, duration: 260, ease: 'Back.easeOut',
          onComplete: () => { this.idle(); this.cheer(); if (onDone) onDone(); }
        });
      }
    });
  }

  // called every frame: breathing + blinking
  tick(time, delta) {
    if (!this.busy) {
      this.torso.scaleY = 1 + Math.sin(time / 600) * 0.008;
      this.armL.rotation = 0.15 + Math.sin(time / 900) * 0.04;
      this.armR.rotation = -0.15 - Math.sin(time / 900) * 0.04;
    }
    this.hairLong.rotation = this.head.rotation * 0.5;
    this.nextBlink -= delta;
    if (this.nextBlink <= 0) {
      this.blinking = !this.blinking;
      this.nextBlink = this.blinking ? 120 : Phaser.Math.Between(1800, 4200);
      this.drawFace();
    }
  }
}
