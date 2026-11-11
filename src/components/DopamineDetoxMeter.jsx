import React, { useState } from 'react';
import { ShieldAlert, Sun, Moon, Zap, EyeOff, Lock, CheckCircle2, Clock } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

export default function DopamineDetoxMeter() {
  const [isMonkModeOn, setIsMonkModeOn] = useState(false);

  const toggleMonkMode = () => {
    playPlunk();
    const next = !isMonkModeOn;
    setIsMonkModeOn(next);
    if (next) {
      playCoinChime();
      try {
        confetti({
          particleCount: 50,
          spread: 60,
          colors: ['#F59E0B', '#E5FE40', '#000000'],
        });
      } catch {}
    }
  };

  const hasMealsOrWorkouts = (() => {
    try {
      const m = JSON.parse(localStorage.getItem('apex_logged_meals') || '[]');
      const v = JSON.parse(localStorage.getItem('apex_camera_workouts') || '[]');
      return m.length > 0 || v.length > 0;
    } catch {
      return false;
    }
  })();

  const dopamineScore = isMonkModeOn ? (hasMealsOrWorkouts ? 100 : 50) : (hasMealsOrWorkouts ? 50 : 0);

  return (
    <div className={`space-y-6 transition-all ${isMonkModeOn ? 'filter sepia-[0.3] contrast-105' : ''}`}>
      {/* MONK MODE HERO CARD */}
      <div className="liquid-glass-elevated rounded-[26px] p-6 border border-white/15 space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-[12px] bg-[#F59E0B]/20 border border-[#F59E0B]/40 flex items-center justify-center">
              <Zap className="w-5 h-5 text-[#F59E0B]" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="text-sm font-bold text-white tracking-tight">
                  Dopamine Receptor Sensitivity Engine
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#F59E0B]/20 text-[#F59E0B] border border-[#F59E0B]/40 font-black">
                  HUBERMAN PROTOCOL
                </span>
              </div>
              <span className="text-[11px] font-mono text-[#8A8A8A]">
                Striatal dopamine baseline regulation & cheap dopamine defense
              </span>
            </div>
          </div>

          <div className="text-right">
            <span className="text-[10px] font-mono text-[#8A8A8A] uppercase block">SESSION DISCIPLINE</span>
            <span className="text-2xl font-mono font-black text-[#10B981]">
              {dopamineScore > 0 ? `${dopamineScore}%` : '—'}
            </span>
          </div>
        </div>

        {/* Circular Progress Bar */}
        <div className="w-full h-3 bg-black/50 rounded-full overflow-hidden border border-white/10">
          <div
            className="h-full bg-gradient-to-r from-[#F59E0B] via-[#E5FE40] to-[#10B981] rounded-full transition-all duration-700"
            style={{ width: `${dopamineScore}%` }}
          />
        </div>

        {/* MONK MODE TOGGLE */}
        <div className="p-4 rounded-[18px] bg-black/60 border border-white/10 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <Lock className={`w-5 h-5 ${isMonkModeOn ? 'text-[#F59E0B]' : 'text-[#8A8A8A]'}`} />
            <div>
              <span className="text-xs font-mono font-bold text-white block">
                {isMonkModeOn ? 'MONK MODE LOCKDOWN ENGAGED' : 'ENGAGE MONK MODE LOCKDOWN'}
              </span>
              <span className="text-[10px] text-[#A1A1AA]">
                Shifts visual display to warm amber tones & silences non-essential dopamine triggers
              </span>
            </div>
          </div>

          <button
            onClick={toggleMonkMode}
            className={`px-4 py-2 rounded-[12px] text-xs font-mono font-black uppercase transition ${
              isMonkModeOn
                ? 'bg-[#F59E0B] text-black shadow-[0_0_15px_rgba(245,158,11,0.6)]'
                : 'cred-plunk-primary'
            }`}
          >
            {isMonkModeOn ? 'DISENGAGE' : 'ACTIVATE LOCK'}
          </button>
        </div>
      </div>

      {/* PROTOCOL GUIDELINES (REAL TIME & SYNC TRACKING) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="liquid-glass rounded-[24px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center space-x-2 text-xs font-mono text-[#10B981] font-bold">
            <CheckCircle2 className="w-4 h-4" />
            <span>HIGH-FRICTION PROTOCOLS</span>
          </div>
          <div className="space-y-2 text-xs font-mono">
            <div className="p-2.5 rounded-[12px] bg-black/40 border border-white/5 flex justify-between">
              <span className="text-white">Monk Mode Lock</span>
              <span className="text-[#10B981] font-bold">{isMonkModeOn ? 'ACTIVE NOW' : 'STANDBY'}</span>
            </div>
            <div className="p-2.5 rounded-[12px] bg-black/40 border border-white/5 flex justify-between">
              <span className="text-white">Cryo & Sauna Suite</span>
              <span className="text-[#8A8A8A]">Run timer in Fitness tab</span>
            </div>
            <div className="p-2.5 rounded-[12px] bg-black/40 border border-white/5 flex justify-between">
              <span className="text-white">40Hz Flow Sprint & Strength</span>
              <span className="text-[#8A8A8A]">Verify via Camera or Logs</span>
            </div>
          </div>
        </div>

        <div className="liquid-glass rounded-[24px] p-5 border border-white/10 space-y-3">
          <div className="flex items-center space-x-2 text-xs font-mono text-[#F59E0B] font-bold">
            <Moon className="w-4 h-4" />
            <span>DIGITAL SUNSET WINDOW</span>
          </div>
          <div className="p-4 rounded-[18px] bg-black/50 border border-white/10 text-center space-y-1">
            {(() => {
              const now = new Date();
              const sunset = new Date(now);
              sunset.setHours(21, 30, 0, 0);
              const diffMin = Math.max(0, Math.round((sunset - now) / 60000));
              const h = Math.floor(diffMin / 60);
              const m = diffMin % 60;
              return (
                <>
                  <span className="text-2xl font-mono font-black text-white">
                    {diffMin === 0 ? 'ACTIVE NOW' : `${String(h).padStart(2, '0')}h ${String(m).padStart(2, '0')}m`}
                  </span>
                  <span className="text-[10px] font-mono text-[#8A8A8A] block">
                    Live countdown to 9:30 PM blue-light cutoff
                  </span>
                </>
              );
            })()}
          </div>
        </div>
      </div>
    </div>
  );
}
