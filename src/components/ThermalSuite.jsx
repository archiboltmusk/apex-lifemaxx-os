import React, { useState, useEffect } from 'react';
import { Snowflake, Flame, Play, Pause, RotateCcw, Heart, ShieldCheck, Zap } from 'lucide-react';
import { playPlunk, playCoinChime, playHaptic } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function ThermalSuite() {
  const [activeMode, setActiveMode] = useState('cold'); // 'cold' | 'heat'
  const [timerSeconds, setTimerSeconds] = useState(180); // 3 mins default
  const [isRunning, setIsRunning] = useState(false);

  useEffect(() => {
    let interval = null;
    if (isRunning && timerSeconds > 0) {
      interval = setInterval(() => {
        setTimerSeconds((prev) => prev - 1);
      }, 1000);
    } else if (timerSeconds === 0 && isRunning) {
      setIsRunning(false);
      playCoinChime();
      try {
        confetti({
          particleCount: 70,
          spread: 70,
          colors: activeMode === 'cold' ? ['#00D6E6', '#00F0FF', '#FFFFFF'] : ['#FA114F', '#F59E0B', '#E5FE40'],
        });
      } catch {}
    }
    return () => clearInterval(interval);
  }, [isRunning, timerSeconds, activeMode]);

  const toggleTimer = () => {
    playPlunk();
    setIsRunning(!isRunning);
  };

  const resetTimer = (secs) => {
    playPlunk();
    setIsRunning(false);
    setTimerSeconds(secs);
  };

  return (
    <div className="space-y-6">
      {/* MODE TOGGLE */}
      <div className="flex items-center space-x-2 border-b border-white/10 pb-3">
        <button
          onClick={() => {
            playPlunk();
            setActiveMode('cold');
            resetTimer(180);
          }}
          className={`px-4 py-2 rounded-[14px] text-xs font-mono font-bold flex items-center space-x-2 transition ${
            activeMode === 'cold'
              ? 'bg-[#00F0FF] text-black font-black shadow-[0_0_15px_rgba(0,240,255,0.4)]'
              : 'bg-white/5 text-[#8A8A8A] hover:text-white'
          }`}
        >
          <Snowflake className="w-4 h-4" />
          <span>Cryo Cold Plunge (RBM3 Protein)</span>
        </button>

        <button
          onClick={() => {
            playPlunk();
            setActiveMode('heat');
            resetTimer(1200); // 20 mins default
          }}
          className={`px-4 py-2 rounded-[14px] text-xs font-mono font-bold flex items-center space-x-2 transition ${
            activeMode === 'heat'
              ? 'bg-[#FA114F] text-white font-black shadow-[0_0_15px_rgba(250,17,79,0.4)]'
              : 'bg-white/5 text-[#8A8A8A] hover:text-white'
          }`}
        >
          <Flame className="w-4 h-4" />
          <span>Finnish Sauna (HSP70 Heat Shock)</span>
        </button>
      </div>

      {/* COLD COCKPIT */}
      {activeMode === 'cold' && (
        <div className="space-y-4">
          <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 text-center space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-mono text-[#00F0FF] font-black uppercase tracking-widest">
                CRYO SHOCK TEMPERATURE: 4°C (39°F)
              </span>
              <span className="text-xs font-mono text-[#10B981] font-bold">RBM3 PROTEIN INDUCTION</span>
            </div>

            <div className="text-5xl md:text-6xl font-mono font-black text-white my-3">
              {Math.floor(timerSeconds / 60).toString().padStart(2, '0')}:
              {(timerSeconds % 60).toString().padStart(2, '0')}
            </div>

            <p className="text-xs font-mono text-[#A1A1AA] max-w-sm mx-auto">
              Focus on unhurried nasal exhalation. Suppress the shivering reflex to trigger vagal autonomic adaptation.
            </p>

            <div className="flex items-center justify-center space-x-3 max-w-xs mx-auto">
              <button
                onClick={toggleTimer}
                className="flex-1 py-3.5 rounded-[14px] cred-plunk-primary text-xs font-mono font-black uppercase flex items-center justify-center space-x-2"
              >
                {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                <span>{isRunning ? 'PAUSE TIMER' : 'START 3m PLUNGE'}</span>
              </button>
              <button
                onClick={() => resetTimer(180)}
                className="px-4 py-3.5 rounded-[14px] cred-plunk-dark text-xs font-mono font-bold"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs font-mono">
            <div className="liquid-glass rounded-[18px] p-4 border border-white/10 space-y-1">
              <span className="text-[10px] text-[#8A8A8A] block">RBM3 SYNAPSE PRESERVATION</span>
              <span className="text-lg font-bold text-[#00F0FF]">Optimal Neurogenesis</span>
              <p className="text-[10px] text-[#A1A1AA]">
                Cold shock protein RBM3 regenerates lost dendritic spines and prevents neurodegeneration.
              </p>
            </div>

            <div className="liquid-glass rounded-[18px] p-4 border border-white/10 space-y-1">
              <span className="text-[10px] text-[#8A8A8A] block">NOREPINEPHRINE & DOPAMINE SPIKE</span>
              <span className="text-lg font-bold text-[#10B981]">+250% Sustained for 4 Hours</span>
              <p className="text-[10px] text-[#A1A1AA]">
                Provides clean non-jittery wakefulness and activates brown adipose tissue thermogenesis.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* HEAT COCKPIT */}
      {activeMode === 'heat' && (
        <div className="space-y-4">
          <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 text-center space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-mono text-[#FA114F] font-black uppercase tracking-widest">
                FINNISH TRADITIONAL SAUNA: 90°C (194°F)
              </span>
              <span className="text-xs font-mono text-[#E5FE40] font-bold">HSP70 CELLULAR CLEANUP</span>
            </div>

            <div className="text-5xl md:text-6xl font-mono font-black text-white my-3">
              {Math.floor(timerSeconds / 60).toString().padStart(2, '0')}:
              {(timerSeconds % 60).toString().padStart(2, '0')}
            </div>

            <p className="text-xs font-mono text-[#A1A1AA] max-w-sm mx-auto">
              High thermal stress mimicking moderate cardiovascular exercise. Heart rate reaches 120-140 bpm.
            </p>

            <div className="flex items-center justify-center space-x-3 max-w-xs mx-auto">
              <button
                onClick={toggleTimer}
                className="flex-1 py-3.5 rounded-[14px] bg-[#FA114F] text-white font-mono font-black text-xs uppercase flex items-center justify-center space-x-2 border-2 border-black shadow-[3px_3px_0px_#000]"
              >
                {isRunning ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                <span>{isRunning ? 'PAUSE SAUNA' : 'START 20m SESSION'}</span>
              </button>
              <button
                onClick={() => resetTimer(1200)}
                className="px-4 py-3.5 rounded-[14px] cred-plunk-dark text-xs font-mono font-bold"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs font-mono">
            <div className="liquid-glass rounded-[18px] p-4 border border-white/10 space-y-1">
              <span className="text-[10px] text-[#8A8A8A] block">HEAT SHOCK PROTEIN 70 (HSP70)</span>
              <span className="text-lg font-bold text-[#FA114F]">Max Autophagy Induction</span>
              <p className="text-[10px] text-[#A1A1AA]">
                Repairs misfolded proteins and induces vascular nitric oxide synthesis for arterial elasticity.
              </p>
            </div>

            <div className="liquid-glass rounded-[18px] p-4 border border-white/10 space-y-1">
              <span className="text-[10px] text-[#8A8A8A] block">GROWTH HORMONE SPIKE</span>
              <span className="text-lg font-bold text-[#E5FE40]">+300% Post-Session</span>
              <p className="text-[10px] text-[#A1A1AA]">
                Accelerates recovery from heavy lifting sessions and improves plasma volume expansion.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
