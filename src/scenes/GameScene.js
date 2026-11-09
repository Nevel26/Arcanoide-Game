import Phaser from 'phaser';
import Heroine from '../heroine.js';
import Sfx from '../sound.js';
import { LEVELS, drawBackdrop, mix, darken } from '../themes.js';

// NevelskyiArt Space: the ship shoots a green blaster at a descending asteroid formation.
// Asteroids and the ship are lit from the side by the level's star.

const W = 1280;
const H = 720;
const PANEL_W = 360;
const FIELD_X = PANEL_W;
const FIELD_W = W - PANEL_W;
const SHIP_Y = 640;
const SHIP_R = 30;
const CELL_W = 80;
const CELL_H = 58;
const FORM_TOP = 112;
const DANGER_Y = SHIP_Y - 50;
const BOLT_SPEED = 950;
const START_LIVES = 3;
const STAR = { x: FIELD_X + 64, y: 250 };
const GREEN = 0x39ff6a;

const BONUSES = {
  triple: { label: 'x3', color: 0x39ff6a, say: 'Потрійний бластер!' },
  rapid: { label: 'R', color: 0xffd23f, say: 'Швидкий вогонь!' },
  shield: { label: 'S', color: 0x40c4ff, say: 'Щит активовано!' },
  life: { label: '+1', color: 0xff4f8b, say: 'Додаткове життя!' }
};

const PHRASES = {
  streak: ['Серія x{n}!', 'Влучно! x{n}', 'Ти ас! x{n}', 'Так тримати! x{n}'],
  hit: ['Ой! Тримайся!', 'Обережно!', 'Корпус пошкоджено!', 'Ухиляйся!'],
  idle: ['Цілься в великі!', 'Метеор праворуч!', 'Гарний політ!', 'Ти найкращий пілот!'],
  win: ['Сектор чистий!', 'Перемога!', 'Летимо далі!']
};

const pick = (a) => Phaser.Utils.Array.GetRandom(a);
const rand = Phaser.Math.FloatBetween;
const rot = (p, a) => ({ x: p.x * Math.cos(a) - p.y * Math.sin(a), y: p.x * Math.sin(a) + p.y * Math.cos(a) });

export default class GameScene extends Phaser.Scene {
  constructor() { super('Game'); }

  create() {
    this.sfx = new Sfx();
    this.bg = this.add.graphics();
    this.g = this.add.graphics();

    this.heroine = new Heroine(this, PANEL_W / 2, 470);
    this.heroine.setTheme({ key: 'space' });
    this.createBubble();
    this.createHud();

    this.sparks = this.add.particles(0, 0, 'spark', {
      speed: { min: 80, max: 300 }, lifespan: 600, scale: { start: 0.9, end: 0 }, emitting: false
    }).setDepth(5);
    this.stars = this.add.particles(0, 0, 'star', {
      speed: { min: 120, max: 320 }, lifespan: 900, scale: { start: 1.4, end: 0 }, rotate: { min: 0, max: 360 },
      tint: [0xffd700, 0xffffff, GREEN], emitting: false
    }).setDepth(20);
    this.confetti = this.add.particles(0, 0, 'confetti', {
      x: { min: 0, max: W }, y: -20, speedY: { min: 160, max: 360 }, speedX: { min: -80, max: 80 },
      rotate: { start: 0, end: 540 }, lifespan: 3200, quantity: 4, frequency: 40,
      tint: [0xff2bd6, 0x00f0ff, 0xfaff00, 0xff7a59, 0x7bffb5], emitting: false
    }).setDepth(30);

    this.starfield = [];
    for (let layer = 0; layer < 2; layer++) {
      for (let i = 0; i < 70; i++) {
        this.starfield.push({ x: rand(FIELD_X, W), y: rand(0, H), layer, r: rand(0.6, 1.4) + layer * 0.6, a: rand(0.3, 1) });
      }
    }

    this.setupInput();
    this.score = 0;
    this.lives = START_LIVES;
    this.shipX = FIELD_X + FIELD_W / 2;
    this.prevShipX = this.shipX;
    this.tilt = 0;
    this.time0 = 0;
    this.invuln = 0;
    this.shieldTime = 0;
    this.tripleTime = 0;
    this.rapidTime = 0;
    this.loadLevel(0, true);
  }

