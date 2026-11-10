// Web Audio API Synthesizer for Lifemaxx OS / APEX Engine
// Features: Multi-Frequency Binaural Beats (Gamma 40Hz, Alpha 10Hz, Theta 6Hz, Delta 2Hz), Brown Noise Generator, CRED Haptics, Coin Chimes, Health Sync, Heartbeats

let audioCtx = null;

const getAudioContext = () => {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
};

// 1. CRED Tactile Plunk (Deep Sub-Bass + High Snap)
export const playPlunk = () => {
  try {
    const ctx = getAudioContext();
    const t = ctx.currentTime;

    // Sub-bass thump
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(160, t);
    osc.frequency.exponentialRampToValueAtTime(35, t + 0.08);

    gain.gain.setValueAtTime(0.28, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.08);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.08);

    // Crisp high snap click
    const clickOsc = ctx.createOscillator();
    const clickGain = ctx.createGain();
    clickOsc.type = 'sine';
    clickOsc.frequency.setValueAtTime(2400, t);
    clickOsc.frequency.exponentialRampToValueAtTime(400, t + 0.02);
    clickGain.gain.setValueAtTime(0.12, t);
    clickGain.gain.exponentialRampToValueAtTime(0.001, t + 0.02);

    clickOsc.connect(clickGain);
    clickGain.connect(ctx.destination);
    clickOsc.start(t);
    clickOsc.stop(t + 0.02);
  } catch {}
};

// 2. CRED Coin / Reward Chime (Two-tone crystal chime)
export const playCoinChime = () => {
  try {
    const ctx = getAudioContext();
    const t = ctx.currentTime;

    const playTone = (freq, delay, dur) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, t + delay);
      gain.gain.setValueAtTime(0.2, t + delay);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + delay + dur);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t + delay);
      osc.stop(t + delay + dur);
    };

    playTone(987.77, 0, 0.15); // B5
    playTone(1318.51, 0.08, 0.28); // E6
    playTone(1975.53, 0.16, 0.4); // B6
  } catch {}
};

// 3. Apple Health Sync Chime (Warm harmonic sweep)
export const playHealthSyncChime = () => {
  try {
    const ctx = getAudioContext();
    const t = ctx.currentTime;

    [523.25, 659.25, 783.99, 1046.50].forEach((freq, idx) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, t + idx * 0.06);
      gain.gain.setValueAtTime(0.18, t + idx * 0.06);
      gain.gain.exponentialRampToValueAtTime(0.001, t + idx * 0.06 + 0.35);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t + idx * 0.06);
      osc.stop(t + idx * 0.06 + 0.35);
    });
  } catch {}
};

// 4. Heartbeat Sound (Dual low thump: lub-dub)
export const playHeartbeat = () => {
  try {
    const ctx = getAudioContext();
    const t = ctx.currentTime;

    const lub = ctx.createOscillator();
    const lubGain = ctx.createGain();
    lub.type = 'sine';
    lub.frequency.setValueAtTime(70, t);
    lub.frequency.exponentialRampToValueAtTime(30, t + 0.1);
    lubGain.gain.setValueAtTime(0.25, t);
    lubGain.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    lub.connect(lubGain);
    lubGain.connect(ctx.destination);
    lub.start(t);
    lub.stop(t + 0.1);

    const dub = ctx.createOscillator();
    const dubGain = ctx.createGain();
    dub.type = 'sine';
    dub.frequency.setValueAtTime(60, t + 0.14);
    dub.frequency.exponentialRampToValueAtTime(25, t + 0.22);
    dubGain.gain.setValueAtTime(0.2, t + 0.14);
    dubGain.gain.exponentialRampToValueAtTime(0.001, t + 0.22);
    dub.connect(dubGain);
    dubGain.connect(ctx.destination);
    dub.start(t + 0.14);
    dub.stop(t + 0.22);
  } catch {}
};

// 5. Jackpot / Wheel Tick
export const playWheelTick = () => {
  try {
    const ctx = getAudioContext();
    const t = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1400, t);
    gain.gain.setValueAtTime(0.12, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.025);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.025);
  } catch {}
};

