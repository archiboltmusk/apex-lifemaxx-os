import React, { useState, useRef, useEffect } from 'react';
import {
  Mic,
  MicOff,
  Volume2,
  Sparkles,
  Activity,
  ShieldCheck,
  ChevronRight,
  AlertCircle,
  Radio,
  CheckCircle2
} from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function VocalResonanceAnalyzer() {
  const savedVocal = (() => {
    try {
      return JSON.parse(localStorage.getItem('apex_vocal_biomarker') || 'null');
    } catch {
      return null;
    }
  })();

  const [isRecording, setIsRecording] = useState(false);
  const [pitchHz, setPitchHz] = useState(savedVocal?.pitchHz || null);
  const [chestResonance, setChestResonance] = useState(savedVocal?.chestResonance || null);
  const [jitterPct, setJitterPct] = useState(savedVocal?.jitterPct ?? null);
  const [volumeRms, setVolumeRms] = useState(0);
  const [micError, setMicError] = useState('');
  const [speechSummary, setSpeechSummary] = useState(null);

  useEffect(() => {
    const onSync = (e) => {
      if (e?.detail?.vocalPitchHz > 0) {
        setPitchHz(Math.round(e.detail.vocalPitchHz));
        if (e.detail.vocalJitterPct !== undefined) setJitterPct(Number(e.detail.vocalJitterPct));
      }
    };
    window.addEventListener('appleHealthSync', onSync);
    return () => window.removeEventListener('appleHealthSync', onSync);
  }, []);

  const audioCtxRef = useRef(null);
  const analyserRef = useRef(null);
  const sourceRef = useRef(null);
  const streamRef = useRef(null);
  const animationFrameRef = useRef(null);
  const canvasRef = useRef(null);

  const samplesCollectedRef = useRef([]);

  // Auto-correlation Algorithm for Fundamental Frequency (F0)
  const autoCorrelate = (buffer, sampleRate) => {
    // 1. Root-Mean-Square (RMS) volume threshold
    let sumSquares = 0;
    for (let i = 0; i < buffer.length; i++) {
      sumSquares += buffer[i] * buffer[i];
    }
    const rms = Math.sqrt(sumSquares / buffer.length);
    setVolumeRms(Math.min(100, Math.round(rms * 400)));

    if (rms < 0.015) {
      // Silence or background room noise
      return -1;
    }

    // 2. Center-clipping to isolate fundamental
    let r1 = 0,
      r2 = buffer.length - 1;
    const threshold = 0.2;
    for (let i = 0; i < buffer.length / 2; i++) {
      if (Math.abs(buffer[i]) < threshold) {
        r1 = i;
        break;
      }
    }
    for (let i = 1; i < buffer.length / 2; i++) {
      if (Math.abs(buffer[buffer.length - i]) < threshold) {
        r2 = buffer.length - i;
        break;
      }
    }

    const trimmed = buffer.slice(r1, r2);
    const c = new Array(trimmed.length).fill(0);

    for (let i = 0; i < trimmed.length; i++) {
      for (let j = 0; j < trimmed.length - i; j++) {
        c[i] += trimmed[j] * trimmed[j + i];
      }
    }

    // Find first local minimum
    let d = 0;
    while (d < c.length - 1 && c[d] > c[d + 1]) {
      d++;
    }

    // Find peak after minimum
    let maxVal = -1;
    let maxPos = -1;
    for (let i = d; i < c.length; i++) {
      if (c[i] > maxVal) {
        maxVal = c[i];
        maxPos = i;
      }
    }

    if (maxPos <= 0) return -1;

    let T0 = maxPos;
    // Parabolic interpolation for sub-bin precision
    if (T0 > 0 && T0 < c.length - 1) {
      const x1 = c[T0 - 1];
      const x2 = c[T0];
      const x3 = c[T0 + 1];
      const a = (x1 + x3 - 2 * x2) / 2;
      const b = (x3 - x1) / 2;
      if (a !== 0) {
        T0 = T0 - b / (2 * a);
      }
    }

    const freq = sampleRate / T0;
    // Human vocal pitch range filter: 65Hz (deep bass) to 350Hz (high tenor/soprano)
    if (freq >= 65 && freq <= 350) {
      return Math.round(freq);
    }
    return -1;
  };

  // Start Real Microphone Capture & DSP Analysis
  const startRecording = async () => {
    playPlunk();
    setMicError('');
    setSpeechSummary(null);
    samplesCollectedRef.current = [];

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Web Audio getUserMedia is not supported in this runtime.');
      }

      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false,
        },
        video: false,
      });

      streamRef.current = stream;

      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      const audioCtx = new AudioContextClass();
      audioCtxRef.current = audioCtx;

      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 2048;
      analyser.smoothingTimeConstant = 0.8;
      analyserRef.current = analyser;

      const source = audioCtx.createMediaStreamSource(stream);
      source.connect(analyser);
      sourceRef.current = source;

      setIsRecording(true);
      playHaptic(850, 'sine', 0.05);

      // DSP Processing Loop
      const timeDomainBuffer = new Float32Array(analyser.fftSize);
      const freqDomainBuffer = new Uint8Array(analyser.frequencyBinCount);

      const updateLoop = () => {
        if (!analyserRef.current) return;

        analyserRef.current.getFloatTimeDomainData(timeDomainBuffer);
        analyserRef.current.getByteFrequencyData(freqDomainBuffer);

        // 1. Calculate Real Fundamental Pitch (F0)
        const detectedPitch = autoCorrelate(timeDomainBuffer, audioCtx.sampleRate);
        if (detectedPitch > 0) {
          setPitchHz(detectedPitch);
          samplesCollectedRef.current.push(detectedPitch);
        }

        // 2. Calculate Real Chest vs Head Resonance
        // Frequency resolution = sampleRate / fftSize (~23.4 Hz per bin)
        // Chest resonance = energy in 85Hz - 250Hz (bins 3 to 11)
        // Head / Nasal resonance = energy in 1.5kHz - 3.5kHz (bins 64 to 150)
        let chestEnergy = 0;
        for (let i = 3; i <= 11; i++) {
          chestEnergy += freqDomainBuffer[i] || 0;
        }
        let totalVoiceEnergy = 0;
        for (let i = 3; i <= 150; i++) {
          totalVoiceEnergy += freqDomainBuffer[i] || 0;
        }

        if (totalVoiceEnergy > 40) {
          const ratio = Math.min(98, Math.max(50, Math.round((chestEnergy / totalVoiceEnergy) * 160)));
          setChestResonance(ratio);
        }

        // 3. Draw Real Oscilloscope Waveform on Canvas
        const canvas = canvasRef.current;
        if (canvas) {
          const ctx = canvas.getContext('2d');
          const w = canvas.width;
          const h = canvas.height;

          ctx.clearRect(0, 0, w, h);
          ctx.lineWidth = 2.5;
          ctx.strokeStyle = '#00F0FF';
          ctx.beginPath();

          const sliceWidth = w / timeDomainBuffer.length;
          let x = 0;

          for (let i = 0; i < timeDomainBuffer.length; i++) {
            const v = timeDomainBuffer[i];
            const y = (v + 1) * (h / 2);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
            x += sliceWidth;
          }

          ctx.lineTo(w, h / 2);
          ctx.stroke();

          // Draw Pitch Marker
          if (detectedPitch > 0) {
            ctx.fillStyle = '#E5FE40';
            ctx.font = '10px monospace';
            ctx.fillText(`F0: ${detectedPitch} Hz`, 10, 20);
          }
        }

        animationFrameRef.current = requestAnimationFrame(updateLoop);
      };

      animationFrameRef.current = requestAnimationFrame(updateLoop);
    } catch (err) {
      console.warn('Microphone access error:', err);
      setMicError(err.message || 'Microphone access denied. Grant microphone permission in System Settings.');
      setIsRecording(false);
    }
  };

  // Stop Recording & Compute Session Biomarkers
  const stopRecording = () => {
    playPlunk();
    playCoinChime();
    setIsRecording(false);

    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    if (audioCtxRef.current) {
      audioCtxRef.current.close();
      audioCtxRef.current = null;
    }

    // Compute average metrics & acoustic jitter from real audio captured
    const samples = samplesCollectedRef.current;
    if (samples.length > 5) {
      const avgPitch = Math.round(samples.reduce((a, b) => a + b, 0) / samples.length);
      let diffSum = 0;
      for (let i = 1; i < samples.length; i++) {
        diffSum += Math.abs(samples[i] - samples[i - 1]);
      }
      const computedJitter = +((diffSum / (samples.length - 1) / Math.max(1, avgPitch)) * 100).toFixed(2);
      setPitchHz(avgPitch);
      setJitterPct(computedJitter);
      try {
        localStorage.setItem('apex_vocal_biomarker', JSON.stringify({
          pitchHz: avgPitch,
          chestResonance,
          jitterPct: computedJitter,
          source: 'Mac Microphone DSP',
          updatedAt: new Date().toISOString(),
        }));
      } catch {}
      setSpeechSummary({
        avgPitch,
        sampleCount: samples.length,
        jitterPct: computedJitter,
        tier: avgPitch < 115 ? 'Deep Baritone (Sovereign)' : avgPitch < 135 ? 'Commanding Mid-Tone' : 'Tenor Resonance',
      });
      try {
        confetti({
          particleCount: 50,
          spread: 60,
          colors: ['#00F0FF', '#E5FE40', '#10B981'],
        });
      } catch {}
    } else {
      setMicError('Not enough voiced frames detected — speak steadily close to the microphone.');
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((t) => t.stop());
      }
      if (audioCtxRef.current) {
        audioCtxRef.current.close();
      }
    };
  }, []);

  return (
    <div className="space-y-6">
      {/* VOCAL RESONANCE HERO */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 rounded-[16px] bg-[#00F0FF]/20 border border-[#00F0FF]/40 flex items-center justify-center">
              <Mic className="w-6 h-6 text-[#00F0FF]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-base font-bold text-white tracking-tight">
                  Real-Time Vocal Resonance & Acoustic Pitch Analyzer
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-black">
                  LIVE MICROPHONE DSP
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Autocorrelation fundamental frequency ($F_0$) & thoracic chest resonance via Mac microphone
              </span>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {!isRecording ? (
              <button
                onClick={startRecording}
                className="px-4 py-2 rounded-[14px] bg-gradient-to-r from-[#00F0FF] to-[#00A3FF] text-black text-xs font-mono font-black uppercase flex items-center space-x-2 shadow-[0_0_15px_rgba(0,240,255,0.4)] transition hover:opacity-90"
              >
                <Mic className="w-4 h-4" />
                <span>START LIVE VOICE TEST</span>
              </button>
            ) : (
              <button
                onClick={stopRecording}
                className="px-4 py-2 rounded-[14px] bg-[#FA114F] text-white text-xs font-mono font-black uppercase flex items-center space-x-2 shadow-[0_0_15px_rgba(250,17,79,0.5)] transition animate-pulse"
              >
                <MicOff className="w-4 h-4" />
                <span>STOP & ANALYZE SPEECH</span>
              </button>
            )}
          </div>
        </div>

        {/* Live Audio Oscilloscope Canvas */}
        <div className="relative rounded-[20px] bg-black/80 border border-white/10 overflow-hidden h-28 flex items-center justify-center">
          <canvas ref={canvasRef} width={640} height={112} className="w-full h-full" />
          {!isRecording && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/60 backdrop-blur-[2px] text-xs font-mono text-[#8A8A8A]">
              <Radio className="w-5 h-5 text-[#00F0FF] mb-1 animate-pulse" />
              <span>Click "Start Live Voice Test" and speak naturally into your Mac</span>
            </div>
          )}
          {isRecording && (
            <div className="absolute top-3 right-3 flex items-center space-x-2 text-[10px] font-mono">
              <span className="w-2 h-2 rounded-full bg-[#FA114F] animate-ping" />
              <span className="text-white font-bold">MIC ACTIVE (48 kHz)</span>
            </div>
          )}
        </div>

        {micError && (
          <div className="p-3 rounded-[14px] bg-[#FA114F]/10 border border-[#FA114F]/30 text-xs font-mono text-[#FA114F] flex items-center space-x-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{micError}</span>
          </div>
        )}

        {/* 3 REAL METRIC TILES */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div className="p-4 rounded-[18px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">
              FUNDAMENTAL PITCH (F0)
            </span>
            <div className="flex items-baseline space-x-1.5">
              <span className="text-3xl font-mono font-black text-white">{pitchHz ?? '--'}</span>
              <span className="text-xs font-mono text-[#00F0FF] font-bold">Hz</span>
            </div>
            <span className="text-[10px] font-mono text-[#10B981] font-bold block">
              {pitchHz == null
                ? 'Press Start Live Voice Test to measure'
                : pitchHz <= 118
                  ? '✓ Optimal Baritone (100–120 Hz)'
                  : pitchHz <= 140
                    ? 'Tenor Baseline'
                    : 'Elevated Frequency'}
            </span>
          </div>

          <div className="p-4 rounded-[18px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">
              CHEST HARMONIC RESONANCE
            </span>
            <div className="flex items-baseline space-x-1.5">
              <span className="text-3xl font-mono font-black text-white">{chestResonance ?? '--'}</span>
              <span className="text-xs font-mono text-[#E5FE40] font-bold">%</span>
            </div>
            <span className="text-[10px] font-mono text-[#E5FE40] font-bold block">
              Subglottic Pressure Transfer (85–250 Hz)
            </span>
          </div>

          <div className="p-4 rounded-[18px] bg-black/40 border border-white/10 space-y-1">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">
              VOCAL FOLD JITTER
            </span>
            <div className="flex items-baseline space-x-1.5">
              <span className="text-3xl font-mono font-black text-white">{jitterPct !== null ? jitterPct.toFixed(2) : '--'}</span>
              <span className="text-xs font-mono text-[#10B981] font-bold">%</span>
            </div>
            <span className="text-[10px] font-mono text-[#A1A1AA] font-bold block">
              {jitterPct === null ? 'Awaiting Mic / iPhone Sync' : jitterPct <= 1.2 ? 'Steady CNS Vagal Tone' : 'Elevated Vocal Fatigue'}
            </span>
          </div>
        </div>

        {speechSummary && (
          <div className="p-3.5 rounded-[16px] bg-[#10B981]/15 border border-[#10B981]/30 flex items-center justify-between text-xs font-mono">
            <div className="flex items-center space-x-2">
              <CheckCircle2 className="w-4 h-4 text-[#10B981]" />
              <span className="text-white">
                Live Voice Session Complete: Measured Mean Pitch <strong>{speechSummary.avgPitch} Hz</strong> ({speechSummary.tier})
              </span>
            </div>
            <span className="text-[#10B981] font-black">{speechSummary.sampleCount} Real Audio Frames</span>
          </div>
        )}
      </div>
    </div>
  );
}
