import Phaser from 'phaser';

// Space waves: star light color, asteroid colors, background and asteroid formation.
// Layout chars: '.' empty, '1'-'3' asteroid size/hits, 'X' armored asteroid (6 hits).
export const LEVELS = [
  {
    name: 'Пояс астероїдів',
    light: 0xfff1b0, star: 0xffe27a,
    spaceTop: 0x05061a, spaceBottom: 0x140c33, nebula: 0x6b3fa0,
    rock: 0x7a685a, armor: 0x8a93a6,
    descend: 5, meteorEvery: 6,
    hello: 'Пілоте, бачу пояс астероїдів! Вогонь!',
    layout: [
      '...........',
      '.111111111.',
      '.122222221.',
      '.123333321.',
      '.111111111.'
    ]
  },
  {
    name: 'Метеорний дощ',
    light: 0xffc08a, star: 0xff9a3d,
    spaceTop: 0x0a0410, spaceBottom: 0x2a0f1f, nebula: 0xa0402f,
    rock: 0x7a4f3e, armor: 0x8d8a99,
    descend: 6.5, meteorEvery: 3.2,
    hello: 'Метеорний дощ! Ухиляйся!',
    layout: [
      '.....3.....',
      '....222....',
      '...11111...',
      '..2221222..',
      '.X1111111X.',
      '..2221222..'
    ]
  },
  {
    name: 'Крижані комети',
    light: 0xd6ecff, star: 0x9fd2ff,
    spaceTop: 0x020a1a, spaceBottom: 0x0b2440, nebula: 0x2f6fa0,
    rock: 0x5f86a8, armor: 0x9aa7bd,
    descend: 7.5, meteorEvery: 2.8,
    hello: 'Тут холодно... але ми впораємось!',
    layout: [
      '3.3.3.3.3.3',
      '.2.2.2.2.2.',
      '1111111111.',
      '.1111111111',
      '2X2X2.2X2X2',
      '11111111111'
    ]
  },
  {
    name: 'Вогняна зірка',
    light: 0xff8a5c, star: 0xff4a1f,
    spaceTop: 0x140202, spaceBottom: 0x3a0a06, nebula: 0xc0391f,
    rock: 0x4a3030, armor: 0x7d6f6f, lava: true,
    descend: 8.5, meteorEvery: 2.2,
    hello: 'Фінал біля червоного гіганта!',
    layout: [
      'X.X.X.X.X.X',
      '33333333333',
      '2.2.2.2.2.2',
      '22222222222',
      '1.1.1.1.1.1',
      '11111111111'
    ]
  }
];

// ---- color helpers (hex ints) ----
export function mix(a, b, t) {
  const ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
  const br = (b >> 16) & 255, bg = (b >> 8) & 255, bb = b & 255;
  return (Math.round(ar + (br - ar) * t) << 16) | (Math.round(ag + (bg - ag) * t) << 8) | Math.round(ab + (bb - ab) * t);
}
export const darken = (c, t) => mix(c, 0x000000, t);

// Static backdrop: heroine cockpit panel + deep space with nebula.
export function drawBackdrop(g, lv, seed, panelW, w, h) {
  g.clear();
  const rnd = new Phaser.Math.RandomDataGenerator([String(seed)]);

  g.fillGradientStyle(lv.spaceTop, lv.spaceTop, lv.spaceBottom, lv.spaceBottom, 1);
  g.fillRect(panelW, 0, w - panelW, h);
  for (let i = 0; i < 7; i++) {
    const cx = rnd.realInRange(panelW + 100, w), cy = rnd.realInRange(80, h - 80);
    const r = rnd.realInRange(90, 200);
    for (let k = 0; k < 12; k++) {
      g.fillStyle(lv.nebula, 0.016);
      g.fillCircle(cx, cy, r * (1 - k * 0.075));
    }
  }

  // cockpit panel
  g.fillGradientStyle(lv.spaceTop, lv.spaceTop, lv.spaceBottom, lv.spaceBottom, 1);
  g.fillRect(0, 0, panelW, h);
  for (let i = 0; i < 70; i++) {
    g.fillStyle(0xffffff, rnd.realInRange(0.3, 1));
    g.fillCircle(rnd.realInRange(0, panelW), rnd.realInRange(0, 520), rnd.realInRange(0.6, 1.8));
  }
  g.fillStyle(darken(lv.rock, 0.3), 1); g.fillCircle(70, 230, 46);
  g.fillStyle(mix(lv.rock, lv.light, 0.25), 1); g.fillCircle(56, 220, 40);
  g.fillStyle(0x1b2030, 1); g.fillRect(0, 640, panelW, 80);
  g.fillStyle(0x39ff6a, 0.7); g.fillRect(0, 640, panelW, 4);
  [0x39ff6a, 0xffd23f, 0xff4f6a].forEach((c, i) => {
    g.fillStyle(c, 1); g.fillCircle(40 + i * 55, 680, 6); g.fillCircle(40 + (i + 3) * 55, 680, 6);
  });
  g.fillStyle(0x39ff6a, 0.8); g.fillRect(panelW - 4, 0, 4, h);
}
