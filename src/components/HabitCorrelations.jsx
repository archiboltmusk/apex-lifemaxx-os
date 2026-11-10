import React, { useState } from 'react';
import { ShieldCheck, Check, Plus, TrendingUp, TrendingDown, Moon, Sun, Snowflake, Zap, AlertTriangle } from 'lucide-react';
import { playPlunk, playCoinChime } from '../utils/audioSynth';
import confetti from 'canvas-confetti';

const INITIAL_HABITS = [
  { id: 'h1', title: 'Cryo Plunge (4°C for 3m)', impact: '+18% HRV', type: 'positive', desc: 'Sustained dopamine and vagal tone spike', checked: true },
  { id: 'h2', title: '15m Direct Morning Lux', impact: '+14% Recovery', type: 'positive', desc: 'Suppresses melatonin, calibrates peripheral clocks', checked: true },
  { id: 'h3', title: 'Mouth Taping for Sleep', impact: '+24% Deep Sleep', type: 'positive', desc: 'Promotes nasal nitric oxide production & zero apnea', checked: true },
  { id: 'h4', title: 'Magnesium L-Threonate (144mg)', impact: '+16% REM Sleep', type: 'positive', desc: 'Crosses blood-brain barrier for synaptic density', checked: true },
  { id: 'h5', title: 'Zero Food 3h Before Bed', impact: '+19% Recovery', type: 'positive', desc: 'Allows resting heart rate to reach true baseline', checked: false },
  { id: 'h6', title: 'Blue Light Glasses After 8 PM', impact: '+12% HRV', type: 'positive', desc: 'Prevents pineal gland phase delay', checked: false },
  { id: 'h7', title: 'Alcohol Consumption (0g)', impact: '+42% Recovery', type: 'positive', desc: 'Zero REM suppression or toxic acetaldehyde load', checked: true },
];

export default function HabitCorrelations() {
  const [habits, setHabits] = useState(INITIAL_HABITS);

  const toggleHabit = (id) => {
    playPlunk();
    setHabits((prev) =>
      prev.map((h) => {
        if (h.id === id) {
          const next = !h.checked;
          if (next) {
            playCoinChime();
          }
          return { ...h, checked: next };
        }
        return h;
      })
    );
  };

  return (
    <div className="space-y-6">
      <div className="liquid-glass-elevated rounded-[24px] p-6 border border-white/15">
        <div className="flex items-center justify-between mb-4">
          <div>
            <span className="text-[10px] font-mono text-[#10B981] font-black uppercase tracking-widest">
              WHOOP JOURNAL CORRELATION MATRIX
            </span>
            <h3 className="text-base font-bold text-white tracking-tight">
              Behavioral Impact on HRV & Autonomic Recovery
            </h3>
          </div>
          <span className="text-xs font-mono px-3 py-1 rounded-full bg-[#10B981]/20 text-[#10B981] border border-[#10B981]/40 font-bold">
            94ms HRV BASELINE
          </span>
        </div>

        <p className="text-xs text-[#A1A1AA] mb-4">
          Statistically verified correlations between your recorded daily habits and next-morning autonomic recovery (SDNN HRV).
        </p>

        {/* Habit list */}
        <div className="space-y-2.5">
          {habits.map((habit) => (
            <div
              key={habit.id}
              onClick={() => toggleHabit(habit.id)}
              className={`p-3.5 rounded-[16px] border transition cursor-pointer flex items-center justify-between ${
                habit.checked
                  ? 'bg-white/[0.04] border-white/15'
                  : 'bg-black/30 border-white/5 opacity-60'
              }`}
            >
              <div className="flex items-center space-x-3.5">
                <div
                  className={`w-6 h-6 rounded-[8px] flex items-center justify-center border transition ${
                    habit.checked
                      ? 'bg-[#10B981] border-[#10B981] text-black font-bold shadow-[0_0_8px_rgba(16,185,129,0.5)]'
                      : 'border-white/20 bg-black/40'
                  }`}
                >
                  {habit.checked && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                </div>
                <div>
                  <h4 className="text-xs font-mono font-bold text-white">{habit.title}</h4>
                  <span className="text-[11px] text-[#8A8A8A]">{habit.desc}</span>
                </div>
              </div>

              <div className="flex items-center space-x-1.5 px-2.5 py-1 rounded-full bg-[#10B981]/15 border border-[#10B981]/30 text-xs font-mono font-bold text-[#10B981]">
                <TrendingUp className="w-3.5 h-3.5" />
                <span>{habit.impact}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
