// Tiny synth: all game sounds are generated, no audio files needed.
export default class Sfx {
  constructor() {
    this.ctx = null;
    this.muted = false;
  }

  unlock() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
  }

  tone(freq, dur = 0.1, type = 'square', vol = 0.15, slideTo = null, delay = 0) {
    if (this.muted || !this.ctx) return;
    const t = this.ctx.currentTime + delay;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  paddle() { this.tone(330, 0.08, 'square', 0.12); }
  wall() { this.tone(220, 0.05, 'triangle', 0.1); }
  brick(combo = 0) { this.tone(520 + Math.min(combo, 12) * 45, 0.09, 'square', 0.12); }
  hard() { this.tone(160, 0.07, 'sawtooth', 0.1); }
  bonus() { [660, 880, 1100].forEach((f, i) => this.tone(f, 0.1, 'triangle', 0.14, null, i * 0.07)); }
  combo() { [784, 988, 1175, 1568].forEach((f, i) => this.tone(f, 0.09, 'square', 0.1, null, i * 0.05)); }
  lose() { this.tone(440, 0.5, 'sawtooth', 0.14, 110); }
  win() { [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone(f, 0.16, 'triangle', 0.16, null, i * 0.12)); }
  gameOver() { [392, 330, 262, 196].forEach((f, i) => this.tone(f, 0.3, 'triangle', 0.15, null, i * 0.22)); }
}
