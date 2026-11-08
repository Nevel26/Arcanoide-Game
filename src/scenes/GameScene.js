import Phaser from 'phaser';
import Heroine from '../heroine.js';
import Sfx from '../sound.js';
import { THEMES, drawBackground } from '../themes.js';

const W = 1280;
const H = 720;
const PANEL_W = 360;
const FIELD_X = PANEL_W;
const FIELD_W = W - PANEL_W;
const PADDLE_Y = 672;
const BRICK_W = 80;
const BRICK_H = 36;
const BRICK_TOP = 92;
const START_LIVES = 3;

const BONUSES = {
  wide: { label: 'W', color: 0x4cd964, say: 'Широка платформа!' },
  multi: { label: '×3', color: 0xb57bff, say: 'Три м\'ячі! Ура!' },
  slow: { label: 'S', color: 0x40c4ff, say: 'Повільніше... так легше!' },
  life: { label: '♥', color: 0xff4f8b, say: 'Додаткове життя!' }
};

const PHRASES = {
  combo: ['Комбо x{n}!', 'Вау, x{n}!', 'Так тримати! x{n}', 'Ти вогонь! x{n}'],
  sad: ['Ой ні...', 'Нічого, ще спроба!', 'Я вірю в тебе!', 'Ех... збери себе!'],
  idle: ['Ти молодець!', 'Ще трошки!', 'Цілься в кути!', 'Мені подобається грати з тобою!', 'Супер!'],
  win: ['Рівень пройдено!', 'Перемога!', 'Чудово! Далі!']
};

export default class GameScene extends Phaser.Scene {
  constructor() { super('Game'); }

  create() {
    this.sfx = new Sfx();
    this.bg = this.add.graphics();

    this.heroine = new Heroine(this, PANEL_W / 2, 470);
    this.createBubble();
    this.createHud();

    this.physics.world.setBounds(FIELD_X, 0, FIELD_W, H + 200);
    this.physics.world.setBoundsCollision(true, true, true, false);
    this.physics.world.on('worldbounds', () => this.sfx.wall());

    this.bricks = this.physics.add.staticGroup();
    this.balls = this.physics.add.group();
    this.capsules = this.physics.add.group();

    this.paddle = this.physics.add.image(FIELD_X + FIELD_W / 2, PADDLE_Y, 'paddle').setImmovable(true);
    this.paddle.body.allowGravity = false;

    // Phaser may pass (paddle, ball) in either order, so pick the ball by its texture.
    const pick = (a, b) => (a.texture.key === 'ball' ? [a, b] : [b, a]);
    this.physics.add.collider(this.balls, this.paddle,
      (a, b) => { const [ball, paddle] = pick(a, b); this.onPaddleHit(paddle, ball); },
      (a, b) => pick(a, b)[0].body.velocity.y > 0, this);
    this.physics.add.collider(this.balls, this.bricks, this.onBrickHit, null, this);
    this.physics.add.overlap(this.paddle, this.capsules, this.onCatchCapsule, null, this);

    this.sparks = this.add.particles(0, 0, 'spark', {
      speed: { min: 80, max: 280 }, lifespan: 520, scale: { start: 0.9, end: 0 }, emitting: false
    }).setDepth(5);
    this.stars = this.add.particles(0, 0, 'star', {
      speed: { min: 120, max: 320 }, lifespan: 900, scale: { start: 1.4, end: 0 }, rotate: { min: 0, max: 360 },
      tint: [0xffd700, 0xffffff, 0xff8fd2, 0x7bffb5], emitting: false
    }).setDepth(20);
    this.confetti = this.add.particles(0, 0, 'confetti', {
      x: { min: 0, max: W }, y: -20, speedY: { min: 160, max: 360 }, speedX: { min: -80, max: 80 },
      rotate: { start: 0, end: 540 }, lifespan: 3200, quantity: 4, frequency: 40,
      tint: [0xff2bd6, 0x00f0ff, 0xfaff00, 0xff7a59, 0x7bffb5], emitting: false
    }).setDepth(30);

    this.setupInput();

    this.score = 0;
    this.lives = START_LIVES;
    this.levelIndex = 0;
    this.combo = 0;
    this.speed = 470;
    this.loadLevel(0, true);
  }