// 6. Generic Haptic Click
export const playHaptic = (freq = 800, type = 'sine', duration = 0.05) => {
  try {
    const ctx = getAudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  } catch {}
};

// ==============================================================
// 7. MULTI-FREQUENCY BINAURAL BEATS ENGINE (GAMMA, ALPHA, THETA, DELTA)
// ==============================================================
let activeOscLeft = null;
let activeOscRight = null;
let activeBinauralGain = null;
let currentFreqType = null;

export const FREQUENCIES = {
  gamma: { label: '40Hz Gamma', base: 200, diff: 40, desc: 'Peak Neural Flow & Focus' },
  alpha: { label: '10Hz Alpha', base: 200, diff: 10, desc: 'Calm Alertness & Creativity' },
  theta: { label: '6Hz Theta', base: 180, diff: 6, desc: 'Deep Meditation & Hypnagogia' },
  delta: { label: '2Hz Delta', base: 150, diff: 2, desc: 'Stage 4 Slow-Wave Sleep' },
};

export const toggleBinaural = (freqType = 'gamma', start = true) => {
  try {
    const ctx = getAudioContext();

    if (!start || (activeOscLeft && currentFreqType === freqType)) {
      if (activeOscLeft) {
        activeOscLeft.stop();
        activeOscRight.stop();
        activeOscLeft = null;
        activeOscRight = null;
        currentFreqType = null;
      }
      return false;
    }

    // Stop current if switching frequency
    if (activeOscLeft) {
      activeOscLeft.stop();
      activeOscRight.stop();
      activeOscLeft = null;
      activeOscRight = null;
    }

    const config = FREQUENCIES[freqType] || FREQUENCIES.gamma;
    currentFreqType = freqType;

    activeBinauralGain = ctx.createGain();
    activeBinauralGain.gain.setValueAtTime(0.06, ctx.currentTime);

    activeOscLeft = ctx.createOscillator();
    activeOscLeft.type = 'sine';
    activeOscLeft.frequency.setValueAtTime(config.base, ctx.currentTime);

    activeOscRight = ctx.createOscillator();
    activeOscRight.type = 'sine';
    activeOscRight.frequency.setValueAtTime(config.base + config.diff, ctx.currentTime);

    activeOscLeft.connect(activeBinauralGain);
    activeOscRight.connect(activeBinauralGain);
    activeBinauralGain.connect(ctx.destination);

    activeOscLeft.start();
    activeOscRight.start();
    return true;
  } catch {
    return false;
  }
};

// Backwards compatibility for gamma toggle
export const toggleGammaBeats = (start = true) => toggleBinaural('gamma', start);

// ==============================================================
// 8. DEEP BROWN NOISE SYNTHESIZER
// ==============================================================
let brownNoiseNode = null;
let brownNoiseGain = null;

export const toggleBrownNoise = (start = true) => {
  try {
    const ctx = getAudioContext();
    if (!start || brownNoiseNode) {
      if (brownNoiseNode) {
        brownNoiseNode.stop();
        brownNoiseNode.disconnect();
        brownNoiseNode = null;
      }
      return false;
    }

    const bufferSize = 2 * ctx.sampleRate;
    const noiseBuffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    let lastOut = 0.0;

    // Brown noise algorithm (integrated white noise)
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      output[i] = (lastOut + 0.02 * white) / 1.02;
      lastOut = output[i];
      output[i] *= 3.5; // Gain compensation
    }

    brownNoiseNode = ctx.createBufferSource();
    brownNoiseNode.buffer = noiseBuffer;
    brownNoiseNode.loop = true;

    brownNoiseGain = ctx.createGain();
    brownNoiseGain.gain.setValueAtTime(0.08, ctx.currentTime);

    brownNoiseNode.connect(brownNoiseGain);
    brownNoiseGain.connect(ctx.destination);
    brownNoiseNode.start();
    return true;
  } catch {
    return false;
  }
};
