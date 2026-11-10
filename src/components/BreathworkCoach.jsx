import React, { useState, useEffect } from 'react';
import { Wind, Play, Pause, RotateCcw, Heart, Sparkles, Check } from 'lucide-react';
import { playPlunk, playHaptic, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const PROTOCOLS = [
  {
    id: 'box',
    name: 'Box Breathing (4-4-4-4)',
    tag: 'Parasympathetic Reset',
    desc: 'Navy SEAL acute stress neutralizer. 4s inhale, 4s hold, 4s exhale, 4s hold.',
    inhale: 4,
    hold1: 4,
    exhale: 4,
    hold2: 4,
  },
  {
    id: 'sigh',
    name: 'Physiological Sigh',
    tag: 'Huberman Autonomic Reset',
    desc: 'Double nasal inhale followed by long unhurried mouth exhale. Immediately drops heart rate.',
    inhale: 3,
    hold1: 1,
    exhale: 6,
    hold2: 1,
  },
  {
    id: 'wimhof',
    name: 'Oxygen Surge (4-0-4-0)',
    tag: 'Mitochondrial Awakening',
    desc: 'Deep rhythmic oxygenation for adrenaline activation and mental clarity.',
    inhale: 3,
    hold1: 0,
    exhale: 2,
    hold2: 0,
  },
];

export default function BreathworkCoach() {
  const [selectedProto, setSelectedProto] = useState(PROTOCOLS[0]);
  const [isActive, setIsActive] = useState(false);
  const [phase, setPhase] = useState('READY'); // 'INHALE' | 'HOLD' | 'EXHALE' | 'HOLD'
  const [phaseSeconds, setPhaseSeconds] = useState(4);
  const [cyclesCompleted, setCyclesCompleted] = useState(0);

  useEffect(() => {
    let timer = null;
    if (isActive) {
      timer = setInterval(() => {
        setPhaseSeconds((prev) => {
          if (prev <= 1) {
            // Transition to next phase
            playHaptic(550, 'sine', 0.05);
            if (phase === 'READY' || phase === 'HOLD_AFTER_EXHALE' || phase === 'HOLD2') {
              setPhase('INHALE');
              return selectedProto.inhale;
            } else if (phase === 'INHALE') {
              if (selectedProto.hold1 > 0) {
                setPhase('HOLD');
                return selectedProto.hold1;
              } else {
                setPhase('EXHALE');
                return selectedProto.exhale;
              }
            } else if (phase === 'HOLD') {
              setPhase('EXHALE');
              return selectedProto.exhale;
            } else if (phase === 'EXHALE') {
              setCyclesCompleted((c) => {
                const next = c + 1;
                if (next % 4 === 0) {
                  playCoinChime();
                  try {
                    confetti({
                      particleCount: 40,
                      spread: 50,
                      colors: ['#00D6E6', '#E5FE40'],
                    });
                  } catch {}
                }
                return next;
              });
              if (selectedProto.hold2 > 0) {
                setPhase('HOLD2');
                return selectedProto.hold2;
              } else {
                setPhase('INHALE');
                return selectedProto.inhale;
              }
            }
          }
          return prev - 1;
        });
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [isActive, phase, selectedProto]);

  const toggleSession = () => {
    playPlunk();
    if (!isActive) {
      setPhase('INHALE');
      setPhaseSeconds(selectedProto.inhale);
    }
    setIsActive(!isActive);
  };

  const resetSession = () => {
    playPlunk();
    setIsActive(false);
    setPhase('READY');
    setPhaseSeconds(selectedProto.inhale);
    setCyclesCompleted(0);
  };

  // Determine breathing bubble scale & color
  let scaleClass = 'scale-90';
  let phaseText = 'TAP START TO BREATHE';
  let phaseColor = '#8A8A8A';

  if (phase === 'INHALE') {
    scaleClass = 'scale-125';
    phaseText = 'INHALE DEEPLY';
    phaseColor = '#00F0FF';
  } else if (phase === 'HOLD' || phase === 'HOLD2') {
    scaleClass = 'scale-120';
    phaseText = 'HOLD STILL';
    phaseColor = '#E5FE40';
  } else if (phase === 'EXHALE') {
    scaleClass = 'scale-85';
    phaseText = 'SLOW EXHALE';
    phaseColor = '#10B981';
  }

  return (
    <div className="space-y-6">
      {/* PROTOCOL SELECTOR */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
        {PROTOCOLS.map((p) => {
          const isSelected = selectedProto.id === p.id;
          return (
            <div
              key={p.id}
              onClick={() => {
                playPlunk();
                setSelectedProto(p);
                resetSession();
              }}
              className={`p-3.5 rounded-[18px] border transition cursor-pointer ${
                isSelected
                  ? 'bg-white/10 border-white/40 shadow-[0_0_15px_rgba(0,240,255,0.15)]'
                  : 'bg-white/[0.03] border-white/10 hover:border-white/20'
              }`}
            >
              <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase block">
                {p.tag}
              </span>
              <h4 className="text-xs font-bold text-white mt-0.5">{p.name}</h4>
              <p className="text-[10px] text-[#A1A1AA] line-clamp-2 mt-1">{p.desc}</p>
            </div>
          );
        })}
      </div>

      {/* INTERACTIVE BREATHING BUBBLE HERO */}
      <div className="liquid-glass-elevated rounded-[28px] p-8 border border-white/20 flex flex-col items-center justify-center relative overflow-hidden">
        <div className="absolute top-4 left-6 flex items-center space-x-2 text-xs font-mono">
          <Heart className="w-4 h-4 text-[#10B981]" />
          <span className="text-white font-bold">CYCLES: {cyclesCompleted}</span>
        </div>

        {/* Dynamic Expanding/Contracting Breathing Orb */}
        <div className="my-8 relative w-56 h-56 flex items-center justify-center">
          {/* Ambient Glow Ring */}
          <div
            className={`absolute inset-0 rounded-full blur-2xl opacity-40 transition-all duration-1000 ${scaleClass}`}
            style={{ backgroundColor: phaseColor }}
          />

          {/* Concentric Pulsing Glass Rings */}
          <div
            className={`w-48 h-48 rounded-full border border-white/20 flex items-center justify-center transition-all duration-1000 ${scaleClass}`}
            style={{
              background: `radial-gradient(circle, ${phaseColor}25 0%, rgba(0,0,0,0.6) 80%)`,
            }}
          >
            <div className="text-center select-none">
              <span
                className="text-xs font-mono font-black tracking-widest block uppercase mb-1"
                style={{ color: phaseColor }}
              >
                {phaseText}
              </span>
              <span className="text-5xl font-mono font-black text-white">
                {isActive ? phaseSeconds : '—'}
              </span>
            </div>
          </div>
        </div>

        {/* Controls */}
        <div className="flex items-center space-x-3 w-full max-w-xs">
          <button
            onClick={toggleSession}
            className="flex-1 py-3.5 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
          >
            {isActive ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
            <span>{isActive ? 'PAUSE COACH' : 'BEGIN BREATHING'}</span>
          </button>
          <button
            onClick={resetSession}
            className="px-4 py-3.5 rounded-[14px] cred-plunk-dark text-xs font-mono font-bold"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
