import Phaser from 'phaser';

// Generates all game textures with code, so the game has no image files.
export default class BootScene extends Phaser.Scene {
  constructor() { super('Boot'); }

  create() {
    const g = this.add.graphics();

    // ball
    g.fillStyle(0xffffff, 1); g.fillCircle(11, 11, 11);
    g.fillStyle(0xdddddd, 1); g.fillCircle(13, 13, 8);
    g.fillStyle(0xffffff, 1); g.fillCircle(8, 8, 4);
    g.generateTexture('ball', 22, 22); g.clear();

    // paddle (white, tinted per theme)
    g.fillStyle(0xbbbbbb, 1); g.fillRoundedRect(0, 0, 150, 24, 12);
    g.fillStyle(0xffffff, 1); g.fillRoundedRect(0, 0, 150, 18, 10);
    g.fillStyle(0xffffff, 0.6); g.fillRoundedRect(10, 3, 130, 5, 3);
    g.generateTexture('paddle', 150, 24); g.clear();

    // brick (white, tinted per theme)
    g.fillStyle(0xaaaaaa, 1); g.fillRoundedRect(0, 0, 76, 30, 6);
    g.fillStyle(0xffffff, 1); g.fillRoundedRect(0, 0, 76, 26, 6);
    g.fillStyle(0xffffff, 0.7); g.fillRect(6, 4, 64, 4);
    g.generateTexture('brick', 76, 30); g.clear();

    // cracked overlay for damaged bricks
    g.lineStyle(2, 0x000000, 0.45);
    g.beginPath(); g.moveTo(20, 2); g.lineTo(28, 12); g.lineTo(22, 18); g.lineTo(32, 28); g.strokePath();
    g.beginPath(); g.moveTo(52, 4); g.lineTo(46, 14); g.lineTo(56, 24); g.strokePath();
    g.generateTexture('crack', 76, 30); g.clear();

    // unbreakable brick
    g.fillStyle(0x55596a, 1); g.fillRoundedRect(0, 0, 76, 30, 6);
    g.fillStyle(0x8d93a8, 1); g.fillRoundedRect(0, 0, 76, 26, 6);
    g.fillStyle(0xc9cede, 1);
    [[8, 8], [68, 8], [8, 20], [68, 20]].forEach(([x, y]) => g.fillCircle(x, y, 3));
    g.generateTexture('brickX', 76, 30); g.clear();

    // capsule for bonuses
    g.fillStyle(0xffffff, 1); g.fillRoundedRect(0, 0, 54, 24, 12);
    g.fillStyle(0xffffff, 0.5); g.fillRoundedRect(6, 3, 42, 5, 3);
    g.generateTexture('capsule', 54, 24); g.clear();

    // particles
    g.fillStyle(0xffffff, 1); g.fillCircle(5, 5, 5);
    g.generateTexture('spark', 10, 10); g.clear();
    g.fillStyle(0xffffff, 1);
    g.fillPoints([{ x: 8, y: 0 }, { x: 10, y: 6 }, { x: 16, y: 8 }, { x: 10, y: 10 }, { x: 8, y: 16 }, { x: 6, y: 10 }, { x: 0, y: 8 }, { x: 6, y: 6 }], true);
    g.generateTexture('star', 16, 16); g.clear();
    g.fillStyle(0xffffff, 1); g.fillRect(0, 0, 8, 14);
    g.generateTexture('confetti', 8, 14);

    g.destroy();
    this.scene.start('Game');
  }
}
