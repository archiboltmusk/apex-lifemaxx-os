import React, { useState } from 'react';
import { Volume2, VolumeX, Sparkles, Brain, Moon, Zap, Waves, Play, Pause, RotateCcw } from 'lucide-react';
import { toggleBinaural, toggleBrownNoise, FREQUENCIES, playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function NeuralSoundEngine() {
  const [activeFreq, setActiveFreq] = useState(null); // 'gamma' | 'alpha' | 'theta' | 'delta' | null
  const [isBrownNoiseOn, setIsBrownNoiseOn] = useState(false);
  const [nsdrActive, setNsdrActive] = useState(false);
  const [nsdrMinutes, setNsdrMinutes] = useState(10);
  const [nsdrSeconds, setNsdrSeconds] = useState(0);

  const handleSelectFreq = (key) => {
    playPlunk();
    if (activeFreq === key) {
      toggleBinaural(key, false);
      setActiveFreq(null);
    } else {
      toggleBinaural(key, true);
      setActiveFreq(key);
    }
  };

  const handleToggleBrownNoise = () => {
    playPlunk();
    const next = !isBrownNoiseOn;
    setIsBrownNoiseOn(next);
    toggleBrownNoise(next);
  };

  const toggleNSDR = () => {
    playPlunk();
    if (!nsdrActive) {
      handleSelectFreq('theta');
      setNsdrMinutes(10);
      setNsdrSeconds(0);
    } else {
      if (activeFreq === 'theta') toggleBinaural('theta', false);
      setActiveFreq(null);
    }
    setNsdrActive(!nsdrActive);
  };

  return (
    <div className="space-y-6">
      {/* MULTI-FREQUENCY BINAURAL MATRIX */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#8B5CF6]/20 border border-[#8B5CF6]/40 flex items-center justify-center">
              <Brain className="w-5 h-5 text-[#8B5CF6]" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-white tracking-tight">
                Multi-Frequency Neural Entrainment Engine
              </h3>
              <p className="text-[11px] font-mono text-[#8A8A8A]">
                Dual-oscillator stereo binaural carrier synthesis (Web Audio API)
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={handleToggleBrownNoise}
              className={`px-3 py-1.5 rounded-[12px] text-xs font-mono font-bold border transition flex items-center space-x-1.5 ${
                isBrownNoiseOn
                  ? 'bg-[#E5FE40] text-black border-[#E5FE40] shadow-[0_0_12px_rgba(229,254,64,0.6)]'
                  : 'bg-white/5 text-[#8A8A8A] border-white/10 hover:text-white'
              }`}
            >
              <Waves className="w-3.5 h-3.5" />
              <span>{isBrownNoiseOn ? 'BROWN NOISE ACTIVE' : 'BROWN NOISE'}</span>
            </button>
          </div>
        </div>

        {/* 4 Frequency Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { key: 'gamma', label: '40Hz Gamma', state: 'Flow State', color: '#8B5CF6', desc: 'Focus & complex problem solving' },
            { key: 'alpha', label: '10Hz Alpha', state: 'Calm Alert', color: '#00F0FF', desc: 'Lateral thinking & relaxed attention' },
            { key: 'theta', label: '6Hz Theta', state: 'Deep Insight', color: '#E5FE40', desc: 'Hypnagogia & creative synthesis' },
            { key: 'delta', label: '2Hz Delta', state: 'Deep Sleep', color: '#10B981', desc: 'Slow-wave stage 4 sleep induction' },
          ].map((f) => {
            const isPlaying = activeFreq === f.key;
            return (
              <div
                key={f.key}
                onClick={() => handleSelectFreq(f.key)}
                className={`p-4 rounded-[18px] border transition cursor-pointer relative ${
                  isPlaying
                    ? 'bg-white/15 border-white/40 shadow-[0_0_20px_rgba(139,92,246,0.3)] scale-102'
                    : 'bg-black/40 border-white/10 hover:border-white/25'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <span
                    className="text-[10px] font-mono font-black uppercase px-2 py-0.5 rounded-full"
                    style={{ backgroundColor: `${f.color}20`, color: f.color }}
                  >
                    {f.state}
                  </span>
                  {isPlaying ? (
                    <Volume2 className="w-4 h-4 text-white animate-pulse" />
                  ) : (
                    <VolumeX className="w-4 h-4 text-[#8A8A8A]" />
                  )}
                </div>

                <h4 className="text-sm font-mono font-bold text-white">{f.label}</h4>
                <p className="text-[11px] text-[#A1A1AA] mt-1">{f.desc}</p>
              </div>
            );
          })}
        </div>

        {/* Visual Audio Waveform */}
        {(activeFreq || isBrownNoiseOn) && (
          <div className="p-3 rounded-[16px] bg-black/60 border border-white/10 flex items-center justify-between text-xs font-mono">
            <span className="text-white flex items-center space-x-2">
              <span className="w-2 h-2 rounded-full bg-[#10B981] animate-ping" />
              <span>
                Playing: {activeFreq ? FREQUENCIES[activeFreq]?.label : 'Deep Brown Noise'}
              </span>
            </span>

            {/* Sound wave bars */}
            <div className="flex items-center space-x-1">
              {[4, 12, 8, 16, 6, 14, 10, 18, 7, 13, 9].map((h, i) => (
                <span
                  key={i}
                  className="w-1 bg-[#8B5CF6] rounded-full animate-bounce"
                  style={{ height: `${h}px`, animationDelay: `${i * 0.08}s` }}
                />
              ))}
            </div>
          </div>
        )}
      </div>

      {/* HUBERMAN NSDR (NON-SLEEP DEEP REST) COACH */}
      <div className="liquid-glass rounded-[24px] p-6 border border-white/10 flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="space-y-1.5 max-w-md">
          <div className="flex items-center space-x-2">
            <Moon className="w-5 h-5 text-[#38BDF8]" />
            <h4 className="text-base font-bold text-white tracking-tight">
              Huberman 10-Min NSDR (Non-Sleep Deep Rest)
            </h4>
          </div>
          <p className="text-xs text-[#A1A1AA] leading-relaxed">
            Restores striatal dopamine reserves, decreases cortisol by 40%, and accelerates motor skill consolidation without grogginess.
          </p>
        </div>

        <button
          onClick={toggleNSDR}
          className={`px-6 py-3.5 rounded-[14px] text-xs font-mono font-black uppercase flex items-center space-x-2 transition ${
            nsdrActive ? 'bg-[#38BDF8] text-black shadow-[0_0_15px_#38BDF8]' : 'cred-plunk-primary'
          }`}
        >
          {nsdrActive ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
          <span>{nsdrActive ? 'PAUSE NSDR SESSION' : 'BEGIN 10m NSDR PROTOCOL'}</span>
        </button>
      </div>
    </div>
  );
}