  // ---------- UI ----------
  createBubble() {
    this.bubble = this.add.container(0, 0).setDepth(40);
    const g = this.add.graphics();
    g.fillStyle(0xffffff, 0.96); g.fillRoundedRect(18, 16, PANEL_W - 36, 104, 22);
    g.fillTriangle(150, 118, 200, 118, 178, 150);
    this.bubbleText = this.add.text(PANEL_W / 2, 68, '', {
      fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '24px', color: '#2a1a40',
      align: 'center', wordWrap: { width: PANEL_W - 70 }
    }).setOrigin(0.5);
    this.bubble.add([g, this.bubbleText]);
    this.bubble.setAlpha(0);
  }

  say(text, ms = 2200) {
    this.bubbleText.setText(text);
    this.tweens.killTweensOf(this.bubble);
    this.bubble.setAlpha(1).setScale(0.85);
    this.tweens.add({ targets: this.bubble, scale: 1, duration: 220, ease: 'Back.easeOut' });
    if (this.bubbleTimer) this.bubbleTimer.remove();
    if (ms > 0) this.bubbleTimer = this.time.delayedCall(ms, () => this.tweens.add({ targets: this.bubble, alpha: 0, duration: 300 }));
  }

  createHud() {
    const style = { fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '26px', color: '#ffffff', stroke: '#000000', strokeThickness: 5 };
    this.scoreText = this.add.text(FIELD_X + 20, 16, '', style).setDepth(50);
    this.levelText = this.add.text(FIELD_X + FIELD_W / 2, 16, '', style).setOrigin(0.5, 0).setDepth(50);
    this.livesText = this.add.text(W - 80, 16, '', { ...style, color: '#ff4f8b' }).setOrigin(1, 0).setDepth(50);
    this.powerText = this.add.text(FIELD_X + 20, 58, '', { ...style, fontSize: '18px', strokeThickness: 4 }).setDepth(50);
    this.muteText = this.add.text(W - 20, 14, '🔊', { fontSize: '30px' }).setOrigin(1, 0).setDepth(50)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', (p, x, y, e) => {
        e.stopPropagation();
        this.muteTap = true;
        this.sfx.muted = !this.sfx.muted;
        this.muteText.setText(this.sfx.muted ? '🔇' : '🔊');
      });
    this.centerText = this.add.text(FIELD_X + FIELD_W / 2, 470, '', {
      ...style, fontSize: '30px', align: 'center', wordWrap: { width: FIELD_W - 80 }
    }).setOrigin(0.5).setDepth(50);
    this.bigText = this.add.text(FIELD_X + FIELD_W / 2, 330, '', {
      ...style, fontSize: '60px', color: '#ffd23f', strokeThickness: 10, align: 'center'
    }).setOrigin(0.5).setDepth(50);
  }

  updateHud() {
    this.scoreText.setText(`Рахунок ${this.score}`);
    this.levelText.setText(`${this.levelIndex + 1}/${LEVELS.length} · ${this.lv.name}`);
    this.livesText.setText('♥'.repeat(Math.max(this.lives, 0)));
    const p = [];
    if (this.tripleTime > 0) p.push(`x3 ${Math.ceil(this.tripleTime)}`);
    if (this.rapidTime > 0) p.push(`R ${Math.ceil(this.rapidTime)}`);
    if (this.shieldTime > 0) p.push(`S ${Math.ceil(this.shieldTime)}`);
    this.powerText.setText(p.join('   '));
  }

  floatText(x, y, text, color = '#ffffff') {
    const t = this.add.text(x, y, text, {
      fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '22px', color, stroke: '#000', strokeThickness: 4
    }).setOrigin(0.5).setDepth(25);
    this.tweens.add({ targets: t, y: y - 50, alpha: 0, duration: 700, onComplete: () => t.destroy() });
  }

  burst(x, y, n, colors) {
    colors.forEach((c) => {
      this.sparks.setParticleTint(c);
      this.sparks.explode(Math.max(1, Math.round(n / colors.length)), x, y);
    });
  }

  // ---------- input ----------
  setupInput() {
    this.firing = false;
    this.input.on('pointerdown', (p) => {
      this.sfx.unlock();
      if (this.muteTap) { this.muteTap = false; this.dragStartX = Infinity; return; }
      this.lastX = p.x;
      this.dragStartX = p.x;
      this.firing = true;
    });
    this.input.on('pointermove', (p) => {
      if (!p.isDown || this.state === 'over' || this.state === 'won') return;
      this.moveShip(this.shipX + (p.x - this.lastX) * 1.35);
      this.lastX = p.x;
    });
    this.input.on('pointerup', (p) => {
      this.firing = false;
      if (Math.abs(p.x - this.dragStartX) < 18) this.onTap();
    });
    this.keys = this.input.keyboard.createCursorKeys();
    this.input.keyboard.on('keydown-SPACE', () => {
      this.sfx.unlock();
      if (this.state !== 'play') this.onTap();
    });
  }

  onTap() {
    if (this.state === 'ready') this.startWave();
    else if (this.state === 'over' || this.state === 'won') this.restart();
  }

  moveShip(x) { this.shipX = Phaser.Math.Clamp(x, FIELD_X + 44, W - 44); }

  makeRock(x, y, r, hp, armored = false) {
    const pts = [];
    const n = 11;
    for (let i = 0; i < n; i++) {
      const a = (Math.PI * 2 * i) / n + rand(-0.15, 0.15);
      const k = r * rand(0.8, 1);
      pts.push({ x: Math.cos(a) * k, y: Math.sin(a) * k });
    }
    const craters = [];
    for (let i = 0; i < Phaser.Math.Between(2, 3); i++) craters.push({ x: rand(-0.45, 0.45) * r, y: rand(-0.45, 0.45) * r, r: r * rand(0.12, 0.22) });
    return { x, y, bx: x, by: y, r, hp, max: hp, pts, craters, rot: rand(0, Math.PI * 2), spin: rand(-0.6, 0.6), armored, flash: 0, free: false, vx: 0, vy: 0 };
  }

  // ---------- levels ----------
  loadLevel(index, first = false) {
    this.levelIndex = index;
    this.lv = LEVELS[index];
    drawBackdrop(this.bg, this.lv, index + 7, PANEL_W, W, H);
    this.rocks = [];
    this.bolts = [];
    this.caps = [];
    this.formY = -260;
    this.streak = 0;
    this.tripleTime = 0;
    this.rapidTime = 0;
    this.bigText.setText('');

    const layout = this.lv.layout;
    const cols = layout[0].length;
    const startX = FIELD_X + (FIELD_W - cols * CELL_W) / 2 + CELL_W / 2;
    layout.forEach((row, r) => [...row].forEach((ch, c) => {
      if (ch === '.') return;
      const x = startX + c * CELL_W + rand(-8, 8);
      const y = FORM_TOP + r * CELL_H + rand(-6, 6);
      if (ch === 'X') this.rocks.push(this.makeRock(x, y, 29, 6, true));
      else this.rocks.push(this.makeRock(x, y, 18 + Number(ch) * 5, Number(ch)));
    }));

    this.state = 'ready';
    this.centerText.setText('Тапни — старт\nТримай палець — вогонь, веди — політ');
    this.heroine.idle();
    if (first) this.say('Привіт, пілоте! Тапни, щоб злетіти!', 0);
    else { this.heroine.cheer(); this.say(this.lv.hello, 2600); }
    this.updateHud();
  }

  startWave() {
    this.state = 'play';
    this.centerText.setText('');
    this.meteorCd = this.lv.meteorEvery;
    this.sfx.shield();
    this.say('Вогонь!', 1200);
    this.scheduleChatter();
  }

  formationLeft() { return this.rocks.filter((a) => !a.free).length; }

  scheduleChatter() {
    if (this.chatter) this.chatter.remove();
    this.chatter = this.time.delayedCall(Phaser.Math.Between(9000, 15000), () => {
      if (this.state === 'play' && !this.heroine.busy) this.say(pick(PHRASES.idle), 1800);
      if (this.state === 'play') this.scheduleChatter();
    });
  }

  // ---------- update ----------
  update(time, deltaMs) {
    const dt = Math.min(deltaMs / 1000, 0.05);
    this.time0 += dt;
    this.heroine.tick(time, deltaMs);

    if (this.keys.left.isDown) this.moveShip(this.shipX - 700 * dt);
    if (this.keys.right.isDown) this.moveShip(this.shipX + 700 * dt);
    const kbFire = this.keys.space.isDown;
    this.tilt += (Phaser.Math.Clamp((this.shipX - this.prevShipX) / Math.max(dt, 0.001) / 1500, -0.25, 0.25) - this.tilt) * 0.2;
    this.prevShipX = this.shipX;

    this.starfield.forEach((s) => {
      s.y += (18 + s.layer * 40) * dt;
      if (s.y > H) { s.y = 0; s.x = rand(FIELD_X, W); }
    });

    this.invuln = Math.max(this.invuln - dt, 0);
    this.shieldTime = Math.max(this.shieldTime - dt, 0);
    this.tripleTime = Math.max(this.tripleTime - dt, 0);
    this.rapidTime = Math.max(this.rapidTime - dt, 0);

    if (this.state === 'play') {
      this.fireCd = (this.fireCd || 0) - dt;
      if ((this.firing || kbFire) && this.fireCd <= 0) this.fire();
      this.updateFormation(dt);
      if (this.state === 'play') this.updateMeteors(dt);
    }
    this.updateBolts(dt);
    this.updateCaps(dt);
    this.rocks.forEach((a) => { a.rot += a.spin * dt; a.flash = Math.max(a.flash - dt, 0); });

    this.updateHud();
    this.draw();
  }

  fire() {
    this.fireCd = this.rapidTime > 0 ? 0.11 : 0.2;
    const angles = this.tripleTime > 0 ? [-0.16, 0, 0.16] : [0];
    angles.forEach((a) => this.bolts.push({ x: this.shipX, y: SHIP_Y - 40, vx: Math.sin(a) * BOLT_SPEED, vy: -Math.cos(a) * BOLT_SPEED }));
    this.sfx.laser();
  }

  updateBolts(dt) {
    for (const b of this.bolts.slice()) {
      b.x += b.vx * dt; b.y += b.vy * dt;
      if (b.y < -20) { this.bolts.splice(this.bolts.indexOf(b), 1); this.streak = 0; continue; }
      const a = this.rocks.find((r) => (b.x - r.x) ** 2 + (b.y - r.y) ** 2 < r.r * r.r);
      if (a) {
        this.bolts.splice(this.bolts.indexOf(b), 1);
        this.hitRock(a, b.x, b.y);
        if (this.state !== 'play') return;
      }
    }
  }

  hitRock(a, x, y) {
    a.hp -= 1;
    a.flash = 0.1;
    this.burst(x, y, 6, [GREEN, 0xb8ffc9]);
    if (a.hp > 0) { this.sfx.hit(); return; }
    this.explodeRock(a, true);
    if (this.formationLeft() === 0 && this.state === 'play') this.levelComplete();
  }

  explodeRock(a, byPlayer) {
    const i = this.rocks.indexOf(a);
    if (i >= 0) this.rocks.splice(i, 1);
    this.sfx.explode();
    const rock = a.armored ? this.lv.armor : this.lv.rock;
    this.burst(a.x, a.y, Math.round(a.r), [rock, mix(rock, this.lv.light, 0.5), this.lv.light]);
    if (!byPlayer) return;
    this.streak += 1;
    const points = 10 * a.max + this.streak * 2;
    this.score += points;
    this.floatText(a.x, a.y, `+${points}`);
    if (Math.random() < 0.12) this.caps.push({ x: a.x, y: a.y, type: pick(Object.keys(BONUSES)) });
    if (this.streak >= 5 && this.streak % 5 === 0) {
      this.heroine.cheer();
      this.say(pick(PHRASES.streak).replace('{n}', this.streak), 1500);
      this.stars.explode(16, PANEL_W / 2, 250);
      this.sfx.combo();
    }
  }

  updateFormation(dt) {
    this.formY += this.formY < 0 ? 140 * dt : this.lv.descend * dt;
    const sway = Math.sin(this.time0 * 0.6) * 22;
    for (const a of this.rocks.slice()) {
      if (a.free) continue;
      a.x = a.bx + sway; a.y = a.by + this.formY;
      if (a.y + a.r > DANGER_Y) {
        this.explodeRock(a, false);
        this.formY -= 110;
        this.shipHit();
        if (this.state !== 'play') return;
      }
    }
    if (this.state === 'play' && this.formationLeft() === 0) this.levelComplete();
  }

  updateMeteors(dt) {
    this.meteorCd -= dt;
    if (this.meteorCd <= 0) {
      this.meteorCd = this.lv.meteorEvery * rand(0.7, 1.3);
      const m = this.makeRock(rand(FIELD_X + 40, W - 40), -30, 14, 1);
      m.free = true;
      m.vx = rand(-70, 70);
      m.vy = rand(170, 230) + this.levelIndex * 25;
      m.spin = rand(-3, 3);
      this.rocks.push(m);
    }
    for (const m of this.rocks.slice()) {
      if (!m.free) continue;
      m.x += m.vx * dt; m.y += m.vy * dt;
      if (m.x < FIELD_X + m.r || m.x > W - m.r) m.vx = -m.vx;
      if (Math.hypot(m.x - this.shipX, m.y - SHIP_Y) < m.r + SHIP_R) {
        this.explodeRock(m, false);
        this.shipHit();
        if (this.state !== 'play') return;
      } else if (m.y > H + 40) this.rocks.splice(this.rocks.indexOf(m), 1);
    }
  }

  shipHit() {
    if (this.invuln > 0) return;
    if (this.shieldTime > 0) {
      this.shieldTime = 0; this.invuln = 1;
      this.sfx.shield(); this.say('Щит врятував!', 1400);
      return;
    }
    this.lives -= 1;
    this.streak = 0;
    this.invuln = 2;
    this.sfx.lose();
    this.cameras.main.shake(300, 0.01);
    this.burst(this.shipX, SHIP_Y, 30, [0xffb347, 0xff5a3c, 0xffffff]);
    if (this.lives <= 0) { this.gameOver(); return; }
    this.heroine.sad();
    this.say(pick(PHRASES.hit), 1800);
  }

  gameOver() {
    this.state = 'over';
    this.firing = false;
    this.bolts = [];
    this.heroine.sad();
    if (this.heroine.resetTimer) this.heroine.resetTimer.remove();
    this.say('Не здавайся! Спробуймо ще раз?', 0);
    this.sfx.gameOver();
    this.bigText.setText('GAME OVER').setColor('#ff4f6a');
    this.centerText.setText(`Рахунок: ${this.score}\nТапни, щоб грати знову`);
  }

  updateCaps(dt) {
    for (const c of this.caps.slice()) {
      c.y += 150 * dt;
      if (Math.hypot(c.x - this.shipX, c.y - SHIP_Y) < 44) {
        this.caps.splice(this.caps.indexOf(c), 1);
        this.applyBonus(c.type);
      } else if (c.y > H + 30) this.caps.splice(this.caps.indexOf(c), 1);
    }
  }

  applyBonus(type) {
    const info = BONUSES[type];
    this.sfx.bonus();
    this.heroine.surprised();
    this.say(info.say, 1600);
    this.score += 25;
    this.floatText(this.shipX, SHIP_Y - 60, info.say, '#' + info.color.toString(16).padStart(6, '0'));
    if (type === 'triple') this.tripleTime = 10;
    else if (type === 'rapid') this.rapidTime = 10;
    else if (type === 'shield') this.shieldTime = 12;
    else this.lives = Math.min(this.lives + 1, 6);
  }

  levelComplete() {
    this.state = 'transition';
    this.firing = false;
    this.bolts = []; this.caps = []; this.rocks = [];
    this.sfx.win();
    this.heroine.victory();
    this.confetti.start();
    this.time.delayedCall(1800, () => this.confetti.stop());
    this.score += 100 * (this.levelIndex + 1);

    if (this.levelIndex === LEVELS.length - 1) {
      this.state = 'won';
      this.say('Ти найкращий пілот галактики!', 0);
      this.bigText.setText('ПЕРЕМОГА!').setColor('#ffd23f');
      this.centerText.setText(`Рахунок: ${this.score}\nТапни, щоб грати знову`);
      this.time.addEvent({ delay: 2500, loop: true, callback: () => { if (this.state === 'won') this.stars.explode(20, PANEL_W / 2, 300); } });
      return;
    }
    this.say(pick(PHRASES.win), 2400);
    this.bigText.setText(`СЕКТОР ${this.levelIndex + 1} ЧИСТИЙ`).setColor('#39ff6a');
    this.time.delayedCall(2600, () => this.loadLevel(this.levelIndex + 1));
  }

  restart() {
    this.time.removeAllEvents();
    this.confetti.stop();
    this.score = 0;
    this.lives = START_LIVES;
    this.invuln = 0;
    this.shieldTime = 0;
    this.loadLevel(0, true);
    this.say('Поїхали ще раз!', 1800);
    this.heroine.cheer();
  }

  // ---------- drawing ----------
  lightDir(x, y) {
    const dx = STAR.x - x, dy = STAR.y - y;
    const l = Math.hypot(dx, dy) || 1;
    return { x: dx / l, y: dy / l };
  }

  draw() {
    const g = this.g;
    g.clear();
    this.starfield.forEach((s) => { g.fillStyle(0xffffff, s.a); g.fillCircle(s.x, s.y, s.r); });
    this.drawStar(g);
    this.rocks.forEach((a) => this.drawRock(g, a));
    this.caps.forEach((c) => {
      const info = BONUSES[c.type];
      g.fillStyle(info.color, 0.25); g.fillCircle(c.x, c.y, 22);
      g.fillStyle(info.color, 1); g.fillCircle(c.x, c.y, 16);
      g.fillStyle(0xffffff, 0.6); g.fillCircle(c.x - 5, c.y - 5, 5);
      if (!c.label) {
        c.label = this.add.text(c.x, c.y, info.label, { fontFamily: 'Arial Black, Arial', fontSize: '15px', color: '#fff', stroke: '#000', strokeThickness: 3 }).setOrigin(0.5).setDepth(6);
      }
      c.label.setPosition(c.x, c.y);
    });
    this.bolts.forEach((b) => {
      const l = Math.hypot(b.vx, b.vy);
      const tx = b.x - (b.vx / l) * 26, ty = b.y - (b.vy / l) * 26;
      g.lineStyle(12, GREEN, 0.25); g.lineBetween(tx, ty, b.x, b.y);
      g.lineStyle(6, GREEN, 0.6); g.lineBetween(tx, ty, b.x, b.y);
      g.lineStyle(2.5, 0xd9ffe3, 1); g.lineBetween(tx, ty, b.x, b.y);
    });
    if (this.state !== 'over') this.drawShip(g);
    this.syncCapLabels();
  }

  syncCapLabels() {
    if (!this.capLabels) this.capLabels = new Set();
    const live = new Set(this.caps.map((c) => c.label).filter(Boolean));
    this.capLabels.forEach((l) => { if (!live.has(l)) { l.destroy(); this.capLabels.delete(l); } });
    live.forEach((l) => this.capLabels.add(l));
  }

  drawStar(g) {
    const pulse = 1 + Math.sin(this.time0 * 2) * 0.04;
    for (let i = 0; i < 6; i++) { g.fillStyle(this.lv.star, 0.06 + i * 0.03); g.fillCircle(STAR.x, STAR.y, (90 - i * 12) * pulse); }
    g.fillStyle(this.lv.light, 1); g.fillCircle(STAR.x, STAR.y, 22);
    g.fillStyle(0xffffff, 1); g.fillCircle(STAR.x, STAR.y, 14);
    g.lineStyle(2, this.lv.light, 0.25);
    for (let i = 0; i < 4; i++) {
      const a = (i * Math.PI) / 4 + this.time0 * 0.1;
      g.lineBetween(STAR.x - Math.cos(a) * 70, STAR.y - Math.sin(a) * 70, STAR.x + Math.cos(a) * 70, STAR.y + Math.sin(a) * 70);
    }
  }

  drawRock(g, a) {
    const L = this.lightDir(a.x, a.y);
    let base = a.armored ? this.lv.armor : this.lv.rock;
    if (a.flash > 0) base = mix(base, 0xffffff, 0.5);
    const shape = a.pts.map((p) => { const q = rot(p, a.rot); return { x: a.x + q.x, y: a.y + q.y }; });

    g.fillStyle(darken(base, 0.55), 1); g.fillPoints(shape, true);
    [[0.86, 0.1, darken(base, 0.15)], [0.6, 0.28, mix(base, this.lv.light, 0.35)]].forEach(([s, sh, col]) => {
      const pts = a.pts.map((p) => { const q = rot(p, a.rot); return { x: a.x + q.x * s + L.x * a.r * sh, y: a.y + q.y * s + L.y * a.r * sh }; });
      g.fillStyle(col, 1); g.fillPoints(pts, true);
    });

    const la = Math.atan2(L.y, L.x);
    a.craters.forEach((c) => {
      const q = rot(c, a.rot);
      const cx = a.x + q.x, cy = a.y + q.y;
      g.fillStyle(darken(base, 0.4), 1); g.fillCircle(cx, cy, c.r);
      g.lineStyle(1.5, mix(base, this.lv.light, 0.5), 1);
      g.beginPath(); g.arc(cx, cy, c.r, la + Math.PI - 1, la + Math.PI + 1); g.strokePath();
    });

    if (a.armored) { g.lineStyle(3, 0xffb347, 0.8); g.beginPath(); g.arc(a.x, a.y, a.r * 0.55, a.rot, a.rot + Math.PI * 1.2); g.strokePath(); }
    if (this.lv.lava) {
      const p1 = rot({ x: -0.4 * a.r, y: -0.2 * a.r }, a.rot), p2 = rot({ x: 0.3 * a.r, y: 0.4 * a.r }, a.rot);
      g.lineStyle(2.5, 0xff7a1f, 0.85);
      g.strokePoints([{ x: a.x + p1.x, y: a.y + p1.y }, { x: a.x, y: a.y }, { x: a.x + p2.x, y: a.y + p2.y }]);
    }
    if (a.hp < a.max) {
      const pts = [{ x: 0.1, y: -0.7 }, { x: -0.1, y: -0.1 }, { x: 0.3, y: 0.5 }].map((p) => { const q = rot({ x: p.x * a.r, y: p.y * a.r }, a.rot); return { x: a.x + q.x, y: a.y + q.y }; });
      g.lineStyle(2, 0x000000, 0.6); g.strokePoints(pts);
    }

    // rim light on edges facing the star
    for (let i = 0; i < shape.length; i++) {
      const p0 = shape[i], p1 = shape[(i + 1) % shape.length];
      const mx = (p0.x + p1.x) / 2 - a.x, my = (p0.y + p1.y) / 2 - a.y;
      const facing = (mx * L.x + my * L.y) / (Math.hypot(mx, my) || 1);
      if (facing > 0.25) { g.lineStyle(2.5, this.lv.light, Math.min(facing, 1)); g.lineBetween(p0.x, p0.y, p1.x, p1.y); }
    }
  }

  drawShip(g) {
    if (this.invuln > 0 && this.time0 % 0.2 < 0.1) return;
    const ox = this.shipX, oy = SHIP_Y;
    const L = this.lightDir(ox, oy);
    const litLeft = L.x < 0;
    const T = (pts) => pts.map(([x, y]) => { const q = rot({ x, y }, this.tilt); return { x: ox + q.x, y: oy + q.y }; });

    const flick = 1 + Math.sin(this.time0 * 40) * 0.15;
    [-6, 6].forEach((ex) => {
      g.fillStyle(0xff9a3d, 0.8); g.fillPoints(T([[ex - 5, 32], [ex + 5, 32], [ex, 32 + 26 * flick]]), true);
      g.fillStyle(0xfff3b0, 1); g.fillPoints(T([[ex - 2.5, 32], [ex + 2.5, 32], [ex, 32 + 14 * flick]]), true);
    });
    const glow = T([[0, 38]])[0];
    g.fillStyle(0xff9a3d, 0.18); g.fillCircle(glow.x, glow.y, 14);

    const hull = 0x4a5470;
    const lit = mix(hull, this.lv.light, 0.45);
    const dark = darken(hull, 0.45);
    const left = [[0, -42], [0, 34], [-9, 34], [-13, 24], [-40, 30], [-38, 20], [-15, 6], [-10, -18]];
    const right = left.map(([x, y]) => [-x, y]);
    g.fillStyle(litLeft ? lit : dark, 1); g.fillPoints(T(left), true);
    g.fillStyle(litLeft ? dark : lit, 1); g.fillPoints(T(right), true);
    g.fillStyle(GREEN, 1); g.fillPoints(T([[-34, 24], [-20, 14], [-20, 19], [-33, 28]]), true);
    g.fillStyle(darken(GREEN, 0.3), 1); g.fillPoints(T([[34, 24], [20, 14], [20, 19], [33, 28]]), true);
    const glass = [];
    for (let i = 0; i < 16; i++) { const a = (Math.PI * 2 * i) / 16; glass.push([Math.cos(a) * 6, -8 + Math.sin(a) * 12]); }
    g.fillStyle(0x1d6f8f, 1); g.fillPoints(T(glass), true);
    const hl = T([[litLeft ? -2 : 2, -12]])[0];
    g.fillStyle(0xc8f4ff, 1); g.fillCircle(hl.x, hl.y, 2.5);

    const edge = litLeft ? left : right;
    g.lineStyle(2, this.lv.light, 0.9);
    g.strokePoints(T([...edge.slice(1), edge[0]]));

    if (this.shieldTime > 0) {
      const a = 0.35 + Math.sin(this.time0 * 6) * 0.1;
      g.fillStyle(0x40c4ff, 0.12); g.fillCircle(ox, oy, 50);
      g.lineStyle(2.5, 0x40c4ff, a + 0.3); g.strokeCircle(ox, oy, 50);
    }
  }
}