  // ---------- UI ----------
  createBubble() {
    this.bubble = this.add.container(0, 0).setDepth(40);
    const g = this.add.graphics();
    g.fillStyle(0xffffff, 0.96); g.fillRoundedRect(18, 16, PANEL_W - 36, 104, 22);
    g.fillTriangle(150, 118, 200, 118, 178, 150);
    g.lineStyle(3, 0x222244, 0.25); g.strokeRoundedRect(18, 16, PANEL_W - 36, 104, 22);
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
    if (ms > 0) {
      this.bubbleTimer = this.time.delayedCall(ms, () => {
        this.tweens.add({ targets: this.bubble, alpha: 0, duration: 300 });
      });
    }
  }

  createHud() {
    const style = { fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '26px', color: '#ffffff', stroke: '#000000', strokeThickness: 5 };
    this.scoreText = this.add.text(FIELD_X + 20, 16, '', style).setDepth(50);
    this.levelText = this.add.text(FIELD_X + FIELD_W / 2, 16, '', style).setOrigin(0.5, 0).setDepth(50);
    this.livesText = this.add.text(W - 80, 16, '', { ...style, color: '#ff4f8b' }).setOrigin(1, 0).setDepth(50);
    this.muteText = this.add.text(W - 20, 14, '🔊', { fontSize: '30px' }).setOrigin(1, 0).setDepth(50)
      .setInteractive({ useHandCursor: true })
      .on('pointerdown', (p, x, y, e) => {
        e.stopPropagation();
        this.sfx.muted = !this.sfx.muted;
        this.muteText.setText(this.sfx.muted ? '🔇' : '🔊');
      });
    this.centerText = this.add.text(FIELD_X + FIELD_W / 2, 440, '', {
      ...style, fontSize: '30px', align: 'center', wordWrap: { width: FIELD_W - 80 }
    }).setOrigin(0.5).setDepth(50);
    this.bigText = this.add.text(FIELD_X + FIELD_W / 2, 300, '', {
      ...style, fontSize: '64px', color: '#ffd700', strokeThickness: 10, align: 'center'
    }).setOrigin(0.5).setDepth(50);
  }

  updateHud() {
    this.scoreText.setText(`★ ${this.score}`);
    this.levelText.setText(`${this.levelIndex + 1}/${THEMES.length} · ${this.theme.name}`);
    this.livesText.setText('♥'.repeat(Math.max(this.lives, 0)));
  }

  floatText(x, y, text, color = '#ffffff') {
    const t = this.add.text(x, y, text, {
      fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '22px', color, stroke: '#000', strokeThickness: 4
    }).setOrigin(0.5).setDepth(25);
    this.tweens.add({ targets: t, y: y - 50, alpha: 0, duration: 700, onComplete: () => t.destroy() });
  }

  // ---------- input ----------
  setupInput() {
    this.dragStartX = 0;
    this.input.on('pointerdown', (p) => {
      this.sfx.unlock();
      this.lastX = p.x;
      this.dragStartX = p.x;
    });
    this.input.on('pointermove', (p) => {
      if (!p.isDown || this.state === 'over' || this.state === 'won') return;
      const dx = (p.x - this.lastX) * 1.35;
      this.lastX = p.x;
      this.movePaddle(this.paddle.x + dx);
    });
    this.input.on('pointerup', (p) => {
      const tap = Math.abs(p.x - this.dragStartX) < 18;
      if (!tap) return;
      if (this.state === 'ready') this.launch();
      else if (this.state === 'over' || this.state === 'won') this.restart();
    });

    this.keys = this.input.keyboard.createCursorKeys();
    this.input.keyboard.on('keydown-SPACE', () => {
      this.sfx.unlock();
      if (this.state === 'ready') this.launch();
      else if (this.state === 'over' || this.state === 'won') this.restart();
    });
  }

  movePaddle(x) {
    const half = this.paddle.displayWidth / 2;
    this.paddle.x = Phaser.Math.Clamp(x, FIELD_X + half, W - half);
  }

