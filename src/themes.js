import Phaser from 'phaser';

// Each level = one theme: heroine outfit, colors, background and brick layout.
// Layout chars: '.' empty, '1'-'3' hits needed, 'X' unbreakable.

export const THEMES = [
  {
    key: 'beach',
    name: 'Пляж',
    skyTop: 0x5ec8f2, skyBottom: 0xffd59e,
    field: 0x0f3d5c,
    accent: 0xff7a59,
    ball: 0xffffff,
    paddle: 0xffb347,
    bricks: [0xff7a59, 0xffc145, 0x4ecdc4],
    hello: 'Привіт! Літо, сонце і м\'ячик!',
    layout: [
      '...........',
      '.111111111.',
      '.122222221.',
      '.123333321.',
      '.122222221.',
      '.111111111.'
    ]
  },
  {
    key: 'neon',
    name: 'Неон-сіті',
    skyTop: 0x12002b, skyBottom: 0x3a0a5e,
    field: 0x0a0018,
    accent: 0x00f0ff,
    ball: 0x00f0ff,
    paddle: 0xff2bd6,
    bricks: [0xff2bd6, 0x00f0ff, 0xfaff00],
    hello: 'Нічне місто світиться для нас!',
    layout: [
      '.....3.....',
      '....222....',
      '...11111...',
      '..2221222..',
      '.X1111111X.',
      '..2221222..',
      '...11111...',
      '....222....'
    ]
  },
  {
    key: 'space',
    name: 'Космос',
    skyTop: 0x02021a, skyBottom: 0x1b1450,
    field: 0x03031a,
    accent: 0xffffff,
    ball: 0xfff3b0,
    paddle: 0x9fb4ff,
    bricks: [0x9fb4ff, 0xc39bff, 0xff9bd2],
    hello: 'Відкритий космос! Летимо!',
    layout: [
      '3.3.3.3.3.3',
      '.2.2.2.2.2.',
      '1111111111.',
      '.1111111111',
      '2X2X2.2X2X2',
      '11111111111',
      '.3.......3.'
    ]
  },
  {
    key: 'fantasy',
    name: 'Казка',
    skyTop: 0x2b1055, skyBottom: 0xd16ba5,
    field: 0x1a0b33,
    accent: 0xffd700,
    ball: 0xffd700,
    paddle: 0xb57bff,
    bricks: [0x7bffb5, 0xb57bff, 0xffd700],
    hello: 'Фінальний рівень. Корона чекає!',
    layout: [
      'X.X.X.X.X.X',
      '33333333333',
      '2.2.2.2.2.2',
      '22222222222',
      '1.1.1.1.1.1',
      '11111111111',
      '11111111111',
      'XX.......XX'
    ]
  }
];

// Draws the theme background for the heroine panel and the play field.
export function drawBackground(scene, g, theme, panelW, w, h) {
  g.clear();
  // panel sky gradient
  g.fillGradientStyle(theme.skyTop, theme.skyTop, theme.skyBottom, theme.skyBottom, 1);
  g.fillRect(0, 0, panelW, h);
  // field
  g.fillStyle(theme.field, 1);
  g.fillRect(panelW, 0, w - panelW, h);

  const rnd = new Phaser.Math.RandomDataGenerator([theme.key]);

  if (theme.key === 'beach') {
    g.fillStyle(0xfff3a0, 1); g.fillCircle(270, 110, 46);
    g.fillStyle(0xfff3a0, 0.25); g.fillCircle(270, 110, 70);
    g.fillStyle(0x1e90c8, 1); g.fillRect(0, 520, panelW, 200);
    g.fillStyle(0x7fd4f5, 1);
    for (let i = 0; i < 4; i++) g.fillRect(0, 530 + i * 26, panelW, 6);
    g.fillStyle(0xf2d29b, 1); g.fillRect(0, 640, panelW, 80);
    // palm
    g.fillStyle(0x8b5a2b, 1); g.fillRect(36, 300, 14, 340);
    g.fillStyle(0x2e8b57, 1);
    g.fillEllipse(10, 300, 90, 26); g.fillEllipse(80, 296, 90, 26); g.fillEllipse(44, 280, 26, 70);
    // field waves
    g.lineStyle(2, 0x1a5a85, 0.6);
    for (let y = 60; y < h; y += 70) {
      g.beginPath();
      for (let x = panelW; x <= w; x += 20) {
        const yy = y + Math.sin(x / 40) * 6;
        if (x === panelW) g.moveTo(x, yy); else g.lineTo(x, yy);
      }
      g.strokePath();
    }
  } else if (theme.key === 'neon') {
    // skyline
    for (let i = 0; i < 9; i++) {
      const bw = 30 + rnd.between(0, 20);
      const bh = 120 + rnd.between(0, 220);
      const x = i * 40;
      g.fillStyle(0x1b0638, 1); g.fillRect(x, 640 - bh, bw, bh);
      for (let wy = 640 - bh + 10; wy < 630; wy += 18) {
        for (let wx = x + 5; wx < x + bw - 6; wx += 10) {
          if (rnd.frac() > 0.55) { g.fillStyle(rnd.pick([0xff2bd6, 0x00f0ff, 0xfaff00]), 0.8); g.fillRect(wx, wy, 4, 6); }
        }
      }
    }
    g.fillStyle(0x0a0018, 1); g.fillRect(0, 640, panelW, 80);
    // neon grid field
    g.lineStyle(1, 0xff2bd6, 0.18);
    for (let x = panelW; x <= w; x += 46) g.lineBetween(x, 0, x, h);
    for (let y = 0; y <= h; y += 46) g.lineBetween(panelW, y, w, y);
  } else if (theme.key === 'space') {
    for (let i = 0; i < 160; i++) {
      g.fillStyle(0xffffff, rnd.realInRange(0.2, 1));
      g.fillCircle(rnd.between(0, w), rnd.between(0, h), rnd.realInRange(0.5, 2));
    }
    g.fillStyle(0xff9bd2, 1); g.fillCircle(80, 120, 50);
    g.lineStyle(6, 0xffd1ea, 0.8); g.strokeEllipse(80, 120, 160, 34);
    g.fillStyle(0x3a3a6a, 1); g.fillEllipse(180, 700, 520, 160);
  } else {
    // fantasy castle + sparkles
    for (let i = 0; i < 40; i++) {
      g.fillStyle(0xfff6c0, rnd.realInRange(0.3, 0.9));
      g.fillCircle(rnd.between(0, w), rnd.between(0, h), rnd.realInRange(1, 2.5));
    }
    g.fillStyle(0xf5f0ff, 0.9); g.fillCircle(290, 80, 34);
    g.fillStyle(0x2a1450, 1);
    g.fillRect(20, 420, 300, 220);
    g.fillRect(10, 330, 70, 310); g.fillRect(260, 330, 70, 310); g.fillRect(140, 300, 60, 340);
    g.fillTriangle(5, 330, 85, 330, 45, 260); g.fillTriangle(255, 330, 335, 330, 295, 260); g.fillTriangle(135, 300, 205, 300, 170, 220);
    g.fillStyle(0xffd700, 0.8);
    g.fillRect(38, 380, 12, 18); g.fillRect(290, 380, 12, 18); g.fillRect(164, 350, 12, 18);
    g.fillStyle(0x1a0b33, 1); g.fillRect(0, 640, panelW, 80);
  }

  // divider between panel and field
  g.fillStyle(theme.accent, 1);
  g.fillRect(panelW - 4, 0, 4, h);
}