  // ---------- levels ----------
  loadLevel(index, first = false) {
    this.levelIndex = index;
    this.theme = THEMES[index];
    this.speed = 470 + index * 35;
    drawBackground(this, this.bg, this.theme, PANEL_W, W, H);

    this.bricks.clear(true, true);
    this.balls.clear(true, true);
    this.clearCapsules();

    const layout = this.theme.layout;
    const cols = layout[0].length;
    const startX = FIELD_X + (FIELD_W - cols * BRICK_W) / 2 + BRICK_W / 2;
    layout.forEach((row, r) => {
      [...row].forEach((ch, c) => {
        if (ch === '.') return;
        const x = startX + c * BRICK_W;
        const y = BRICK_TOP + r * BRICK_H;
        if (ch === 'X') {
          const b = this.bricks.create(x, y, 'brickX');
          b.setData('hp', Infinity);
        } else {
          const hp = Number(ch);
          const b = this.bricks.create(x, y, 'brick');
          b.setData('hp', hp);
          b.setData('color', this.theme.bricks[hp - 1]);
          b.setTint(this.theme.bricks[hp - 1]);
          // drop-in animation
          b.setScale(0);
          this.tweens.add({ targets: b, scale: 1, duration: 300, delay: (r * cols + c) * 12, ease: 'Back.easeOut' });
        }
      });
    });

    this.paddle.setTint(this.theme.paddle).setScale(1, 1);
    this.paddle.x = FIELD_X + FIELD_W / 2;
    this.paddle.body.updateFromGameObject();
    this.resetEffects();
    this.combo = 0;

    if (first) {
      this.heroine.setTheme(this.theme);
      this.heroine.idle();
      this.say('Привіт! Тапни, щоб почати!', 0);
    } else {
      this.heroine.changeOutfit(this.theme, () => this.say(this.theme.hello, 2600));
      this.stars.explode(30, PANEL_W / 2, 330);
    }

    this.bigText.setText('');
    this.updateHud();
    this.readyBall();
  }

  readyBall() {
    this.state = 'ready';
    const ball = this.balls.create(this.paddle.x, PADDLE_Y - 24, 'ball');
    ball.setTint(this.theme.ball);
    ball.body.setCircle(11);
    ball.body.allowGravity = false;
    ball.setData('onPaddle', true);
    this.centerText.setText('Тапни — запуск\nВеди пальцем — платформа');
  }

  launch() {
    this.state = 'play';
    this.centerText.setText('');
    this.balls.getChildren().forEach((b) => {
      if (!b.getData('onPaddle')) return;
      b.setData('onPaddle', false);
      this.setupBallPhysics(b);
      const angle = Phaser.Math.DegToRad(Phaser.Math.Between(-25, 25));
      b.setVelocity(Math.sin(angle) * this.currentSpeed(), -Math.cos(angle) * this.currentSpeed());
    });
    this.sfx.paddle();
    this.scheduleChatter();
  }

  setupBallPhysics(b) {
    b.setCollideWorldBounds(true);
    b.setBounce(1);
    b.body.onWorldBounds = true;
  }

  currentSpeed() { return this.slowTimer ? this.speed * 0.72 : this.speed; }

  // ---------- collisions ----------
  onPaddleHit(paddle, ball) {
    const half = paddle.displayWidth / 2;
    const diff = Phaser.Math.Clamp((ball.x - paddle.x) / half, -1, 1);
    const angle = Phaser.Math.DegToRad(diff * 62);
    const s = this.currentSpeed();
    ball.setVelocity(Math.sin(angle) * s, -Math.cos(angle) * s);
    this.combo = 0;
    this.sfx.paddle();
    this.tweens.add({ targets: paddle, scaleY: 0.7, duration: 70, yoyo: true });
  }

  onBrickHit(ball, brick) {
    const hp = brick.getData('hp');
    if (hp === Infinity) {
      this.sfx.hard();
      this.tweens.add({ targets: brick, alpha: 0.6, duration: 60, yoyo: true });
      return;
    }
    if (hp > 1) {
      brick.setData('hp', hp - 1);
      const col = this.theme.bricks[hp - 2];
      brick.setTint(col);
      brick.setData('color', col);
      if (!brick.getData('crack')) {
        brick.setData('crack', this.add.image(brick.x, brick.y, 'crack').setDepth(1));
      }
      this.sfx.hard();
      this.tweens.add({ targets: brick, scaleX: 1.1, scaleY: 1.1, duration: 60, yoyo: true });
      return;
    }

    this.combo += 1;
    const points = 10 + (this.combo - 1) * 5;
    this.score += points;
    this.sfx.brick(this.combo);
    this.sparks.setParticleTint(brick.getData('color'));
    this.sparks.explode(14, brick.x, brick.y);
    this.floatText(brick.x, brick.y, `+${points}`);
    const crack = brick.getData('crack');
    if (crack) crack.destroy();
    const { x, y } = brick;
    brick.destroy();

    if (Math.random() < 0.15) this.spawnCapsule(x, y);

    if (this.combo >= 3 && this.combo % 3 === 0) {
      this.heroine.cheer();
      this.say(Phaser.Utils.Array.GetRandom(PHRASES.combo).replace('{n}', this.combo), 1500);
      this.stars.explode(16, PANEL_W / 2, 250);
      this.sfx.combo();
    }

    this.updateHud();
    if (this.breakableLeft() === 0) this.levelComplete();
  }

  breakableLeft() {
    return this.bricks.getChildren().filter((b) => b.getData('hp') !== Infinity).length;
  }

  // ---------- bonuses ----------
  spawnCapsule(x, y) {
    const type = Phaser.Utils.Array.GetRandom(Object.keys(BONUSES));
    const info = BONUSES[type];
    const cap = this.capsules.create(x, y, 'capsule').setTint(info.color);
    cap.body.allowGravity = false;
    cap.setVelocityY(190);
    cap.setData('type', type);
    cap.setData('label', this.add.text(x, y, info.label, {
      fontFamily: 'Arial Black, Arial, sans-serif', fontSize: '18px', color: '#ffffff', stroke: '#000', strokeThickness: 3
    }).setOrigin(0.5).setDepth(6));
  }

  onCatchCapsule(paddle, cap) {
    const type = cap.getData('type');
    cap.getData('label').destroy();
    cap.destroy();
    this.applyBonus(type);
  }

  clearCapsules() {
    this.capsules.getChildren().forEach((c) => c.getData('label') && c.getData('label').destroy());
    this.capsules.clear(true, true);
  }

  applyBonus(type) {
    const info = BONUSES[type];
    this.sfx.bonus();
    this.heroine.surprised();
    this.say(info.say, 1600);
    this.score += 25;
    this.floatText(this.paddle.x, PADDLE_Y - 30, info.say, '#' + info.color.toString(16).padStart(6, '0'));

    if (type === 'wide') {
      if (this.wideTimer) this.wideTimer.remove();
      this.tweens.add({ targets: this.paddle, scaleX: 1.55, duration: 200 });
      this.wideTimer = this.time.delayedCall(12000, () => {
        this.wideTimer = null;
        this.tweens.add({ targets: this.paddle, scaleX: 1, duration: 200, onUpdate: () => this.movePaddle(this.paddle.x) });
      });
    } else if (type === 'multi') {
      const source = this.balls.getChildren().find((b) => !b.getData('onPaddle'));
      if (source) {
        [-0.45, 0.45].forEach((rot) => {
          const v = source.body.velocity.clone().rotate(rot);
          const nb = this.balls.create(source.x, source.y, 'ball').setTint(this.theme.ball);
          nb.body.setCircle(11);
          nb.body.allowGravity = false;
          nb.setData('onPaddle', false);
          this.setupBallPhysics(nb);
          nb.setVelocity(v.x, v.y < 0 ? v.y : -Math.abs(v.y));
        });
      }
    } else if (type === 'slow') {
      if (this.slowTimer) this.slowTimer.remove();
      this.slowTimer = this.time.delayedCall(10000, () => { this.slowTimer = null; });
    } else if (type === 'life') {
      this.lives = Math.min(this.lives + 1, 6);
    }
    this.updateHud();
  }

  resetEffects() {
    if (this.wideTimer) { this.wideTimer.remove(); this.wideTimer = null; }
    if (this.slowTimer) { this.slowTimer.remove(); this.slowTimer = null; }
    this.paddle.setScale(1, 1);
  }

  // ---------- life / win ----------
  loseLife() {
    this.lives -= 1;
    this.combo = 0;
    this.sfx.lose();
    this.cameras.main.shake(250, 0.008);
    this.clearCapsules();
    this.resetEffects();
    this.updateHud();

    if (this.lives <= 0) {
      this.state = 'over';
      this.heroine.sad();
      this.heroine.resetTimer && this.heroine.resetTimer.remove();
      this.say('Не здавайся! Спробуймо ще раз?', 0);
      this.sfx.gameOver();
      this.bigText.setText('GAME OVER').setColor('#ff4f8b');
      this.centerText.setText(`Рахунок: ${this.score}\nТапни, щоб грати знову`);
      return;
    }
    this.state = 'wait';
    this.heroine.sad();
    this.say(Phaser.Utils.Array.GetRandom(PHRASES.sad), 1800);
    this.time.delayedCall(700, () => { if (this.state === 'wait') this.readyBall(); });
  }

  levelComplete() {
    this.state = 'transition';
    this.balls.clear(true, true);
    this.clearCapsules();
    this.sfx.win();
    this.heroine.victory();
    this.confetti.start();
    this.time.delayedCall(1800, () => this.confetti.stop());
    this.score += 100 * (this.levelIndex + 1);
    this.updateHud();

    const last = this.levelIndex === THEMES.length - 1;
    if (last) {
      this.state = 'won';
      this.say('Ти справжній чемпіон! 👑', 0);
      this.bigText.setText('ПЕРЕМОГА!').setColor('#ffd700');
      this.centerText.setText(`Рахунок: ${this.score}\nТапни, щоб грати знову`);
      this.time.addEvent({ delay: 2500, loop: true, callback: () => { if (this.state === 'won') this.stars.explode(20, PANEL_W / 2, 300); } });
      return;
    }
    this.say(Phaser.Utils.Array.GetRandom(PHRASES.win), 2400);
    this.bigText.setText(`РІВЕНЬ ${this.levelIndex + 1} ✓`).setColor('#ffd700');
    this.time.delayedCall(2600, () => this.loadLevel(this.levelIndex + 1));
  }

  restart() {
    this.time.removeAllEvents();
    this.confetti.stop();
    this.score = 0;
    this.lives = START_LIVES;
    this.bigText.setText('');
    this.heroine.setTheme(THEMES[0]);
    this.loadLevel(0, true);
    this.say('Поїхали ще раз!', 1800);
    this.heroine.cheer();
  }

  scheduleChatter() {
    if (this.chatter) this.chatter.remove();
    this.chatter = this.time.delayedCall(Phaser.Math.Between(9000, 15000), () => {
      if (this.state === 'play' && !this.heroine.busy) this.say(Phaser.Utils.Array.GetRandom(PHRASES.idle), 1800);
      if (this.state === 'play') this.scheduleChatter();
    });
  }

  // ---------- loop ----------
  update(time, delta) {
    this.heroine.tick(time, delta);

    if (this.keys.left.isDown) this.movePaddle(this.paddle.x - 0.9 * delta);
    if (this.keys.right.isDown) this.movePaddle(this.paddle.x + 0.9 * delta);

    const s = this.currentSpeed();
    this.balls.getChildren().slice().forEach((b) => {
      if (b.getData('onPaddle')) {
        b.x = this.paddle.x;
        b.y = PADDLE_Y - 24;
        b.body.reset(b.x, b.y);
        return;
      }
      // keep constant speed and avoid near-horizontal endless bouncing
      const v = b.body.velocity;
      if (Math.abs(v.y) < s * 0.28) v.y = (v.y < 0 ? -1 : 1) * s * 0.28;
      v.normalize().scale(s);
      if (b.y > H + 30) b.destroy();
    });

    this.capsules.getChildren().slice().forEach((c) => {
      const label = c.getData('label');
      label.setPosition(c.x, c.y);
      if (c.y > H + 30) { label.destroy(); c.destroy(); }
    });

    if (this.state === 'play' && this.balls.countActive() === 0) this.loseLife();
  }
}
